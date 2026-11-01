import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_failure.dart';

import '../../domain/models/equipment_models.dart';
import '../../domain/repositories/equipment_repository.dart';

final class DriftEquipmentRepository implements EquipmentRepository {
  const DriftEquipmentRepository(this._database);

  final AppDatabase _database;

  @override
  Future<EquipmentInventory> load() async {
    final itemRows = await _database.select(_database.equipmentItems).get();

    final profileRows = await _database.select(_database.opticalProfiles).get();

    final items = itemRows.map(_mapItem).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final profiles = profileRows.map(_mapProfile).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return EquipmentInventory(items: items, profiles: profiles);
  }

  @override
  Future<void> saveItem(EquipmentItem item) async {
    item.validate();

    await _database.transaction(() async {
      final table = _database.equipmentItems;

      final existing = await (_database.select(
        table,
      )..where((row) => row.id.equals(item.id))).getSingleOrNull();

      if (existing != null && existing.kind != item.kind.name) {
        throw const ValidationFailure(
          'Equipment type cannot be changed after creation.',
        );
      }

      await _database
          .into(table)
          .insertOnConflictUpdate(
            EquipmentItemsCompanion.insert(
              id: item.id,
              name: item.name.trim(),
              kind: item.kind.name,
              sensorWidthMm: Value(
                item.kind == EquipmentKind.camera ? item.sensorWidthMm : null,
              ),
              sensorHeightMm: Value(
                item.kind == EquipmentKind.camera ? item.sensorHeightMm : null,
              ),
              resolutionX: Value(
                item.kind == EquipmentKind.camera ? item.resolutionX : null,
              ),
              resolutionY: Value(
                item.kind == EquipmentKind.camera ? item.resolutionY : null,
              ),
              focalLengthMm: Value(
                item.kind.isOptic ? item.focalLengthMm : null,
              ),
              apertureMm: Value(item.kind.isOptic ? item.apertureMm : null),
              payloadCapacityKg: Value(
                item.kind == EquipmentKind.mount
                    ? item.payloadCapacityKg
                    : null,
              ),
            ),
          );
    });
  }

  @override
  Future<void> deleteItem(String id) async {
    await _database.transaction(() async {
      final profiles = _database.opticalProfiles;

      final referencing =
          await (_database.select(profiles)..where(
                (row) =>
                    row.cameraId.equals(id) |
                    row.opticId.equals(id) |
                    row.mountId.equals(id),
              ))
              .get();

      if (referencing.isNotEmpty) {
        throw const ValidationFailure(
          'This equipment is used by an optical profile. '
          'Delete or update that profile first.',
        );
      }

      await (_database.delete(
        _database.equipmentItems,
      )..where((row) => row.id.equals(id))).go();
    });
  }

  @override
  Future<void> saveProfile(OpticalProfile profile) async {
    profile.validate();

    await _database.transaction(() async {
      await _requireEquipmentKind(profile.cameraId, EquipmentKind.camera);

      final optic = await _findItem(profile.opticId);

      if (optic == null ||
          optic.kind != EquipmentKind.lens.name &&
              optic.kind != EquipmentKind.telescope.name) {
        throw const ValidationFailure('Select a valid lens or telescope.');
      }

      if (profile.mountId != null) {
        await _requireEquipmentKind(profile.mountId!, EquipmentKind.mount);
      }

      await _database
          .into(_database.opticalProfiles)
          .insertOnConflictUpdate(
            OpticalProfilesCompanion.insert(
              id: profile.id,
              name: profile.name.trim(),
              cameraId: profile.cameraId,
              opticId: profile.opticId,
              mountId: Value(profile.mountId),
              focalMultiplier: Value(profile.focalMultiplier),
            ),
          );
    });
  }

  @override
  Future<void> deleteProfile(String id) async {
    await (_database.delete(
      _database.opticalProfiles,
    )..where((row) => row.id.equals(id))).go();
  }

  Future<EquipmentItemRow?> _findItem(String id) {
    return (_database.select(
      _database.equipmentItems,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<void> _requireEquipmentKind(String id, EquipmentKind kind) async {
    final row = await _findItem(id);

    if (row == null || row.kind != kind.name) {
      throw ValidationFailure('Select a valid ${kind.label.toLowerCase()}.');
    }
  }

  EquipmentItem _mapItem(EquipmentItemRow row) {
    final kind = EquipmentKind.values.byName(row.kind);

    return EquipmentItem(
      id: row.id,
      name: row.name,
      kind: kind,
      sensorWidthMm: row.sensorWidthMm,
      sensorHeightMm: row.sensorHeightMm,
      resolutionX: row.resolutionX,
      resolutionY: row.resolutionY,
      focalLengthMm: row.focalLengthMm,
      apertureMm: row.apertureMm,
      payloadCapacityKg: row.payloadCapacityKg,
    );
  }

  OpticalProfile _mapProfile(OpticalProfileRow row) {
    return OpticalProfile(
      id: row.id,
      name: row.name,
      cameraId: row.cameraId,
      opticId: row.opticId,
      mountId: row.mountId,
      focalMultiplier: row.focalMultiplier,
    );
  }
}
