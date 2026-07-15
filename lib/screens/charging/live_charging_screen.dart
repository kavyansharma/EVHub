import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/premium_button.dart';
import '../../core/widgets/glass_container.dart';
import '../../providers/charging_session_provider.dart';
import 'dart:ui';
import 'dart:math' as math;

class LiveChargingScreen extends StatefulWidget {
  const LiveChargingScreen({super.key});

  @override
  State<LiveChargingScreen> createState() => _LiveChargingScreenState();
}

class _LiveChargingScreenState extends State<LiveChargingScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
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
        title: const Text('Live Charging', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          image: DecorationImage(
            image: const NetworkImage('https://images.unsplash.com/photo-1617783921319-7977eb780131?auto=format&fit=crop&w=800&q=80'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(AppColors.background.withOpacity(0.9), BlendMode.darken),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // 3D Glowing Battery Visualization
              Expanded(
                flex: 5,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glowing Aura
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width: 250 + (_pulseController.value * 30),
                            height: 250 + (_pulseController.value * 30),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.success.withOpacity(0.15),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.success.withOpacity(0.3 + (_pulseController.value * 0.2)),
                                  blurRadius: 60 + (_pulseController.value * 40),
                                  spreadRadius: 20,
                                )
                              ],
                            ),
                          );
                        },
                      ),
                      
                      // Rotating Rings
                      AnimatedBuilder(
                        animation: _rotateController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _rotateController.value * 2 * math.pi,
                            child: Container(
                              width: 280,
                              height: 280,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.success.withOpacity(0.2),
                                  width: 2,
                                  style: BorderStyle.solid,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      
                      // Progress Arc
                      SizedBox(
                        width: 240,
                        height: 240,
                        child: CircularProgressIndicator(
                          value: session.batteryPercentage / 100,
                          strokeWidth: 16,
                          backgroundColor: Colors.white.withOpacity(0.05),
                          color: AppColors.success,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      
                      // Percentage Text
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.bolt, color: AppColors.success, size: 40),
                          Text(
                            '${session.batteryPercentage.toInt()}%',
                            style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.white, height: 1.0),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${session.estimatedFinishTimeMinutes} mins remaining',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Live Data Panel
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.card.withOpacity(0.6),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                    border: Border(top: BorderSide(color: AppColors.success.withOpacity(0.4), width: 1)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildDataWidget('Power', '${session.currentKw}', 'kW', Icons.speed, Colors.orange),
                              Container(width: 1, height: 60, color: Colors.white12),
                              _buildDataWidget('Added', '${session.unitsConsumed.toStringAsFixed(1)}', 'kWh', Icons.battery_charging_full, AppColors.success),
                              Container(width: 1, height: 60, color: Colors.white12),
                              _buildDataWidget('Cost', '${session.currentCost.toStringAsFixed(0)}', 'INR', Icons.account_balance_wallet, Colors.blue),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              gradient: LinearGradient(
                                colors: [Colors.redAccent.withOpacity(0.8), Colors.red.withOpacity(0.8)],
                              ),
                              boxShadow: [
                                BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8)),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(30),
                                onTap: () => chargingProvider.stopSession(),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.stop_circle_outlined, color: Colors.white, size: 28),
                                      SizedBox(width: 12),
                                      Text('STOP CHARGING', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
            Icon(Icons.ev_station_outlined, size: 120, color: Colors.white12),
            const SizedBox(height: 24),
            const Text('No Active Session', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Connect your EV to begin charging.', style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 40),
            PremiumButton(
              text: 'Scan QR to Charge',
              icon: Icons.qr_code_scanner,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataWidget(String title, String value, String unit, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 4),
            Text(unit, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1)),
      ],
    );
  }
}
