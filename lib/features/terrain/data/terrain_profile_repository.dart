import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../locations/domain/models/observing_location.dart';
import '../domain/terrain_horizon.dart';

abstract interface class TerrainProfileStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
  Future<Set<String>> getKeys();
}

final class SharedPreferencesTerrainProfileStore
    implements TerrainProfileStore {
  SharedPreferencesTerrainProfileStore([SharedPreferencesAsync? preferences])
    : _prefs = preferences ?? SharedPreferencesAsync();
  final SharedPreferencesAsync _prefs;
  @override
  Future<String?> getString(String key) => _prefs.getString(key);
  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
  @override
  Future<void> remove(String key) => _prefs.remove(key);
  @override
  Future<Set<String>> getKeys() => _prefs.getKeys();
}

/// Derived caches are intentionally not part of the user-data backup:
/// a cached profile is invalidated when the site, resolution, or provider changes.
final class TerrainProfileRepository {
  TerrainProfileRepository({
    required this.provider,
    TerrainProfileStore? store,
    this.maximumEntries = 16,
    this.maximumAge = const Duration(days: 30),
  }) : _store = store ?? SharedPreferencesTerrainProfileStore() {
    if (maximumEntries < 1) {
      throw ArgumentError('maximumEntries must be positive.');
    }
  }

  static const prefix = 'astromanager.terrain.v1.';
  final TerrainElevationProvider provider;
  final TerrainProfileStore _store;
  final int maximumEntries;
  final Duration maximumAge;

  String cacheKey(ObservingLocation site, TerrainHorizonOptions options) {
    options.validate();
    final content =
        '${provider.id}|${site.latitude}|${site.longitude}|'
        '${site.elevationMeters}|${options.azimuthStepDegrees}|'
        '${options.maximumDistanceMeters}|${options.distanceStepMeters}';
    return '$prefix${sha256.convert(utf8.encode(content))}';
  }

  /// Cache-only result, including expired profiles for an explicitly
  /// labelled stale preview. No elevation provider calls are made here.
  Future<({TerrainHorizonProfile profile, bool isStale})?> cachedWithStatus(
    ObservingLocation site,
    TerrainHorizonOptions options,
  ) async {
    final key = cacheKey(site, options);
    final raw = await _store.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid cache.');
      }
      final profile = TerrainHorizonProfile.fromJson(decoded);
      if (profile.sourceId != provider.id ||
          profile.latitude != site.latitude ||
          profile.longitude != site.longitude ||
          profile.observerElevationMeters != site.elevationMeters ||
          profile.options.azimuthStepDegrees != options.azimuthStepDegrees ||
          profile.options.maximumDistanceMeters !=
              options.maximumDistanceMeters ||
          profile.options.distanceStepMeters != options.distanceStepMeters) {
        throw const FormatException('Terrain site/provider mismatch.');
      }
      final age = DateTime.now().toUtc().difference(profile.createdAtUtc);
      return (
        profile: profile,
        isStale: age > maximumAge || age.inMinutes < -5,
      );
    } catch (_) {
      await _store.remove(key);
      return null;
    }
  }

  /// Finds any compatible cached resolution at this location. This is useful
  /// for a dashboard preview without fetching a different DEM resolution.
  /// A fresh profile is preferred over a stale one, then the newest sample.
  Future<({TerrainHorizonProfile profile, bool isStale})?> cachedAnyForSite(
    ObservingLocation site,
  ) async {
    final keys = await _store.getKeys();
    ({TerrainHorizonProfile profile, bool isStale})? best;
    for (final key in keys.where((key) => key.startsWith(prefix))) {
      final raw = await _store.getString(key);
      if (raw == null) continue;
      try {
        final parsed = jsonDecode(raw);
        if (parsed is! Map<String, dynamic>) {
          throw const FormatException('Invalid terrain cache.');
        }
        final profile = TerrainHorizonProfile.fromJson(parsed);
        if (profile.sourceId != provider.id ||
            profile.latitude != site.latitude ||
            profile.longitude != site.longitude ||
            profile.observerElevationMeters != site.elevationMeters) {
          continue;
        }
        // Protect against storing a profile under a mismatched resolution key.
        if (cacheKey(site, profile.options) != key) continue;
        final age = DateTime.now().toUtc().difference(profile.createdAtUtc);
        final stale = age > maximumAge || age.inMinutes < -5;
        if (best == null ||
            (best.isStale && !stale) ||
            (best.isStale == stale &&
                profile.createdAtUtc.isAfter(best.profile.createdAtUtc))) {
          best = (profile: profile, isStale: stale);
        }
      } catch (_) {
        await _store.remove(key);
      }
    }
    return best;
  }

  Future<TerrainHorizonProfile?> cached(
    ObservingLocation site,
    TerrainHorizonOptions options,
  ) async {
    final value = await cachedWithStatus(site, options);
    if (value == null) return null;
    if (value.isStale) {
      await _store.remove(cacheKey(site, options));
      return null;
    }
    return value.profile;
  }

  /// Cache-first. A network error does not erase a valid, already-loaded profile.
  Future<TerrainHorizonProfile> load(
    ObservingLocation site,
    TerrainHorizonOptions options,
  ) async {
    final saved = await cached(site, options);
    if (saved != null) {
      return saved;
    }
    final profile = await TerrainHorizonCalculator.calculate(
      site: site,
      options: options,
      provider: provider,
    );
    // An entirely missing dataset is not useful and must not be cached as a
    // definitive unobstructed horizon.
    if (profile.knownBearings == 0) {
      throw StateError('No elevation data for this site and search radius.');
    }
    await _store.setString(
      cacheKey(site, options),
      jsonEncode(profile.toJson()),
    );
    await _evict();
    return profile;
  }

  Future<void> remove(ObservingLocation site, TerrainHorizonOptions options) =>
      _store.remove(cacheKey(site, options));

  Future<void> _evict() async {
    final keys = (await _store.getKeys())
        .where((key) => key.startsWith(prefix))
        .toList();
    if (keys.length <= maximumEntries) {
      return;
    }
    final dated = <(String, DateTime)>[];
    for (final key in keys) {
      try {
        final raw = await _store.getString(key);
        if (raw == null) {
          continue;
        }
        final data = TerrainHorizonProfile.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
        dated.add((key, data.createdAtUtc));
      } catch (_) {
        await _store.remove(key);
      }
    }
    dated.sort((a, b) => a.$2.compareTo(b.$2));
    for (var i = 0; i < dated.length - maximumEntries; i++) {
      await _store.remove(dated[i].$1);
    }
  }
}
