import 'package:cloud_firestore/cloud_firestore.dart';

class ChargingHistoryModel {
  final String id;
  final String userId;
  final String stationId;
  final String stationName;
  final double kWh;
  final double cost;
  final int durationMinutes;
  final DateTime timestamp;

  const ChargingHistoryModel({
    required this.id,
    required this.userId,
    required this.stationId,
    required this.stationName,
    required this.kWh,
    required this.cost,
    required this.durationMinutes,
    required this.timestamp,
  });

  factory ChargingHistoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChargingHistoryModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      stationId: data['stationId'] ?? '',
      stationName: data['stationName'] ?? '',
      kWh: (data['kWh'] ?? 0.0).toDouble(),
      cost: (data['cost'] ?? 0.0).toDouble(),
      durationMinutes: (data['durationMinutes'] ?? 0) as int,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'stationId': stationId,
      'stationName': stationName,
      'kWh': kWh,
      'cost': cost,
      'durationMinutes': durationMinutes,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
