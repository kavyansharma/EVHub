import 'package:flutter/material.dart';
import '../models/battery_health.dart';
import '../services/battery_health_service.dart';

class BatteryProvider extends ChangeNotifier {
  final BatteryHealthService _batteryHealthService;

  BatteryHealth? _batteryHealth;
  bool _isLoading = false;

  BatteryProvider({required BatteryHealthService batteryHealthService})
      : _batteryHealthService = batteryHealthService;

  BatteryHealth? get batteryHealth => _batteryHealth;
  bool get isLoading => _isLoading;

  Future<void> loadBatteryHealth(String vehicleId, String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _batteryHealth = await _batteryHealthService.getBatteryHealth(vehicleId, userId);
    } catch (e) {
      debugPrint("Error loading battery health: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
