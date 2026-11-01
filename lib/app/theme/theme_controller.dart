import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme_choice.dart';
import 'theme_repository.dart';

final initialThemeProvider = Provider<AppThemeChoice>(
  (ref) => AppThemeChoice.dark,
);

final themeRepositoryProvider = Provider<ThemeRepository>(
  (ref) => SharedPreferencesThemeRepository(SharedPreferencesAsync()),
);

final appThemeProvider = NotifierProvider<AppThemeController, AppThemeChoice>(
  AppThemeController.new,
);

class AppThemeController extends Notifier<AppThemeChoice> {
  @override
  AppThemeChoice build() {
    return ref.watch(initialThemeProvider);
  }

  Future<void> select(AppThemeChoice choice) async {
    if (state == choice) return;

    final previous = state;
    final repository = ref.read(themeRepositoryProvider);

    // Update the UI immediately.
    state = choice;

    try {
      await repository.save(choice);
    } catch (_) {
      // Restore previous selection if persistence fails.
      state = previous;
      rethrow;
    }
  }
}
