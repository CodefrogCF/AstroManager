import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_text.dart';
import '../application/dashboard_layout_controller.dart';
import '../domain/dashboard_grid.dart';
import '../domain/dashboard_grid_engine.dart';
import '../domain/dashboard_layout.dart';
import 'dashboard_size_fields.dart';

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
  DashboardTile? _dropPreview;
  static const _gap = 12.0;

  Future<void> _save(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText('Could not save dashboard changes.'),
                Text('$error'),
              ],
            ),
          ),
        );
      }
    }
  }

  void _showDropPreview(DashboardTile? tile) {
    if (_dropPreview?.widgetId == tile?.widgetId &&
        _dropPreview?.column == tile?.column &&
        _dropPreview?.row == tile?.row &&
        _dropPreview?.columns == tile?.columns &&
        _dropPreview?.rows == tile?.rows) {
      return;
    }
    setState(() => _dropPreview = tile);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final viewport = DashboardViewport.forWidth(constraints.maxWidth);
      final columns = viewport.columns;
      final cellWidth = (constraints.maxWidth - (columns - 1) * _gap) / columns;
      // Scaled content remains scrollable inside its card, but reserve a
      // larger visible area for headings, actions and status messages.
      final textScale = math.max(
        1.0,
        MediaQuery.textScalerOf(context).scale(16) / 16,
      );
      final cellHeight =
          (widget.editing ? 248.0 : 198.0) + (textScale - 1.0) * 116.0;
      final columnStride = cellWidth + _gap;
      final rowStride = cellHeight + _gap;
      final tiles = DashboardGridEngine.arrange(
        viewport: viewport,
        widgets: widget.widgets,
        saved: widget.layout.grids[viewport] ?? const [],
      );
      final maxRow = tiles.fold<num>(
        0,
        (maxBottom, tile) => math.max(maxBottom, tile.row + tile.rows),
      );
      final height =
          (maxRow * rowStride -
                  (maxRow > 0 ? _gap : 0) +
                  (widget.editing ? rowStride * DashboardTile.rowStep : 0))
              .toDouble();
      final byId = {
        for (final instance in widget.widgets) instance.id: instance,
      };

      Rect bounds(DashboardTile tile) => Rect.fromLTWH(
        (tile.column * columnStride).toDouble(),
        (tile.row * rowStride).toDouble(),
        (tile.columns * columnStride - _gap).toDouble(),
        (tile.rows * rowStride - _gap).toDouble(),
      );

      ({DashboardTile tile, String? overWidgetId})? destination(
        DragTargetDetails<String> details,
      ) {
        final box = _gridKey.currentContext?.findRenderObject();
        final source = tiles
            .where((tile) => tile.widgetId == details.data)
            .firstOrNull;
        if (!widget.editing ||
            box is! RenderBox ||
            !box.hasSize ||
            source == null) {
          return null;
        }
        final pointer = box.globalToLocal(details.offset);
        final target = tiles
            .where((tile) => bounds(tile).contains(pointer))
            .firstOrNull;
        if (viewport == DashboardViewport.phone && target != null) {
          final reordered = DashboardGridEngine.reorderColumn(
            tiles,
            source.widgetId,
            target.widgetId,
          );
          if (reordered != null) {
            return (
              tile: reordered.firstWhere(
                (tile) => tile.widgetId == source.widgetId,
              ),
              overWidgetId: target.widgetId,
            );
          }
        }
        // Over a tile, use its origin. In empty space, snap the pointer to
        // the nearest valid grid line within the dashboard.
        final column =
            target?.column ??
            (pointer.dx / columnStride / DashboardTile.columnStep).round() *
                DashboardTile.columnStep;
        final row =
            target?.row ??
            (pointer.dy / rowStride / DashboardTile.rowStep).round() *
                DashboardTile.rowStep;
        return (
          tile: source.copyWith(
            column: column.clamp(0, columns - source.columns),
            row: row.clamp(0, DashboardTile.lastRow),
          ),
          overWidgetId: null,
        );
      }

      return FocusTraversalGroup(
        child: DragTarget<String>(
          onWillAcceptWithDetails: (details) =>
              widget.editing && byId.containsKey(details.data),
          onMove: (details) => _showDropPreview(destination(details)?.tile),
          onLeave: (_) => _showDropPreview(null),
          onAcceptWithDetails: (details) {
            final drop = destination(details);
            _showDropPreview(null);
            if (drop == null) return;
            final target = drop.tile;
            final current = tiles.firstWhere(
              (tile) => tile.widgetId == target.widgetId,
            );
            if (target.column == current.column && target.row == current.row) {
              return;
            }
            _save(
              () => ref
                  .read(dashboardLayoutProvider.notifier)
                  .placeTile(
                    target.widgetId,
                    viewport,
                    column: target.column,
                    row: target.row,
                    overWidgetId: drop.overWidgetId,
                  ),
            );
          },
          builder: (context, candidates, rejected) => SizedBox(
            key: _gridKey,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final tile in tiles)
                  Positioned.fromRect(
                    key: ValueKey(tile.widgetId),
                    rect: bounds(tile),
                    child: Semantics(
                      container: true,
                      sortKey: OrdinalSortKey(
                        tile.row / DashboardTile.rowStep * columns +
                            tile.column,
                      ),
                      child: SizedBox(
                        key: ValueKey('dashboard-widget-${tile.widgetId}'),
                        child: Column(
                          children: [
                            if (widget.editing)
                              _TileEditBar(
                                instance: byId[tile.widgetId]!,
                                title: widget.titleFor(byId[tile.widgetId]!),
                                viewport: viewport,
                                tile: tile,
                                sizes: widget.sizesFor(byId[tile.widgetId]!),
                                save: _save,
                              ),
                            Expanded(
                              child: widget.tileBuilder(
                                context,
                                byId[tile.widgetId]!,
                                viewport,
                                tile,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (widget.editing &&
                    candidates.isNotEmpty &&
                    _dropPreview != null)
                  Positioned.fromRect(
                    rect: bounds(_dropPreview!),
                    child: IgnorePointer(
                      child: DecoratedBox(
                        key: const ValueKey('dashboard-drop-preview'),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary
                              .withValues(alpha: 0.1),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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

  Future<void> _resize(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(dashboardLayoutProvider.notifier);
    final initial = DashboardWidgetSize(tile.columns, tile.rows);
    var size = initial;
    final selection = await showDialog<DashboardWidgetSize>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const AppText('Resize widget'),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: DashboardSizeFields(
                viewport: viewport,
                sizes: sizes,
                initialSize: initial,
                size: size,
                onChanged: (value) => setState(() => size = value),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: size == initial
                  ? null
                  : () => Navigator.pop(context, size),
              child: const AppText('Save'),
            ),
          ],
        ),
      ),
    );
    if (selection != null && context.mounted) {
      await save(() => controller.resizeTile(instance.id, viewport, selection));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      container: true,
      label:
          '${appTranslate(context, 'Edit widget')}: ${appTranslate(context, title)}',
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 0,
          runSpacing: 0,
          children: [
            Draggable<String>(
              data: instance.id,
              maxSimultaneousDrags: 1,
              hitTestBehavior: HitTestBehavior.opaque,
              dragAnchorStrategy: pointerDragAnchorStrategy,
              feedback: Transform.translate(
                offset: const Offset(12, 12),
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: AppText(title),
                  ),
                ),
              ),
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Tooltip(
                  triggerMode: TooltipTriggerMode.manual,
                  message: appTranslate(context, 'Drag widget'),
                  child: SizedBox(
                    key: ValueKey('dashboard-drag-${instance.id}'),
                    width: 48,
                    height: 48,
                    child: const Icon(Icons.drag_indicator),
                  ),
                ),
              ),
            ),
            Tooltip(
              message: appTranslate(context, 'Resize widget'),
              child: OutlinedButton.icon(
                key: ValueKey('dashboard-size-${instance.id}'),
                icon: const Icon(Icons.aspect_ratio_outlined),
                label: const AppText('Resize'),
                onPressed: () => _resize(context, ref),
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
          ],
        ),
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
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
