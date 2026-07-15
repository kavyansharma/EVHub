import 'package:cloud_firestore/cloud_firestore.dart';

class ChargingSession {
  final String id;
  final String userId;
  final String stationId;
  final String stationName;
  final String network;
  final DateTime date;
  final Duration duration;
  final String vehicleId;
  final double energyUsed; // in kWh
  final double amountPaid;
  final String connector;
  final double averageChargingSpeed; // in kW
  final int batteryBefore; // percentage
  final int batteryAfter; // percentage

  const ChargingSession({
    required this.id,
    required this.userId,
    required this.stationId,
    required this.stationName,
    required this.network,
    required this.date,
    required this.duration,
    required this.vehicleId,
    required this.energyUsed,
    required this.amountPaid,
    required this.connector,
    required this.averageChargingSpeed,
    required this.batteryBefore,
    required this.batteryAfter,
  });

  factory ChargingSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChargingSession(
      id: doc.id,
      userId: data['userId'] ?? '',
      stationId: data['stationId'] ?? '',
      stationName: data['stationName'] ?? 'Unknown Station',
      network: data['network'] ?? 'Unknown Network',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      duration: Duration(minutes: data['durationMinutes'] ?? 0),
      vehicleId: data['vehicleId'] ?? '',
      energyUsed: (data['energyUsed'] ?? 0.0).toDouble(),
      amountPaid: (data['amountPaid'] ?? 0.0).toDouble(),
      connector: data['connector'] ?? '',
      averageChargingSpeed: (data['averageChargingSpeed'] ?? 0.0).toDouble(),
      batteryBefore: data['batteryBefore'] ?? 0,
      batteryAfter: data['batteryAfter'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'stationId': stationId,
      'stationName': stationName,
      'network': network,
      'date': Timestamp.fromDate(date),
      'durationMinutes': duration.inMinutes,
      'vehicleId': vehicleId,
      'energyUsed': energyUsed,
      'amountPaid': amountPaid,
      'connector': connector,
      'averageChargingSpeed': averageChargingSpeed,
      'batteryBefore': batteryBefore,
      'batteryAfter': batteryAfter,
    };
  }
}
