/// One scheduled target/project slot. Persist absolute UTC instants so a night
/// can cross midnight or a DST transition without losing its meaning.
final class NightObservationBlock {
  NightObservationBlock({
    required this.id,
    required this.locationId,
    required this.nightDate,
    required this.timeZoneId,
    required this.projectId,
    required this.targetId,
    required this.projectName,
    required this.targetName,
    required this.startUtc,
    required this.endUtc,
    this.notes = '',
  }) {
    validate();
  }

  final String id;
  final String locationId;

  /// The ISO date of the *start* of the observing night at its location.
  final String nightDate;
  final String timeZoneId;
  final String projectId;
  final String targetId;

  /// Snapshots survive project/catalog edits or deletion.
  final String projectName;
  final String targetName;
  final DateTime startUtc;
  final DateTime endUtc;
  final String notes;

  Duration get duration => endUtc.difference(startUtc);

  void validate() {
    if ([
          id,
          locationId,
          timeZoneId,
          projectId,
          targetId,
          projectName,
          targetName,
        ].any((field) => field.trim().isEmpty) ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(nightDate) ||
        !startUtc.isUtc ||
        !endUtc.isUtc ||
        !endUtc.isAfter(startUtc) ||
        duration > const Duration(hours: 24)) {
      throw const FormatException('Invalid planned observation block.');
    }
    final parsed = DateTime.tryParse(nightDate);
    if (parsed == null ||
        '${parsed.year.toString().padLeft(4, '0')}-'
                '${parsed.month.toString().padLeft(2, '0')}-'
                '${parsed.day.toString().padLeft(2, '0')}' !=
            nightDate) {
      throw const FormatException('Invalid observing-night date.');
    }
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'locationId': locationId,
    'nightDate': nightDate,
    'timeZoneId': timeZoneId,
    'projectId': projectId,
    'targetId': targetId,
    'projectName': projectName,
    'targetName': targetName,
    'startUtc': startUtc.toIso8601String(),
    'endUtc': endUtc.toIso8601String(),
    'notes': notes,
  };

  factory NightObservationBlock.fromJson(Map<String, dynamic> json) =>
      NightObservationBlock(
        id: json['id'] as String,
        locationId: json['locationId'] as String,
        nightDate: json['nightDate'] as String,
        timeZoneId: json['timeZoneId'] as String,
        projectId: json['projectId'] as String,
        targetId: json['targetId'] as String,
        projectName: json['projectName'] as String,
        targetName: json['targetName'] as String,
        startUtc: DateTime.parse(json['startUtc'] as String).toUtc(),
        endUtc: DateTime.parse(json['endUtc'] as String).toUtc(),
        notes: json['notes'] as String? ?? '',
      );
}

/// A night is scoped by location and its local starting date, not the device.
final class NightPlanKey {
  const NightPlanKey(this.locationId, this.nightDate);
  final String locationId;
  final String nightDate;

  @override
  bool operator ==(Object other) =>
      other is NightPlanKey &&
      locationId == other.locationId &&
      nightDate == other.nightDate;
  @override
  int get hashCode => Object.hash(locationId, nightDate);
}

/// Detect conflicts using half-open UTC intervals. Back-to-back blocks are OK.
abstract final class NightPlanConflicts {
  static Map<String, Set<String>> detect(
    Iterable<NightObservationBlock> blocks,
  ) {
    final sorted = blocks.toList()
      ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
    final result = <String, Set<String>>{};
    for (var i = 0; i < sorted.length; i++) {
      for (var j = i + 1; j < sorted.length; j++) {
        final a = sorted[i];
        final b = sorted[j];
        if (!b.startUtc.isBefore(a.endUtc)) {
          break;
        }
        if (b.endUtc.isAfter(a.startUtc)) {
          result.putIfAbsent(a.id, () => <String>{}).add(b.id);
          result.putIfAbsent(b.id, () => <String>{}).add(a.id);
        }
      }
    }
    return result;
  }
}
