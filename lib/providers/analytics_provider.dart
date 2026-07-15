import 'package:flutter/material.dart';
import '../models/wallet_statistics.dart';
import '../models/charging_session.dart';
import '../repositories/analytics_repository.dart';
import '../services/analytics_service.dart';

class AnalyticsProvider extends ChangeNotifier {
  final AnalyticsRepository _analyticsRepository;
  final AnalyticsService _analyticsService;

  WalletStatistics? _statistics;
  bool _isLoading = false;

  AnalyticsProvider({
    required AnalyticsRepository analyticsRepository,
    required AnalyticsService analyticsService,
  })  : _analyticsRepository = analyticsRepository,
        _analyticsService = analyticsService;

  WalletStatistics? get statistics => _statistics;
  bool get isLoading => _isLoading;

  Future<void> loadStatistics(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _statistics = await _analyticsRepository.getStatistics(userId);
    } catch (e) {
      debugPrint("Error loading statistics: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> recalculateAndSave(String userId, double currentBalance, List<ChargingSession> sessions) async {
    _isLoading = true;
    notifyListeners();

    try {
      final newStats = _analyticsService.computeStatistics(userId, currentBalance, sessions);
      await _analyticsRepository.saveStatistics(newStats);
      _statistics = newStats;
    } catch (e) {
      debugPrint("Error recalculating statistics: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
