import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wallet_statistics.dart';

class AnalyticsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveStatistics(WalletStatistics stats) async {
    await _firestore
        .collection('users')
        .doc(stats.userId)
        .collection('analytics')
        .doc('wallet_summary')
        .set(stats.toMap());
  }

  Future<WalletStatistics?> getStatistics(String userId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('analytics')
        .doc('wallet_summary')
        .get();
        
    if (doc.exists) {
      return WalletStatistics.fromFirestore(doc);
    }
    return null;
  }
}
