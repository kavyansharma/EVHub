import 'package:cloud_firestore/cloud_firestore.dart';

enum ReservationStatus { pending, active, completed, cancelled }

class ReservationModel {
  final String id;
  final String userId;
  final String stationId;
  final String chargerId;
  final DateTime startTime;
  final DateTime endTime;
  final ReservationStatus status;
  final DateTime createdAt;
  final double estimatedCost;

  const ReservationModel({
    required this.id,
    required this.userId,
    required this.stationId,
    required this.chargerId,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.createdAt,
    required this.estimatedCost,
  });

  factory ReservationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReservationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      stationId: data['stationId'] ?? '',
      chargerId: data['chargerId'] ?? '',
      startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['endTime'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(minutes: 30)),
      status: _statusFromString(data['status']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      estimatedCost: (data['estimatedCost'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'stationId': stationId,
      'chargerId': chargerId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'estimatedCost': estimatedCost,
    };
  }

  ReservationModel copyWith({
    String? id,
    String? userId,
    String? stationId,
    String? chargerId,
    DateTime? startTime,
    DateTime? endTime,
    ReservationStatus? status,
    DateTime? createdAt,
    double? estimatedCost,
  }) {
    return ReservationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      stationId: stationId ?? this.stationId,
      chargerId: chargerId ?? this.chargerId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      estimatedCost: estimatedCost ?? this.estimatedCost,
    );
  }

  static ReservationStatus _statusFromString(String? statusStr) {
    switch (statusStr) {
      case 'active':
        return ReservationStatus.active;
      case 'completed':
        return ReservationStatus.completed;
      case 'cancelled':
        return ReservationStatus.cancelled;
      default:
        return ReservationStatus.pending;
    }
  }
}
