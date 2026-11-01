import 'package:flutter/material.dart';

abstract final class AstroPalette {
  // Codefrog Dark - original brand colors
  static const darkBackground = Color(0xFF0D1110);
  static const darkSurface = Color(0xFF151B18);
  static const darkSurface2 = Color(0xFF1B2420);
  static const darkAccent = Color(0xFF8BD67A);
  static const darkAccentStrong = Color(0xFFB4EEA7);
  static const darkText = Color(0xFFF1F5F2);
  static const darkMuted = Color(0xFFAAB5AE);
  static const darkBorder = Color(0xFF29332E);

  // Codefrog Light - derived from the dark branding
  static const lightBackground = Color(0xFFF4F7F4);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurface2 = Color(0xFFE8EFE9);
  static const lightAccent = Color(0xFF286A36);
  static const lightText = Color(0xFF19231D);
  static const lightMuted = Color(0xFF5B7061);
  static const lightBorder = Color(0xFFD5E0D7);

  // Astronomy Night - independent red-only palette
  static const nightBackground = Color(0xFF090303);
  static const nightSurface = Color(0xFF170909);
  static const nightAccent = Color(0xFFD65A5A);
  static const nightText = Color(0xFFE2AAAA);
  static const nightMuted = Color(0xFFAB7070);
  static const nightBorder = Color(0xFF492020);
}

abstract final class AstroThemes {
  static final ThemeData dark = _build(
    ColorScheme.fromSeed(
      seedColor: AstroPalette.darkAccent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AstroPalette.darkAccent,
      onPrimary: AstroPalette.darkBackground,
      primaryContainer: const Color(0xFF27412B),
      onPrimaryContainer: AstroPalette.darkAccentStrong,
      secondary: AstroPalette.darkAccentStrong,
      onSecondary: AstroPalette.darkBackground,
      surface: AstroPalette.darkBackground,
      surfaceContainerLowest: AstroPalette.darkBackground,
      surfaceContainerLow: AstroPalette.darkSurface,
      surfaceContainer: AstroPalette.darkSurface2,
      surfaceContainerHigh: const Color(0xFF243029),
      surfaceContainerHighest: const Color(0xFF2C3930),
      onSurface: AstroPalette.darkText,
      onSurfaceVariant: AstroPalette.darkMuted,
      outline: AstroPalette.darkBorder,
      outlineVariant: AstroPalette.darkBorder,
    ),
  );

  static final ThemeData light = _build(
    ColorScheme.fromSeed(
      seedColor: AstroPalette.lightAccent,
      brightness: Brightness.light,
    ).copyWith(
      primary: AstroPalette.lightAccent,
      onPrimary: Colors.white,
      surface: AstroPalette.lightBackground,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: AstroPalette.lightSurface,
      surfaceContainer: AstroPalette.lightSurface2,
      onSurface: AstroPalette.lightText,
      onSurfaceVariant: AstroPalette.lightMuted,
      outline: AstroPalette.lightBorder,
      outlineVariant: AstroPalette.lightBorder,
    ),
  );

  static final ThemeData night = _build(
    ColorScheme.fromSeed(
      seedColor: AstroPalette.nightAccent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AstroPalette.nightAccent,
      onPrimary: const Color(0xFF1B0505),
      primaryContainer: const Color(0xFF671F1F),
      onPrimaryContainer: const Color(0xFFFFD0D0),
      secondary: const Color(0xFFB94A4A),
      onSecondary: const Color(0xFF170404),
      tertiary: const Color(0xFFC65353),
      onTertiary: const Color(0xFF170404),
      surface: AstroPalette.nightBackground,
      surfaceContainerLowest: const Color(0xFF060202),
      surfaceContainerLow: AstroPalette.nightSurface,
      surfaceContainer: const Color(0xFF1D0B0B),
      surfaceContainerHigh: const Color(0xFF271010),
      surfaceContainerHighest: const Color(0xFF361616),
      onSurface: AstroPalette.nightText,
      onSurfaceVariant: AstroPalette.nightMuted,
      outline: AstroPalette.nightBorder,
      outlineVariant: AstroPalette.nightBorder,
      error: const Color(0xFFFF7777),
      onError: const Color(0xFF210505),
    ),
  );

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData.from(colorScheme: scheme, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,

      appBarTheme: AppBarThemeData(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(color: scheme.primary),
        unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),

      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),

      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        contentTextStyle: TextStyle(color: scheme.onSurface),
      ),
    );
  }
}
