import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/charging_session.dart';

class HistoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  HistoryRepository();

  Future<void> addChargingSession(String userId, ChargingSession session) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('history')
        .doc(session.id)
        .set(session.toMap());
  }

  Future<List<ChargingSession>> getChargingHistory(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('history')
        .orderBy('date', descending: true)
        .get();
        
    return snapshot.docs.map((doc) => ChargingSession.fromFirestore(doc)).toList();
  }
}
