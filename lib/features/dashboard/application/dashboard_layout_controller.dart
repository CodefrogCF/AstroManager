import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/dashboard_layout_repository.dart';
import '../domain/dashboard_layout.dart';

final dashboardLayoutProvider =
    AsyncNotifierProvider<DashboardLayoutController, DashboardLayout>(
      DashboardLayoutController.new,
      retry: (count, error) => null,
    );

class DashboardLayoutController extends AsyncNotifier<DashboardLayout> {
  // Serialize mutations to avoid losing quick consecutive edits.
  Future<void> _pending = Future<void>.value();

  @override
  Future<DashboardLayout> build() =>
      ref.watch(dashboardLayoutRepositoryProvider).load();

  Future<void> _update(DashboardLayout Function(DashboardLayout) update) {
    final currentOperation = _pending.then((_) async {
      final previous = state.value;
      if (previous == null) {
        throw StateError('Dashboard configuration is not loaded.');
      }
      final next = update(previous);
      next.validate();
      await ref.read(dashboardLayoutRepositoryProvider).save(next);
      if (ref.mounted) state = AsyncData(next);
    });
    _pending = currentOperation.then(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return currentOperation;
  }

  Future<void> selectLocation(String? id) => _update(
    (layout) => layout.copyWith(
      selectedLocationId: id,
      clearSelectedLocation: id == null,
    ),
  );

  Future<void> addWidget(
    String typeId,
    DashboardWidgetSize size, {
    Map<String, Object?> settings = const {},
  }) => _update(
    (layout) => layout.copyWith(
      widgets: [
        ...layout.widgets,
        DashboardWidgetInstance(
          id: const Uuid().v4(),
          typeId: typeId,
          size: size,
          settings: settings,
        ),
      ],
    ),
  );

  Future<void> removeWidget(String id) => _update(
    (layout) => layout.copyWith(
      widgets: [
        for (final widget in layout.widgets)
          if (widget.id != id) widget,
      ],
    ),
  );

  Future<void> setVisible(String id, bool visible) =>
      _editWidget(id, (widget) => widget.copyWith(visible: visible));

  Future<void> configureWidget(
    String id, {
    required DashboardWidgetSize size,
    required Map<String, Object?> settings,
  }) => _editWidget(
    id,
    (widget) => widget.copyWith(
      size: size,
      settings: Map<String, Object?>.from(settings),
    ),
  );

  Future<void> _editWidget(
    String id,
    DashboardWidgetInstance Function(DashboardWidgetInstance) edit,
  ) => _update((layout) {
    if (!layout.widgets.any((widget) => widget.id == id)) {
      throw StateError('Unknown dashboard widget.');
    }
    return layout.copyWith(
      widgets: [
        for (final widget in layout.widgets)
          widget.id == id ? edit(widget) : widget,
      ],
    );
  });

  Future<void> moveWidget(String id, int direction) => _update((layout) {
    final list = List<DashboardWidgetInstance>.from(layout.widgets);
    final index = list.indexWhere((widget) => widget.id == id);
    if (index < 0) throw StateError('Unknown dashboard widget.');
    final target = index + direction;
    if (target < 0 || target >= list.length) return layout;
    final selected = list.removeAt(index);
    list.insert(target, selected);
    return layout.copyWith(widgets: list);
  });

  Future<void> reset() => _update((layout) => DashboardLayout.defaults);

  /// Explicit repair action for a malformed saved layout. The original value
  /// is not overwritten during a failed load without user confirmation.
  Future<void> recoverDefaults() async {
    await ref
        .read(dashboardLayoutRepositoryProvider)
        .save(DashboardLayout.defaults);
    if (ref.mounted) state = const AsyncData(DashboardLayout.defaults);
  }
}
