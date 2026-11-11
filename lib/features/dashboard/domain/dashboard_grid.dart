/// Independent arrangements for different device classes. A narrow device uses
/// one column, preserving room for large text and comfortable touch controls.
enum DashboardViewport {
  phone(1),
  tablet(2),
  desktop(4);

  const DashboardViewport(this.columns);
  final int columns;

  static DashboardViewport forWidth(double width) {
    if (width >= 1120) {
      return DashboardViewport.desktop;
    }
    if (width >= 680) {
      return DashboardViewport.tablet;
    }
    return DashboardViewport.phone;
  }
}

/// A grid rectangle. Positions use zero-based coordinates and can be snapped
/// to half columns and quarter rows.
final class DashboardTile {
  const DashboardTile({
    required this.widgetId,
    required this.column,
    required this.row,
    required this.columns,
    required this.rows,
  });

  static const columnStep = 0.5;
  static const rowStep = 0.25;
  static const lastRow = 128;
  static const maxRows = 4;

  final String widgetId;
  final num column;
  final num row;
  final num columns;
  final num rows;

  DashboardTile copyWith({num? column, num? row, num? columns, num? rows}) =>
      DashboardTile(
        widgetId: widgetId,
        column: column ?? this.column,
        row: row ?? this.row,
        columns: columns ?? this.columns,
        rows: rows ?? this.rows,
      );

  bool intersects(DashboardTile other) =>
      column < other.column + other.columns &&
      column + columns > other.column &&
      row < other.row + other.rows &&
      row + rows > other.row;

  void validate(DashboardViewport viewport) {
    if (!RegExp(r'^[A-Za-z0-9_.-]{1,100}$').hasMatch(widgetId) ||
        column < 0 ||
        row < 0 ||
        row > lastRow ||
        columns < 1 ||
        columns > viewport.columns ||
        rows < 1 ||
        rows > maxRows ||
        column.remainder(columnStep) != 0 ||
        row.remainder(rowStep) != 0 ||
        columns.remainder(columnStep) != 0 ||
        rows.remainder(rowStep) != 0 ||
        column + columns > viewport.columns) {
      throw const FormatException('Invalid dashboard tile position.');
    }
  }

  Map<String, Object> toJson() => {
    'widgetId': widgetId,
    'column': column,
    'row': row,
    'columns': columns,
    'rows': rows,
  };

  factory DashboardTile.fromJson(Object? value, DashboardViewport viewport) {
    if (value is! Map ||
        value['widgetId'] is! String ||
        value['column'] is! num ||
        value['row'] is! num ||
        value['columns'] is! num ||
        value['rows'] is! num) {
      throw const FormatException('Invalid dashboard tile.');
    }
    final tile = DashboardTile(
      widgetId: value['widgetId'] as String,
      column: value['column'] as num,
      row: value['row'] as num,
      columns: value['columns'] as num,
      rows: value['rows'] as num,
    );
    tile.validate(viewport);
    return tile;
  }
}

/// Ensures persisted tiles are well-formed and do not overlap.
abstract final class DashboardGridValidator {
  static void validateSaved({
    required DashboardViewport viewport,
    required List<DashboardTile> tiles,
    required Set<String> knownWidgetIds,
  }) {
    final visited = <String>{};
    for (final tile in tiles) {
      tile.validate(viewport);
      if (!knownWidgetIds.contains(tile.widgetId) ||
          !visited.add(tile.widgetId)) {
        throw const FormatException('Invalid dashboard widget reference.');
      }
    }
    for (var i = 0; i < tiles.length; i++) {
      for (var j = i + 1; j < tiles.length; j++) {
        if (tiles[i].intersects(tiles[j])) {
          throw const FormatException('Dashboard tiles overlap.');
        }
      }
    }
  }
}
