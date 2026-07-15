import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../models/vehicle_model.dart';
import '../../providers/garage_provider.dart';

class GarageScreen extends StatelessWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final brandColor = theme.colorScheme.primary;
    final garageProvider = context.watch<GarageProvider>();
    final vehicles = garageProvider.vehicles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Garage'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {},
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Primary Vehicle', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  // Active Vehicle Hero Card
                  if (vehicles.isNotEmpty)
                    _buildHeroVehicleCard(context, vehicles.first, brandColor, isDark)
                  else
                    const Center(child: Text('No vehicles found. Add one!')),
                  
                  const SizedBox(height: 32),
                  const Text('Battery Health & Analytics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildAnalyticCard('SoH', '98%', Icons.battery_charging_full, Colors.green, isDark),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildAnalyticCard('Est. Range', '385 km', Icons.route, Colors.blue, isDark),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  const Text('Other Vehicles', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          
          // List of other vehicles
          if (vehicles.length > 1)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == 0) return const SizedBox.shrink(); // Skip primary
                  final vehicle = vehicles[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    child: _buildSecondaryVehicleCard(context, vehicle, isDark),
                  );
                },
                childCount: vehicles.length,
              ),
            ),
            
          const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding
        ],
      ),
    );
  }

  Widget _buildHeroVehicleCard(BuildContext context, VehicleModel vehicle, Color brandColor, bool isDark) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.glassFill(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: brandColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: brandColor.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Stack(
        children: [
          // Background Gradient Glow
          Positioned(
            right: -20,
            bottom: -20,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: brandColor.withOpacity(0.3), blurRadius: 60, spreadRadius: 30)
                ],
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(vehicle.manufacturer, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Connected', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Text(vehicle.model, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Battery', style: TextStyle(color: Colors.grey, fontSize: 14)),
                        Text('${vehicle.batteryCapacity} kWh', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Icon(Icons.directions_car, size: 60, color: Colors.white54),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryVehicleCard(BuildContext context, VehicleModel vehicle, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: Colors.blueGrey,
            child: Icon(Icons.directions_car, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vehicle.model, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(vehicle.manufacturer, style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          ),
          Text('${vehicle.batteryCapacity} kWh', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAnalyticCard(String title, String value, IconData icon, Color color, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }
}
