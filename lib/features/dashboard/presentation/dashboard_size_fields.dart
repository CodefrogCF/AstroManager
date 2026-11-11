import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_text.dart';
import '../domain/dashboard_grid.dart';
import '../domain/dashboard_layout.dart';

class DashboardSizeFields extends StatelessWidget {
  const DashboardSizeFields({
    super.key,
    required this.viewport,
    required this.sizes,
    required this.initialSize,
    required this.size,
    required this.onChanged,
  });

  final DashboardViewport viewport;
  final List<DashboardWidgetSize> sizes;
  final DashboardWidgetSize initialSize;
  final DashboardWidgetSize size;
  final ValueChanged<DashboardWidgetSize> onChanged;

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final widths = _values([
      initialSize.columns,
      for (final preset in sizes) preset.columns.clamp(1, viewport.columns),
    ], DashboardTile.columnStep);
    final heights = _values([
      initialSize.rows,
      for (final preset in sizes) preset.rows,
    ], DashboardTile.rowStep);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<num>(
          key: const ValueKey('dashboard-widget-width'),
          initialValue: size.columns,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: appTranslate(context, 'Width (columns)'),
          ),
          items: [
            for (final width in widths)
              DropdownMenuItem(value: width, child: Text(format.format(width))),
          ],
          onChanged: widths.length > 1
              ? (width) => onChanged(DashboardWidgetSize(width!, size.rows))
              : null,
        ),
        DropdownButtonFormField<num>(
          key: const ValueKey('dashboard-widget-height'),
          initialValue: size.rows,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: appTranslate(context, 'Height (rows)'),
          ),
          items: [
            for (final height in heights)
              DropdownMenuItem(
                value: height,
                child: Text(format.format(height)),
              ),
          ],
          onChanged: heights.length > 1
              ? (height) =>
                    onChanged(DashboardWidgetSize(size.columns, height!))
              : null,
        ),
      ],
    );
  }

  static List<num> _values(List<num> bounds, num step) {
    bounds.sort();
    return [
      for (var value = bounds.first; value <= bounds.last; value += step) value,
    ];
  }
}
