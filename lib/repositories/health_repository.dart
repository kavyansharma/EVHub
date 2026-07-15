import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/health_model.dart';

class HealthRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveHealthData(HealthModel health) async {
    await _firestore
        .collection('vehicle_health')
        .doc(health.vehicleId)
        .set(health.toMap(), SetOptions(merge: true));
  }

  Stream<HealthModel?> watchHealthData(String vehicleId) {
    return _firestore
        .collection('vehicle_health')
        .doc(vehicleId)
        .snapshots()
        .map((doc) => doc.exists ? HealthModel.fromFirestore(doc) : null);
  }
}
