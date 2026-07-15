import 'package:cloud_firestore/cloud_firestore.dart';

enum MaintenanceUrgency { low, medium, high, critical }

class MaintenanceModel {
  final String id;
  final String vehicleId;
  final String component; // e.g., 'Coolant', 'Brake Pads', 'Battery Diagnostics'
  final MaintenanceUrgency urgency;
  final String description;
  final DateTime estimatedDueDate;
  final bool isCompleted;

  const MaintenanceModel({
    required this.id,
    required this.vehicleId,
    required this.component,
    required this.urgency,
    required this.description,
    required this.estimatedDueDate,
    this.isCompleted = false,
  });

  factory MaintenanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MaintenanceModel(
      id: doc.id,
      vehicleId: data['vehicleId'] ?? '',
      component: data['component'] ?? '',
      urgency: _urgencyFromString(data['urgency']),
      description: data['description'] ?? '',
      estimatedDueDate: (data['estimatedDueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isCompleted: data['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vehicleId': vehicleId,
      'component': component,
      'urgency': urgency.name,
      'description': description,
      'estimatedDueDate': Timestamp.fromDate(estimatedDueDate),
      'isCompleted': isCompleted,
    };
  }

  static MaintenanceUrgency _urgencyFromString(String? str) {
    switch (str) {
      case 'critical':
        return MaintenanceUrgency.critical;
      case 'high':
        return MaintenanceUrgency.high;
      case 'medium':
        return MaintenanceUrgency.medium;
      case 'low':
      default:
        return MaintenanceUrgency.low;
    }
  }
}
