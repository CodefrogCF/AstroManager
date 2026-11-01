import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../../../core/errors/app_failure.dart';

final class DeviceCoordinates {
  const DeviceCoordinates({
    required this.latitude,
    required this.longitude,
    required this.elevationMeters,
  });

  final double latitude;
  final double longitude;
  final double elevationMeters;
}

abstract interface class DeviceLocationService {
  Future<DeviceCoordinates> getCurrentCoordinates();
}

final class GeolocatorDeviceLocationService implements DeviceLocationService {
  const GeolocatorDeviceLocationService();

  @override
  Future<DeviceCoordinates> getCurrentCoordinates() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();

      if (!enabled) {
        throw const ValidationFailure(
          'Location services are disabled. '
          'Enter coordinates manually or enable location services.',
        );
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw const ValidationFailure(
          'Location permission was denied. '
          'You can enter coordinates manually.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        throw const ValidationFailure(
          'Location permission is permanently denied. '
          'Enable it in device settings or enter coordinates manually.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      return DeviceCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
        elevationMeters: position.altitude,
      );
    } on ValidationFailure {
      rethrow;
    } on TimeoutException {
      throw const ValidationFailure(
        'Location request timed out. '
        'Try again or enter coordinates manually.',
      );
    } catch (_) {
      throw const ValidationFailure(
        'Unable to determine your location. '
        'Enter coordinates manually.',
      );
    }
  }
}
