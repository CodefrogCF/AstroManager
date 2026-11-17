import 'dart:convert';

import 'package:astromanager/core/astronomy/astronomical_coordinates.dart';
import 'package:astromanager/features/atlas/application/sky_atlas_controller.dart';
import 'package:astromanager/features/atlas/domain/sky_atlas_models.dart';
import 'package:astromanager/features/atlas/presentation/sky_atlas_screen.dart';
import 'package:astromanager/features/targets/application/celestial_catalog_controller.dart';
import 'package:astromanager/features/targets/domain/models/celestial_object.dart';
import 'package:astromanager/features/targets/domain/repositories/celestial_catalog_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _AtlasCatalog extends Fake implements CelestialCatalogRepository {
  _AtlasCatalog(this.objects);

  final List<CelestialObject> objects;
  final tolerances = <double>[];

  @override
  Future<CelestialObject?> findAt(
    EquatorialPosition position, {
    required double toleranceDegrees,
  }) async {
    tolerances.add(toleranceDegrees);
    return objects
        .where((object) => object.raDegrees == position.raDegrees)
        .firstOrNull;
  }
}

void main() {
  const target = CelestialObject(
    id: 'NGC0224',
    designation: 'NGC 224',
    category: CelestialCategory.galaxy,
    sourceType: 'G',
    raDegrees: 10.6847,
    decDegrees: 41.2688,
    constellation: 'And',
    commonNames: 'Andromeda',
    aliases: 'M31',
    messierNumber: 31,
  );

  testWidgets('a selected catalog target is centered in the atlas model', (
    tester,
  ) async {
    SkyAtlasController? controller;
    await tester.pumpWidget(
      MaterialApp(
        home: SkyAtlasScreen(
          target: target,
          hostBuilder: (value) {
            controller = value;
            return const ColoredBox(color: Colors.black);
          },
        ),
      ),
    );
    final label = find.byKey(const ValueKey('atlas-selected-object'));
    expect(
      find.descendant(of: label, matching: find.text(target.displayTitle)),
      findsOneWidget,
    );
    expect(controller!.position.raDegrees, closeTo(10.6847, 1e-8));
    expect(controller!.markers.single.id, 'NGC0224');
    await tester.tap(find.byKey(const ValueKey('atlas-fov-0.5')));
    await tester.pump();
    expect(controller!.fieldOfViewDegrees, 0.5);
    await tester.tap(find.byKey(const ValueKey('atlas-recenter')));
    await tester.pump();
    expect(controller!.position.decDegrees, closeTo(41.2688, 1e-8));
  });

  testWidgets(
    'selecting objects changes the outline, label and catalog dialog',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const extended = CelestialObject(
        id: 'NGC1976',
        designation: 'NGC 1976',
        category: CelestialCategory.nebula,
        sourceType: 'HII',
        raDegrees: 83.82,
        decDegrees: -5.39,
        constellation: 'Ori',
        commonNames: 'Orion Nebula',
        aliases: 'M42',
        messierNumber: 42,
        visualMagnitude: 4,
        majorAxisArcmin: 66,
        minorAxisArcmin: 60,
      );
      late SkyAtlasController controller;
      final catalog = _AtlasCatalog(const [target, extended]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            celestialCatalogProvider.overrideWithBuild(
              (ref, notifier) => CelestialCatalogViewState(
                totalObjects: 2,
                query: '',
                category: null,
                results: const [target, extended],
              ),
            ),
            celestialCatalogRepositoryProvider.overrideWithValue(catalog),
          ],
          child: MaterialApp(
            home: SkyAtlasScreen(
              hostBuilder: (value) {
                controller = value;
                return const SizedBox.expand(key: ValueKey('fake-atlas'));
              },
            ),
          ),
        ),
      );
      void send(String type, [Map<String, Object> fields = const {}]) {
        controller.receive(
          jsonEncode({
            'protocol': SkyAtlasProtocol.identifier,
            'version': SkyAtlasProtocol.version,
            'type': type,
            ...fields,
          }),
        );
      }

      void select(CelestialObject object) => send('skyTap', {
        'ra': object.raDegrees,
        'dec': object.decDegrees,
        'tolerance': 0.02,
      });

      send('ready');
      await tester.pumpAndSettle();
      final label = find.byKey(const ValueKey('atlas-selected-object'));
      final dialog = find.byKey(const ValueKey('atlas-object-details'));
      expect(label, findsNothing);

      select(extended);
      await tester.pumpAndSettle();
      expect(catalog.tolerances, [0.02]);
      expect(
        find.descendant(of: label, matching: find.text(extended.displayTitle)),
        findsOneWidget,
      );
      expect(
        tester.getRect(label).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(const ValueKey('fake-atlas'))).top,
        ),
      );
      expect(controller.markers, isEmpty);
      final outline = controller.overlays.single;
      expect(outline.radiusDegrees, 0.55);
      expect(outline.position.raDegrees, extended.raDegrees);
      expect(outline.position.decDegrees, extended.decDegrees);

      send('viewChanged', {'ra': 84, 'dec': -4, 'fov': 0.8});
      await tester.pump();
      expect(controller.overlays.single, same(outline));
      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(dialog, findsOneWidget);
      expect(controller.pointerInputEnabled, isFalse);
      expect(find.text('Common names: Orion Nebula'), findsOneWidget);
      expect(find.text('Major axis: 66.0′'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(controller.pointerInputEnabled, isTrue);

      select(target);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: label, matching: find.text(target.displayTitle)),
        findsOneWidget,
      );
      expect(controller.overlays, isEmpty);
      expect(controller.markers.single.id, target.id);
      expect(controller.position.raDegrees, 84);
      expect(controller.fieldOfViewDegrees, 0.8);
      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: dialog, matching: find.text(target.displayTitle)),
        findsOneWidget,
      );
      expect(find.text('Common names: Andromeda'), findsOneWidget);
      expect(find.text('Major axis: unknown'), findsOneWidget);
      expect(find.textContaining('Orion Nebula'), findsNothing);
    },
  );

  testWidgets('a bridge error exposes retry without navigation', (
    tester,
  ) async {
    SkyAtlasController? controller;
    await tester.pumpWidget(
      MaterialApp(
        home: SkyAtlasScreen(
          hostBuilder: (value) {
            controller = value;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    controller!.reportError('Network is offline');
    await tester.pump();
    expect(find.text('Sky atlas unavailable'), findsOneWidget);
    expect(find.text('Network is offline'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('atlas-retry')));
    await tester.pump();
    expect(controller!.status, SkyAtlasStatus.loading);
    expect(find.text('Loading Aladin Lite sky survey...'), findsOneWidget);
  });
  testWidgets('attribution and retry stay visible when imagery tiles fail', (
    tester,
  ) async {
    SkyAtlasController? controller;
    await tester.pumpWidget(
      MaterialApp(
        home: SkyAtlasScreen(
          hostBuilder: (value) {
            controller = value;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    expect(find.byKey(const ValueKey('atlas-attribution')), findsOneWidget);
    controller!.receive(
      '{"protocol":"astromanager.aladin","version":1,'
      '"type":"imageryError","message":"Tile request failed"}',
    );
    await tester.pump();
    expect(find.textContaining('Tile request failed'), findsOneWidget);
    expect(find.byKey(const ValueKey('atlas-attribution')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('atlas-retry')));
    await tester.pump();
    expect(controller!.status, SkyAtlasStatus.loading);
    expect(find.byKey(const ValueKey('atlas-attribution')), findsOneWidget);
  });

  testWidgets(
    'unsupported platform offers explanation without pointless retry',
    (tester) async {
      SkyAtlasController? controller;
      await tester.pumpWidget(
        MaterialApp(
          home: SkyAtlasScreen(
            hostBuilder: (value) {
              controller = value;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      controller!.reportUnsupported('Open AstroManager Web instead.');
      await tester.pump();
      expect(find.text('Embedded sky atlas unsupported'), findsOneWidget);
      expect(find.byKey(const ValueKey('atlas-retry')), findsNothing);
      expect(find.byKey(const ValueKey('atlas-attribution')), findsOneWidget);
    },
  );
}
