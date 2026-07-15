import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String userId;
  final String userName;
  final String stationId;
  final double rating;
  final String comment;
  final List<String> photos;
  final int helpfulVotes;
  final DateTime timestamp;

  const ReviewModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.stationId,
    required this.rating,
    required this.comment,
    this.photos = const [],
    this.helpfulVotes = 0,
    required this.timestamp,
  });

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReviewModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      stationId: data['stationId'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      comment: data['comment'] ?? '',
      photos: List<String>.from(data['photos'] ?? []),
      helpfulVotes: data['helpfulVotes'] ?? 0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'stationId': stationId,
      'rating': rating,
      'comment': comment,
      'photos': photos,
      'helpfulVotes': helpfulVotes,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
