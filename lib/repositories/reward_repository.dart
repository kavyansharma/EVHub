import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reward_model.dart';

class RewardRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addReward(RewardModel reward) async {
    final batch = _firestore.batch();
    
    // Add reward log
    final rewardRef = _firestore.collection('rewards').doc(reward.id);
    batch.set(rewardRef, reward.toMap());

    // Update user profile total points
    final profileRef = _firestore.collection('profiles').doc(reward.userId);
    batch.set(profileRef, {
      'totalRewardPoints': FieldValue.increment(reward.points),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<List<RewardModel>> getUserRewards(String userId) async {
    final snapshot = await _firestore
        .collection('rewards')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => RewardModel.fromFirestore(doc)).toList();
  }
}
