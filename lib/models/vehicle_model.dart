import 'package:cloud_firestore/cloud_firestore.dart';

class VehicleModel {
  final String id;
  final String? userId; // Optional for default DB models
  final String manufacturer;
  final String model;
  final String variant;
  final int year;
  final double batteryCapacity; // in kWh
  final double realRange; // in km
  final List<String> connectorTypes; // e.g. CCS2, Type 2, CHAdeMO
  final double maxAcChargingSpeed; // in kW
  final double maxDcChargingSpeed; // in kW
  final String vehicleImage;
  final String registrationNumber;
  final String nickname;
  final bool isDefault;
  
  // Phase 6 Additions
  final String vehicleColor;
  final double currentBatteryPct;
  final double averageEfficiency; // Wh/km
  final bool fastChargingSupport;
  final int wheelSize;
  final String drivingStyle; // e.g., 'Eco', 'Normal', 'Sport'

  const VehicleModel({
    required this.id,
    this.userId,
    required this.manufacturer,
    required this.model,
    required this.variant,
    required this.year,
    required this.batteryCapacity,
    required this.realRange,
    required this.connectorTypes,
    required this.maxAcChargingSpeed,
    required this.maxDcChargingSpeed,
    required this.vehicleImage,
    required this.registrationNumber,
    required this.nickname,
    this.isDefault = false,
    this.vehicleColor = 'White',
    this.currentBatteryPct = 100.0,
    this.averageEfficiency = 150.0,
    this.fastChargingSupport = true,
    this.wheelSize = 18,
    this.drivingStyle = 'Normal',
  });

  factory VehicleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VehicleModel.fromMap(doc.id, data);
  }

  factory VehicleModel.fromMap(String id, Map<String, dynamic> data) {
    return VehicleModel(
      id: id,
      userId: data['userId'],
      manufacturer: data['manufacturer'] ?? '',
      model: data['model'] ?? '',
      variant: data['variant'] ?? '',
      year: data['year'] ?? 2023,
      batteryCapacity: (data['batteryCapacity'] ?? 0.0).toDouble(),
      realRange: (data['realRange'] ?? 0.0).toDouble(),
      connectorTypes: List<String>.from(data['connectorTypes'] ?? []),
      maxAcChargingSpeed: (data['maxAcChargingSpeed'] ?? 0.0).toDouble(),
      maxDcChargingSpeed: (data['maxDcChargingSpeed'] ?? 0.0).toDouble(),
      vehicleImage: data['vehicleImage'] ?? '',
      registrationNumber: data['registrationNumber'] ?? '',
      nickname: data['nickname'] ?? '',
      isDefault: data['isDefault'] ?? false,
      vehicleColor: data['vehicleColor'] ?? 'White',
      currentBatteryPct: (data['currentBatteryPct'] ?? 100.0).toDouble(),
      averageEfficiency: (data['averageEfficiency'] ?? 150.0).toDouble(),
      fastChargingSupport: data['fastChargingSupport'] ?? true,
      wheelSize: data['wheelSize'] ?? 18,
      drivingStyle: data['drivingStyle'] ?? 'Normal',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (userId != null) 'userId': userId,
      'manufacturer': manufacturer,
      'model': model,
      'variant': variant,
      'year': year,
      'batteryCapacity': batteryCapacity,
      'realRange': realRange,
      'connectorTypes': connectorTypes,
      'maxAcChargingSpeed': maxAcChargingSpeed,
      'maxDcChargingSpeed': maxDcChargingSpeed,
      'vehicleImage': vehicleImage,
      'registrationNumber': registrationNumber,
      'nickname': nickname,
      'isDefault': isDefault,
      'vehicleColor': vehicleColor,
      'currentBatteryPct': currentBatteryPct,
      'averageEfficiency': averageEfficiency,
      'fastChargingSupport': fastChargingSupport,
      'wheelSize': wheelSize,
      'drivingStyle': drivingStyle,
    };
  }

  VehicleModel copyWith({
    String? id,
    String? userId,
    String? manufacturer,
    String? model,
    String? variant,
    int? year,
    double? batteryCapacity,
    double? realRange,
    List<String>? connectorTypes,
    double? maxAcChargingSpeed,
    double? maxDcChargingSpeed,
    String? vehicleImage,
    String? registrationNumber,
    String? nickname,
    bool? isDefault,
  }) {
    return VehicleModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      variant: variant ?? this.variant,
      year: year ?? this.year,
      batteryCapacity: batteryCapacity ?? this.batteryCapacity,
      realRange: realRange ?? this.realRange,
      connectorTypes: connectorTypes ?? this.connectorTypes,
      maxAcChargingSpeed: maxAcChargingSpeed ?? this.maxAcChargingSpeed,
      maxDcChargingSpeed: maxDcChargingSpeed ?? this.maxDcChargingSpeed,
      vehicleImage: vehicleImage ?? this.vehicleImage,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      nickname: nickname ?? this.nickname,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
