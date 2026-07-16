import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/vehicle_model.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/charging_session_provider.dart';
import '../../providers/garage_provider.dart';
import '../../providers/maps_provider.dart';
import '../ai/ai_assistant_screen.dart';
import '../phase4/route_planner_screen.dart';
import '../phase4/charger_details_screen.dart';
import '../charging/live_charging_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _getVehicleImage(String? model) {
    if (model == null) return 'https://images.unsplash.com/photo-1619767886558-efdc259cde1a?auto=format&fit=crop&w=800&q=80';
    final m = model.toLowerCase();
    if (m.contains('nexon')) return 'https://images.unsplash.com/photo-1619767886558-efdc259cde1a?auto=format&fit=crop&w=800&q=80';
    if (m.contains('windsor') || m.contains('zs')) return 'https://images.unsplash.com/photo-1606016159991-dfe4f2746ad5?auto=format&fit=crop&w=800&q=80';
    if (m.contains('atto') || m.contains('seal')) return 'https://images.unsplash.com/photo-1681283620953-73c38db5dfc8?auto=format&fit=crop&w=800&q=80';
    if (m.contains('xuv')) return 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=800&q=80';
    if (m.contains('ioniq')) return 'https://images.unsplash.com/photo-1669062508887-21be148970e5?auto=format&fit=crop&w=800&q=80';
    return 'https://images.unsplash.com/photo-1619767886558-efdc259cde1a?auto=format&fit=crop&w=800&q=80';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final walletProvider = context.watch<WalletProvider>();
    final chargingProvider = context.watch<ChargingSessionProvider>();
    final garageProvider = context.watch<GarageProvider>();
    final mapsProvider = context.watch<MapsProvider>();

    final user = authProvider.user;
    final primaryVehicle = garageProvider.selectedVehicle ?? 
        (garageProvider.vehicles.isNotEmpty ? garageProvider.vehicles.first : null);

    final hasActiveSession = chargingProvider.activeSession != null;
    final brandColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(
                user?.avatarUrl ?? 'https://i.pravatar.cc/150?img=11',
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Good Morning,',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
                Text(
                  user?.name ?? 'EV Driver',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedNotification01, color: Colors.white, size: 22),
            onPressed: () {},
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          // Ambient Background Top Glow Halo
          Positioned(
            top: -120,
            left: MediaQuery.of(context).size.width / 4,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: brandColor.withOpacity(0.08),
                boxShadow: [
                  BoxShadow(color: brandColor.withOpacity(0.12), blurRadius: 100, spreadRadius: 60)
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Immersive Active Vehicle Frame
                  _buildImmersiveVehicleFrame(context, primaryVehicle, hasActiveSession, chargingProvider),
                  const SizedBox(height: 24),

                  // 2. Wallet & Financial Gradient Console
                  _buildGradientWalletConsole(context, walletProvider, brandColor),
                  const SizedBox(height: 24),

                  // 3. AI Assistant & Trips Navigation Console
                  _buildNavigationConsole(context, brandColor),
                  const SizedBox(height: 24),

                  // 4. Nearest Charger Preview
                  _buildNearestChargerPreview(context, mapsProvider),
                  const SizedBox(height: 24),

                  // 5. Recent Sessions Logs
                  _buildRecentSessionsLogs(context, brandColor),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImmersiveVehicleFrame(
    BuildContext context,
    VehicleModel? vehicle,
    bool hasActiveSession,
    ChargingSessionProvider chargingProvider,
  ) {
    if (vehicle == null) {
      return GlassContainer(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.directions_car, color: AppColors.textSecondary, size: 48),
            const SizedBox(height: 12),
            const Text(
              'No Connected Vehicle Found',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 4),
            const Text(
              'Go to the Garage tab to configure your EV variant.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final batteryPct = hasActiveSession
        ? chargingProvider.activeSession!.batteryPercentage
        : (vehicle.currentBatteryPct);
    final range = hasActiveSession
        ? (chargingProvider.activeSession!.batteryPercentage * vehicle.realRange / 100.0).toInt()
        : (vehicle.currentBatteryPct * vehicle.realRange / 100.0).toInt();

    final vehicleImage = _getVehicleImage(vehicle.model);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Radial Glow underneath vehicle
            Positioned(
              bottom: 10,
              child: Container(
                width: 240,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: hasActiveSession ? AppColors.secondary.withOpacity(0.3) : AppColors.primary.withOpacity(0.15),
                      blurRadius: 40,
                      spreadRadius: 8,
                    )
                  ],
                ),
              ),
            ),
            // Car Render
            GestureDetector(
              onTap: () {
                if (hasActiveSession) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveChargingScreen()));
                }
              },
              child: Hero(
                tag: 'vehicle_${vehicle.id}',
                child: Image.network(
                  vehicleImage,
                  height: 150,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Health / SoC parameters dashboard
        GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${vehicle.manufacturer} ${vehicle.model}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasActiveSession ? '⚡ Fast Charging Session Active' : 'Connected • Status Idle',
                    style: TextStyle(
                      color: hasActiveSession ? AppColors.secondary : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: hasActiveSession ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${batteryPct.toInt()}% SoC',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '~ $range km range',
                    style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGradientWalletConsole(BuildContext context, WalletProvider wallet, Color brandColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.walletGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.neonShadow(color: AppColors.accent, blurRadius: 20),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'UNIVERSAL WALLET BALANCE',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              Icon(Icons.payment, color: Colors.white70, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '₹${wallet.balance.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    final auth = context.read<AuthProvider>();
                    wallet.topUp(auth.user?.id ?? 'default_user', 500.0);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Added ₹500.00 successfully!'), backgroundColor: AppColors.secondary),
                    );
                  },
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'Top Up +₹500',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Initiating EV charging scan...')),
                    );
                  },
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Scan & Pay',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationConsole(BuildContext context, Color brandColor) {
    return Row(
      children: [
        // AI assistant
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIAssistantScreen())),
            child: GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: brandColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: HugeIcon(icon: HugeIcons.strokeRoundedBot, color: brandColor, size: 20),
                  ),
                  const SizedBox(height: 16),
                  const Text('AI assistant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                  const SizedBox(height: 2),
                  const Text('Ask EV queries, health SOH specs', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Smart routing
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoutePlannerScreen())),
            child: GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: HugeIcon(icon: HugeIcons.strokeRoundedRoute01, color: AppColors.accent, size: 20),
                  ),
                  const SizedBox(height: 16),
                  const Text('AI Trip Router', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                  const SizedBox(height: 2),
                  const Text('Plan route with battery elevations', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNearestChargerPreview(BuildContext context, MapsProvider mapsProvider) {
    final stations = mapsProvider.markers;
    if (stations.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Sort and pick nearest station (first marker from coordinates seed)
    final nearest = stations.first;

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NEAREST CHARGER PREVIEW',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 1.2),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(icon: HugeIcons.strokeRoundedFuelStation, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nearest.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${nearest.network} • ${nearest.power} • ${nearest.availableStalls} stalls',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 24, thickness: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Connaught Place, Delhi', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChargerDetailsScreen(marker: nearest),
                    ),
                  );
                },
                child: const Row(
                  children: [
                    Text(
                      'View Details',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: AppColors.primary, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSessionsLogs(BuildContext context, Color brandColor) {
    final logs = [
      {'title': 'Tata Power EZ, Delhi', 'units': '34.5 kWh', 'cost': '₹724.50', 'date': 'Yesterday, 3:30 PM'},
      {'title': 'Statiq Hub, CyberHub', 'units': '45.2 kWh', 'cost': '₹949.20', 'date': '12 July, 9:20 AM'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'RECENT SESSIONS',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
            ),
            TextButton(
              onPressed: () {},
              child: Text('See All', style: TextStyle(color: brandColor, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Column(
          children: logs.map((log) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: GlassContainer(
                padding: const EdgeInsets.all(16),
                borderRadius: 18,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        shape: BoxShape.circle,
                      ),
                      child: HugeIcon(icon: HugeIcons.strokeRoundedBatteryCharging02, color: AppColors.secondary, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(log['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text('${log['date']} • ${log['units']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                    Text(
                      log['cost']!,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

