import 'dashboard_grid.dart';
import 'dashboard_layout.dart';

/// Deterministic collision handling and snap-to-grid for at most 30 widgets.
/// The moved/resized widget is placed first. Obstructed widgets flow to the
/// next available grid cell; no two resulting rectangles overlap.
abstract final class DashboardGridEngine {
  /// Insert a tile at the hovered position in a single-column layout. Keep
  /// gaps between slots and use the actual tile heights to place each widget.
  static List<DashboardTile>? reorderColumn(
    List<DashboardTile> tiles,
    String widgetId,
    String targetId,
  ) {
    final original = [...tiles]..sort((a, b) => a.row.compareTo(b.row));
    final from = original.indexWhere((tile) => tile.widgetId == widgetId);
    final to = original.indexWhere((tile) => tile.widgetId == targetId);
    if (from < 0 || to < 0 || from == to) return null;

    final reordered = [...original];
    final moved = reordered.removeAt(from);
    reordered.insert(to, moved);
    final placed = <DashboardTile>[];
    var row = original.first.row;
    for (var i = 0; i < reordered.length; i++) {
      final tile = reordered[i];
      placed.add(tile.copyWith(row: row));
      if (i + 1 < original.length) {
        final gap = original[i + 1].row - original[i].row - original[i].rows;
        row += tile.rows + gap;
      }
    }
    // Valid old layouts can have tiles at the last available row. Fall back
    // to ordinary placement if the reorder would exceed that bound.
    return placed.last.row <= DashboardTile.lastRow ? placed : null;
  }

  static List<DashboardTile> arrange({
    required DashboardViewport viewport,
    required List<DashboardWidgetInstance> widgets,
    required List<DashboardTile> saved,
    String? priorityWidgetId,
    num? compactFromRow,
  }) {
    final previous = {for (final tile in saved) tile.widgetId: tile};
    final ordered = [...widgets];
    // Existing placement coordinates win over legacy order; unspecified tiles
    // are appended in the stable widget order.
    ordered.sort((a, b) {
      if (a.id == priorityWidgetId) {
        return -1;
      }
      if (b.id == priorityWidgetId) {
        return 1;
      }
      if (a.visible != b.visible) {
        return a.visible ? -1 : 1;
      }
      final ta = previous[a.id];
      final tb = previous[b.id];
      if (ta == null && tb == null) {
        return widgets.indexOf(a).compareTo(widgets.indexOf(b));
      }
      if (ta == null) {
        return 1;
      }
      if (tb == null) {
        return -1;
      }
      final byRow = ta.row.compareTo(tb.row);
      return byRow != 0 ? byRow : ta.column.compareTo(tb.column);
    });
    final placed = <DashboardTile>[];
    for (final widget in ordered) {
      final desired = previous[widget.id];
      final spanColumns = (desired?.columns ?? widget.size.columns).clamp(
        1,
        viewport.columns,
      );
      final spanRows = (desired?.rows ?? widget.size.rows).clamp(
        1,
        DashboardTile.maxRows,
      );
      var row = (desired?.row ?? 0).clamp(0, DashboardTile.lastRow);
      final firstColumn = (desired?.column ?? 0).clamp(
        0,
        viewport.columns - spanColumns,
      );
      if (compactFromRow != null &&
          row >= compactFromRow &&
          widget.visible &&
          widget.id != priorityWidgetId) {
        // Pack from the resized tile's row so later widgets can use space
        // freed below or beside it. Prefer their original columns on ties.
        row = compactFromRow;
      }
      // First try the requested column, then other columns in the same row.
      final candidates = <num>[
        firstColumn,
        for (
          num col = 0;
          col <= viewport.columns - spanColumns;
          col += DashboardTile.columnStep
        )
          if (col != firstColumn) col,
      ];
      var found = false;
      while (row <= DashboardTile.lastRow && !found) {
        for (final col in candidates) {
          final tile = DashboardTile(
            widgetId: widget.id,
            column: col,
            row: row,
            columns: spanColumns,
            rows: spanRows,
          );
          if (!placed.any(tile.intersects)) {
            placed.add(tile);
            found = true;
            break;
          }
        }
        if (!found) {
          row += DashboardTile.rowStep;
        }
      }
      if (!found) {
        throw StateError('Dashboard grid is full.');
      }
    }
    return placed;
  }
}
