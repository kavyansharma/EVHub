import 'package:flutter/material.dart';
import 'charger_management_screen.dart';

/// ManageChargersScreen
///
/// EVHub Phase 7.3A & 7.4A Manage Chargers Screen.
/// Wraps ChargerManagementScreen with optional initial filter parameters.
class ManageChargersScreen extends StatelessWidget {
  final String? initialSearchQuery;
  final String? initialStatusFilter;
  final String? initialNetworkFilter;

  const ManageChargersScreen({
    super.key,
    this.initialSearchQuery,
    this.initialStatusFilter,
    this.initialNetworkFilter,
  });

  @override
  Widget build(BuildContext context) {
    return ChargerManagementScreen(
      initialSearchQuery: initialSearchQuery,
      initialStatusFilter: initialStatusFilter,
      initialNetworkFilter: initialNetworkFilter,
    );
  }
}
