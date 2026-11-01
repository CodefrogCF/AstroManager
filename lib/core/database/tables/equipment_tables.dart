import 'package:drift/drift.dart';

/// Cameras, lenses, telescopes and mounts.
///
/// Equipment-specific fields are nullable. Their required
/// values are validated by the domain model.
@DataClassName('EquipmentItemRow')
class EquipmentItems extends Table {
  TextColumn get id => text()();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  TextColumn get kind => text()();

  // Camera specifications
  RealColumn get sensorWidthMm => real().nullable()();
  RealColumn get sensorHeightMm => real().nullable()();
  IntColumn get resolutionX => integer().nullable()();
  IntColumn get resolutionY => integer().nullable()();

  // Lens and telescope specifications
  RealColumn get focalLengthMm => real().nullable()();
  RealColumn get apertureMm => real().nullable()();

  // Mount specifications
  RealColumn get payloadCapacityKg => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Saved combinations of cameras, optics and mounts.
@DataClassName('OpticalProfileRow')
class OpticalProfiles extends Table {
  TextColumn get id => text()();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  TextColumn get cameraId =>
      text().references(EquipmentItems, #id, onDelete: KeyAction.restrict)();

  TextColumn get opticId =>
      text().references(EquipmentItems, #id, onDelete: KeyAction.restrict)();

  TextColumn get mountId => text().nullable().references(
    EquipmentItems,
    #id,
    onDelete: KeyAction.restrict,
  )();

  RealColumn get focalMultiplier => real().withDefault(const Constant(1.0))();

  @override
  Set<Column> get primaryKey => {id};
}
