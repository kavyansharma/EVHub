import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/premium_button.dart';
import '../../providers/charging_session_provider.dart';

class LiveChargingScreen extends StatefulWidget {
  const LiveChargingScreen({super.key});

  @override
  State<LiveChargingScreen> createState() => _LiveChargingScreenState();
}

class _LiveChargingScreenState extends State<LiveChargingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandColor = theme.colorScheme.primary;
    final chargingProvider = context.watch<ChargingSessionProvider>();
    final session = chargingProvider.activeSession;

    if (session == null) {
      return _buildNoActiveSession(context, brandColor);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Live Charging Session'),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.success.withOpacity(0.2),
              AppColors.background,
            ],
            stops: const [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              
              // 3D Glowing Battery Visualization
              Center(
                child: ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success.withOpacity(0.1),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withOpacity(0.3),
                          blurRadius: 40,
                          spreadRadius: 20,
                        )
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: session.batteryPercentage / 100,
                          strokeWidth: 12,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          color: AppColors.success,
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${session.batteryPercentage.toInt()}%',
                              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const Text(
                              'Charged',
                              style: TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 60),
              
              // Live Data Panel
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.glassFill(theme.brightness),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                    border: Border(top: BorderSide(color: AppColors.success.withOpacity(0.3), width: 1.5)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildDataWidget('Power', '${session.currentKw} kW', Icons.bolt, Colors.orange),
                          _buildDataWidget('Added', '${session.unitsConsumed.toStringAsFixed(1)} kWh', Icons.battery_charging_full, AppColors.success),
                          _buildDataWidget('Cost', '₹${session.currentCost.toStringAsFixed(0)}', Icons.currency_rupee, Colors.blue),
                        ],
                      ),
                      const SizedBox(height: 32),
                      
                      // Progress Bar
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Est. Time Remaining', style: TextStyle(color: Colors.grey)),
                              Text('${session.estimatedFinishTimeMinutes} mins', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: session.batteryPercentage / 100,
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            color: AppColors.success,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                      
                      const Spacer(),
                      
                      PremiumButton(
                        text: 'Stop Charging',
                        icon: Icons.stop_rounded,
                        isPrimary: true, // Need to make red? We'll let primary handle it or override
                        onPressed: () => chargingProvider.stopSession(),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildNoActiveSession(BuildContext context, Color brandColor) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Charging Dashboard'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.ev_station_outlined, size: 100, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 24),
            const Text('No Active Charging Session', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Scan a QR code or tap a charger on the map to begin.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: brandColor,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              onPressed: () {},
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              label: const Text('Scan QR to Charge', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataWidget(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 12),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
