import 'package:cloud_firestore/cloud_firestore.dart';

enum ChargingSessionStatus {
  idle,
  starting,
  charging,
  paused,
  completing,
  paymentPending,
  completed,
  paymentFailed,
  cancelled,
  error,
}

// Backward compatibility alias for legacy callers
typedef SessionStatus = ChargingSessionStatus;

extension ChargingSessionStatusExt on ChargingSessionStatus {
  bool get isActive =>
      this == ChargingSessionStatus.starting ||
      this == ChargingSessionStatus.charging ||
      this == ChargingSessionStatus.paused ||
      this == ChargingSessionStatus.completing ||
      this == ChargingSessionStatus.paymentPending;

  bool get isTerminal =>
      this == ChargingSessionStatus.completed ||
      this == ChargingSessionStatus.cancelled ||
      this == ChargingSessionStatus.error;

  String get displayName {
    switch (this) {
      case ChargingSessionStatus.idle:
        return 'Idle';
      case ChargingSessionStatus.starting:
        return 'Starting Session';
      case ChargingSessionStatus.charging:
        return 'Charging';
      case ChargingSessionStatus.paused:
        return 'Paused';
      case ChargingSessionStatus.completing:
        return 'Completing';
      case ChargingSessionStatus.paymentPending:
        return 'Payment Pending';
      case ChargingSessionStatus.completed:
        return 'Completed';
      case ChargingSessionStatus.paymentFailed:
        return 'Payment Failed';
      case ChargingSessionStatus.cancelled:
        return 'Cancelled';
      case ChargingSessionStatus.error:
        return 'Session Error';
    }
  }
}

class ChargingSessionModel {
  final String sessionId;
  final String userId;
  final String walletId;
  final String chargerId;
  final String chargerName;
  final String networkName;
  final String chargerAddress;
  final String vehicleId;
  final String vehicleName;
  final String connectorType;
  final double chargerPowerKw;
  final String chargingMode;
  final DateTime startTime;
  final DateTime? endTime;
  final double initialSocPercent;
  final double currentSocPercent;
  final double targetSocPercent;
  final double batteryCapacityKwh;
  final double energyDeliveredKwh;
  final double estimatedCost;
  final double finalCost;
  final double pricePerKwh;
  final double chargingEfficiency;
  final double chargingLossKwh;
  final double activePowerKw;
  final ChargingSessionStatus status;
  final String? transactionId;
  final String? referenceId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<GraphPoint> powerGraph;

  ChargingSessionModel({
    String? sessionId,
    String? id,
    String? userId,
    this.walletId = 'wallet_local',
    String? chargerId,
    String? stationId,
    String? chargerName,
    this.networkName = 'EVHub Network',
    this.chargerAddress = 'India EV Charger Station',
    this.vehicleId = 'ev_default',
    this.vehicleName = 'Electric Vehicle',
    this.connectorType = 'CCS2',
    double? chargerPowerKw,
    double? currentKw,
    this.chargingMode = 'DC Fast',
    DateTime? startTime,
    this.endTime,
    this.initialSocPercent = 20.0,
    double? currentSocPercent,
    double? batteryPercentage,
    this.targetSocPercent = 80.0,
    this.batteryCapacityKwh = 50.0,
    double? energyDeliveredKwh,
    double? unitsConsumed,
    double? estimatedCost,
    double? currentCost,
    this.finalCost = 0.0,
    this.pricePerKwh = 18.0,
    this.chargingEfficiency = 0.90,
    this.chargingLossKwh = 0.0,
    double? activePowerKw,
    this.status = ChargingSessionStatus.starting,
    this.transactionId,
    this.referenceId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.powerGraph = const [],
  })  : sessionId = sessionId ?? id ?? 'sess_local',
        userId = userId ?? 'user_local',
        chargerId = chargerId ?? stationId ?? 'chg_local',
        chargerName = chargerName ?? 'EV Charging Station',
        chargerPowerKw = chargerPowerKw ?? currentKw ?? 60.0,
        activePowerKw = activePowerKw ?? currentKw ?? 0.0,
        currentSocPercent = currentSocPercent ?? batteryPercentage ?? initialSocPercent,
        energyDeliveredKwh = energyDeliveredKwh ?? unitsConsumed ?? 0.0,
        estimatedCost = estimatedCost ?? currentCost ?? 0.0,
        startTime = startTime ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // ─── Backward Compatibility Getters ────────────────────────────────────────

  String get id => sessionId;
  String get stationId => chargerId;
  double get unitsConsumed => energyDeliveredKwh;
  double get currentCost => estimatedCost;
  double get batteryPercentage => currentSocPercent;
  double get currentKw => activePowerKw;
  double get temperature => 32.5;
  double get voltage => 400.0;
  double get current => activePowerKw > 0 ? (activePowerKw * 1000 / 400.0) : 0.0;

