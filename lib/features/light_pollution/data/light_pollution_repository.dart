import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/light_pollution.dart';

abstract interface class LightPollutionCacheStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

final class SharedPreferencesLightPollutionStore
    implements LightPollutionCacheStore {
  SharedPreferencesLightPollutionStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();
  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> getString(String key) => _preferences.getString(key);
  @override
  Future<void> setString(String key, String value) =>
      _preferences.setString(key, value);
  @override
  Future<void> remove(String key) => _preferences.remove(key);
}

final class LightPollutionSnapshot {
  const LightPollutionSnapshot({
    required this.reading,
    required this.fromCache,
    required this.isStale,
    this.refreshError,
    this.checkedAtUtc,
  });

  final LightPollutionReading? reading;
  final bool fromCache;
  final bool isStale;
  final String? refreshError;

  /// When this location/provider value was fetched, distinct from datasetDate.
  final DateTime? checkedAtUtc;
}

/// Coordinate + provider-version keyed cache. Entries contain their retrieval
/// date and retain their actual dataset date, never masquerading as live data.
final class LightPollutionRepository {
  LightPollutionRepository({
    required this.provider,
    LightPollutionCacheStore? cache,
    this.maximumAge = const Duration(days: 30),
    DateTime Function()? now,
  }) : _cache = cache ?? SharedPreferencesLightPollutionStore(),
       _now = now ?? DateTime.now;

  final LightPollutionProvider provider;
  final LightPollutionCacheStore _cache;
  final Duration maximumAge;
  final DateTime Function() _now;
  static const prefix = 'astromanager.light-pollution.v1.';

  String cacheKey(double latitude, double longitude) =>
      '$prefix${sha256.convert(utf8.encode('${provider.id}|$latitude|$longitude'))}';

  Future<({LightPollutionReading reading, DateTime checkedAt})?> _readCache(
    double latitude,
    double longitude,
  ) async {
    final key = cacheKey(latitude, longitude);
    final raw = await _cache.getString(key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final reading = LightPollutionReading.fromJson(
        json['reading'] as Map<String, dynamic>,
      );
      final checkedAt = DateTime.parse(json['checkedAt'] as String).toUtc();
      if (reading.sourceId != provider.id ||
          reading.latitude != latitude ||
          reading.longitude != longitude ||
          !checkedAt.isUtc) {
        throw const FormatException('Location/source cache mismatch.');
      }
      return (reading: reading, checkedAt: checkedAt);
    } catch (_) {
      await _cache.remove(key);
      return null;
    }
  }

  /// Reads ONLY the existing cache. Never calls the upstream VIIRS service.
  /// Stale readings stay identifiable rather than being presented as live data.
  Future<LightPollutionSnapshot> cachedOnly({
    required double latitude,
    required double longitude,
  }) async {
    if (!latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180) {
      throw ArgumentError('Invalid observing coordinates.');
    }
    final cached = await _readCache(latitude, longitude);
    if (cached == null) {
      return const LightPollutionSnapshot(
        reading: null,
        fromCache: true,
        isStale: false,
      );
    }
    final age = _now().toUtc().difference(cached.checkedAt);
    return LightPollutionSnapshot(
      reading: cached.reading,
      fromCache: true,
      isStale: age.isNegative || age > maximumAge,
      checkedAtUtc: cached.checkedAt,
    );
  }

  Future<LightPollutionSnapshot> load({
    required double latitude,
    required double longitude,
    bool forceRefresh = false,
  }) async {
    if (!latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180) {
      throw ArgumentError('Invalid observing coordinates.');
    }
    final cached = await _readCache(latitude, longitude);
    final now = _now().toUtc();
    final age = cached == null ? null : now.difference(cached.checkedAt);
    final cacheFresh = age != null && !age.isNegative && age <= maximumAge;
    if (cached != null && cacheFresh && !forceRefresh) {
      return LightPollutionSnapshot(
        reading: cached.reading,
        fromCache: true,
        isStale: false,
        checkedAtUtc: cached.checkedAt,
      );
    }
    try {
      final value = await provider.fetch(
        latitude: latitude,
        longitude: longitude,
      );
      if (value != null) {
        value.validate();
        if (value.sourceId != provider.id ||
            value.latitude != latitude ||
            value.longitude != longitude) {
          throw const FormatException('Unexpected provider location/source.');
        }
        await _cache.setString(
          cacheKey(latitude, longitude),
          jsonEncode({
            'checkedAt': now.toIso8601String(),
            'reading': value.toJson(),
          }),
        );
      } else {
        // A genuine no-data result must not be replaced by a stale reading.
        await _cache.remove(cacheKey(latitude, longitude));
      }
      return LightPollutionSnapshot(
        reading: value,
        fromCache: false,
        isStale: false,
        checkedAtUtc: value == null ? null : now,
      );
    } catch (error) {
      if (cached != null) {
        return LightPollutionSnapshot(
          reading: cached.reading,
          fromCache: true,
          isStale: !cacheFresh,
          checkedAtUtc: cached.checkedAt,
          refreshError: error.toString(),
        );
      }
      rethrow;
    }
  }
}
