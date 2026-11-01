enum MeasurementUnits { metric, imperial }

enum ClockFormat { system, hour12, hour24 }

enum LanguagePreference { system, english, german }

class AppPreferences {
  const AppPreferences({
    required this.units,
    required this.clockFormat,
    required this.language,
  });

  final MeasurementUnits units;
  final ClockFormat clockFormat;
  final LanguagePreference language;

  static const defaults = AppPreferences(
    units: MeasurementUnits.metric,
    clockFormat: ClockFormat.system,
    language: LanguagePreference.system,
  );

  AppPreferences copyWith({
    MeasurementUnits? units,
    ClockFormat? clockFormat,
    LanguagePreference? language,
  }) {
    return AppPreferences(
      units: units ?? this.units,
      clockFormat: clockFormat ?? this.clockFormat,
      language: language ?? this.language,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'units': units.name,
    'clockFormat': clockFormat.name,
    'language': language.name,
  };

  factory AppPreferences.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported preferences format version.');
    }

    return AppPreferences(
      units: _parseEnum(MeasurementUnits.values, json['units'], 'units'),
      clockFormat: _parseEnum(
        ClockFormat.values,
        json['clockFormat'],
        'clockFormat',
      ),
      language: _parseEnum(
        LanguagePreference.values,
        json['language'],
        'language',
      ),
    );
  }

  static T _parseEnum<T extends Enum>(
    List<T> values,
    Object? raw,
    String field,
  ) {
    for (final value in values) {
      if (value.name == raw) return value;
    }

    throw FormatException('Invalid preference: $field');
  }

  @override
  bool operator ==(Object other) =>
      other is AppPreferences &&
      other.units == units &&
      other.clockFormat == clockFormat &&
      other.language == language;

  @override
  int get hashCode => Object.hash(units, clockFormat, language);
}
