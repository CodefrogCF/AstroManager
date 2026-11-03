import 'dart:convert';

import 'package:astromanager/features/dashboard/domain/dashboard_layout.dart';
import 'package:astromanager/features/dashboard/data/dashboard_layout_repository.dart';
import 'package:astromanager/features/dashboard/application/dashboard_layout_controller.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astromanager/core/database/app_database.dart';
import 'package:astromanager/core/database/repositories/app_settings_repository.dart';

void main() {
  test('default preset is stable and locally serializable', () {
    final defaultLayout = DashboardLayout.defaults;
    expect(defaultLayout.widgets.map((widget) => widget.typeId), [
      'seven-night-weather',
      'top-targets',
      'tonight',
      'quick-actions',
    ]);
    expect(defaultLayout.widgets.every((widget) => widget.visible), isTrue);
    final restored = DashboardLayout.fromJson(
      jsonDecode(jsonEncode(defaultLayout.toJson())),
    );
    expect(jsonEncode(restored.toJson()), jsonEncode(defaultLayout.toJson()));
    expect(restored.selectedLocationId, isNull);
  });

  test('unknown widget type survives persistence', () {
    const layout = DashboardLayout(
      widgets: [
        DashboardWidgetInstance(
          id: 'a',
          typeId: 'third-party',
          visible: false,
          settings: {'option': 3},
        ),
      ],
    );
    final restored = DashboardLayout.fromJson(
      jsonDecode(jsonEncode(layout.toJson())),
    );
    expect(restored.widgets.single.typeId, 'third-party');
    expect(restored.widgets.single.settings['option'], 3);
    expect(restored.widgets.single.visible, false);
  });

  test('malformed versions, identifiers, sizes and duplicate instances are rejected', () {
    final invalid = DashboardLayout.defaults.toJson();
    expect(
      () => DashboardLayout.fromJson({...invalid, 'formatVersion': 99}),
      throwsFormatException,
    );
    expect(
      () => DashboardWidgetSize.fromJson({'columns': 0, 'rows': 1}),
      throwsFormatException,
    );
    expect(
      () => DashboardLayout(
        widgets: [
          DashboardLayout.defaults.widgets.first,
          DashboardLayout.defaults.widgets.first,
        ],
      ).validate(),
      throwsFormatException,
    );
    expect(
      () => const DashboardWidgetInstance(id: '', typeId: 'a').validate(),
      throwsFormatException,
    );
    expect(
      () => const DashboardWidgetInstance(
        id: 'ok',
        typeId: 'a',
        settings: {
          'unsafe': <int>[1],
        },
      ).validate(),
      throwsFormatException,
    );
  });

  test('settings-backed layout persists without a schema migration', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = AppSettingsRepository(database);
    final repository = SettingsDashboardLayoutRepository(settings);
    expect((await repository.load()).widgets.length, 4);
    const saved = DashboardLayout(
      selectedLocationId: 'site-a',
      widgets: [
        DashboardWidgetInstance(
          id: 'actions',
          typeId: 'quick-actions',
          settings: {'compact': true},
          size: DashboardWidgetSize(2, 1),
        ),
      ],
    );
    await repository.save(saved);
    final loaded = await SettingsDashboardLayoutRepository(settings).load();
    expect(loaded.selectedLocationId, 'site-a');
    expect(loaded.widgets.single.settings['compact'], true);
    expect(
      await settings.get(SettingsDashboardLayoutRepository.storageKey),
      isNotNull,
    );
  });

  test('corrupt settings are rejected without silent replacement', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = AppSettingsRepository(database);
    await settings.put(
      SettingsDashboardLayoutRepository.storageKey,
      '{bad json',
    );
    final repository = SettingsDashboardLayoutRepository(settings);
    await expectLater(repository.load(), throwsFormatException);
    expect(
      await settings.get(SettingsDashboardLayoutRepository.storageKey),
      '{bad json',
    );
  });

  test(
    'explicit recovery preserves invalid configuration until requested',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final settings = AppSettingsRepository(database);
      final repository = SettingsDashboardLayoutRepository(settings);
      await settings.put(
        SettingsDashboardLayoutRepository.storageKey,
        '{bad json',
      );
      final container = ProviderContainer.test(
        overrides: [
          dashboardLayoutRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await expectLater(
        container.read(dashboardLayoutProvider.future),
        throwsFormatException,
      );
      expect(
        await settings.get(SettingsDashboardLayoutRepository.storageKey),
        '{bad json',
      );
      await container.read(dashboardLayoutProvider.notifier).recoverDefaults();
      final recovered = await repository.load();
      expect(recovered.widgets.length, 4);
      expect(recovered.toJson()['formatVersion'], 2);
      expect(
        container.read(dashboardLayoutProvider).requireValue.widgets.length,
        4,
      );
    },
  );

  test(
    'layout controller serializes changes and preserves widget settings',
    () async {
      final store = MemoryDashboardLayoutRepository();
      final container = ProviderContainer.test(
        overrides: [dashboardLayoutRepositoryProvider.overrideWithValue(store)],
      );
      await container.read(dashboardLayoutProvider.future);
      final controller = container.read(dashboardLayoutProvider.notifier);
      await Future.wait([
        controller.selectLocation('site-b'),
        controller.addWidget(
          'observing-site',
          const DashboardWidgetSize(1, 1),
          settings: {'showCoordinates': false},
        ),
      ]);
      var state = container.read(dashboardLayoutProvider).requireValue;
      expect(state.selectedLocationId, 'site-b');
      expect(state.widgets.length, 5);
      final added = state.widgets.last;
      await controller.setVisible(added.id, false);
      expect(
        container
            .read(dashboardLayoutProvider)
            .requireValue
            .widgets
            .last
            .visible,
        false,
      );
      await controller.moveWidget(added.id, -1);
      await controller.configureWidget(
        added.id,
        size: const DashboardWidgetSize(2, 1),
        settings: {'showCoordinates': true},
      );
      state = container.read(dashboardLayoutProvider).requireValue;
      expect(state.widgets[state.widgets.length - 2].id, added.id);
      expect(
        state.widgets[state.widgets.length - 2].settings['showCoordinates'],
        true,
      );
      await controller.removeWidget(added.id);
      expect(
        container.read(dashboardLayoutProvider).requireValue.widgets.length,
        4,
      );
      expect(store.saveCount, 6);
    },
  );
}
