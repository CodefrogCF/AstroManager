import '../../../../core/errors/app_failure.dart';

enum CelestialCategory {
  galaxy,
  nebula,
  cluster,
  star,
  other;

  String get label => switch (this) {
    CelestialCategory.galaxy => 'Galaxy',
    CelestialCategory.nebula => 'Nebula',
    CelestialCategory.cluster => 'Star cluster',
    CelestialCategory.star => 'Star',
    CelestialCategory.other => 'Other',
  };
}

/// Equatorial J2000 coordinates and catalog metadata.
///
/// No apparent-position or observation-time corrections
/// are applied to these coordinates.
final class CelestialObject {
  const CelestialObject({
    required this.id,
    required this.designation,
    required this.category,
    required this.sourceType,
    required this.raDegrees,
    required this.decDegrees,
    required this.constellation,
    required this.commonNames,
    required this.aliases,
    this.visualMagnitude,
    this.majorAxisArcmin,
    this.minorAxisArcmin,
    this.messierNumber,
  });

  final String id;
  final String designation;
  final CelestialCategory category;
  final String sourceType;

  final double raDegrees;
  final double decDegrees;

  final String constellation;

  final double? visualMagnitude;
  final double? majorAxisArcmin;
  final double? minorAxisArcmin;
  final int? messierNumber;

  final String commonNames;
  final String aliases;

  String get displayTitle {
    if (messierNumber != null) {
      return 'M $messierNumber · $designation';
    }

    return designation;
  }

  String get rightAscensionText {
    final totalSeconds = raDegrees / 15 * 3600;

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}h '
        '${minutes.toString().padLeft(2, '0')}m '
        '${seconds.toStringAsFixed(1)}s';
  }

  String get declinationText {
    final sign = decDegrees < 0 ? '-' : '+';
    final absolute = decDegrees.abs();

    final degrees = absolute.floor();
    final minutes = ((absolute - degrees) * 60).floor();
    final seconds = ((absolute - degrees) * 60 - minutes) * 60;

    return '$sign${degrees.toString().padLeft(2, '0')}° '
        '${minutes.toString().padLeft(2, '0')}′ '
        '${seconds.toStringAsFixed(1)}″';
  }

  void validate() {
    if (id.trim().isEmpty ||
        designation.trim().isEmpty ||
        sourceType.trim().isEmpty) {
      throw const ValidationFailure(
        'Celestial catalog identification is invalid.',
      );
    }

    if (!raDegrees.isFinite || raDegrees < 0 || raDegrees >= 360) {
      throw const ValidationFailure(
        'Right ascension must be between 0 and 360 degrees.',
      );
    }

    if (!decDegrees.isFinite || decDegrees < -90 || decDegrees > 90) {
      throw const ValidationFailure(
        'Declination must be between -90 and 90 degrees.',
      );
    }

    for (final value in [visualMagnitude, majorAxisArcmin, minorAxisArcmin]) {
      if (value != null && !value.isFinite) {
        throw const ValidationFailure('Catalog numeric values must be finite.');
      }
    }

    if ((majorAxisArcmin != null && majorAxisArcmin! <= 0) ||
        (minorAxisArcmin != null && minorAxisArcmin! <= 0)) {
      throw const ValidationFailure('Angular dimensions must be positive.');
    }

    if (messierNumber != null && (messierNumber! < 1 || messierNumber! > 110)) {
      throw const ValidationFailure(
        'Messier number must be between 1 and 110.',
      );
    }
  }

  factory CelestialObject.fromJson(Map<String, dynamic> json) {
    final object = CelestialObject(
      id: json['id'] as String,
      designation: json['designation'] as String,
      category: CelestialCategory.values.byName(json['category'] as String),
      sourceType: json['sourceType'] as String,
      raDegrees: (json['raDegrees'] as num).toDouble(),
      decDegrees: (json['decDegrees'] as num).toDouble(),
      constellation: json['constellation'] as String,
      visualMagnitude: (json['visualMagnitude'] as num?)?.toDouble(),
      majorAxisArcmin: (json['majorAxisArcmin'] as num?)?.toDouble(),
      minorAxisArcmin: (json['minorAxisArcmin'] as num?)?.toDouble(),
      messierNumber: json['messierNumber'] as int?,
      commonNames: json['commonNames'] as String,
      aliases: json['aliases'] as String,
    );

    object.validate();
    return object;
  }
}

/// Immutable, versioned catalog imported into local SQLite.
final class CelestialCatalogBundle {
  CelestialCatalogBundle({
    required this.version,
    required List<CelestialObject> objects,
  }) : objects = List.unmodifiable(objects);

  final String version;
  final List<CelestialObject> objects;

  factory CelestialCatalogBundle.fromJson(Map<String, dynamic> json) {
    if (json['source'] != 'OpenNGC' || json['license'] != 'CC-BY-SA-4.0') {
      throw const FormatException('Unsupported celestial catalog source.');
    }

    final version = json['version'];
    final rows = json['objects'];

    if (version is! String || version.isEmpty || rows is! List) {
      throw const FormatException('Invalid celestial catalog bundle.');
    }

    final objects = rows
        .map((raw) {
          if (raw is! Map<String, dynamic>) {
            throw const FormatException('Invalid celestial catalog entry.');
          }

          return CelestialObject.fromJson(raw);
        })
        .toList(growable: false);

    return CelestialCatalogBundle(version: version, objects: objects);
  }
}
