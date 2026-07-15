import '../models/profile_model.dart';

class ProfileService {
  
  double calculateCompleteness(ProfileModel profile) {
    double score = 0;
    if (profile.phone.isNotEmpty) score += 25;
    if (profile.preferredNetworks.isNotEmpty) score += 25;
    if (profile.totalSessions > 0) score += 25;
    if (profile.badges.isNotEmpty) score += 25;
    return score;
  }

  bool canRedeemReward(ProfileModel profile, int pointsRequired) {
    return profile.totalRewardPoints >= pointsRequired;
  }
}
