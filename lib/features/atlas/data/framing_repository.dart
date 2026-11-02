import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/camera_framing.dart';

abstract interface class CameraFramingRepository {
  Future<CameraFramingConfiguration?> load(String targetKey);
  Future<void> save(String targetKey, CameraFramingConfiguration frame);
  Future<void> delete(String targetKey);
}

abstract interface class CameraFramingStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

final class SharedPreferencesCameraFramingStore implements CameraFramingStore {
  SharedPreferencesCameraFramingStore([SharedPreferencesAsync? preferences])
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

/// Each target's last saved frame is stored independently. This is a small
/// user preference, not a cache; missing or malformed records are ignored.
final class SharedPreferencesCameraFramingRepository
    implements CameraFramingRepository {
  SharedPreferencesCameraFramingRepository({CameraFramingStore? store})
    : _store = store ?? SharedPreferencesCameraFramingStore();

  final CameraFramingStore _store;

  static String _key(String targetKey) {
    if (targetKey.isEmpty || targetKey.length > 150) {
      throw ArgumentError.value(targetKey, 'targetKey');
    }
    return 'astromanager.camera_frame.v1.${Uri.encodeComponent(targetKey)}';
  }

  @override
  Future<CameraFramingConfiguration?> load(String targetKey) async {
    final key = _key(targetKey);
    final content = await _store.getString(key);
    if (content == null) return null;
    try {
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid framing record.');
      }
      return CameraFramingConfiguration.fromJson(decoded);
    } on FormatException {
      // Do not allow a corrupt local preference to break sky atlas startup.
      return null;
    } on ArgumentError {
      return null;
    }
  }

  @override
  Future<void> save(String targetKey, CameraFramingConfiguration frame) async {
    await _store.setString(_key(targetKey), jsonEncode(frame.toJson()));
  }

  @override
  Future<void> delete(String targetKey) => _store.remove(_key(targetKey));
}

/// Deterministic storage for widgets and service tests.
final class MemoryCameraFramingRepository implements CameraFramingRepository {
  final Map<String, CameraFramingConfiguration> records = {};

  @override
  Future<CameraFramingConfiguration?> load(String targetKey) async =>
      records[targetKey];

  @override
  Future<void> save(String targetKey, CameraFramingConfiguration frame) async {
    frame.validate();
    records[targetKey] = frame;
  }

  @override
  Future<void> delete(String targetKey) async {
    records.remove(targetKey);
  }
}
