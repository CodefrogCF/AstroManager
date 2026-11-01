import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme_choice.dart';

abstract interface class ThemeRepository {
  Future<AppThemeChoice> load();
  Future<void> save(AppThemeChoice choice);
}

final class SharedPreferencesThemeRepository implements ThemeRepository {
  SharedPreferencesThemeRepository(this._preferences);

  static const _storageKey = 'astromanager.theme.v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<AppThemeChoice> load() async {
    final saved = await _preferences.getString(_storageKey);

    for (final choice in AppThemeChoice.values) {
      if (choice.name == saved) {
        return choice;
      }
    }

    return AppThemeChoice.dark;
  }

  @override
  Future<void> save(AppThemeChoice choice) {
    return _preferences.setString(_storageKey, choice.name);
  }
}
