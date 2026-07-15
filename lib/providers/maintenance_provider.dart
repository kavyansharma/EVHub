import 'dart:async';
import 'package:flutter/material.dart';
import '../models/maintenance_model.dart';
import '../models/health_model.dart';
import '../repositories/maintenance_repository.dart';
import '../services/maintenance_service.dart';

class MaintenanceProvider extends ChangeNotifier {
  final MaintenanceRepository _repository;
  final MaintenanceService _service;

  List<MaintenanceModel> _tasks = [];
  StreamSubscription<List<MaintenanceModel>>? _sub;

  MaintenanceProvider({
    required MaintenanceRepository repository,
    required MaintenanceService service,
  })  : _repository = repository,
        _service = service;

  List<MaintenanceModel> get tasks => _tasks;

  void loadTasks(String vehicleId, HealthModel? currentHealth) {
    _sub?.cancel();
    _sub = _repository.watchTasks(vehicleId).listen((data) async {
      if (data.isEmpty && currentHealth != null) {
        // Generate predictive tasks
        final generated = _service.generatePredictiveMaintenance(currentHealth);
        for (var task in generated) {
          await _repository.saveMaintenanceTask(task);
        }
      } else {
        _tasks = data;
        notifyListeners();
      }
    });
  }

  Future<void> completeTask(MaintenanceModel task) async {
    final updated = MaintenanceModel(
      id: task.id,
      vehicleId: task.vehicleId,
      component: task.component,
      urgency: task.urgency,
      description: task.description,
      estimatedDueDate: task.estimatedDueDate,
      isCompleted: true,
    );
    await _repository.saveMaintenanceTask(updated);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
