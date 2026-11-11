import 'dart:convert';
import 'dart:io';

import 'package:astromanager/app/theme/app_themes.dart';
import 'package:astromanager/features/dashboard/application/dashboard_layout_controller.dart';
import 'package:astromanager/features/dashboard/data/dashboard_layout_repository.dart';
import 'package:astromanager/features/dashboard/domain/dashboard_grid.dart';
import 'package:astromanager/features/dashboard/domain/dashboard_layout.dart';
import 'package:astromanager/features/dashboard/presentation/dashboard_editable_grid.dart';
import 'package:astromanager/l10n/ui_strings.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _sharedWork = FutureProvider<int>((ref) async => 5);

const _layout = DashboardLayout(
  widgets: [
    DashboardWidgetInstance(id: 'first', typeId: 'fixture'),
    DashboardWidgetInstance(id: 'second', typeId: 'fixture'),
  ],
);

class _GridHarness extends ConsumerWidget {
  const _GridHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(dashboardLayoutProvider);
    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(2)),
      child: Scaffold(
        body: SingleChildScrollView(
          primary: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: layout.when(
              loading: () => const CircularProgressIndicator(),
              error: (error, _) => Text('$error'),
              data: (value) => DashboardEditableGrid(
                layout: value,
                widgets: value.widgets,
                editing: true,
                titleFor: (widget) => 'Fixture ${widget.id}',
                sizesFor: (_) => const [
                  DashboardWidgetSize(1, 1),
                  DashboardWidgetSize(1, 2),
                ],
                tileBuilder: (context, instance, viewport, tile) =>
                    Card(child: Center(child: Text('Tile ${instance.id}'))),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _contrast(Color a, Color b) {
  final light = a.computeLuminance();
  final dark = b.computeLuminance();
  final max = light > dark ? light : dark;
  final min = light < dark ? light : dark;
  return (max + 0.05) / (min + 0.05);
}

void main() {
  for (final device in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets('${device.name} drop uses the highlighted tile position', (
      tester,
    ) async {
      final phone = device == PointerDeviceKind.touch;
      final viewport = phone
          ? DashboardViewport.phone
          : DashboardViewport.desktop;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(phone ? 390 : 1300, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final store = MemoryDashboardLayoutRepository(
        phone
            ? _layout.copyWith(
                widgets: [
                  _layout.widgets.first,
                  _layout.widgets.last.copyWith(
                    size: const DashboardWidgetSize(1, 1.5),
                  ),
                ],
              )
            : _layout,
      );

      Future<void> openDashboard() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dashboardLayoutRepositoryProvider.overrideWithValue(store),
            ],
            child: const MaterialApp(home: _GridHarness()),
          ),
        );
        await tester.pumpAndSettle();
      }

      await openDashboard();
      final grip = find.byKey(const ValueKey('dashboard-drag-first'));
      final first = find.byKey(const ValueKey('dashboard-widget-first'));
      final second = find.byKey(const ValueKey('dashboard-widget-second'));
      final originalFirst = tester.getTopLeft(first);
      final originalSecond = tester.getTopLeft(second);
      final expectedDrop = phone
          ? originalFirst + Offset(0, tester.getSize(second).height + 12)
          : originalSecond;
      final drag = await tester.startGesture(
        tester.getCenter(grip),
        kind: device,
      );
      await drag.moveBy(const Offset(0, 24));
      await drag.moveTo(originalSecond + const Offset(20, 4));
      await tester.pump();
      final preview = find.byKey(const ValueKey('dashboard-drop-preview'));
      expect(tester.getTopLeft(preview), expectedDrop);
      await drag.up();
      await tester.pumpAndSettle();

      expect(preview, findsNothing);
      expect(store.layout.grids[viewport], hasLength(2));
      expect(tester.getTopLeft(first), expectedDrop);
      expect(tester.getTopLeft(second), originalFirst);
      await tester.pumpWidget(const SizedBox.shrink());
      await openDashboard();
      expect(tester.getTopLeft(first), expectedDrop);
      expect(tester.getTopLeft(second), originalFirst);

      if (!phone) {
        final columnWidth = originalSecond.dx - originalFirst.dx;
        final emptySlot = originalFirst + Offset(columnWidth * 2.5, 0);
        final drag = await tester.startGesture(
          tester.getCenter(grip),
          kind: device,
        );
        await drag.moveBy(const Offset(24, 0));
        await drag.moveTo(emptySlot + const Offset(4, 4));
        await tester.pump();
        expect(tester.getTopLeft(preview), emptySlot);
        await drag.up();
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(first), emptySlot);
        expect(
          store.layout.grids[viewport]!
              .singleWhere((tile) => tile.widgetId == 'first')
              .column,
          2.5,
        );
      }
    });
  }

  test(
    'Codefrog and astronomy night palettes meet text and boundary contrast',
    () {
      for (final theme in [
        AstroThemes.dark,
        AstroThemes.light,
        AstroThemes.night,
      ]) {
        final scheme = theme.colorScheme;
        expect(
          _contrast(scheme.onSurface, scheme.surfaceContainerLow),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(scheme.onSurfaceVariant, scheme.surfaceContainerLow),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(scheme.primary, scheme.surfaceContainerLow),
          greaterThanOrEqualTo(3),
        );
      }
      expect(
        _contrast(AstroPalette.nightBorder, AstroPalette.nightSurface),
        greaterThanOrEqualTo(3),
      );
    },
  );

  test('English and German dashboard localization catalogs stay in sync', () {
    final en = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final de = jsonDecode(
      File('lib/l10n/app_de.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final enKeys = en.keys.where((key) => !key.startsWith('@')).toSet();
    final deKeys = de.keys.where((key) => !key.startsWith('@')).toSet();
    expect(deKeys, enKeys);
    expect(en['dashboardSaveError'], 'Could not save dashboard changes.');
    expect(de['dashboardSaveError'], isNotEmpty);
  });

  test('Dashboard UI labels are available in German', () {
    for (final label in [
      'Observing dashboard',
      'Edit layout',
      'Done editing',
      'Manage widgets',
      'Drag widget',
      'Move widget up',
      'Move widget down',
      'Move widget left',
      'Move widget right',
      'Resize widget',
      'Resize',
      'Width (columns)',
      'Height (rows)',
      'Reset layout',
      'Widget options',
      'Could not save dashboard changes.',
    ]) {
      expect(appGermanUiStrings[label], isNotNull, reason: label);
    }
  });

  test('legacy layout migrates while unknown widgets and settings survive', () {
    const saved = DashboardLayout(
      selectedLocationId: 'site-a',
      widgets: [
        DashboardWidgetInstance(
          id: 'custom',
          typeId: 'future-extension',
          visible: false,
          settings: {'note': 'preserve', 'limit': 2},
        ),
      ],
    );
    final legacy = saved.toJson()..['formatVersion'] = 1;
    legacy.remove('grids');
    final migrated = DashboardLayout.fromJson(jsonDecode(jsonEncode(legacy)));
    expect(migrated.selectedLocationId, 'site-a');
    expect(migrated.widgets.single.typeId, 'future-extension');
    expect(migrated.widgets.single.settings['note'], 'preserve');
    expect(migrated.widgets.single.visible, isFalse);
    expect(migrated.toJson()['formatVersion'], 3);
  });

  testWidgets('edit handles are usable at 200% text in portrait and landscape', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = MemoryDashboardLayoutRepository(_layout);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dashboardLayoutRepositoryProvider.overrideWithValue(store)],
        child: const MaterialApp(home: _GridHarness()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('dashboard-drag-first')), findsOneWidget);
    final moveDown = find.byKey(const ValueKey('dashboard-move-down-first'));
    expect(find.byTooltip('Move widget down'), findsWidgets);
    await tester.ensureVisible(moveDown);
    await tester.tap(moveDown);
    await tester.pumpAndSettle();
    expect(
      store.layout.grids[DashboardViewport.phone]!
          .singleWhere((tile) => tile.widgetId == 'first')
          .row,
      greaterThan(0),
    );
    final resize = find.byKey(const ValueKey('dashboard-size-first'));
    await tester.ensureVisible(resize);
    await tester.tap(resize);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dashboard-widget-height')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      store.layout.grids[DashboardViewport.phone]!
          .singleWhere((tile) => tile.widgetId == 'first')
          .rows,
      2,
    );
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(900, 520);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('dashboard-widget-first')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(1380, 800);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('dashboard-widget-second')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    // The phone-specific edit was not copied into the tablet or desktop grids.
    expect(store.layout.grids.containsKey(DashboardViewport.tablet), isFalse);
    expect(store.layout.grids.containsKey(DashboardViewport.desktop), isFalse);
  });

  testWidgets('two visible consumers share one asynchronous provider load', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _sharedWork.overrideWith((ref) async {
            calls++;
            return 42;
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                for (var i = 0; i < 2; i++)
                  Consumer(
                    builder: (context, ref, _) => Text(
                      ref.watch(_sharedWork).value?.toString() ?? 'Loading',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('42'), findsNWidgets(2));
    expect(calls, 1);
  });
}
