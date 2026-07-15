import 'dart:async';
import 'package:flutter/material.dart';
import '../models/route_analytics_model.dart';
import '../models/trip_plan_model.dart';
import '../repositories/route_analytics_repository.dart';
import '../services/route_analytics_service.dart';

class RouteAnalyticsProvider extends ChangeNotifier {
  final RouteAnalyticsRepository _repository;
  final RouteAnalyticsService _service;

  List<RouteAnalyticsModel> _history = [];
  StreamSubscription<List<RouteAnalyticsModel>>? _sub;

  RouteAnalyticsProvider({
    required RouteAnalyticsRepository repository,
    required RouteAnalyticsService service,
  })  : _repository = repository,
        _service = service;

  List<RouteAnalyticsModel> get history => _history;

  void loadAnalytics(String userId) {
    _sub?.cancel();
    _sub = _repository.watchAnalytics(userId).listen((data) {
      _history = data;
      notifyListeners();
    });
  }

  Future<void> generatePostTripReport(TripPlanModel trip, double actualEnergyKwhUsed) async {
    final analytics = await _service.analyzeCompletedTrip(trip, actualEnergyKwhUsed);
    await _repository.saveAnalytics(analytics);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
