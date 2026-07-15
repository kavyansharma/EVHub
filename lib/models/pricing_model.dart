class PricingModel {
  final double baseRatePerKwh;
  final double peakMultiplier;
  final double nightDiscount;
  final double membershipDiscount;
  final bool isPeakHours;
  final bool isNightHours;
  final double connectionFee;

  const PricingModel({
    this.baseRatePerKwh = 15.0, // Default INR 15 per kWh
    this.peakMultiplier = 1.2,  // 20% extra during peak
    this.nightDiscount = 0.8,   // 20% discount at night
    this.membershipDiscount = 0.9, // 10% discount for members
    this.isPeakHours = false,
    this.isNightHours = false,
    this.connectionFee = 20.0,
  });

  double getCurrentRate(bool isMember) {
    double rate = baseRatePerKwh;
    
    if (isPeakHours) {
      rate *= peakMultiplier;
    } else if (isNightHours) {
      rate *= nightDiscount;
    }
    
    if (isMember) {
      rate *= membershipDiscount;
    }
    
    return rate;
  }
}
