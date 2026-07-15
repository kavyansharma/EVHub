import 'dart:async';
import 'package:flutter/material.dart';
import '../models/subscription_model.dart';
import '../repositories/subscription_repository.dart';
import '../services/subscription_service.dart';

class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionRepository _repository;
  final SubscriptionService _service;

  SubscriptionModel? _subscription;
  StreamSubscription<SubscriptionModel?>? _sub;
  Map<String, dynamic> _benefits = {};

  SubscriptionProvider({
    required SubscriptionRepository repository,
    required SubscriptionService service,
  })  : _repository = repository,
        _service = service;

  SubscriptionModel? get subscription => _subscription;
  Map<String, dynamic> get benefits => _benefits;

  void loadSubscription(String userId) {
    _sub?.cancel();
    _sub = _repository.watchSubscription(userId).listen((data) {
      if (data == null) {
        // Default free tier
        final defaultSub = SubscriptionModel(
          userId: userId,
          tier: SubscriptionTier.free,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 365)),
        );
        _repository.saveSubscription(defaultSub);
      } else {
        _subscription = data;
        _benefits = _service.getTierBenefits(data.tier);
        notifyListeners();
      }
    });
  }

  Future<void> upgradeTier(SubscriptionTier newTier) async {
    if (_subscription == null) return;
    
    // Simulate payment / upgrade process
    final upgraded = SubscriptionModel(
      userId: _subscription!.userId,
      tier: newTier,
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 30)),
      autoRenew: true,
      discountMultiplier: newTier == SubscriptionTier.platinum ? 0.8 : (newTier == SubscriptionTier.gold ? 0.9 : 0.95),
      freeChargingCredits: newTier == SubscriptionTier.platinum ? 100 : (newTier == SubscriptionTier.gold ? 50 : 10),
    );
    
    await _repository.saveSubscription(upgraded);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
