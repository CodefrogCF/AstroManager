import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:astromanager/features/atlas/domain/sky_atlas_models.dart';
import 'package:astromanager/features/equipment/domain/models/equipment_models.dart';
import 'package:astromanager/features/mosaic/domain/mosaic_plan.dart';

const optics = OpticalMetrics(
  effectiveFocalLengthMm: 600,
  effectiveFocalRatio: 6,
  horizontalFovDegrees: 3.4367160033,
  verticalFovDegrees: 2.2915256764,
  pixelScaleXArcsec: 2,
  pixelScaleYArcsec: 2,
);

MosaicPlan plan({
  int rows = 2,
  int cols = 3,
  double overlap = 20,
  double rotation = 0,
  double ra = 10,
  double dec = 0,
}) => MosaicPlan(
  projectId: 'project',
  targetId: 'NGC224',
  profileId: 'setup',
  center: SkyAtlasPosition(raDegrees: ra, decDegrees: dec),
  rows: rows,
  columns: cols,
  overlapPercent: overlap,
  rotationDegrees: rotation,
);

double angularDelta(double a, double b) {
  final value = (a - b + 540) % 360 - 180;
  return value.abs();
}

void main() {
  test(
    'single panel equals selected optical field of view and target center',
    () {
      final p = MosaicGeometry.calculate(
        plan: plan(rows: 1, cols: 1),
        optics: optics,
      );
      expect(p.panels, hasLength(1));
      expect(p.panels.single.center.raDegrees, closeTo(10, 1e-10));
      expect(p.panels.single.center.decDegrees, closeTo(0, 1e-10));
      expect(p.widthDegrees, closeTo(optics.horizontalFovDegrees, 1e-10));
      expect(p.heightDegrees, closeTo(optics.verticalFovDegrees, 1e-10));
      expect(p.panels.single.outline, hasLength(5));
    },
  );

  test('20 percent overlap applied to tangent-plane footprint spacing', () {
    final p = MosaicGeometry.calculate(
      plan: plan(rows: 2, cols: 3),
      optics: optics,
    );
    final hx = math.tan(optics.horizontalFovDegrees * math.pi / 360);
    final hy = math.tan(optics.verticalFovDegrees * math.pi / 360);
    final w = 2 * math.atan(hx + (3 - 1) * 2 * hx * .8 / 2) * 180 / math.pi;
    final h = 2 * math.atan(hy + (2 - 1) * 2 * hy * .8 / 2) * 180 / math.pi;
    expect(p.widthDegrees, closeTo(w, 1e-9));
    expect(p.heightDegrees, closeTo(h, 1e-9));
    expect(p.panels.map((panel) => panel.label), [
      'R1C1',
      'R1C2',
      'R1C3',
      'R2C1',
      'R2C2',
      'R2C3',
    ]);
    expect(
      p.panels[0].center.raDegrees,
      lessThan(p.panels[1].center.raDegrees),
    );
    expect(
      p.panels[0].center.decDegrees,
      greaterThan(p.panels[3].center.decDegrees),
    );
  });

  test(
    'rotation changes celestial panel coordinates without field dimensions',
    () {
      final original = MosaicGeometry.calculate(plan: plan(), optics: optics);
      final rotated = MosaicGeometry.calculate(
        plan: plan(rotation: 90),
        optics: optics,
      );
      expect(rotated.widthDegrees, closeTo(original.widthDegrees, 1e-9));
      expect(rotated.heightDegrees, closeTo(original.heightDegrees, 1e-9));
      expect(
        angularDelta(
          rotated.panels.first.center.raDegrees,
          original.panels.first.center.raDegrees,
        ),
        greaterThan(.01),
      );
      expect(
        rotated.panels.first.center.decDegrees,
        isNot(closeTo(original.panels.first.center.decDegrees, 1e-6)),
      );
    },
  );

  test('crosses RA zero without invalid negative or 360 degree RA', () {
    final result = MosaicGeometry.calculate(
      plan: plan(ra: 359.9, dec: 40),
      optics: optics,
    );
    expect(result.panels.any((p) => p.center.raDegrees < 10), isTrue);
    for (final p in result.panels) {
      expect(p.center.raDegrees, inInclusiveRange(0.0, 359.9999999999));
      expect(p.center.decDegrees, inInclusiveRange(-90.0, 90.0));
    }
  });

  test('near pole keeps coordinates valid with spherical projection', () {
    final result = MosaicGeometry.calculate(
      plan: plan(ra: 40, dec: 89.9, rotation: 37),
      optics: optics,
    );
    for (final panel in result.panels) {
      panel.center.validate();
      for (final corner in panel.outline) {
        corner.validate();
      }
    }
  });

  test('optical setup change recalculates panel size and mosaic span', () {
    final p = plan();
    final a = MosaicGeometry.calculate(plan: p, optics: optics);
    final b = MosaicGeometry.calculate(
      plan: p,
      optics: const OpticalMetrics(
        effectiveFocalLengthMm: 1200,
        effectiveFocalRatio: 12,
        horizontalFovDegrees: 1.72,
        verticalFovDegrees: 1.15,
        pixelScaleXArcsec: 1,
        pixelScaleYArcsec: 1,
      ),
    );
    expect(a.widthDegrees, greaterThan(b.widthDegrees));
    expect(a.heightDegrees, greaterThan(b.heightDegrees));
  });

  test('versioned plan serialization and coordinate export round trip', () {
    final original = plan(rotation: 45);
    final copy = MosaicPlan.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(jsonEncode(original.toJson())) as Map,
      ),
    );
    expect(copy.projectId, original.projectId);
    expect(copy.rotationDegrees, 45);
    final footprint = MosaicGeometry.calculate(plan: copy, optics: optics);
    final export = jsonDecode(footprint.exportJson()) as Map<String, dynamic>;
    expect(export['format'], 'astromanager-mosaic-panels');
    expect(export['referenceFrame'], 'ICRS/J2000');
    expect(export['panels'], hasLength(6));
    expect((export['panels'] as List).first['row'], 1);
  });

  test('invalid overlap, size and coordinates are rejected', () {
    expect(() => plan(overlap: 90).validate(), throwsFormatException);
    expect(() => plan(rows: 9, cols: 8).validate(), throwsFormatException);
    expect(() => plan(dec: 91).validate(), throwsArgumentError);
    expect(() => MosaicPlan.fromJson({'version': 2}), throwsFormatException);
  });
}
