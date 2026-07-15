import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/fleet_provider.dart';
import '../../models/fleet_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';

class FleetDashboard extends StatefulWidget {
  const FleetDashboard({super.key});

  @override
  State<FleetDashboard> createState() => _FleetDashboardState();
}

class _FleetDashboardState extends State<FleetDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FleetProvider>().loadDriverFleets('demo_driver_123');
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FleetProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeFleet = provider.activeFleet;

    return Scaffold(
      appBar: AppBar(title: const Text('Fleet Management')),
      body: activeFleet == null
          ? const Center(child: Text('You are not assigned to any fleet.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFleetInfoCard(activeFleet, isDark),
                  const SizedBox(height: 24),
                  const Text('Fleet Vehicles', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildVehicleList(),
                ],
              ),
            ),
    );
  }

  Widget _buildFleetInfoCard(FleetModel fleet, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.business_center, size: 48, color: AppColors.primaryPurple),
          const SizedBox(height: 16),
          Text(fleet.companyName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Fleet ID: ${fleet.fleetId}', style: const TextStyle(color: Colors.grey)),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Vehicles', '${fleet.vehicleIds.length}', Icons.directions_car),
              _buildStatItem('Drivers', '${fleet.driverUserIds.length}', Icons.person),
              _buildStatItem('Balance', '₹${fleet.fleetWalletBalance.toStringAsFixed(0)}', Icons.account_balance_wallet),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primaryCyan),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildVehicleList() {
    // Simulated fleet vehicles
    return Column(
      children: List.generate(2, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.directions_car, color: AppColors.primaryCyan, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tata Nexon EV (Fleet #${index + 1})', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Text('Last driven: Today, 10:30 AM', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white),
                  child: const Text('Assign'),
                )
              ],
            ),
          ),
        );
      }),
    );
  }
}
