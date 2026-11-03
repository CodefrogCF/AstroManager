/// Persisted, UI-independent dashboard layout data.
///
/// Layout v1 is intentionally independent of any particular widget registry:
/// unknown widget types remain in storage for forward compatibility.
final class DashboardWidgetSize {
  const DashboardWidgetSize(this.columns, this.rows);

  final int columns;
  final int rows;

  void validate() {
    if (columns < 1 || columns > 4 || rows < 1 || rows > 4) {
      throw const FormatException('Invalid dashboard widget dimensions.');
    }
  }

  Map<String, Object> toJson() => {'columns': columns, 'rows': rows};

  factory DashboardWidgetSize.fromJson(Object? input) {
    if (input is! Map || input['columns'] is! int || input['rows'] is! int) {
      throw const FormatException('Invalid dashboard widget size.');
    }
    final result = DashboardWidgetSize(
      input['columns'] as int,
      input['rows'] as int,
    );
    result.validate();
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is DashboardWidgetSize &&
      other.columns == columns &&
      other.rows == rows;

  @override
  int get hashCode => Object.hash(columns, rows);
}

final class DashboardWidgetInstance {
  const DashboardWidgetInstance({
    required this.id,
    required this.typeId,
    this.size = const DashboardWidgetSize(1, 1),
    this.visible = true,
    this.settings = const {},
  });

  final String id;
  final String typeId;
  final DashboardWidgetSize size;
  final bool visible;
  final Map<String, Object?> settings;

  DashboardWidgetInstance copyWith({
    DashboardWidgetSize? size,
    bool? visible,
    Map<String, Object?>? settings,
  }) => DashboardWidgetInstance(
    id: id,
    typeId: typeId,
    size: size ?? this.size,
    visible: visible ?? this.visible,
    settings: settings ?? this.settings,
  );

  void validate() {
    final idPattern = RegExp(r'^[A-Za-z0-9_.-]{1,100}$');
    if (!idPattern.hasMatch(id) || !idPattern.hasMatch(typeId)) {
      throw const FormatException('Invalid dashboard widget identifier.');
    }
    size.validate();
    if (settings.length > 30) {
      throw const FormatException('Too many dashboard widget settings.');
    }
    for (final entry in settings.entries) {
      if (entry.value is double && !(entry.value as double).isFinite) {
        throw const FormatException('Invalid dashboard widget number.');
      }
      if (!idPattern.hasMatch(entry.key) ||
          (entry.value != null &&
              entry.value is! bool &&
              entry.value is! int &&
              entry.value is! double &&
              entry.value is! String)) {
        throw const FormatException('Invalid dashboard widget setting.');
      }
    }
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'typeId': typeId,
    'size': size.toJson(),
    'visible': visible,
    'settings': settings,
  };

  factory DashboardWidgetInstance.fromJson(Object? input) {
    if (input is! Map ||
        input['id'] is! String ||
        input['typeId'] is! String ||
        input['visible'] is! bool ||
        input['settings'] is! Map) {
      throw const FormatException('Invalid dashboard widget configuration.');
    }
    final settings = <String, Object?>{};
    for (final entry in (input['settings'] as Map).entries) {
      if (entry.key is! String) {
        throw const FormatException('Invalid dashboard setting key.');
      }
      settings[entry.key as String] = entry.value;
    }
    final instance = DashboardWidgetInstance(
      id: input['id'] as String,
      typeId: input['typeId'] as String,
      size: DashboardWidgetSize.fromJson(input['size']),
      visible: input['visible'] as bool,
      settings: settings,
    );
    instance.validate();
    return instance;
  }
}

final class DashboardLayout {
  const DashboardLayout({required this.widgets, this.selectedLocationId});

  static const formatVersion = 1;
  final List<DashboardWidgetInstance> widgets;

  /// Null means follow the user's default observing location.
  final String? selectedLocationId;

  static const defaults = DashboardLayout(
    widgets: [
      DashboardWidgetInstance(
        id: 'weather-default',
        typeId: 'seven-night-weather',
        size: DashboardWidgetSize(2, 1),
      ),
      DashboardWidgetInstance(
        id: 'targets-default',
        typeId: 'top-targets',
        size: DashboardWidgetSize(2, 1),
      ),
      DashboardWidgetInstance(
        id: 'tonight-default',
        typeId: 'tonight',
        size: DashboardWidgetSize(1, 1),
      ),
      DashboardWidgetInstance(
        id: 'actions-default',
        typeId: 'quick-actions',
        size: DashboardWidgetSize(1, 1),
      ),
    ],
  );

  DashboardLayout copyWith({
    List<DashboardWidgetInstance>? widgets,
    String? selectedLocationId,
    bool clearSelectedLocation = false,
  }) => DashboardLayout(
    widgets: widgets ?? this.widgets,
    selectedLocationId: clearSelectedLocation
        ? null
        : selectedLocationId ?? this.selectedLocationId,
  );

  void validate() {
    if (widgets.length > 30) {
      throw const FormatException('Too many dashboard widgets.');
    }
    if (selectedLocationId != null &&
        (selectedLocationId!.isEmpty || selectedLocationId!.length > 100)) {
      throw const FormatException('Invalid dashboard observing location.');
    }
    final ids = <String>{};
    for (final widget in widgets) {
      widget.validate();
      if (!ids.add(widget.id)) {
        throw const FormatException('Duplicate dashboard widget identifier.');
      }
    }
  }

  Map<String, Object?> toJson() => {
    'formatVersion': formatVersion,
    'selectedLocationId': selectedLocationId,
    'widgets': widgets.map((widget) => widget.toJson()).toList(),
  };

  factory DashboardLayout.fromJson(Object? input) {
    if (input is! Map ||
        input['formatVersion'] != formatVersion ||
        input['widgets'] is! List ||
        (input['selectedLocationId'] != null &&
            input['selectedLocationId'] is! String)) {
      throw const FormatException('Unsupported dashboard layout format.');
    }
    final layout = DashboardLayout(
      selectedLocationId: input['selectedLocationId'] as String?,
      widgets: (input['widgets'] as List)
          .map(DashboardWidgetInstance.fromJson)
          .toList(growable: false),
    );
    layout.validate();
    return layout;
  }
}
