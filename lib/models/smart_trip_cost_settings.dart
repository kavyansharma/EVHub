

/// Phase 4 Step 3: Smart Charging Cost & Energy Planner
///
/// Holds the user-configurable settings for estimating trip costs and ICE comparisons.
class SmartTripCostSettings {
  final double defaultChargingPricePerKwh;
  final double petrolPricePerLitre;
  final double dieselPricePerLitre;
  final double petrolEfficiencyKml;
  final double dieselEfficiencyKml;
  final String iceComparisonFuelType; // 'Petrol' or 'Diesel'

  const SmartTripCostSettings({
    this.defaultChargingPricePerKwh = 20.0,
    this.petrolPricePerLitre = 100.0,
    this.dieselPricePerLitre = 90.0,
    this.petrolEfficiencyKml = 15.0,
    this.dieselEfficiencyKml = 20.0,
    this.iceComparisonFuelType = 'Petrol',
  });

  SmartTripCostSettings copyWith({
    double? defaultChargingPricePerKwh,
    double? petrolPricePerLitre,
    double? dieselPricePerLitre,
    double? petrolEfficiencyKml,
    double? dieselEfficiencyKml,
    String? iceComparisonFuelType,
  }) {
    return SmartTripCostSettings(
      defaultChargingPricePerKwh: defaultChargingPricePerKwh ?? this.defaultChargingPricePerKwh,
      petrolPricePerLitre: petrolPricePerLitre ?? this.petrolPricePerLitre,
      dieselPricePerLitre: dieselPricePerLitre ?? this.dieselPricePerLitre,
      petrolEfficiencyKml: petrolEfficiencyKml ?? this.petrolEfficiencyKml,
      dieselEfficiencyKml: dieselEfficiencyKml ?? this.dieselEfficiencyKml,
      iceComparisonFuelType: iceComparisonFuelType ?? this.iceComparisonFuelType,
    );
  }

  /// Deserialization from MapsProvider (SharedPreferences)
  factory SmartTripCostSettings.fromJson(Map<String, dynamic> json) {
    return SmartTripCostSettings(
      defaultChargingPricePerKwh: (json['defaultChargingPricePerKwh'] as num?)?.toDouble() ?? 20.0,
      petrolPricePerLitre: (json['petrolPricePerLitre'] as num?)?.toDouble() ?? 100.0,
      dieselPricePerLitre: (json['dieselPricePerLitre'] as num?)?.toDouble() ?? 90.0,
      petrolEfficiencyKml: (json['petrolEfficiencyKml'] as num?)?.toDouble() ?? 15.0,
      dieselEfficiencyKml: (json['dieselEfficiencyKml'] as num?)?.toDouble() ?? 20.0,
      iceComparisonFuelType: json['iceComparisonFuelType'] as String? ?? 'Petrol',
    );
  }

  /// Serialization for MapsProvider (SharedPreferences)
  Map<String, dynamic> toJson() {
    return {
      'defaultChargingPricePerKwh': defaultChargingPricePerKwh,
      'petrolPricePerLitre': petrolPricePerLitre,
      'dieselPricePerLitre': dieselPricePerLitre,
      'petrolEfficiencyKml': petrolEfficiencyKml,
      'dieselEfficiencyKml': dieselEfficiencyKml,
      'iceComparisonFuelType': iceComparisonFuelType,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SmartTripCostSettings &&
        other.defaultChargingPricePerKwh == defaultChargingPricePerKwh &&
        other.petrolPricePerLitre == petrolPricePerLitre &&
        other.dieselPricePerLitre == dieselPricePerLitre &&
        other.petrolEfficiencyKml == petrolEfficiencyKml &&
        other.dieselEfficiencyKml == dieselEfficiencyKml &&
        other.iceComparisonFuelType == iceComparisonFuelType;
  }

  @override
  int get hashCode {
    return defaultChargingPricePerKwh.hashCode ^
        petrolPricePerLitre.hashCode ^
        dieselPricePerLitre.hashCode ^
        petrolEfficiencyKml.hashCode ^
        dieselEfficiencyKml.hashCode ^
        iceComparisonFuelType.hashCode;
  }
}