  double get gridEnergyDrawnKwh =>
      chargingEfficiency > 0 ? (energyDeliveredKwh / chargingEfficiency) : energyDeliveredKwh;

  int get estimatedFinishTimeMinutes {
    if (status == ChargingSessionStatus.completed || status == ChargingSessionStatus.cancelled) return 0;
    final remainingSocPct = (targetSocPercent - currentSocPercent).clamp(0.0, 100.0);
    final remainingEnergyKwh = (remainingSocPct / 100.0) * batteryCapacityKwh;
    final effectivePower = activePowerKw > 0 ? activePowerKw : (chargerPowerKw * 0.8);
    if (effectivePower <= 0) return 0;
    return ((remainingEnergyKwh / effectivePower) * 60).round();
  }

  factory ChargingSessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final now = DateTime.now();
    return ChargingSessionModel.fromJson({...data, 'sessionId': doc.id, 'createdAt': data['createdAt'] ?? now});
  }

  Map<String, dynamic> toMap() => toJson();

  factory ChargingSessionModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return ChargingSessionModel(
      sessionId: json['sessionId'] ?? json['id'] ?? 'sess_local',
      userId: json['userId'] ?? 'user_local',
      walletId: json['walletId'] ?? 'wallet_local',
      chargerId: json['chargerId'] ?? json['stationId'] ?? '',
      chargerName: json['chargerName'] ?? 'EV Charging Station',
      networkName: json['networkName'] ?? 'EVHub Network',
      chargerAddress: json['chargerAddress'] ?? 'India EV Charging Station',
      vehicleId: json['vehicleId'] ?? 'vehicle_local',
      vehicleName: json['vehicleName'] ?? 'Electric Vehicle',
      connectorType: json['connectorType'] ?? 'CCS2',
      chargerPowerKw: (json['chargerPowerKw'] ?? json['currentKw'] ?? 60.0).toDouble(),
      chargingMode: json['chargingMode'] ?? 'DC Fast',
      startTime: json['startTime'] != null
          ? (json['startTime'] is Timestamp
              ? (json['startTime'] as Timestamp).toDate()
              : DateTime.tryParse(json['startTime'].toString()) ?? now)
          : now,
      endTime: json['endTime'] != null
          ? (json['endTime'] is Timestamp
              ? (json['endTime'] as Timestamp).toDate()
              : DateTime.tryParse(json['endTime'].toString()))
          : null,
      initialSocPercent: (json['initialSocPercent'] ?? 20.0).toDouble(),
      currentSocPercent: (json['currentSocPercent'] ?? json['batteryPercentage'] ?? 20.0).toDouble(),
      targetSocPercent: (json['targetSocPercent'] ?? 80.0).toDouble(),
      batteryCapacityKwh: (json['batteryCapacityKwh'] ?? 50.0).toDouble(),
      energyDeliveredKwh: (json['energyDeliveredKwh'] ?? json['unitsConsumed'] ?? 0.0).toDouble(),
      estimatedCost: (json['estimatedCost'] ?? json['currentCost'] ?? 0.0).toDouble(),
      finalCost: (json['finalCost'] ?? 0.0).toDouble(),
      pricePerKwh: (json['pricePerKwh'] ?? 18.0).toDouble(),
      chargingEfficiency: (json['chargingEfficiency'] ?? 0.90).toDouble(),
      chargingLossKwh: (json['chargingLossKwh'] ?? 0.0).toDouble(),
      activePowerKw: (json['activePowerKw'] ?? json['currentKw'] ?? 0.0).toDouble(),
      status: _statusFromString(json['status']?.toString()),
      transactionId: json['transactionId'],
      referenceId: json['referenceId'],
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is Timestamp
              ? (json['createdAt'] as Timestamp).toDate()
              : DateTime.tryParse(json['createdAt'].toString()) ?? now)
          : now,
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] is Timestamp
              ? (json['updatedAt'] as Timestamp).toDate()
              : DateTime.tryParse(json['updatedAt'].toString()) ?? now)
          : now,
      powerGraph: (json['powerGraph'] as List<dynamic>? ?? [])
          .map((e) => GraphPoint.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'id': sessionId,
      'userId': userId,
      'walletId': walletId,
      'chargerId': chargerId,
      'stationId': chargerId,
      'chargerName': chargerName,
      'networkName': networkName,
      'chargerAddress': chargerAddress,
      'vehicleId': vehicleId,
      'vehicleName': vehicleName,
      'connectorType': connectorType,
      'chargerPowerKw': chargerPowerKw,
      'chargingMode': chargingMode,
      'startTime': startTime.toIso8601String(),
      if (endTime != null) 'endTime': endTime!.toIso8601String(),
      'initialSocPercent': initialSocPercent,
      'currentSocPercent': currentSocPercent,
      'batteryPercentage': currentSocPercent,
      'targetSocPercent': targetSocPercent,
      'batteryCapacityKwh': batteryCapacityKwh,
      'energyDeliveredKwh': energyDeliveredKwh,
      'unitsConsumed': energyDeliveredKwh,
      'estimatedCost': estimatedCost,
      'currentCost': estimatedCost,
      'finalCost': finalCost,
      'pricePerKwh': pricePerKwh,
      'chargingEfficiency': chargingEfficiency,
      'chargingLossKwh': chargingLossKwh,
      'activePowerKw': activePowerKw,
      'currentKw': activePowerKw,
      'status': status.name,
      if (transactionId != null) 'transactionId': transactionId,
      if (referenceId != null) 'referenceId': referenceId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'powerGraph': powerGraph.map((e) => e.toMap()).toList(),
    };
  }

  ChargingSessionModel copyWith({
    String? sessionId,
    String? id,
    String? userId,
    String? walletId,
    String? chargerId,
    String? stationId,
    String? chargerName,
    String? networkName,
    String? chargerAddress,
    String? vehicleId,
    String? vehicleName,
    String? connectorType,
    double? chargerPowerKw,
    String? chargingMode,
    DateTime? startTime,
    DateTime? endTime,
    double? initialSocPercent,
    double? currentSocPercent,
    double? batteryPercentage,
    double? targetSocPercent,
    double? batteryCapacityKwh,
    double? energyDeliveredKwh,
    double? unitsConsumed,
    double? estimatedCost,
    double? currentCost,
    double? finalCost,
    double? pricePerKwh,
    double? chargingEfficiency,
    double? chargingLossKwh,
    double? activePowerKw,
    double? currentKw,
    ChargingSessionStatus? status,
    String? transactionId,
    String? referenceId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<GraphPoint>? powerGraph,
  }) {
    return ChargingSessionModel(
      sessionId: sessionId ?? id ?? this.sessionId,
      userId: userId ?? this.userId,
      walletId: walletId ?? this.walletId,
      chargerId: chargerId ?? stationId ?? this.chargerId,
      chargerName: chargerName ?? this.chargerName,
      networkName: networkName ?? this.networkName,
      chargerAddress: chargerAddress ?? this.chargerAddress,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleName: vehicleName ?? this.vehicleName,
      connectorType: connectorType ?? this.connectorType,
      chargerPowerKw: chargerPowerKw ?? currentKw ?? this.chargerPowerKw,
      chargingMode: chargingMode ?? this.chargingMode,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      initialSocPercent: initialSocPercent ?? this.initialSocPercent,
      currentSocPercent: currentSocPercent ?? batteryPercentage ?? this.currentSocPercent,
      targetSocPercent: targetSocPercent ?? this.targetSocPercent,
      batteryCapacityKwh: batteryCapacityKwh ?? this.batteryCapacityKwh,
      energyDeliveredKwh: energyDeliveredKwh ?? unitsConsumed ?? this.energyDeliveredKwh,
      estimatedCost: estimatedCost ?? currentCost ?? this.estimatedCost,
      finalCost: finalCost ?? this.finalCost,
      pricePerKwh: pricePerKwh ?? this.pricePerKwh,
      chargingEfficiency: chargingEfficiency ?? this.chargingEfficiency,
      chargingLossKwh: chargingLossKwh ?? this.chargingLossKwh,
      activePowerKw: activePowerKw ?? currentKw ?? this.activePowerKw,
      status: status ?? this.status,
      transactionId: transactionId ?? this.transactionId,
      referenceId: referenceId ?? this.referenceId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      powerGraph: powerGraph ?? this.powerGraph,
    );
  }

  static ChargingSessionStatus _statusFromString(String? s) {
    if (s == null) return ChargingSessionStatus.idle;
    final lower = s.toLowerCase();
    if (lower == 'starting' || lower == 'preparing') return ChargingSessionStatus.starting;
    if (lower == 'charging') return ChargingSessionStatus.charging;
    if (lower == 'paused') return ChargingSessionStatus.paused;
    if (lower == 'completing') return ChargingSessionStatus.completing;
    if (lower == 'paymentpending' || lower == 'payment_pending') return ChargingSessionStatus.paymentPending;
    if (lower == 'completed') return ChargingSessionStatus.completed;
    if (lower == 'paymentfailed' || lower == 'payment_failed') return ChargingSessionStatus.paymentFailed;
    if (lower == 'cancelled' || lower == 'stopped') return ChargingSessionStatus.cancelled;
    if (lower == 'error') return ChargingSessionStatus.error;
    return ChargingSessionStatus.idle;
  }
}

class GraphPoint {
  final int timestampOffsetSeconds;
  final double kwValue;

  const GraphPoint({required this.timestampOffsetSeconds, required this.kwValue});

  factory GraphPoint.fromMap(Map<String, dynamic> map) {
    return GraphPoint(
      timestampOffsetSeconds: map['t'] ?? 0,
      kwValue: (map['v'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'t': timestampOffsetSeconds, 'v': kwValue};
  }
}
