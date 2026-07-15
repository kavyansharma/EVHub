import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subscription_model.dart';

class SubscriptionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveSubscription(SubscriptionModel subscription) async {
    await _firestore
        .collection('subscriptions')
        .doc(subscription.userId)
        .set(subscription.toMap(), SetOptions(merge: true));
  }

  Stream<SubscriptionModel?> watchSubscription(String userId) {
    return _firestore
        .collection('subscriptions')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? SubscriptionModel.fromFirestore(doc) : null);
  }
}
