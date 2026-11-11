import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/dashboard_layout_repository.dart';
import '../domain/dashboard_layout.dart';
import '../domain/dashboard_grid.dart';
import '../domain/dashboard_grid_engine.dart';

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
      grids: {
        for (final entry in layout.grids.entries)
          entry.key: [
            for (final tile in entry.value)
              if (tile.widgetId != id) tile,
          ],
      },
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

  Future<void> configureWidgetForViewport(
    String id,
    DashboardViewport viewport, {
    required DashboardWidgetSize size,
    required Map<String, Object?> settings,
  }) => _update((layout) {
    if (!layout.widgets.any((widget) => widget.id == id)) {
      throw StateError('Unknown dashboard widget.');
    }
    final updated = layout.copyWith(
      widgets: [
        for (final widget in layout.widgets)
          widget.id == id
              ? widget.copyWith(settings: Map<String, Object?>.from(settings))
              : widget,
      ],
    );
    final current = DashboardGridEngine.arrange(
      viewport: viewport,
      widgets: updated.widgets,
      saved: updated.grids[viewport] ?? const [],
    ).firstWhere((tile) => tile.widgetId == id);
    return _relocate(
      updated,
      id,
      viewport,
      column: current.column,
      row: current.row,
      columns: size.columns,
      rows: size.rows,
    );
  });

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

  /// Reflow all tiles in one device class without touching other layouts.
  Future<void> resetViewport(DashboardViewport viewport) => _update((layout) {
    final updated = Map<DashboardViewport, List<DashboardTile>>.from(
      layout.grids,
    );
    updated.remove(viewport);
    return layout.copyWith(grids: updated);
  });

  /// Place the selected tile first and relocate colliding tiles. Running this
  /// inside _update keeps rapid drag/keyboard/resize edits serialized.
  DashboardLayout _relocate(
    DashboardLayout layout,
    String id,
    DashboardViewport viewport, {
    required num column,
    required num row,
    num? columns,
    num? rows,
    bool swapOnCollision = false,
    String? overWidgetId,
  }) {
    if (!layout.widgets.any((widget) => widget.id == id)) {
      throw StateError('Unknown dashboard widget.');
    }
    final existing = DashboardGridEngine.arrange(
      viewport: viewport,
      widgets: layout.widgets,
      saved: layout.grids[viewport] ?? const [],
    );
    final current = existing.firstWhere((tile) => tile.widgetId == id);
    final hiddenIds = {
      for (final widget in layout.widgets)
        if (!widget.visible) widget.id,
    };
    if (viewport == DashboardViewport.phone && overWidgetId != null) {
      final visible = existing
          .where((tile) => !hiddenIds.contains(tile.widgetId))
          .toList();
      final reordered = DashboardGridEngine.reorderColumn(
        visible,
        id,
        overWidgetId,
      );
      if (reordered != null) {
        final normalized = DashboardGridEngine.arrange(
          viewport: viewport,
          widgets: layout.widgets,
          saved: [
            ...reordered,
            for (final tile in existing)
              if (hiddenIds.contains(tile.widgetId)) tile,
          ],
        );
        return layout.copyWith(grids: {...layout.grids, viewport: normalized});
      }
    }
    final spanColumns = (columns ?? current.columns).clamp(1, viewport.columns);
    final spanRows = (rows ?? current.rows).clamp(1, DashboardTile.maxRows);
    final updatedTile = current.copyWith(
      column: column.clamp(0, viewport.columns - spanColumns),
      row: row.clamp(0, DashboardTile.lastRow),
      columns: spanColumns,
      rows: spanRows,
    );
    DashboardTile? swapped;
    if (swapOnCollision) {
      final others = existing.where(
        (tile) => tile.widgetId != id && !hiddenIds.contains(tile.widgetId),
      );
      final collisions = others.where(updatedTile.intersects).toList();
      if (collisions.length == 1) {
        final other = collisions.single;
        final replacement = other.copyWith(
          column: current.column,
          row: current.row,
        );
        if (replacement.column + replacement.columns <= viewport.columns &&
            !replacement.intersects(updatedTile) &&
            !others.any(
              (tile) =>
                  tile.widgetId != other.widgetId &&
                  replacement.intersects(tile),
            )) {
          swapped = replacement;
        }
      }
    }
    final normalized = DashboardGridEngine.arrange(
      viewport: viewport,
      widgets: layout.widgets,
      saved: [
        for (final tile in existing)
          if (tile.widgetId == id)
            updatedTile
          else if (tile.widgetId == swapped?.widgetId)
            swapped!
          else
            tile,
      ],
      priorityWidgetId: id,
      compactFromRow: spanColumns != current.columns || spanRows != current.rows
          ? current.row
          : null,
    );
    return layout.copyWith(grids: {...layout.grids, viewport: normalized});
  }

  Future<void> placeTile(
    String id,
    DashboardViewport viewport, {
    required num column,
    required num row,
    num? columns,
    num? rows,
    String? overWidgetId,
  }) => _update(
    (layout) => _relocate(
      layout,
      id,
      viewport,
      column: column,
      row: row,
      columns: columns,
      rows: rows,
      swapOnCollision: true,
      overWidgetId: overWidgetId,
    ),
  );

  Future<void> nudgeTile(
    String id,
    DashboardViewport viewport, {
    int horizontal = 0,
    int vertical = 0,
  }) => _update((layout) {
    final tile = DashboardGridEngine.arrange(
      viewport: viewport,
      widgets: layout.widgets,
      saved: layout.grids[viewport] ?? const [],
    ).firstWhere((tile) => tile.widgetId == id);
    return _relocate(
      layout,
      id,
      viewport,
      column: tile.column + horizontal,
      row: tile.row + vertical,
    );
  });

  Future<void> resizeTile(
    String id,
    DashboardViewport viewport,
    DashboardWidgetSize size,
  ) => _update((layout) {
    final tile = DashboardGridEngine.arrange(
      viewport: viewport,
      widgets: layout.widgets,
      saved: layout.grids[viewport] ?? const [],
    ).firstWhere((tile) => tile.widgetId == id);
    return _relocate(
      layout,
      id,
      viewport,
      column: tile.column,
      row: tile.row,
      columns: size.columns,
      rows: size.rows,
    );
  });

  Future<void> reset() => _update(
    (layout) => DashboardLayout.defaults.copyWith(
      selectedLocationId: layout.selectedLocationId,
    ),
  );

  /// Explicit repair action for a malformed saved layout. The original value
  /// is not overwritten during a failed load without user confirmation.
  Future<void> recoverDefaults() async {
    await ref
        .read(dashboardLayoutRepositoryProvider)
        .save(DashboardLayout.defaults);
    if (ref.mounted) state = const AsyncData(DashboardLayout.defaults);
  }
}
