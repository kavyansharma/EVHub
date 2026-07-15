import 'package:flutter/material.dart';
import '../models/reward_model.dart';
import '../repositories/reward_repository.dart';
import '../services/reward_service.dart';

class RewardProvider extends ChangeNotifier {
  final RewardRepository _rewardRepository;
  final RewardService _rewardService;

  List<RewardModel> _rewards = [];
  bool _isLoading = false;

  RewardProvider({
    required RewardRepository rewardRepository,
    required RewardService rewardService,
  })  : _rewardRepository = rewardRepository,
        _rewardService = rewardService;

  List<RewardModel> get rewards => _rewards;
  bool get isLoading => _isLoading;

  Future<void> fetchUserRewards(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _rewards = await _rewardRepository.getUserRewards(userId);
    } catch (e) {
      debugPrint("Error fetching rewards: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> grantReward(String userId, RewardAction action, {double? kwhCharged}) async {
    final points = _rewardService.calculatePointsForAction(action, kwhCharged: kwhCharged);
    if (points <= 0) return;

    final reward = RewardModel(
      id: 'rwd_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      points: points,
      title: 'Earned from ${action.name}',
      description: 'System granted reward for user activity.',
      action: action,
      timestamp: DateTime.now(),
    );

    try {
      await _rewardRepository.addReward(reward);
      _rewards.insert(0, reward);
      notifyListeners();
    } catch (e) {
      debugPrint("Error granting reward: $e");
    }
  }
}
