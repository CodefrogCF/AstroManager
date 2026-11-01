import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/errors/app_failure.dart';

/// Immutable representation of an observing location.
final class ObservingLocation {
  const ObservingLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.elevationMeters,
    required this.timeZone,
    required this.isDefault,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double elevationMeters;
  final String timeZone;
  final bool isDefault;

  ObservingLocationInput toInput() {
    return ObservingLocationInput(
      name: name,
      latitude: latitude,
      longitude: longitude,
      elevationMeters: elevationMeters,
      timeZone: timeZone,
    );
  }

  void validate() {
    if (id.trim().isEmpty) {
      throw const ValidationFailure('Location ID must not be empty.');
    }

    toInput().validate();
  }
}

/// Input data used when creating or editing a location.
final class ObservingLocationInput {
  const ObservingLocationInput({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.elevationMeters,
    required this.timeZone,
  });

  final String name;
  final double latitude;
  final double longitude;
  final double elevationMeters;
  final String timeZone;

  void validate() {
    final normalizedName = name.trim();

    if (normalizedName.isEmpty || normalizedName.length > 100) {
      throw const ValidationFailure(
        'Location name must contain 1 to 100 characters.',
      );
    }

    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      throw const ValidationFailure(
        'Latitude must be between -90 and 90 degrees.',
      );
    }

    if (!longitude.isFinite || longitude < -180 || longitude > 180) {
      throw const ValidationFailure(
        'Longitude must be between -180 and 180 degrees.',
      );
    }

    if (!elevationMeters.isFinite ||
        elevationMeters < -500 ||
        elevationMeters > 10000) {
      throw const ValidationFailure(
        'Elevation must be between -500 and 10000 meters.',
      );
    }

    if (timeZone.trim().isEmpty || timeZone.length > 100) {
      throw const ValidationFailure('A valid IANA time zone is required.');
    }

    _TimeZoneValidator.validate(timeZone.trim());
  }
}

/// Validates IANA identifiers with a bundled time zone database.
abstract final class _TimeZoneValidator {
  static bool _initialized = false;

  static void validate(String identifier) {
    if (!_initialized) {
      tz_data.initializeTimeZones();
      _initialized = true;
    }

    try {
      tz.getLocation(identifier);
    } on tz.LocationNotFoundException {
      throw const ValidationFailure(
        'Unknown IANA time zone. Example: Europe/Zurich.',
      );
    }
  }
}
