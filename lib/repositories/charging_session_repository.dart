import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/charging_session_model.dart';

class ChargingSessionRepository {
  final FirebaseFirestore _firestore;

  ChargingSessionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> saveSession(ChargingSessionModel session) async {
    try {
      await _firestore
          .collection('charging_sessions')
          .doc(session.sessionId)
          .set(session.toMap(), SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> updateSessionState(ChargingSessionModel session) async {
    try {
      await _firestore
          .collection('charging_sessions')
          .doc(session.sessionId)
          .set(session.toMap(), SetOptions(merge: true));
    } catch (_) {}
  }

  Stream<ChargingSessionModel?> watchSession(String sessionId) {
    return _firestore
        .collection('charging_sessions')
        .doc(sessionId)
        .snapshots()
        .map((doc) => doc.exists ? ChargingSessionModel.fromFirestore(doc) : null);
  }

  Future<List<ChargingSessionModel>> getUserHistory(String userId) async {
    try {
      final snap = await _firestore
          .collection('charging_sessions')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: ChargingSessionStatus.completed.name)
          .orderBy('startTime', descending: true)
          .limit(50)
          .get();

      return snap.docs.map((doc) => ChargingSessionModel.fromFirestore(doc)).toList();
    } catch (_) {
      return [];
    }
  }
}
