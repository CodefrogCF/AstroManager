enum AppThemeChoice {
  system,
  light,
  dark,
  night;

  String get label => switch (this) {
    AppThemeChoice.system => 'Follow system',
    AppThemeChoice.light => 'Codefrog light',
    AppThemeChoice.dark => 'Codefrog dark',
    AppThemeChoice.night => 'Astronomy night',
  };

  String get description => switch (this) {
    AppThemeChoice.system => 'Automatically follow your device appearance.',
    AppThemeChoice.light => 'Bright surfaces with Codefrog green accents.',
    AppThemeChoice.dark => 'Dark Codefrog design with green highlights.',
    AppThemeChoice.night => 'Dark surfaces and red lighting for observations.',
  };
}
