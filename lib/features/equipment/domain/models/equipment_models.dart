import 'dart:math' as math;

import '../../../../core/errors/app_failure.dart';

enum EquipmentKind {
  camera,
  lens,
  telescope,
  mount;

  String get label => switch (this) {
    EquipmentKind.camera => 'Camera',
    EquipmentKind.lens => 'Lens',
    EquipmentKind.telescope => 'Telescope',
    EquipmentKind.mount => 'Mount',
  };

  bool get isOptic =>
      this == EquipmentKind.lens || this == EquipmentKind.telescope;
}

final class EquipmentItem {
  const EquipmentItem({
    required this.id,
    required this.name,
    required this.kind,
    this.sensorWidthMm,
    this.sensorHeightMm,
    this.resolutionX,
    this.resolutionY,
    this.focalLengthMm,
    this.apertureMm,
    this.payloadCapacityKg,
  });

  final String id;
  final String name;
  final EquipmentKind kind;

  // Camera specifications
  final double? sensorWidthMm;
  final double? sensorHeightMm;
  final int? resolutionX;
  final int? resolutionY;

  // Lens / telescope specifications
  final double? focalLengthMm;
  final double? apertureMm;

  // Mount specifications
  final double? payloadCapacityKg;

  double? get pixelSizeXMicrons {
    if (sensorWidthMm == null || resolutionX == null || resolutionX! <= 0) {
      return null;
    }

    return sensorWidthMm! * 1000 / resolutionX!;
  }

  double? get pixelSizeYMicrons {
    if (sensorHeightMm == null || resolutionY == null || resolutionY! <= 0) {
      return null;
    }

    return sensorHeightMm! * 1000 / resolutionY!;
  }

  double? get focalRatio {
    if (focalLengthMm == null || apertureMm == null || apertureMm! <= 0) {
      return null;
    }

    return focalLengthMm! / apertureMm!;
  }

  void validate() {
    if (id.trim().isEmpty) {
      throw const ValidationFailure('Equipment ID must not be empty.');
    }

    if (name.trim().isEmpty || name.trim().length > 120) {
      throw const ValidationFailure(
        'Equipment name must contain 1 to 120 characters.',
      );
    }

    switch (kind) {
      case EquipmentKind.camera:
        _requirePositive(sensorWidthMm, 'Sensor width', max: 100);
        _requirePositive(sensorHeightMm, 'Sensor height', max: 100);

        if (resolutionX == null ||
            resolutionY == null ||
            resolutionX! < 1 ||
            resolutionY! < 1 ||
            resolutionX! > 100000 ||
            resolutionY! > 100000) {
          throw const ValidationFailure('Camera resolution must be valid.');
        }

      case EquipmentKind.lens:
      case EquipmentKind.telescope:
        _requirePositive(focalLengthMm, 'Focal length', max: 20000);
        _requirePositive(apertureMm, 'Aperture', max: 2500);

      case EquipmentKind.mount:
        _requirePositive(payloadCapacityKg, 'Payload capacity', max: 1000);
    }
  }

  static void _requirePositive(
    double? value,
    String label, {
    required double max,
  }) {
    if (value == null || !value.isFinite || value <= 0 || value > max) {
      throw ValidationFailure(
        '$label must be greater than zero '
        'and at most $max.',
      );
    }
  }
}

final class OpticalProfile {
  const OpticalProfile({
    required this.id,
    required this.name,
    required this.cameraId,
    required this.opticId,
    required this.focalMultiplier,
    this.mountId,
  });

  final String id;
  final String name;
  final String cameraId;
  final String opticId;
  final String? mountId;

  /// 1.0 = native focal length
  /// 0.8 = reducer
  /// 2.0 = Barlow / teleconverter
  final double focalMultiplier;

  void validate() {
    if (id.trim().isEmpty ||
        cameraId.trim().isEmpty ||
        opticId.trim().isEmpty ||
        name.trim().isEmpty ||
        name.trim().length > 120) {
      throw const ValidationFailure('Optical profile details are incomplete.');
    }

    if (!focalMultiplier.isFinite ||
        focalMultiplier < 0.1 ||
        focalMultiplier > 10) {
      throw const ValidationFailure(
        'Optical multiplier must be between 0.1 and 10.',
      );
    }
  }
}

/// Calculated optical characteristics.
///
/// Assumes direct imaging with a rectangular flat sensor.
/// Binning, distortion and vignetting are not modeled.
final class OpticalMetrics {
  const OpticalMetrics({
    required this.effectiveFocalLengthMm,
    required this.effectiveFocalRatio,
    required this.horizontalFovDegrees,
    required this.verticalFovDegrees,
    required this.pixelScaleXArcsec,
    required this.pixelScaleYArcsec,
  });

  final double effectiveFocalLengthMm;
  final double effectiveFocalRatio;
  final double horizontalFovDegrees;
  final double verticalFovDegrees;
  final double pixelScaleXArcsec;
  final double pixelScaleYArcsec;

  static OpticalMetrics calculate({
    required EquipmentItem camera,
    required EquipmentItem optic,
    required double focalMultiplier,
  }) {
    camera.validate();
    optic.validate();

    if (camera.kind != EquipmentKind.camera || !optic.kind.isOptic) {
      throw const ValidationFailure(
        'An optical setup needs a camera and an optic.',
      );
    }

    if (!focalMultiplier.isFinite ||
        focalMultiplier < 0.1 ||
        focalMultiplier > 10) {
      throw const ValidationFailure('Invalid focal multiplier.');
    }

    final effectiveFocalLength = optic.focalLengthMm! * focalMultiplier;

    double fieldOfView(double sensorDimensionMm) {
      return 2 *
          math.atan(sensorDimensionMm / (2 * effectiveFocalLength)) *
          180 /
          math.pi;
    }

    double pixelScale(double pixelSizeMicrons) {
      return 206.265 * pixelSizeMicrons / effectiveFocalLength;
    }

    return OpticalMetrics(
      effectiveFocalLengthMm: effectiveFocalLength,
      effectiveFocalRatio: effectiveFocalLength / optic.apertureMm!,
      horizontalFovDegrees: fieldOfView(camera.sensorWidthMm!),
      verticalFovDegrees: fieldOfView(camera.sensorHeightMm!),
      pixelScaleXArcsec: pixelScale(camera.pixelSizeXMicrons!),
      pixelScaleYArcsec: pixelScale(camera.pixelSizeYMicrons!),
    );
  }
}

final class EquipmentInventory {
  EquipmentInventory({
    required List<EquipmentItem> items,
    required List<OpticalProfile> profiles,
  }) : items = List.unmodifiable(items),
       profiles = List.unmodifiable(profiles);

  final List<EquipmentItem> items;
  final List<OpticalProfile> profiles;

  List<EquipmentItem> get cameras => items
      .where((item) => item.kind == EquipmentKind.camera)
      .toList(growable: false);

  List<EquipmentItem> get optics =>
      items.where((item) => item.kind.isOptic).toList(growable: false);

  List<EquipmentItem> get mounts => items
      .where((item) => item.kind == EquipmentKind.mount)
      .toList(growable: false);

  EquipmentItem? itemById(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }

    return null;
  }

  OpticalMetrics metricsFor(OpticalProfile profile) {
    final camera = itemById(profile.cameraId);
    final optic = itemById(profile.opticId);

    if (camera == null || optic == null) {
      throw const ValidationFailure(
        'The optical profile references missing equipment.',
      );
    }

    return OpticalMetrics.calculate(
      camera: camera,
      optic: optic,
      focalMultiplier: profile.focalMultiplier,
    );
  }
}
