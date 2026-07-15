import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vehicle_model.dart';
import '../services/storage_service.dart';

class GarageRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  GarageRepository();

  Future<void> addVehicle(String userId, VehicleModel vehicle) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('garage')
        .doc(vehicle.id)
        .set(vehicle.toMap());
  }

  Future<void> updateVehicle(String userId, VehicleModel vehicle) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('garage')
        .doc(vehicle.id)
        .update(vehicle.toMap());
  }

  Future<void> deleteVehicle(String userId, String vehicleId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('garage')
        .doc(vehicleId)
        .delete();
  }

  Future<List<VehicleModel>> getVehicles(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('garage')
        .get();
        
    return snapshot.docs.map((doc) => VehicleModel.fromFirestore(doc)).toList();
  }

  Future<void> setDefaultVehicle(String userId, String vehicleId) async {
    // First, set all to false
    final vehicles = await getVehicles(userId);
    final batch = _firestore.batch();
    
    for (var v in vehicles) {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('garage')
          .doc(v.id);
      
      batch.update(docRef, {'isDefault': v.id == vehicleId});
    }
    
    await batch.commit();
  }
}
