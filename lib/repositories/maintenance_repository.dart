import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/maintenance_model.dart';

class MaintenanceRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveMaintenanceTask(MaintenanceModel task) async {
    await _firestore
        .collection('maintenance')
        .doc(task.id)
        .set(task.toMap(), SetOptions(merge: true));
  }

  Stream<List<MaintenanceModel>> watchTasks(String vehicleId) {
    return _firestore
        .collection('maintenance')
        .where('vehicleId', isEqualTo: vehicleId)
        .orderBy('estimatedDueDate')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => MaintenanceModel.fromFirestore(doc)).toList());
  }
}
