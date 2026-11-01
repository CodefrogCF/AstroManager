import 'package:drift/drift.dart';

// Persistent observing locations.
//
// Geographic coordinates use WGS84 decimal degrees.
// Elevation is stored in meters above mean sea level.
// Time zones use IANA identifiers such as Europe/Zurich.
@DataClassName('ObservingLocationRow')
class ObservingLocations extends Table {
  TextColumn get id => text()();

  TextColumn get name => text().withLength(min: 1, max: 100)();

  RealColumn get latitude => real()();

  RealColumn get longitude => real()();

  RealColumn get elevationMeters => real()();

  TextColumn get timeZone => text()();

  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
