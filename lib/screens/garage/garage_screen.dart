import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../providers/garage_provider.dart';
import '../../providers/auth_provider.dart';

class GarageScreen extends StatefulWidget {
  const GarageScreen({super.key});

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<GarageProvider>().fetchGarage(auth.user?.id ?? 'default_user');
      context.read<GarageProvider>().loadEcosystemVehicles();
    });
  }

  void _showAddVehicleSheet(BuildContext context, GarageProvider garageProvider, String userId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 24),
                    const Text(
                      'ADD VEHICLE TO GARAGE',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: garageProvider.ecosystemVehicles.length,
                        itemBuilder: (context, index) {
                          final vehicle = garageProvider.ecosystemVehicles[index];
                          final isAlreadyAdded = garageProvider.vehicles.any((v) => v.id == vehicle.id);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: GlassContainer(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Image.network(vehicle.vehicleImage, width: 80, height: 60, fit: BoxFit.contain),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${vehicle.manufacturer} ${vehicle.model}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        Text(vehicle.variant, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                        Text('${vehicle.realRange.toInt()} km range • ${vehicle.batteryCapacity} kWh', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(
                                      isAlreadyAdded ? Icons.check_circle : Icons.add_circle,
                                      color: isAlreadyAdded ? AppColors.secondary : AppColors.primary,
                                      size: 28,
                                    ),
                                    onPressed: isAlreadyAdded
                                        ? null
                                        : () {
                                            garageProvider.addVehicle(userId, vehicle);
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('${vehicle.model} added successfully!'), backgroundColor: AppColors.secondary),
                                            );
                                          },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final garageProvider = context.watch<GarageProvider>();
    final auth = context.watch<AuthProvider>();
    final userId = auth.user?.id ?? 'default_user';

    final userVehicles = garageProvider.vehicles;
    final selectedVehicle = garageProvider.selectedVehicle ?? 
        (userVehicles.isNotEmpty ? userVehicles.first : null);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('GARAGE CONSOLE', style: TextStyle(letterSpacing: 2.0, fontSize: 16)),
        actions: [
          IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedAddCircle, color: AppColors.primary, size: 24),
            onPressed: () => _showAddVehicleSheet(context, garageProvider, userId),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: garageProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : userVehicles.isEmpty
              ? _buildEmptyState(context, garageProvider, userId)
              : CustomScrollView(
                  slivers: [
                    // Horizontal Selector Tabs for User's Cars
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 55,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: userVehicles.length,
                          itemBuilder: (context, index) {
                            final vehicle = userVehicles[index];
                            final isSel = selectedVehicle?.id == vehicle.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: GestureDetector(
                                onTap: () => garageProvider.selectVehicle(vehicle),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSel ? AppColors.primary : AppColors.card.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSel ? AppColors.primary : Colors.white.withOpacity(0.08),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      vehicle.model,
                                      style: TextStyle(
                                        color: isSel ? Colors.black : Colors.white,
                                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Primary Selected Vehicle Detail Panel
                    if (selectedVehicle != null) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Large Vehicle Render Frame
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Positioned(
                                    bottom: 0,
                                    child: Container(
                                      width: 280,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.primary.withOpacity(0.15),
                                        boxShadow: [
                                          BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 40, spreadRadius: 10)
                                        ],
                                      ),
                                    ),
                                  ),
                                  Hero(
                                    tag: 'vehicle_${selectedVehicle.id}',
                                    child: Image.network(
                                      selectedVehicle.vehicleImage,
                                      height: 180,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Quick metrics grid
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMetricTile(
                                      'State of Health',
                                      '98%',
                                      HugeIcons.strokeRoundedBatteryCharging02,
                                      AppColors.secondary,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildMetricTile(
                                      'Range (SoC)',
                                      '${selectedVehicle.realRange.toInt()} km',
                                      HugeIcons.strokeRoundedRoute01,
                                      AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Tech Specifications Breakdown
                              const Text(
                                'CHARGING SPECIFICATIONS',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white),
                              ),
                              const SizedBox(height: 12),
                              GlassContainer(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    _buildSpecRow('Model Variant', selectedVehicle.variant),
                                    _buildSpecRow('Battery Capacity', '${selectedVehicle.batteryCapacity} kWh'),
                                    _buildSpecRow('Max DC Charge Rate', '${selectedVehicle.maxDcChargingSpeed} kW'),
                                    _buildSpecRow('Max AC Charge Rate', '${selectedVehicle.maxAcChargingSpeed} kW'),
                                    _buildSpecRow('Reg. Number', selectedVehicle.registrationNumber.isEmpty ? 'N/A' : selectedVehicle.registrationNumber),
                                    _buildSpecRow('Driving Style Profile', selectedVehicle.drivingStyle),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Remove button
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                  side: const BorderSide(color: AppColors.danger, width: 1.2),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: () {
                                  garageProvider.removeVehicle(userId, selectedVehicle.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${selectedVehicle.model} removed from garage.')),
                                  );
                                },
                                icon: const Icon(Icons.delete_outline, size: 20),
                                label: const Text('Remove Vehicle', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
    );
  }

  Widget _buildEmptyState(BuildContext context, GarageProvider garageProvider, String userId) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.card.withOpacity(0.5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10),
              ),
              child: const HugeIcon(icon: HugeIcons.strokeRoundedCar02, color: Colors.white24, size: 72),
            ),
            const SizedBox(height: 24),
            const Text('Your Garage is Empty', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Add your EV to unlock live range parameters,\nSOH status dials, and fast charge estimations.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showAddVehicleSheet(context, garageProvider, userId),
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text('Add My First Vehicle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, List<List<dynamic>> icon, Color color) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(icon: icon, color: color, size: 24),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

