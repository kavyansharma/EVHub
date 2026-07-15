import '../models/pricing_model.dart';
import '../models/station_model.dart';

class ReservationService {
  
  double calculateReservationCost(DateTime start, DateTime end, double ratePerMin) {
    final duration = end.difference(start).inMinutes;
    if (duration <= 0) return 0.0;
    
    // Base fee + duration * rate
    const double baseFee = 20.0; // INR
    return baseFee + (duration * ratePerMin);
  }

  bool validateReservationTime(DateTime start, DateTime end) {
    final now = DateTime.now();
    if (start.isBefore(now)) return false;
    if (end.difference(start).inMinutes < 15) return false;
    if (start.difference(now).inHours > 24) return false;
    
    return true;
  }

  /// Phase 5 - Module 3 & 4: Smart Cost Optimizer & Dynamic Pricing Engine
  Map<String, dynamic> calculateSmartOptimization({
    required StationModel station,
    required double currentBatteryPct,
    required double targetBatteryPct,
    required double vehicleBatteryCapacityKw,
    required PricingModel pricing,
    required bool isMember,
  }) {
    if (targetBatteryPct <= currentBatteryPct) return {};

    final pctToCharge = (targetBatteryPct - currentBatteryPct) / 100.0;
    final kwhNeeded = pctToCharge * vehicleBatteryCapacityKw;
    
    // Efficiency losses (approx 10% lost as heat)
    final actualKwhToPull = kwhNeeded * 1.1;
    
    // Estimate Time (Station Power vs Vehicle Max Power)
    // Assuming vehicle can accept full station power for simplicity, or 50kW max
    final chargeSpeedKw = station.power > 50.0 ? 50.0 : station.power;
    final hoursNeeded = actualKwhToPull / chargeSpeedKw;
    
    // Pricing calculation
    final currentRate = pricing.getCurrentRate(isMember);
    final totalCost = (actualKwhToPull * currentRate) + pricing.connectionFee;

    return {
      'expectedUnits': actualKwhToPull,
      'durationMinutes': (hoursNeeded * 60).round(),
      'totalCost': totalCost,
      'rateApplied': currentRate,
      'efficiencyLossKw': actualKwhToPull - kwhNeeded,
    };
  }
}
