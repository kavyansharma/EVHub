import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/charging_session_model.dart';

class ChargingSessionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveSession(ChargingSessionModel session) async {
    await _firestore
        .collection('charging_sessions')
        .doc(session.id)
        .set(session.toMap());
  }

  Future<void> updateSessionState(ChargingSessionModel session) async {
    await _firestore
        .collection('charging_sessions')
        .doc(session.id)
        .set(session.toMap(), SetOptions(merge: true));
  }

  Stream<ChargingSessionModel?> watchSession(String sessionId) {
    return _firestore
        .collection('charging_sessions')
        .doc(sessionId)
        .snapshots()
        .map((doc) => doc.exists ? ChargingSessionModel.fromFirestore(doc) : null);
  }

  Future<List<ChargingSessionModel>> getUserHistory(String userId) async {
    final snap = await _firestore
        .collection('charging_sessions')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: SessionStatus.completed.name)
        .orderBy('startTime', descending: true)
        .limit(50)
        .get();

    return snap.docs.map((doc) => ChargingSessionModel.fromFirestore(doc)).toList();
  }
}
