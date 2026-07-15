import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/garage_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../models/vehicle_model.dart';

class GarageScreen extends StatelessWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final garageProvider = context.watch<GarageProvider>();
    final theme = Theme.of(context);
    final brandColor = theme.colorScheme.primary;

    if (garageProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final vehicle = garageProvider.selectedVehicle;

    if (vehicle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My EV Garage')),
        body: const Center(child: Text('No vehicles found. Add one in setup.')),
      );
    }

    // Since we don't have real 3D assets, we use a high-quality placeholder URL based on brand
    final imageUrl = _getVehicleImageUrl(vehicle.manufacturer);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car, color: brandColor),
            const SizedBox(width: 8),
            Text(vehicle.nickname.isNotEmpty ? vehicle.nickname : '${vehicle.manufacturer} ${vehicle.model}', 
              style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              brandColor.withOpacity(0.2),
              AppColors.background,
            ],
            stops: const [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildVehicleHero(vehicle, imageUrl, brandColor),
                _buildQuickControls(brandColor),
                const SizedBox(height: 24),
                _buildBatteryStatus(vehicle, brandColor),
                const SizedBox(height: 24),
                _buildGridStats(brandColor),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getVehicleImageUrl(String manufacturer) {
    if (manufacturer.toLowerCase().contains('tesla')) {
      return 'https://images.unsplash.com/photo-1560958089-b8a1929cea89?q=80&w=1000&auto=format&fit=crop';
    } else if (manufacturer.toLowerCase().contains('tata')) {
      return 'https://images.unsplash.com/photo-1619767886558-efdc259cde1a?q=80&w=1000&auto=format&fit=crop'; // Placeholder SUV
    }
    return 'https://images.unsplash.com/photo-1593941707882-a5bba14938c7?q=80&w=1000&auto=format&fit=crop'; // Generic sleek EV
  }

  Widget _buildVehicleHero(VehicleModel vehicle, String imageUrl, Color brandColor) {
    return SizedBox(
      height: 300,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glowing orb behind car
          Container(
            width: 250,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: brandColor.withOpacity(0.5),
                  blurRadius: 100,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),
          // Vehicle Image
          Image.network(
            imageUrl,
            height: 220,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, trace) => Icon(Icons.directions_car, size: 150, color: brandColor),
          ),
          Positioned(
            bottom: 20,
            child: Text(
              '${vehicle.realRange.toInt()} km Range',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickControls(Color brandColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(Icons.lock_open, 'Unlock', brandColor),
          _buildControlButton(Icons.ac_unit, 'Climate', brandColor),
          _buildControlButton(Icons.bolt, 'Charge', brandColor),
          _buildControlButton(Icons.open_in_browser, 'Frunk', brandColor),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, String label, Color brandColor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card.withOpacity(0.5),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.textPrimary.withOpacity(0.1)),
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildBatteryStatus(VehicleModel vehicle, Color brandColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GlassContainer(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Battery Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text('${vehicle.currentBatteryPct.toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: brandColor)),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: vehicle.currentBatteryPct / 100,
                minHeight: 12,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(brandColor),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Capacity: ${vehicle.batteryCapacity} kWh', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const Text('Status: Idle', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGridStats(Color brandColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
        children: [
          _buildStatCard(Icons.health_and_safety, 'Battery Health', '98%', Colors.greenAccent),
          _buildStatCard(Icons.tire_repair, 'Tyre Pressure', '34 PSI', AppColors.warning),
          _buildStatCard(Icons.speed, 'Odometer', '12,450 km', Colors.white),
          _buildStatCard(Icons.build, 'Next Service', 'In 2,000 km', AppColors.primaryCyan),
          _buildStatCard(Icons.shield, 'Insurance', 'Active', Colors.greenAccent),
          _buildStatCard(Icons.history, 'Charging History', 'View All', brandColor),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String title, String value, Color iconColor) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const Spacer(),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
