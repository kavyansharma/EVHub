import 'package:cloud_firestore/cloud_firestore.dart';

class QueueModel {
  final String stationId;
  final int currentQueueLength;
  final int estimatedWaitTimeMinutes;
  final DateTime lastUpdated;

  const QueueModel({
    required this.stationId,
    required this.currentQueueLength,
    required this.estimatedWaitTimeMinutes,
    required this.lastUpdated,
  });

  factory QueueModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QueueModel(
      stationId: doc.id,
      currentQueueLength: data['currentQueueLength'] ?? 0,
      estimatedWaitTimeMinutes: data['estimatedWaitTimeMinutes'] ?? 0,
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currentQueueLength': currentQueueLength,
      'estimatedWaitTimeMinutes': estimatedWaitTimeMinutes,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}
