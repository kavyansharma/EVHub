import '../models/reward_model.dart';

class RewardService {
  
  int calculatePointsForAction(RewardAction action, {double? kwhCharged}) {
    switch (action) {
      case RewardAction.dailyLogin:
        return 10;
      case RewardAction.referral:
        return 500;
      case RewardAction.charging:
        // 5 points per kWh
        return ((kwhCharged ?? 0) * 5).round();
      case RewardAction.achievement:
        return 100;
      case RewardAction.redemption:
        return 0; // Redemption handled separately
    }
  }

  String getMembershipTier(int totalPoints) {
    if (totalPoints >= 10000) return 'Platinum';
    if (totalPoints >= 5000) return 'Gold';
    if (totalPoints >= 1000) return 'Silver';
    return 'Bronze';
  }
}
