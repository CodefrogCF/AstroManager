import 'dart:convert';

import 'package:astromanager/features/atlas/application/sky_atlas_controller.dart';
import 'package:astromanager/features/atlas/domain/sky_atlas_models.dart';
import 'package:astromanager/features/atlas/domain/camera_framing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const andromeda = SkyAtlasPosition(raDegrees: 10.6847, decDegrees: 41.2688);

  String event(String type, [Map<String, Object> fields = const {}]) =>
      jsonEncode({
        'protocol': SkyAtlasProtocol.identifier,
        'version': SkyAtlasProtocol.version,
        'type': type,
        ...fields,
      });

  test('state contains positions, FoV, and marker overlay', () {
    final controller = SkyAtlasController(
      initialPosition: andromeda,
      initialMarkers: const [
        SkyAtlasMarker(id: 'M31', position: andromeda, label: 'Andromeda'),
      ],
    );
    addTearDown(controller.dispose);
    final json = jsonDecode(controller.stateJson) as Map<String, dynamic>;
    expect(json['protocol'], SkyAtlasProtocol.identifier);
    expect(json['version'], 1);
    expect(json['ra'], closeTo(10.6847, 1e-6));
    expect(json['dec'], closeTo(41.2688, 1e-6));
    expect(json['fov'], 3.0);
    expect((json['markers'] as List).single['id'], 'M31');
    expect(json['overlays'], isEmpty);
  });

  test('Flutter changes increment only outbound revision', () {
    final controller = SkyAtlasController(initialPosition: andromeda);
    addTearDown(controller.dispose);
    expect(controller.revision, 0);
    controller.goto(const SkyAtlasPosition(raDegrees: 83.633, decDegrees: 22));
    controller.setFieldOfView(1.2);
    expect(controller.revision, 2);
    expect(controller.position.raDegrees, 83.633);
    expect(controller.fieldOfViewDegrees, 1.2);
    controller.receive(
      event('viewChanged', {'ra': 84.1, 'dec': 22.2, 'fov': 2.5}),
    );
    expect(controller.revision, 2, reason: 'No view-change echo loops');
    expect(controller.fieldOfViewDegrees, 2.5);
  });

  test('ready, error, and retry transitions are explicit', () {
    final controller = SkyAtlasController(initialPosition: andromeda);
    addTearDown(controller.dispose);
    expect(controller.status, SkyAtlasStatus.loading);
    controller.receive(event('ready'));
    expect(controller.status, SkyAtlasStatus.ready);
    controller.receive(
      event('error', {'message': 'Failed to load image survey'}),
    );
    expect(controller.status, SkyAtlasStatus.error);
    expect(controller.error, contains('Failed'));
    controller.resetLoading();
    expect(controller.status, SkyAtlasStatus.loading);
    expect(controller.error, isNull);
  });

  test('invalid packets and impossible positions are ignored', () {
    final controller = SkyAtlasController(initialPosition: andromeda);
    addTearDown(controller.dispose);
    controller.receive('not JSON');
    controller.receive('{"protocol":"unknown","version":1,"type":"ready"}');
    controller.receive(event('viewChanged', {'ra': 400, 'dec': 0, 'fov': 1}));
    controller.receive(event('viewChanged', {'ra': 2, 'dec': 2, 'fov': -4}));
    expect(controller.position.raDegrees, andromeda.raDegrees);
    expect(controller.status, SkyAtlasStatus.loading);
    expect(() => controller.setFieldOfView(0), throwsArgumentError);
    expect(
      () => controller.goto(
        const SkyAtlasPosition(raDegrees: double.nan, decDegrees: 2),
      ),
      throwsArgumentError,
    );
    expect(
      () => SkyAtlasController(
        initialPosition: andromeda,
        initialMarkers: const [
          SkyAtlasMarker(id: '', label: '', position: andromeda),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('circle overlays are validated and sent in JSON state', () {
    final controller = SkyAtlasController(initialPosition: andromeda);
    addTearDown(controller.dispose);
    controller.setOverlays(const [
      SkyAtlasCircleOverlay(position: andromeda, radiusDegrees: 0.5),
    ]);
    final json = jsonDecode(controller.stateJson) as Map<String, dynamic>;
    expect((json['overlays'] as List).single['radius'], 0.5);
    expect(
      () => controller.setOverlays(const [
        SkyAtlasCircleOverlay(position: andromeda, radiusDegrees: -1),
      ]),
      throwsArgumentError,
    );
  });

  test('marker labels survive JSON encoding without altering protocol', () {
    final controller = SkyAtlasController(initialPosition: andromeda);
    addTearDown(controller.dispose);
    controller.setMarkers(const [
      SkyAtlasMarker(
        id: 'M31',
        label: '<script>alert("x")</script>',
        position: andromeda,
      ),
    ]);
    final json = jsonDecode(controller.stateJson) as Map<String, dynamic>;
    final markers = json['markers'] as List;
    expect(markers.single['label'], '<script>alert("x")</script>');
    // HTML-escaping happens in the atlas JavaScript display layer.
  });
  test(
    'imagery failure and retry retain camera framing, location and projection',
    () {
      final controller = SkyAtlasController(initialPosition: andromeda);
      addTearDown(controller.dispose);
      final frame = CameraFramingGeometry.calculate(
        configuration: const CameraFramingConfiguration(
          profileId: 'profile-1',
          center: andromeda,
          rotationDegrees: 42,
        ),
        horizontalFovDegrees: 2.5,
        verticalFovDegrees: 1.7,
      );
      controller.setCameraFrame(frame);
      controller.setFieldOfView(4);
      controller.receive(event('ready'));
      controller.receive(event('imageryLoading'));
      expect(controller.status, SkyAtlasStatus.imageryLoading);
      controller.receive(event('imageryError', {'message': 'Tile timeout'}));
      expect(controller.status, SkyAtlasStatus.error);
      expect(controller.error, contains('Tile timeout'));
      final before = controller.stateJson;
      controller.resetLoading();
      expect(controller.stateJson, before);
      expect(controller.cameraFrame, same(frame));
      controller.receive(event('ready'));
      controller.receive(event('imageryReady'));
      expect(controller.status, SkyAtlasStatus.ready);
      expect(controller.cameraFrame!.configuration.rotationDegrees, 42);
    },
  );

  test(
    'unsupported host fallback is distinct from recoverable imagery failures',
    () {
      final controller = SkyAtlasController(initialPosition: andromeda);
      addTearDown(controller.dispose);
      controller.reportUnsupported('Windows native viewer unsupported');
      expect(controller.status, SkyAtlasStatus.unsupported);
      expect(controller.error, contains('Windows'));
      expect(controller.position.raDegrees, andromeda.raDegrees);
    },
  );
}
