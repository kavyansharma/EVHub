import 'package:cloud_firestore/cloud_firestore.dart';

enum SessionStatus { preparing, charging, paused, completed, stopped, error }

class ChargingSessionModel {
  final String id;
  final String userId;
  final String stationId;
  final String chargerId;
  final DateTime startTime;
  final DateTime? endTime;
  final SessionStatus status;
  
  // Real-time metrics
  final double currentKw;
  final double batteryPercentage;
  final double unitsConsumed;
  final double currentCost;
  final double temperature;
  final double voltage;
  final double current;
  final int estimatedFinishTimeMinutes;

  // Graph data points (Time -> kW)
  final List<GraphPoint> powerGraph;

  const ChargingSessionModel({
    required this.id,
    required this.userId,
    required this.stationId,
    required this.chargerId,
    required this.startTime,
    this.endTime,
    required this.status,
    this.currentKw = 0.0,
    this.batteryPercentage = 0.0,
    this.unitsConsumed = 0.0,
    this.currentCost = 0.0,
    this.temperature = 25.0,
    this.voltage = 0.0,
    this.current = 0.0,
    this.estimatedFinishTimeMinutes = 0,
    this.powerGraph = const [],
  });

  factory ChargingSessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChargingSessionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      stationId: data['stationId'] ?? '',
      chargerId: data['chargerId'] ?? '',
      startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
      status: _statusFromString(data['status']),
      currentKw: (data['currentKw'] ?? 0.0).toDouble(),
      batteryPercentage: (data['batteryPercentage'] ?? 0.0).toDouble(),
      unitsConsumed: (data['unitsConsumed'] ?? 0.0).toDouble(),
      currentCost: (data['currentCost'] ?? 0.0).toDouble(),
      temperature: (data['temperature'] ?? 25.0).toDouble(),
      voltage: (data['voltage'] ?? 0.0).toDouble(),
      current: (data['current'] ?? 0.0).toDouble(),
      estimatedFinishTimeMinutes: data['estimatedFinishTimeMinutes'] ?? 0,
      powerGraph: (data['powerGraph'] as List<dynamic>? ?? [])
          .map((e) => GraphPoint.fromMap(e))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'stationId': stationId,
      'chargerId': chargerId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'status': status.name,
      'currentKw': currentKw,
      'batteryPercentage': batteryPercentage,
      'unitsConsumed': unitsConsumed,
      'currentCost': currentCost,
      'temperature': temperature,
      'voltage': voltage,
      'current': current,
      'estimatedFinishTimeMinutes': estimatedFinishTimeMinutes,
      'powerGraph': powerGraph.map((e) => e.toMap()).toList(),
    };
  }

  ChargingSessionModel copyWith({
    String? id,
    String? userId,
    String? stationId,
    String? chargerId,
    DateTime? startTime,
    DateTime? endTime,
    SessionStatus? status,
    double? currentKw,
    double? batteryPercentage,
    double? unitsConsumed,
    double? currentCost,
    double? temperature,
    double? voltage,
    double? current,
    int? estimatedFinishTimeMinutes,
    List<GraphPoint>? powerGraph,
  }) {
    return ChargingSessionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      stationId: stationId ?? this.stationId,
      chargerId: chargerId ?? this.chargerId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      currentKw: currentKw ?? this.currentKw,
      batteryPercentage: batteryPercentage ?? this.batteryPercentage,
      unitsConsumed: unitsConsumed ?? this.unitsConsumed,
      currentCost: currentCost ?? this.currentCost,
      temperature: temperature ?? this.temperature,
      voltage: voltage ?? this.voltage,
      current: current ?? this.current,
      estimatedFinishTimeMinutes: estimatedFinishTimeMinutes ?? this.estimatedFinishTimeMinutes,
      powerGraph: powerGraph ?? this.powerGraph,
    );
  }

  static SessionStatus _statusFromString(String? statusStr) {
    switch (statusStr) {
      case 'charging':
        return SessionStatus.charging;
      case 'paused':
        return SessionStatus.paused;
      case 'completed':
        return SessionStatus.completed;
      case 'stopped':
        return SessionStatus.stopped;
      case 'error':
        return SessionStatus.error;
      default:
        return SessionStatus.preparing;
    }
  }
}

class GraphPoint {
  final int timestampOffsetSeconds; // Seconds since start
  final double kwValue;

  const GraphPoint({required this.timestampOffsetSeconds, required this.kwValue});

  factory GraphPoint.fromMap(Map<String, dynamic> map) {
    return GraphPoint(
      timestampOffsetSeconds: map['t'] ?? 0,
      kwValue: (map['v'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      't': timestampOffsetSeconds,
      'v': kwValue,
    };
  }
}
