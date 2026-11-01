import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/theme/app_theme_choice.dart';
import 'app/theme/theme_controller.dart';
import 'app/theme/theme_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final repository = SharedPreferencesThemeRepository(SharedPreferencesAsync());

  AppThemeChoice initialTheme;

  try {
    initialTheme = await repository.load();
  } catch (_) {
    initialTheme = AppThemeChoice.dark;
  }

  runApp(
    ProviderScope(
      overrides: [
        themeRepositoryProvider.overrideWithValue(repository),
        initialThemeProvider.overrideWithValue(initialTheme),
      ],
      child: const AstroManagerApp(),
    ),
  );
}
