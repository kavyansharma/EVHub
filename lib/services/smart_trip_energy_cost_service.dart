
import '../models/map_marker_model.dart';
import '../models/smart_trip_cost_settings.dart';

/// Service responsible for computing energy loss, grid energy draw, cost, 
/// and ICE comparisons for the Smart Trip Planner.
class SmartTripEnergyCostService {
  /// Default charging efficiencies
  static const double _acEfficiency = 0.90;
  static const double _dcEfficiency = 0.92;
  static const double _ultraFastEfficiency = 0.94;

  const SmartTripEnergyCostService();

  /// Determine the charging efficiency based on charger power.
  double getChargingEfficiency(double powerKw) {
    if (powerKw <= 22) return _acEfficiency;
    if (powerKw >= 100) return _ultraFastEfficiency;
    return _dcEfficiency;
  }

  /// Calculates the grid energy required to add [batteryAddedKwh].
  double calculateGridEnergyDrawn(double batteryAddedKwh, double powerKw) {
    if (batteryAddedKwh <= 0) return 0.0;
    final efficiency = getChargingEfficiency(powerKw);
    return batteryAddedKwh / efficiency;
  }

  /// Extracts the numeric tariff from a charger's price string if available.
  /// Example: "₹20/kWh", "20", "INR 20" -> 20.0
  double? parseTariff(MapMarkerModel charger) {
    if (charger.price == null || charger.price!.isEmpty) return null;
    
    // Look for numbers in the string
    final match = RegExp(r'(\d+(\.\d+)?)').firstMatch(charger.price!);
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }
    return null;
  }

  /// Determines the applicable tariff and its source.
  /// Returns a tuple of (pricePerKwh, tariffSource).
  ({double? price, String source}) determineTariff(
    MapMarkerModel charger, 
    SmartTripCostSettings settings,
  ) {
    // 1. Check direct charger price
    final parsedPrice = parseTariff(charger);
    if (parsedPrice != null && parsedPrice > 0) {
      return (price: parsedPrice, source: 'Station tariff');
    }

    // 2. Use user-configured default estimated tariff
    if (settings.defaultChargingPricePerKwh > 0) {
      return (price: settings.defaultChargingPricePerKwh, source: 'Estimated tariff');
    }

    return (price: null, source: 'Price unavailable');
  }

  /// Calculates the cost for a specific charging session.
  double calculateChargingCost(double gridEnergyDrawnKwh, double? pricePerKwh) {
    if (gridEnergyDrawnKwh <= 0 || pricePerKwh == null || pricePerKwh <= 0) {
      return 0.0;
    }
    return gridEnergyDrawnKwh * pricePerKwh;
  }

  /// Calculates ICE fuel cost comparison.
  ({double fuelCost, double fuelRequiredLiters, double savings, double savingsPct}) calculateIceComparison({
    required double tripDistanceKm,
    required double totalEvCost,
    required SmartTripCostSettings settings,
  }) {
    final bool isPetrol = settings.iceComparisonFuelType.toLowerCase() == 'petrol';
    final double efficiencyKml = isPetrol ? settings.petrolEfficiencyKml : settings.dieselEfficiencyKml;
    final double pricePerLitre = isPetrol ? settings.petrolPricePerLitre : settings.dieselPricePerLitre;

    if (efficiencyKml <= 0 || pricePerLitre <= 0 || tripDistanceKm <= 0) {
      return (fuelCost: 0.0, fuelRequiredLiters: 0.0, savings: 0.0, savingsPct: 0.0);
    }

    final double fuelRequiredLiters = tripDistanceKm / efficiencyKml;
    final double fuelCost = fuelRequiredLiters * pricePerLitre;
    
    final double savings = fuelCost - totalEvCost;
    final double savingsPct = fuelCost > 0 ? (savings / fuelCost) * 100.0 : 0.0;

    return (
      fuelCost: fuelCost, 
      fuelRequiredLiters: fuelRequiredLiters, 
      savings: savings, 
      savingsPct: savingsPct
    );
  }

  /// Parses power string to KW double safely
  double parsePowerKW(String powerStr) {
    if (powerStr.isEmpty) return 50.0;
    final match = RegExp(r'(\d+(\.\d+)?)').firstMatch(powerStr);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 50.0;
    }
    return 50.0;
  }
}
