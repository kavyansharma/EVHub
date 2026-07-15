import 'package:cloud_firestore/cloud_firestore.dart';

class AdminRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> getSystemStats() async {
    // In a real app, this would use Cloud Functions for aggregation
    // For now, we simulate fetching some high-level metrics
    final usersCount = await _firestore.collection('users').count().get();
    final stationsCount = await _firestore.collection('stations').count().get();
    final fleetsCount = await _firestore.collection('fleets').count().get();

    return {
      'totalUsers': usersCount.count ?? 0,
      'totalStations': stationsCount.count ?? 0,
      'totalFleets': fleetsCount.count ?? 0,
    };
  }

  Future<void> elevateUserRole(String userId, String role) async {
    await _firestore.collection('users').doc(userId).update({'role': role});
  }
}
