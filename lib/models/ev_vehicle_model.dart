/// EVVehicleModel
///
/// Phase 4 Step 2 spec-compliant EV vehicle model.
/// Uses clean field names as specified in the Smart Trip Planner spec.
/// Converts to/from the existing [VehicleModel] used throughout the app.
library;

import 'vehicle_model.dart';

class EVVehicleModel {
  final String id;
  final String brand;
  final String model;

  /// Total battery capacity in kWh (nameplate).
  final double batteryCapacityKWh;

  /// Usable battery capacity in kWh (typically 90–98% of nameplate).
  final double usableBatteryCapacityKWh;

  /// Real-world range estimate in km (not ARAI/WLTP).
  final double realWorldRangeKm;

  /// Supported connector types (e.g., 'CCS2', 'Type 2', 'CHAdeMO').
  final List<String> connectorTypes;

  /// Maximum AC charging power in kW.
  final double maxACChargingPowerKW;

  /// Maximum DC charging power in kW.
  final double maxDCChargingPowerKW;

  /// Average energy consumption in Wh/km (used for efficiency calculations).
  final double averageEfficiencyWhPerKm;

  const EVVehicleModel({
    required this.id,
    required this.brand,
    required this.model,
    required this.batteryCapacityKWh,
    required this.usableBatteryCapacityKWh,
    required this.realWorldRangeKm,
    required this.connectorTypes,
    required this.maxACChargingPowerKW,
    required this.maxDCChargingPowerKW,
    this.averageEfficiencyWhPerKm = 150.0,
  });

  /// Display-friendly name: "Tata Nexon EV"
  String get displayName => '$brand $model';

  /// Energy consumption rate in kWh/km (derived from usable capacity and range).
  double get consumptionKWhPerKm =>
      usableBatteryCapacityKWh / realWorldRangeKm;

  /// Whether this vehicle supports DC fast charging.
  bool get supportsFastCharging => maxDCChargingPowerKW >= 25.0;

  /// Whether this vehicle supports Ultra-Fast DC charging (≥ 100 kW).
  bool get supportsUltraFastCharging => maxDCChargingPowerKW >= 100.0;

  /// Converts a [VehicleModel] (existing app model) into an [EVVehicleModel].
  factory EVVehicleModel.fromVehicleModel(VehicleModel v) {
    return EVVehicleModel(
      id: v.id,
      brand: v.manufacturer,
      model: '${v.model} ${v.variant}'.trim(),
      batteryCapacityKWh: v.batteryCapacity,
      usableBatteryCapacityKWh: v.usableBatteryCapacity,
      realWorldRangeKm: v.realRange,
      connectorTypes: v.connectorTypes,
      maxACChargingPowerKW: v.maxAcChargingSpeed,
      maxDCChargingPowerKW: v.maxDcChargingSpeed,
      averageEfficiencyWhPerKm: v.averageEfficiency,
    );
  }

  /// Converts back to [VehicleModel] for use in existing provider/service code.
  VehicleModel toVehicleModel() {
    return VehicleModel(
      id: id,
      manufacturer: brand,
      model: model,
      variant: '',
      year: 2024,
      batteryCapacity: batteryCapacityKWh,
      usableBatteryCapacityKWh: usableBatteryCapacityKWh,
      realRange: realWorldRangeKm,
      connectorTypes: connectorTypes,
      maxAcChargingSpeed: maxACChargingPowerKW,
      maxDcChargingSpeed: maxDCChargingPowerKW,
      vehicleImage: '',
      registrationNumber: '',
      nickname: displayName,
      averageEfficiency: averageEfficiencyWhPerKm,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EVVehicleModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'EVVehicleModel(id: $id, brand: $brand, model: $model, '
      'battery: ${batteryCapacityKWh}kWh, range: ${realWorldRangeKm}km)';
}
