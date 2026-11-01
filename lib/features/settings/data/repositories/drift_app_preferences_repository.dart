import 'dart:convert';

import '../../../../core/database/repositories/app_settings_repository.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/logging/app_logger.dart';

import '../../domain/models/app_preferences.dart';
import '../../domain/repositories/app_preferences_repository.dart';

final class DriftAppPreferencesRepository implements AppPreferencesRepository {
  const DriftAppPreferencesRepository(this._storage);

  static const storageKey = 'app.preferences.v1';

  final AppSettingsRepository _storage;

  @override
  Future<AppPreferences> load() async {
    try {
      final raw = await _storage.get(storageKey);

      if (raw == null) {
        return AppPreferences.defaults;
      }

      final decoded = jsonDecode(raw);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Preferences must be a JSON object.');
      }

      return AppPreferences.fromJson(decoded);
    } on FormatException {
      AppLogger.warning('settings_invalid_data');

      throw const StorageFailure(
        'Saved settings are invalid. '
        'You can restore the defaults.',
      );
    } on StorageFailure {
      rethrow;
    } catch (_) {
      AppLogger.error('settings_load_failed');

      throw const StorageFailure('Unable to load application settings.');
    }
  }

  @override
  Future<void> save(AppPreferences preferences) async {
    try {
      final encoded = jsonEncode(preferences.toJson());

      await _storage.put(storageKey, encoded);
    } on StorageFailure {
      rethrow;
    } catch (_) {
      AppLogger.error('settings_save_failed');

      throw const StorageFailure('Unable to save application settings.');
    }
  }
}
