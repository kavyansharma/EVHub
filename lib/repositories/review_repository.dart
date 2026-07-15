import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review_model.dart';

class ReviewRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> submitReview(ReviewModel review) async {
    await _firestore
        .collection('reviews')
        .doc(review.id)
        .set(review.toMap());
  }

  Future<List<ReviewModel>> getStationReviews(String stationId) async {
    final snapshot = await _firestore
        .collection('reviews')
        .where('stationId', isEqualTo: stationId)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => ReviewModel.fromFirestore(doc)).toList();
  }

  Future<void> upvoteReview(String reviewId) async {
    await _firestore
        .collection('reviews')
        .doc(reviewId)
        .update({'helpfulVotes': FieldValue.increment(1)});
  }
}
