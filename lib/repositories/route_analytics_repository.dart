import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/route_analytics_model.dart';

class RouteAnalyticsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveAnalytics(RouteAnalyticsModel analytics) async {
    await _firestore
        .collection('route_analytics')
        .doc(analytics.id)
        .set(analytics.toMap());
  }

  Stream<List<RouteAnalyticsModel>> watchAnalytics(String userId) {
    return _firestore
        .collection('route_analytics')
        .where('userId', isEqualTo: userId)
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => RouteAnalyticsModel.fromFirestore(doc)).toList());
  }
}
