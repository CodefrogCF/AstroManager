import '../models/equipment_models.dart';

abstract interface class EquipmentRepository {
  Future<EquipmentInventory> load();

  Future<void> saveItem(EquipmentItem item);

  Future<void> deleteItem(String id);

  Future<void> saveProfile(OpticalProfile profile);

  Future<void> deleteProfile(String id);
}
