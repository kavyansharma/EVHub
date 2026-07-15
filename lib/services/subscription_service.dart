import '../models/subscription_model.dart';

class SubscriptionService {
  
  Map<String, dynamic> getTierBenefits(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.platinum:
        return {
          'discount': '20% Off Charging',
          'priority': 'High Priority Reservations',
          'support': '24/7 Premium Support',
          'freeCredits': '100 kWh / month',
        };
      case SubscriptionTier.gold:
        return {
          'discount': '10% Off Charging',
          'priority': 'Standard Priority Reservations',
          'support': 'Priority Email Support',
          'freeCredits': '50 kWh / month',
        };
      case SubscriptionTier.silver:
        return {
          'discount': '5% Off Charging',
          'priority': 'Basic Reservations',
          'support': 'Standard Support',
          'freeCredits': '10 kWh / month',
        };
      case SubscriptionTier.free:
        return {
          'discount': 'None',
          'priority': 'Basic Reservations',
          'support': 'Community Support',
          'freeCredits': 'None',
        };
    }
  }

  double calculateDiscountedPrice(double basePrice, SubscriptionModel subscription) {
    return basePrice * subscription.discountMultiplier;
  }
}
