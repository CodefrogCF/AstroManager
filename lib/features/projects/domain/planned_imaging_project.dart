/// Lifecycle of a persisted astrophotography imaging project.
enum ImagingProjectStatus {
  planned,
  inProgress,
  completed,
  archived;

  String get label => switch (this) {
    planned => 'Planned',
    inProgress => 'In progress',
    completed => 'Completed',
    archived => 'Archived',
  };
}

/// Offline project record. Catalog and optical-profile identifiers are kept
/// as references rather than foreign keys: the project survives catalog or
/// equipment removal, and dangling references are shown in the UI.
final class PlannedImagingProject {
  PlannedImagingProject({
    required this.id,
    required this.title,
    required List<String> targetIds,
    required this.createdAtUtc,
    DateTime? updatedAtUtc,
    this.description = '',
    this.notes = '',
    this.imagingGoal = '',
    this.status = ImagingProjectStatus.planned,
    this.plannedIntegrationSeconds = 0,
    this.observingDate,
    this.locationId,
    this.opticalProfileId,
    this.windowStartUtc,
    this.windowEndUtc,
  }) : targetIds = List.unmodifiable(targetIds),
       updatedAtUtc = updatedAtUtc ?? createdAtUtc {
    validate();
  }

  final String id;
  final String title;
  final List<String> targetIds;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final String description;
  final String notes;
  final String imagingGoal;
  final ImagingProjectStatus status;
  final int plannedIntegrationSeconds;
  final String? observingDate;
  final String? locationId;
  final String? opticalProfileId;
  final DateTime? windowStartUtc;
  final DateTime? windowEndUtc;

  void validate() {
    if (id.trim().isEmpty ||
        title.trim().isEmpty ||
        targetIds.any((value) => value.trim().isEmpty) ||
        targetIds.toSet().length != targetIds.length ||
        !createdAtUtc.isUtc ||
        !updatedAtUtc.isUtc ||
        updatedAtUtc.isBefore(createdAtUtc) ||
        plannedIntegrationSeconds < 0 ||
        (windowStartUtc != null && !windowStartUtc!.isUtc) ||
        (windowEndUtc != null && !windowEndUtc!.isUtc) ||
        (windowStartUtc != null &&
            windowEndUtc != null &&
            !windowEndUtc!.isAfter(windowStartUtc!)) ||
        (observingDate != null &&
            !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(observingDate!))) {
      throw const FormatException('Invalid astrophotography project.');
    }
  }

  PlannedImagingProject copyWith({
    String? title,
    List<String>? targetIds,
    DateTime? updatedAtUtc,
    String? description,
    String? notes,
    String? imagingGoal,
    ImagingProjectStatus? status,
    int? plannedIntegrationSeconds,
    String? observingDate,
    String? locationId,
    String? opticalProfileId,
    DateTime? windowStartUtc,
    DateTime? windowEndUtc,
    bool clearObservingDate = false,
    bool clearLocation = false,
    bool clearOpticalProfile = false,
    bool clearWindow = false,
  }) => PlannedImagingProject(
    id: id,
    title: title ?? this.title,
    targetIds: targetIds ?? this.targetIds,
    createdAtUtc: createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? DateTime.now().toUtc(),
    description: description ?? this.description,
    notes: notes ?? this.notes,
    imagingGoal: imagingGoal ?? this.imagingGoal,
    status: status ?? this.status,
    plannedIntegrationSeconds:
        plannedIntegrationSeconds ?? this.plannedIntegrationSeconds,
    observingDate: clearObservingDate
        ? null
        : observingDate ?? this.observingDate,
    locationId: clearLocation ? null : locationId ?? this.locationId,
    opticalProfileId: clearOpticalProfile
        ? null
        : opticalProfileId ?? this.opticalProfileId,
    windowStartUtc: clearWindow ? null : windowStartUtc ?? this.windowStartUtc,
    windowEndUtc: clearWindow ? null : windowEndUtc ?? this.windowEndUtc,
  );

  PlannedImagingProject withTarget(String targetId) => copyWith(
    targetIds: targetIds.contains(targetId)
        ? targetIds
        : [...targetIds, targetId],
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'targetIds': targetIds,
    'createdAtUtc': createdAtUtc.toIso8601String(),
    'updatedAtUtc': updatedAtUtc.toIso8601String(),
    'description': description,
    'notes': notes,
    'imagingGoal': imagingGoal,
    'status': status.name,
    'plannedIntegrationSeconds': plannedIntegrationSeconds,
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
        updatedAtUtc: json['updatedAtUtc'] == null
            ? null
            : DateTime.parse(json['updatedAtUtc'] as String).toUtc(),
        description: json['description'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        imagingGoal: json['imagingGoal'] as String? ?? '',
        status: ImagingProjectStatus.values.firstWhere(
          (status) => status.name == (json['status'] as String? ?? 'planned'),
        ),
        plannedIntegrationSeconds:
            json['plannedIntegrationSeconds'] as int? ?? 0,
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
