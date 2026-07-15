import '../models/maintenance_model.dart';
import '../models/health_model.dart';

class MaintenanceService {

  List<MaintenanceModel> generatePredictiveMaintenance(HealthModel health) {
    List<MaintenanceModel> tasks = [];
    final String vid = health.vehicleId;

    // Simulate predictive analytics based on health & cycle count
    if (health.cycleCount > 500) {
      tasks.add(MaintenanceModel(
        id: 'm_${vid}_batt',
        vehicleId: vid,
        component: 'Battery Cell Diagnostics',
        urgency: MaintenanceUrgency.high,
        description: 'High cycle count detected. Recommended deep diagnostic check for cell balancing.',
        estimatedDueDate: DateTime.now().add(const Duration(days: 7)),
      ));
    }
    
    if (health.drivingEfficiency < 5.0) { // low efficiency km/kWh
      tasks.add(MaintenanceModel(
        id: 'm_${vid}_tire',
        vehicleId: vid,
        component: 'Tire Pressure & Alignment',
        urgency: MaintenanceUrgency.medium,
        description: 'Drop in driving efficiency detected. Check tire pressure to improve range.',
        estimatedDueDate: DateTime.now().add(const Duration(days: 14)),
      ));
    }

    if (tasks.isEmpty) {
      tasks.add(MaintenanceModel(
        id: 'm_${vid}_routine',
        vehicleId: vid,
        component: 'Routine Checkup',
        urgency: MaintenanceUrgency.low,
        description: 'Standard 6-month inspection (Coolant, Wipers, Brake Pads).',
        estimatedDueDate: DateTime.now().add(const Duration(days: 90)),
      ));
    }

    return tasks;
  }
}
