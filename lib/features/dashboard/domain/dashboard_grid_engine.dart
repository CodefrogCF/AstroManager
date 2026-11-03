import 'dashboard_layout.dart';
import 'dashboard_grid.dart';

/// Deterministic collision handling and snap-to-grid for at most 30 widgets.
/// The moved/resized widget is placed first. Obstructed widgets flow to the
/// next available grid cell; no two resulting rectangles overlap.
abstract final class DashboardGridEngine {
  static List<DashboardTile> arrange({
    required DashboardViewport viewport,
    required List<DashboardWidgetInstance> widgets,
    required List<DashboardTile> saved,
    String? priorityWidgetId,
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
      final spanColumns = (desired?.columns ?? widget.size.columns)
          .clamp(1, viewport.columns)
          .toInt();
      final spanRows = (desired?.rows ?? widget.size.rows).clamp(1, 4).toInt();
      var row = (desired?.row ?? 0).clamp(0, 128).toInt();
      final firstColumn = (desired?.column ?? 0)
          .clamp(0, viewport.columns - spanColumns)
          .toInt();
      var found = false;
      while (row <= 128 && !found) {
        // First try the requested column, then other columns in the same row.
        final candidates = <int>[
          firstColumn,
          for (var col = 0; col <= viewport.columns - spanColumns; col++)
            if (col != firstColumn) col,
        ];
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
          row++;
        }
      }
      if (!found) {
        throw StateError('Dashboard grid is full.');
      }
    }
    return placed;
  }
}
