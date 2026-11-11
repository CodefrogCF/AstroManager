import 'dart:convert';
import 'dart:typed_data';

import 'package:astromanager/core/database/app_database.dart';
import 'package:astromanager/core/database/repositories/app_settings_repository.dart';
import 'package:astromanager/features/backup/data/backup_service.dart';
import 'package:astromanager/features/projects/data/attachments/attachment_store.dart';
import 'package:drift/native.dart';

import 'package:astromanager/features/dashboard/application/dashboard_layout_controller.dart';
import 'package:astromanager/features/dashboard/data/dashboard_layout_repository.dart';
import 'package:astromanager/features/dashboard/domain/dashboard_grid.dart';
import 'package:astromanager/features/dashboard/domain/dashboard_grid_engine.dart';
import 'package:astromanager/features/dashboard/domain/dashboard_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _UnusedAttachments implements SessionAttachmentStore {
  @override
  Future<void> put(String key, Uint8List bytes) async {}
  @override
  Future<Uint8List> read(String key) async => Uint8List(0);
  @override
  Future<void> remove(String key) async {}
}

void main() {
  test('layout v1 restores and upgrades without losing settings', () {
    final old = DashboardLayout.defaults.toJson()
      ..['formatVersion'] = 1
      ..remove('grids');
    final layout = DashboardLayout.fromJson(old);
    expect(layout.widgets.length, 4);
    expect(layout.grids, isEmpty);
    expect(layout.toJson()['formatVersion'], 3);
    final roundTrip = DashboardLayout.fromJson(
      jsonDecode(jsonEncode(layout.toJson())),
    );
    expect(roundTrip.widgets.length, 4);
  });

  test('version 2 keeps existing whole-cell placements', () {
    final saved = DashboardLayout.defaults.copyWith(
      grids: {
        DashboardViewport.tablet: const [
          DashboardTile(
            widgetId: 'weather-default',
            column: 1,
            row: 3,
            columns: 1,
            rows: 2,
          ),
        ],
      },
    );
    final legacy = saved.toJson()..['formatVersion'] = 2;
    expect(DashboardLayout.fromJson(legacy).toJson(), saved.toJson());
  });

  test(
    'three responsive classes have independent widths and all widgets fit',
    () {
      expect(DashboardViewport.forWidth(390), DashboardViewport.phone);
      expect(DashboardViewport.forWidth(810), DashboardViewport.tablet);
      expect(DashboardViewport.forWidth(1440), DashboardViewport.desktop);
      for (final viewport in DashboardViewport.values) {
        final placed = DashboardGridEngine.arrange(
          viewport: viewport,
          widgets: DashboardLayout.defaults.widgets,
          saved: const [],
        );
        expect(placed.length, 4);
        for (final tile in placed) {
          tile.validate(viewport);
        }
        for (var i = 0; i < placed.length; i++) {
          for (var j = i + 1; j < placed.length; j++) {
            expect(placed[i].intersects(placed[j]), isFalse);
          }
        }
      }
    },
  );

  test('resizing moves widgets below down and back up without gaps', () async {
    final store = MemoryDashboardLayoutRepository(
      DashboardLayout.defaults.copyWith(
        widgets: [
          ...DashboardLayout.defaults.widgets,
          const DashboardWidgetInstance(
            id: 'hidden',
            typeId: 'tonight',
            visible: false,
          ),
        ],
      ),
    );
    final container = ProviderContainer.test(
      overrides: [dashboardLayoutRepositoryProvider.overrideWithValue(store)],
    );
    await container.read(dashboardLayoutProvider.future);
    final controller = container.read(dashboardLayoutProvider.notifier);
    const viewport = DashboardViewport.phone;

    for (final height in [2, 1.25]) {
      await controller.resizeTile(
        'weather-default',
        viewport,
        DashboardWidgetSize(1, height),
      );
      final reloaded = await store.load();
      final visible = reloaded.grids[viewport]!.where(
        (tile) => tile.widgetId != 'hidden',
      );
      expect(visible.map((tile) => tile.row), [
        0,
        height,
        height + 1,
        height + 2,
      ]);
      expect(visible.first.rows, height);
    }
  });

  test(
    'moving and resizing reflows collisions without disturbing other screens',
    () async {
      final store = MemoryDashboardLayoutRepository();
      final container = ProviderContainer.test(
        overrides: [dashboardLayoutRepositoryProvider.overrideWithValue(store)],
      );
      await container.read(dashboardLayoutProvider.future);
      final controller = container.read(dashboardLayoutProvider.notifier);
      await controller.placeTile(
        'actions-default',
        DashboardViewport.tablet,
        column: 0,
        row: 0,
      );
      await controller.resizeTile(
        'actions-default',
        DashboardViewport.tablet,
        const DashboardWidgetSize(2, 2),
      );
      final current = container.read(dashboardLayoutProvider).requireValue;
      final tablet = current.grids[DashboardViewport.tablet]!;
      final moved = tablet.singleWhere(
        (tile) => tile.widgetId == 'actions-default',
      );
      expect(moved.column, 0);
      expect(moved.row, 0);
      expect(moved.columns, 2);
      expect(moved.rows, 2);
      DashboardGridValidator.validateSaved(
        viewport: DashboardViewport.tablet,
        tiles: tablet,
        knownWidgetIds: current.widgets.map((w) => w.id).toSet(),
      );
      expect(current.grids.containsKey(DashboardViewport.desktop), isFalse);
      expect(current.grids.containsKey(DashboardViewport.phone), isFalse);
      expect(
        DashboardLayout.fromJson(jsonDecode(jsonEncode(current.toJson())))
            .grids[DashboardViewport.tablet]!
            .length,
        4,
      );
      await controller.resetViewport(DashboardViewport.tablet);
      final after = container.read(dashboardLayoutProvider).requireValue;
      expect(after.grids.containsKey(DashboardViewport.tablet), isFalse);
      expect(after.widgets.length, 4);
    },
  );

  test('narrowing a tile frees space for the next widget beside it', () async {
    final store = MemoryDashboardLayoutRepository(
      const DashboardLayout(
        widgets: [
          DashboardWidgetInstance(
            id: 'wide',
            typeId: 'forecast',
            size: DashboardWidgetSize(2, 1),
          ),
          DashboardWidgetInstance(id: 'next', typeId: 'tonight'),
        ],
      ),
    );
    final container = ProviderContainer.test(
      overrides: [dashboardLayoutRepositoryProvider.overrideWithValue(store)],
    );
    await container.read(dashboardLayoutProvider.future);
    await container
        .read(dashboardLayoutProvider.notifier)
        .resizeTile(
          'wide',
          DashboardViewport.tablet,
          const DashboardWidgetSize(1, 1),
        );
    final next = store.layout.grids[DashboardViewport.tablet]!.singleWhere(
      (tile) => tile.widgetId == 'next',
    );
    expect(next.row, 0);
    expect(next.column, 1);
  });

  test('malformed placements and overlaps fail validation', () {
    const a = DashboardTile(
      widgetId: 'a',
      column: 0,
      row: 0,
      columns: 1,
      rows: 1,
    );
    const b = DashboardTile(
      widgetId: 'b',
      column: 0,
      row: 0,
      columns: 1,
      rows: 1,
    );
    const widgets = [
      DashboardWidgetInstance(id: 'a', typeId: 'observing-site'),
      DashboardWidgetInstance(id: 'b', typeId: 'observing-site'),
    ];
    expect(
      () => DashboardLayout(
        widgets: widgets,
        grids: {
          DashboardViewport.phone: [a, b],
        },
      ).validate(),
      throwsFormatException,
    );
    expect(
      () => const DashboardTile(
        widgetId: 'a',
        column: 1,
        row: 0,
        columns: 1,
        rows: 1,
      ).validate(DashboardViewport.phone),
      throwsFormatException,
    );
    expect(
      () => DashboardLayout.fromJson({
        ...DashboardLayout.defaults.toJson(),
        'grids': {'invalid-device': []},
      }),
      throwsFormatException,
    );
  });

  test('hidden widgets never need a geometry to be restored later', () async {
    const layout = DashboardLayout(
      widgets: [
        DashboardWidgetInstance(
          id: 'a',
          typeId: 'observing-site',
          visible: false,
        ),
        DashboardWidgetInstance(id: 'b', typeId: 'quick-actions'),
      ],
    );
    final visible = DashboardGridEngine.arrange(
      viewport: DashboardViewport.phone,
      widgets: layout.widgets.where((w) => w.visible).toList(),
      saved: const [],
    );
    expect(visible.map((tile) => tile.widgetId), ['b']);
    expect(
      DashboardLayout.fromJson(jsonDecode(jsonEncode(layout.toJson())))
          .widgets
          .first
          .visible,
      isFalse,
    );
  });

  test('fractional layouts survive .ambackup export and restore', () async {
    final source = AppDatabase(NativeDatabase.memory());
    final target = AppDatabase(NativeDatabase.memory());
    addTearDown(source.close);
    addTearDown(target.close);
    final saved = DashboardLayout.defaults.copyWith(
      selectedLocationId: 'restored-site',
      widgets: [
        ...DashboardLayout.defaults.widgets,
        const DashboardWidgetInstance(
          id: 'hidden-extension',
          typeId: 'future-widget',
          visible: false,
          settings: {'size': 3, 'useCache': true},
        ),
      ],
      grids: {
        DashboardViewport.phone: const [
          DashboardTile(
            widgetId: 'actions-default',
            column: 0,
            row: 0,
            columns: 1,
            rows: 2,
          ),
        ],
        DashboardViewport.tablet: const [
          DashboardTile(
            widgetId: 'targets-default',
            column: 0,
            row: 0,
            columns: 2,
            rows: 1,
          ),
        ],
        DashboardViewport.desktop: const [
          DashboardTile(
            widgetId: 'weather-default',
            column: 2.5,
            row: 3.25,
            columns: 1.5,
            rows: 1.75,
          ),
        ],
      },
    );
    await SettingsDashboardLayoutRepository(AppSettingsRepository(source))
        .save(saved);
    final archive = await AstroBackupService(
      source,
      attachments: _UnusedAttachments(),
    ).export();
    await AstroBackupService(
      target,
      attachments: _UnusedAttachments(),
    ).restore(archive);
    final restored = await SettingsDashboardLayoutRepository(
      AppSettingsRepository(target),
    ).load();
    final tile = restored.grids[DashboardViewport.phone]!.single;
    expect(tile.widgetId, 'actions-default');
    expect(tile.rows, 2);
    expect(restored.widgets.length, 5);
    expect(restored.selectedLocationId, 'restored-site');
    expect(restored.widgets.last.visible, isFalse);
    expect(restored.widgets.last.settings['useCache'], isTrue);
    expect(restored.grids[DashboardViewport.tablet]!.single.columns, 2);
    expect(restored.grids[DashboardViewport.desktop]!.single.row, 3.25);
    expect(jsonEncode(restored.toJson()), jsonEncode(saved.toJson()));
  });
}
