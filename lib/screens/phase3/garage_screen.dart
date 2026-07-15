import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/garage_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';

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
      context.read<GarageProvider>().fetchGarage(auth.user?.id ?? 'guest');
    });
  }

  @override
  Widget build(BuildContext context) {
    final garageProvider = context.watch<GarageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My EV Garage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Vehicle',
            onPressed: () => _showAddVehicleModal(context, garageProvider),
          ),
        ],
      ),
      body: garageProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : garageProvider.vehicles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car, size: 64, color: isDark ? Colors.white24 : Colors.black26),
                      const SizedBox(height: 16),
                      Text('No vehicles in your garage.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _showAddVehicleModal(context, garageProvider),
                        child: const Text('Add Vehicle'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: garageProvider.vehicles.length,
                  itemBuilder: (context, index) {
                    final vehicle = garageProvider.vehicles[index];
                    final isSelected = vehicle.id == garageProvider.selectedVehicle?.id;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: GestureDetector(
                        onTap: () {
                          garageProvider.selectVehicle(vehicle);
                        },
                        child: Container(
                          decoration: isSelected 
                            ? BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppColors.primaryCyan, width: 2),
                              ) 
                            : null,
                          child: GlassContainer(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                            children: [
                              Container(
                                width: 80,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white12 : Colors.black12,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.directions_car, size: 40),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${vehicle.manufacturer} ${vehicle.model}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text('${vehicle.batteryCapacity} kWh • ${vehicle.realRange} km range', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
                                    if (vehicle.isDefault)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryPurple.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('Default', style: TextStyle(fontSize: 10, color: AppColors.primaryPurple)),
                                      ),
                                  ],
                                ),
                              ),
                                if (isSelected)
                                  const Icon(Icons.check_circle, color: AppColors.primaryCyan),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _showAddVehicleModal(BuildContext context, GarageProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassContainer(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select from Indian EV Database', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: provider.ecosystemVehicles.length,
                itemBuilder: (context, index) {
                  final v = provider.ecosystemVehicles[index];
                  return ListTile(
                    leading: const Icon(Icons.electric_car, color: AppColors.primaryCyan),
                    title: Text('${v.manufacturer} ${v.model}'),
                    subtitle: Text(v.variant),
                    onTap: () {
                      final auth = context.read<AuthProvider>();
                      // Create a new instance for garage
                      final newVehicle = v.copyWith(
                        id: 'garage_${DateTime.now().millisecondsSinceEpoch}',
                        userId: auth.user?.id ?? 'guest',
                        isDefault: provider.vehicles.isEmpty, // First vehicle is default
                      );
                      provider.addVehicle(auth.user?.id ?? 'guest', newVehicle);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
