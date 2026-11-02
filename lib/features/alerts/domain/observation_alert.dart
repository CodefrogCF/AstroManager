/// User-owned alert configuration. Scoring is performed by the existing
/// ObservationWindowRecommendation engine; this model stores no cached score.
final class ObservationAlertRule {
  const ObservationAlertRule({
    required this.id,
    required this.targetId,
    required this.targetName,
    required this.locationId,
    this.minimumScore = 70,
    this.minimumDurationMinutes = 60,
    this.enabled = true,
  });

  final String id;
  final String targetId;
  final String targetName;
  final String locationId;
  final double minimumScore;
  final int minimumDurationMinutes;
  final bool enabled;

  void validate() {
    if (id.trim().isEmpty ||
        targetId.trim().isEmpty ||
        targetName.trim().isEmpty ||
        locationId.trim().isEmpty) {
      throw const FormatException(
        'Alert target, location and ID are required.',
      );
    }
    if (!minimumScore.isFinite || minimumScore < 0 || minimumScore > 100) {
      throw const FormatException('Alert score must be between 0 and 100.');
    }
    if (minimumDurationMinutes < 15 || minimumDurationMinutes > 1440) {
      throw const FormatException('Alert duration must be 15–1440 minutes.');
    }
  }

  ObservationAlertRule copyWith({bool? enabled}) => ObservationAlertRule(
    id: id,
    targetId: targetId,
    targetName: targetName,
    locationId: locationId,
    minimumScore: minimumScore,
    minimumDurationMinutes: minimumDurationMinutes,
    enabled: enabled ?? this.enabled,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'targetId': targetId,
    'targetName': targetName,
    'locationId': locationId,
    'minimumScore': minimumScore,
    'minimumDurationMinutes': minimumDurationMinutes,
    'enabled': enabled,
  };

  factory ObservationAlertRule.fromJson(Map<String, dynamic> json) {
    final rule = ObservationAlertRule(
      id: json['id'] as String,
      targetId: json['targetId'] as String,
      targetName: json['targetName'] as String,
      locationId: json['locationId'] as String,
      minimumScore: (json['minimumScore'] as num).toDouble(),
      minimumDurationMinutes: json['minimumDurationMinutes'] as int,
      enabled: json['enabled'] as bool,
    );
    rule.validate();
    return rule;
  }
}

/// A delivered alert is identified by its rule and observing night (not by
/// forecast fetch time). Revised forecasts cannot notify repeatedly for the
/// same target/site/night. All timestamps are UTC instants.
final class ObservationAlertState {
  ObservationAlertState({
    this.enabled = false,
    List<ObservationAlertRule> rules = const [],
    Map<String, DateTime> delivered = const {},
  }) : rules = List.unmodifiable(rules),
       delivered = Map.unmodifiable(delivered);

  final bool enabled;
  final List<ObservationAlertRule> rules;
  final Map<String, DateTime> delivered;

  void validate() {
    final ids = <String>{};
    for (final rule in rules) {
      rule.validate();
      if (!ids.add(rule.id)) {
        throw const FormatException('Duplicate alert ID.');
      }
    }
    if (delivered.length > 2048 ||
        delivered.entries.any(
          (entry) =>
              entry.key.isEmpty || entry.key.length > 250 || !entry.value.isUtc,
        )) {
      throw const FormatException('Invalid alert delivery history.');
    }
  }

  ObservationAlertState copyWith({
    bool? enabled,
    List<ObservationAlertRule>? rules,
    Map<String, DateTime>? delivered,
  }) => ObservationAlertState(
    enabled: enabled ?? this.enabled,
    rules: rules ?? this.rules,
    delivered: delivered ?? this.delivered,
  );

  Map<String, Object?> toJson() => {
    'version': 1,
    'enabled': enabled,
    'rules': rules.map((rule) => rule.toJson()).toList(),
    'delivered': delivered.map(
      (key, value) => MapEntry(key, value.toIso8601String()),
    ),
  };

  factory ObservationAlertState.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported observation alerts format.');
    }
    final state = ObservationAlertState(
      enabled: json['enabled'] as bool,
      rules: (json['rules'] as List)
          .map(
            (entry) => ObservationAlertRule.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList(),
      delivered: (json['delivered'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, DateTime.parse(value as String).toUtc()),
      ),
    );
    state.validate();
    return state;
  }
}
