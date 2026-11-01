import 'dart:math' as math;

import '../../../../core/errors/app_failure.dart';

/// A rectangular readout region, expressed in physical sensor pixels.
///
/// The origin is the sensor's top-left corner. The region must lie entirely
/// inside the camera's native pixel resolution. ROI changes the recorded
/// field of view, but neither focal length nor the pitch of a sensor pixel.
final class SensorRegionOfInterest {
  const SensorRegionOfInterest({
    required this.xPixels,
    required this.yPixels,
    required this.widthPixels,
    required this.heightPixels,
  });

  final int xPixels;
  final int yPixels;
  final int widthPixels;
  final int heightPixels;

  void validate({required int resolutionX, required int resolutionY}) {
    if (xPixels < 0 ||
        yPixels < 0 ||
        widthPixels < 1 ||
        heightPixels < 1 ||
        xPixels > resolutionX - widthPixels ||
        yPixels > resolutionY - heightPixels) {
      throw const ValidationFailure(
        'The sensor region of interest must fit inside the sensor.',
      );
    }
  }
}

/// Result of a geometric prime-focus camera field-of-view calculation.
///
/// Angular fields are in decimal degrees; image scales are in arcseconds per
/// native sensor pixel. Cropping is not optical magnification and therefore
/// does not change image scale. Binning, distortion and vignetting are not
/// included in this model.
final class OpticalFieldOfViewResult {
  const OpticalFieldOfViewResult({
    required this.effectiveFocalLengthMm,
    required this.effectiveFocalRatio,
    required this.activeSensorWidthMm,
    required this.activeSensorHeightMm,
    required this.activeResolutionX,
    required this.activeResolutionY,
    required this.horizontalFovDegrees,
    required this.verticalFovDegrees,
    required this.diagonalFovDegrees,
    required this.pixelScaleXArcsecPerPixel,
    required this.pixelScaleYArcsecPerPixel,
  });

  final double effectiveFocalLengthMm;
  final double effectiveFocalRatio;

  /// Active (potentially cropped) sensor area in millimeters.
  final double activeSensorWidthMm;
  final double activeSensorHeightMm;

  /// Actual number of native pixels contributing to the active area.
  final int activeResolutionX;
  final int activeResolutionY;

  final double horizontalFovDegrees;
  final double verticalFovDegrees;
  final double diagonalFovDegrees;
  final double pixelScaleXArcsecPerPixel;
  final double pixelScaleYArcsecPerPixel;
}

/// Stateless field-of-view and image-scale calculations, without Flutter or
/// persistence dependencies.
abstract final class OpticalFieldOfViewService {
  static const double _arcsecPerPixelFactor = 206.265;

  /// Calculates direct imaging geometry using real sensor dimensions.
  ///
  /// [focalMultiplier] is the legacy overall optical modifier (e.g. 0.8 for a
  /// reducer or 2 for a Barlow). [reducerFactor] and [barlowFactor] can be
  /// supplied separately and multiply with it. A reducer is in (0, 1], and a
  /// Barlow is in [1, 10]. The combined focal length is calculated once.
  ///
  /// A digital [cropFactor] >= 1 selects a centered area with whole-pixel
  /// dimensions rounded to the nearest pixel. Alternatively, a
  /// [regionOfInterest] specifies an exact pixel rectangle. Supplying both is
  /// rejected to prevent accidental double-cropping.
  static OpticalFieldOfViewResult calculate({
    required double focalLengthMm,
    required double apertureMm,
    required double sensorWidthMm,
    required double sensorHeightMm,
    required int resolutionX,
    required int resolutionY,
    double focalMultiplier = 1,
    double reducerFactor = 1,
    double barlowFactor = 1,
    double cropFactor = 1,
    SensorRegionOfInterest? regionOfInterest,
  }) {
    _validatePositive(focalLengthMm, 'Focal length', 20000);
    _validatePositive(apertureMm, 'Aperture', 2500);
    _validatePositive(sensorWidthMm, 'Sensor width', 100);
    _validatePositive(sensorHeightMm, 'Sensor height', 100);

    if (resolutionX < 1 ||
        resolutionY < 1 ||
        resolutionX > 100000 ||
        resolutionY > 100000) {
      throw const ValidationFailure('Camera resolution must be valid.');
    }

    if (!focalMultiplier.isFinite ||
        focalMultiplier < 0.1 ||
        focalMultiplier > 10) {
      throw const ValidationFailure(
        'Optical multiplier must be between 0.1 and 10.',
      );
    }

    if (!reducerFactor.isFinite || reducerFactor <= 0 || reducerFactor > 1) {
      throw const ValidationFailure(
        'Reducer factor must be greater than zero and at most 1.',
      );
    }

    if (!barlowFactor.isFinite || barlowFactor < 1 || barlowFactor > 10) {
      throw const ValidationFailure('Barlow factor must be between 1 and 10.');
    }

    if (!cropFactor.isFinite ||
        cropFactor < 1 ||
        cropFactor > math.min(resolutionX, resolutionY)) {
      throw const ValidationFailure(
        'Crop factor must be at least 1 and must retain a sensor pixel.',
      );
    }

    if (regionOfInterest != null && cropFactor != 1) {
      throw const ValidationFailure(
        'Choose either a crop factor or a region of interest.',
      );
    }

    regionOfInterest?.validate(
      resolutionX: resolutionX,
      resolutionY: resolutionY,
    );

    final effectiveFocalLength =
        focalLengthMm * focalMultiplier * reducerFactor * barlowFactor;
    if (!effectiveFocalLength.isFinite || effectiveFocalLength <= 0) {
      throw const ValidationFailure('Effective focal length must be valid.');
    }

    final activeX =
        regionOfInterest?.widthPixels ?? (resolutionX / cropFactor).round();
    final activeY =
        regionOfInterest?.heightPixels ?? (resolutionY / cropFactor).round();

    // Calculate physical dimensions FROM native pixels so ROI and rounded
    // digital crops cannot silently change the camera's physical pixel pitch.
    final activeWidth = sensorWidthMm * activeX / resolutionX;
    final activeHeight = sensorHeightMm * activeY / resolutionY;
    final diagonalMm = math.sqrt(
      activeWidth * activeWidth + activeHeight * activeHeight,
    );

    double fov(double millimeters) =>
        2 * math.atan(millimeters / (2 * effectiveFocalLength)) * 180 / math.pi;

    return OpticalFieldOfViewResult(
      effectiveFocalLengthMm: effectiveFocalLength,
      effectiveFocalRatio: effectiveFocalLength / apertureMm,
      activeSensorWidthMm: activeWidth,
      activeSensorHeightMm: activeHeight,
      activeResolutionX: activeX,
      activeResolutionY: activeY,
      horizontalFovDegrees: fov(activeWidth),
      verticalFovDegrees: fov(activeHeight),
      diagonalFovDegrees: fov(diagonalMm),
      pixelScaleXArcsecPerPixel:
          _arcsecPerPixelFactor *
          (sensorWidthMm * 1000 / resolutionX) /
          effectiveFocalLength,
      pixelScaleYArcsecPerPixel:
          _arcsecPerPixelFactor *
          (sensorHeightMm * 1000 / resolutionY) /
          effectiveFocalLength,
    );
  }

  static void _validatePositive(double value, String label, double max) {
    if (!value.isFinite || value <= 0 || value > max) {
      throw ValidationFailure(
        '$label must be greater than zero and at most $max.',
      );
    }
  }
}
