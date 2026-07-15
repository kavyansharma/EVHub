import 'dart:async';
import 'package:flutter/material.dart';
import '../models/health_model.dart';
import '../repositories/health_repository.dart';
import '../services/health_service.dart';

class HealthProvider extends ChangeNotifier {
  final HealthRepository _repository;
  final HealthService _service;

  HealthModel? _healthData;
  StreamSubscription<HealthModel?>? _healthSub;
  List<String> _recommendations = [];

  HealthProvider({
    required HealthRepository repository,
    required HealthService service,
  })  : _repository = repository,
        _service = service;

  HealthModel? get healthData => _healthData;
  List<String> get recommendations => _recommendations;

  void loadHealthData(String vehicleId) {
    _healthSub?.cancel();
    _healthSub = _repository.watchHealthData(vehicleId).listen((data) {
      if (data == null) {
        // Initialize if not exists
        final newHealth = HealthModel(
          vehicleId: vehicleId,
          userId: 'guest',
          lastUpdated: DateTime.now(),
        );
        _repository.saveHealthData(newHealth);
      } else {
        _healthData = data;
        _recommendations = _service.getHealthRecommendations(data);
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _healthSub?.cancel();
    super.dispose();
  }
}
