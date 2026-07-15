import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/fleet_model.dart';

class FleetRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveFleet(FleetModel fleet) async {
    await _firestore
        .collection('fleets')
        .doc(fleet.fleetId)
        .set(fleet.toMap(), SetOptions(merge: true));
  }

  Stream<FleetModel?> watchFleet(String fleetId) {
    return _firestore
        .collection('fleets')
        .doc(fleetId)
        .snapshots()
        .map((doc) => doc.exists ? FleetModel.fromFirestore(doc) : null);
  }

  Stream<List<FleetModel>> watchFleetsByDriver(String driverId) {
    return _firestore
        .collection('fleets')
        .where('driverUserIds', arrayContains: driverId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => FleetModel.fromFirestore(doc)).toList());
  }
}
