import 'package:drift/drift.dart';

/// Offline reference catalog of celestial objects.
///
/// Coordinates are J2000 equatorial coordinates in degrees.
/// Angular dimensions are stored in arcminutes.
@DataClassName('CelestialCatalogEntryRow')
class CelestialCatalogEntries extends Table {
  TextColumn get id => text()();

  TextColumn get designation => text()();

  TextColumn get category => text()();

  TextColumn get sourceType => text()();

  RealColumn get raDegrees => real()();

  RealColumn get decDegrees => real()();

  TextColumn get constellation => text()();

  RealColumn get visualMagnitude => real().nullable()();

  RealColumn get majorAxisArcmin => real().nullable()();

  RealColumn get minorAxisArcmin => real().nullable()();

  IntColumn get messierNumber => integer().nullable()();

  TextColumn get commonNames => text().withDefault(const Constant(''))();

  TextColumn get aliases => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}
