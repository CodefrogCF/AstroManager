/// A lightweight, persisted planning record; actual capture/session tracking
/// can be added later without changing the target-detail workflow.
final class PlannedImagingProject {
  PlannedImagingProject({
    required this.id,
    required this.title,
    required List<String> targetIds,
    required this.createdAtUtc,
    this.observingDate,
    this.locationId,
    this.opticalProfileId,
    this.windowStartUtc,
    this.windowEndUtc,
  }) : targetIds = List.unmodifiable(targetIds) {
    validate();
  }

  final String id;
  final String title;
  final List<String> targetIds;
  final DateTime createdAtUtc;
  final String? observingDate;
  final String? locationId;
  final String? opticalProfileId;
  final DateTime? windowStartUtc;
  final DateTime? windowEndUtc;

  void validate() {
    if (id.trim().isEmpty ||
        title.trim().isEmpty ||
        targetIds.isEmpty ||
        targetIds.any((id) => id.trim().isEmpty) ||
        targetIds.toSet().length != targetIds.length ||
        !createdAtUtc.isUtc ||
        (windowStartUtc != null && !windowStartUtc!.isUtc) ||
        (windowEndUtc != null && !windowEndUtc!.isUtc) ||
        (windowStartUtc != null &&
            windowEndUtc != null &&
            !windowEndUtc!.isAfter(windowStartUtc!))) {
      throw const FormatException('Invalid planned imaging project.');
    }
  }

  PlannedImagingProject withTarget(String targetId) => PlannedImagingProject(
    id: id,
    title: title,
    targetIds: targetIds.contains(targetId)
        ? targetIds
        : [...targetIds, targetId],
    createdAtUtc: createdAtUtc,
    observingDate: observingDate,
    locationId: locationId,
    opticalProfileId: opticalProfileId,
    windowStartUtc: windowStartUtc,
    windowEndUtc: windowEndUtc,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'targetIds': targetIds,
    'createdAtUtc': createdAtUtc.toIso8601String(),
    'observingDate': observingDate,
    'locationId': locationId,
    'opticalProfileId': opticalProfileId,
    'windowStartUtc': windowStartUtc?.toIso8601String(),
    'windowEndUtc': windowEndUtc?.toIso8601String(),
  };

  factory PlannedImagingProject.fromJson(Map<String, dynamic> json) =>
      PlannedImagingProject(
        id: json['id'] as String,
        title: json['title'] as String,
        targetIds: (json['targetIds'] as List).cast<String>(),
        createdAtUtc: DateTime.parse(json['createdAtUtc'] as String).toUtc(),
        observingDate: json['observingDate'] as String?,
        locationId: json['locationId'] as String?,
        opticalProfileId: json['opticalProfileId'] as String?,
        windowStartUtc: json['windowStartUtc'] == null
            ? null
            : DateTime.parse(json['windowStartUtc'] as String).toUtc(),
        windowEndUtc: json['windowEndUtc'] == null
            ? null
            : DateTime.parse(json['windowEndUtc'] as String).toUtc(),
      );
}
