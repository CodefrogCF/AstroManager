import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_text.dart';
import '../application/dashboard_layout_controller.dart';
import '../domain/dashboard_grid.dart';
import '../domain/dashboard_grid_engine.dart';
import '../domain/dashboard_layout.dart';

/// A responsive, pixel-snapped dashboard. Dragging starts only from the grip;
/// the cards and surrounding ListView keep their normal touch behavior.
class DashboardEditableGrid extends ConsumerStatefulWidget {
  const DashboardEditableGrid({
    super.key,
    required this.layout,
    required this.widgets,
    required this.editing,
    required this.tileBuilder,
    required this.titleFor,
    required this.sizesFor,
  });

  final DashboardLayout layout;
  final List<DashboardWidgetInstance> widgets;
  final bool editing;
  final Widget Function(
    BuildContext,
    DashboardWidgetInstance,
    DashboardViewport,
    DashboardTile,
  )
  tileBuilder;
  final String Function(DashboardWidgetInstance) titleFor;
  final List<DashboardWidgetSize> Function(DashboardWidgetInstance) sizesFor;

  @override
  ConsumerState<DashboardEditableGrid> createState() =>
      _DashboardEditableGridState();
}

class _DashboardEditableGridState extends ConsumerState<DashboardEditableGrid> {
  final _gridKey = GlobalKey();
  DashboardViewport _viewport = DashboardViewport.phone;
  double _cellWidth = 300;
  double _cellHeight = 200;
  static const _gap = 12.0;

  Future<void> _save(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: AppText('Could not save dashboard changes: $error'),
          ),
        );
      }
    }
  }

  void _acceptDrop(DragTargetDetails<String> details) {
    final object = _gridKey.currentContext?.findRenderObject();
    if (!widget.editing || object is! RenderBox || !object.hasSize) {
      return;
    }
    final local = object.globalToLocal(details.offset);
    final column = (local.dx / (_cellWidth + _gap)).floor();
    final row = (local.dy / (_cellHeight + _gap)).floor();
    _save(
      () => ref
          .read(dashboardLayoutProvider.notifier)
          .placeTile(
            details.data,
            _viewport,
            column: column.clamp(0, _viewport.columns - 1).toInt(),
            row: math.max(0, row),
          ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final viewport = DashboardViewport.forWidth(constraints.maxWidth);
      final columns = viewport.columns;
      final cellWidth = (constraints.maxWidth - (columns - 1) * _gap) / columns;
      final cellHeight = widget.editing ? 248.0 : 198.0;
      _viewport = viewport;
      _cellWidth = cellWidth;
      _cellHeight = cellHeight;
      final tiles = DashboardGridEngine.arrange(
        viewport: viewport,
        widgets: widget.widgets,
        saved: widget.layout.grids[viewport] ?? const [],
      );
      final maxRow = tiles.fold<int>(
        0,
        (maxBottom, tile) => math.max(maxBottom, tile.row + tile.rows),
      );
      final height = maxRow * (cellHeight + _gap) - (maxRow > 0 ? _gap : 0);
      final byId = {
        for (final instance in widget.widgets) instance.id: instance,
      };

      return DragTarget<String>(
        onWillAcceptWithDetails: (details) =>
            widget.editing && byId.containsKey(details.data),
        onAcceptWithDetails: _acceptDrop,
        builder: (context, candidates, rejected) => SizedBox(
          key: _gridKey,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final tile in tiles)
                Positioned(
                  left: tile.column * (cellWidth + _gap),
                  top: tile.row * (cellHeight + _gap),
                  width: tile.columns * cellWidth + (tile.columns - 1) * _gap,
                  height: tile.rows * cellHeight + (tile.rows - 1) * _gap,
                  child: SizedBox(
                    key: ValueKey('dashboard-widget-${tile.widgetId}'),
                    child: Column(
                      children: [
                        Expanded(
                          child: widget.tileBuilder(
                            context,
                            byId[tile.widgetId]!,
                            viewport,
                            tile,
                          ),
                        ),
                        if (widget.editing)
                          SizedBox(
                            height: 48,
                            child: _TileEditBar(
                              instance: byId[tile.widgetId]!,
                              title: widget.titleFor(byId[tile.widgetId]!),
                              viewport: viewport,
                              tile: tile,
                              sizes: widget.sizesFor(byId[tile.widgetId]!),
                              save: _save,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (widget.editing && candidates.isNotEmpty)
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SizedBox.expand(),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _TileEditBar extends ConsumerWidget {
  const _TileEditBar({
    required this.instance,
    required this.title,
    required this.viewport,
    required this.tile,
    required this.sizes,
    required this.save,
  });

  final DashboardWidgetInstance instance;
  final String title;
  final DashboardViewport viewport;
  final DashboardTile tile;
  final List<DashboardWidgetSize> sizes;
  final Future<void> Function(Future<void> Function()) save;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(dashboardLayoutProvider.notifier);
    final permittedSizes = sizes
        .where((size) => size.columns <= viewport.columns)
        .toList();
    final current = DashboardWidgetSize(tile.columns, tile.rows);
    return Semantics(
      container: true,
      label:
          '${appTranslate(context, 'Edit widget')}: ${appTranslate(context, title)}',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LongPressDraggable<String>(
            data: instance.id,
            feedback: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(title),
              ),
            ),
            child: Tooltip(
              message: appTranslate(context, 'Hold to drag widget'),
              child: SizedBox(
                key: ValueKey('dashboard-drag-${instance.id}'),
                width: 44,
                height: 44,
                child: const Icon(Icons.drag_indicator),
              ),
            ),
          ),
          _move(
            context,
            ref,
            Icons.arrow_back,
            'Move widget left',
            'left',
            -1,
            0,
            enabled: tile.column > 0,
          ),
          _move(
            context,
            ref,
            Icons.arrow_upward,
            'Move widget up',
            'up',
            0,
            -1,
            enabled: tile.row > 0,
          ),
          _move(
            context,
            ref,
            Icons.arrow_downward,
            'Move widget down',
            'down',
            0,
            1,
          ),
          _move(
            context,
            ref,
            Icons.arrow_forward,
            'Move widget right',
            'right',
            1,
            0,
            enabled: tile.column + tile.columns < viewport.columns,
          ),
          PopupMenuButton<DashboardWidgetSize>(
            key: ValueKey('dashboard-size-${instance.id}'),
            tooltip: appTranslate(context, 'Resize widget'),
            icon: const Icon(Icons.aspect_ratio_outlined),
            onSelected: (value) =>
                save(() => controller.resizeTile(instance.id, viewport, value)),
            itemBuilder: (context) => [
              for (final size in permittedSizes)
                PopupMenuItem(
                  value: size,
                  child: Row(
                    children: [
                      if (size == current) const Icon(Icons.check, size: 16),
                      Text('${size.columns} × ${size.rows}'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _move(
    BuildContext context,
    WidgetRef ref,
    IconData icon,
    String label,
    String action,
    int dx,
    int dy, {
    bool enabled = true,
  }) => IconButton(
    key: ValueKey('dashboard-move-$action-${instance.id}'),
    tooltip: appTranslate(context, label),
    visualDensity: VisualDensity.compact,
    iconSize: 19,
    onPressed: enabled
        ? () => save(
            () => ref
                .read(dashboardLayoutProvider.notifier)
                .nudgeTile(instance.id, viewport, horizontal: dx, vertical: dy),
          )
        : null,
    icon: Icon(icon),
  );
}
