import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/weather_forecast.dart';
import '../domain/repositories/weather_cache_repository.dart';
import 'weather_forecast_codec.dart';

/// Minimal persistence abstraction for deterministic tests.
abstract interface class WeatherCacheStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<Set<String>> getKeys();
  Future<void> remove(String key);
}

final class SharedPreferencesWeatherStore implements WeatherCacheStore {
  SharedPreferencesWeatherStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> getString(String key) => _preferences.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<Set<String>> getKeys() => _preferences.getKeys();

  @override
  Future<void> remove(String key) => _preferences.remove(key);
}

/// Small, bounded and portable persistent forecast cache.
///
/// Each request has its own JSON record. Writes are serialized within this
/// repository instance to avoid eviction races; cross-process transactional
/// guarantees are intentionally NOT claimed by shared_preferences.
final class SharedPreferencesWeatherCacheRepository
    implements WeatherCacheRepository {
  SharedPreferencesWeatherCacheRepository({
    WeatherCacheStore? store,
    this.maximumEntries = 20,
  }) : assert(maximumEntries > 0),
       _store = store ?? SharedPreferencesWeatherStore();

  static const prefix = 'astromanager.weather.v1.';
  final WeatherCacheStore _store;
  final int maximumEntries;
  Future<void> _lastMutation = Future<void>.value();

  @override
  Future<WeatherForecast?> read(WeatherCacheKey key) async {
    final raw = await _store.getString(key.storageKey);
    if (raw == null) return null;
    try {
      return WeatherForecastCodec.decode(raw, key);
    } on FormatException {
      // Invalid or obsolete records must not prevent a new forecast download.
      await _store.remove(key.storageKey);
      return null;
    }
  }

  @override
  Future<void> write(WeatherCacheKey key, WeatherForecast forecast) {
    if (forecast.provider.id != key.providerId) {
      throw ArgumentError('Forecast provider ID does not match cache key.');
    }
    final encoded = WeatherForecastCodec.encode(key, forecast);
    return _mutate(() async {
      await _store.setString(key.storageKey, encoded);
      await _trim();
    });
  }

  @override
  Future<void> remove(WeatherCacheKey key) =>
      _mutate(() => _store.remove(key.storageKey));

  @override
  Future<void> clear() => _mutate(() async {
    final keys = await _store.getKeys();
    for (final key in keys.where((name) => name.startsWith(prefix))) {
      await _store.remove(key);
    }
  });

  Future<void> _mutate(Future<void> Function() action) async {
    final previous = _lastMutation;
    final release = Completer<void>();
    _lastMutation = release.future;
    await previous;
    try {
      await action();
    } finally {
      release.complete();
    }
  }

  Future<void> _trim() async {
    final keys = (await _store.getKeys())
        .where((name) => name.startsWith(prefix))
        .toList();
    if (keys.length <= maximumEntries) return;

    final dated = <(String, DateTime)>[];
    for (final key in keys) {
      try {
        final raw = await _store.getString(key);
        if (raw == null) continue;
        final parsed = jsonDecode(raw);
        if (parsed is! Map<String, dynamic>) {
          throw const FormatException('Invalid cache item.');
        }
        final fetched = DateTime.tryParse('${parsed['fetchedAtUtc']}');
        if (fetched == null || !fetched.isUtc) {
          throw const FormatException('Invalid cache timestamp.');
        }
        dated.add((key, fetched));
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
