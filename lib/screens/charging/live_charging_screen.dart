import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../providers/charging_session_provider.dart';
import '../../providers/garage_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import 'dart:math' as math;

class LiveChargingScreen extends StatefulWidget {
  const LiveChargingScreen({super.key});

  @override
  State<LiveChargingScreen> createState() => _LiveChargingScreenState();
}

class _LiveChargingScreenState extends State<LiveChargingScreen> with TickerProviderStateMixin {
  late AnimationController _flowController;
  late AnimationController _pulseController;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _flowController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

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
    final sessionProvider = context.watch<ChargingSessionProvider>();
    final garageProvider = context.watch<GarageProvider>();
    final session = sessionProvider.activeSession;
    final primaryVehicle = garageProvider.selectedVehicle ?? 
        (garageProvider.vehicles.isNotEmpty ? garageProvider.vehicles.first : null);

    if (session == null) {
      return _buildNoActiveSession(context);
    }

    final batteryPercentage = session.batteryPercentage;
    final vehicleImg = _getVehicleImage(primaryVehicle?.model);

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('CHARGING CONSOLE', style: TextStyle(letterSpacing: 2.0, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background ambient glows
          Positioned(
            top: 100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.05),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 100, spreadRadius: 50)
                ],
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Large Vehicle Render & Charging Port Particle Flow
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glow underneath the car
                      Positioned(
                        bottom: 40,
                        child: Container(
                          width: 260,
                          height: 40,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: _isPaused ? AppColors.warning.withOpacity(0.15) : AppColors.secondary.withOpacity(0.3),
                                blurRadius: 40,
                                spreadRadius: 10,
                              )
                            ],
                          ),
                        ),
                      ),
                      // Vehicle Image
                      Container(
                        height: 180,
                        margin: const EdgeInsets.only(bottom: 20),
                        child: Hero(
                          tag: 'vehicle_${primaryVehicle?.id ?? 'default'}',
                          child: Image.network(
                            vehicleImg,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      // Animated Electricity Flow Overlay
                      if (!_isPaused)
                        Positioned(
                          right: 30,
                          bottom: 50,
                          child: AnimatedBuilder(
                            animation: _flowController,
                            builder: (context, child) {
                              return CustomPaint(
                                size: const Size(120, 40),
                                painter: ElectricityFlowPainter(
                                  progress: _flowController.value,
                                  flowColor: AppColors.secondary,
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),

                  // 2. Battery Percentage Gauge
                  GlassContainer(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        // Radial progress ring
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: batteryPercentage / 100.0,
                                strokeWidth: 10,
                                backgroundColor: Colors.white.withOpacity(0.04),
                                color: _isPaused ? AppColors.warning : AppColors.secondary,
                                strokeCap: StrokeCap.round,
                              ),
                              Center(
                                child: Text(
                                  '${batteryPercentage.toInt()}%',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                primaryVehicle?.model ?? 'Tata Nexon EV',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    _isPaused ? Icons.pause_circle_outline : Icons.flash_on,
                                    size: 14,
                                    color: _isPaused ? AppColors.warning : AppColors.secondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isPaused ? 'Charging Paused' : 'Fast Charging...',
                                    style: TextStyle(
                                      color: _isPaused ? AppColors.warning : AppColors.secondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${session.estimatedFinishTimeMinutes} mins remaining',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Live Tech Metrics Panel
                  Row(
                    children: [
                      Expanded(child: _buildParameterItem('POWER', '${_isPaused ? 0.0 : session.currentKw}', 'kW', AppColors.primary)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildParameterItem('ADDED', session.unitsConsumed.toStringAsFixed(1), 'kWh', AppColors.secondary)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildParameterItem('COST', '₹${session.currentCost.toStringAsFixed(0)}', 'INR', Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildParameterItem('CURRENT', _isPaused ? '0.0' : '150.2', 'A', AppColors.accent)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildParameterItem('VOLTAGE', _isPaused ? '0.0' : '398.5', 'V', AppColors.accent)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildParameterItem('TEMP', '34.5', '°C', AppColors.warning)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4. Energy Input Live Graph
                  GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LIVE POWER OUTFLOW',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1.0),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 120,
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(show: false),
                              titlesData: FlTitlesData(show: false),
                              borderData: FlBorderData(show: false),
                              minX: 0,
                              maxX: 7,
                              minY: 0,
                              maxY: 80,
                              lineBarsData: [
                                LineChartBarData(
                                  spots: [
                                    FlSpot(0, _isPaused ? 0 : 45),
                                    FlSpot(1, _isPaused ? 0 : 50),
                                    FlSpot(2, _isPaused ? 0 : 58),
                                    FlSpot(3, _isPaused ? 0 : 57),
                                    FlSpot(4, _isPaused ? 0 : 60),
                                    FlSpot(5, _isPaused ? 0 : 59),
                                    FlSpot(6, _isPaused ? 0 : 61),
                                    FlSpot(7, _isPaused ? 0 : 60),
                                  ],
                                  isCurved: true,
                                  color: AppColors.primary,
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: AppColors.primary.withOpacity(0.1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 5. Technical Health Index
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Battery Health Index (SoH)', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '98.4% (Excellent)',
                            style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 6. Pause & Stop Buttons
                  Row(
                    children: [
                      // Pause Button
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isPaused = !_isPaused;
                            });
                          },
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _isPaused ? AppColors.warning.withOpacity(0.5) : Colors.white.withOpacity(0.08),
                                width: 1.2,
                              ),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isPaused ? Icons.play_arrow : Icons.pause,
                                    color: _isPaused ? AppColors.warning : Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isPaused ? 'Resume' : 'Pause Session',
                                    style: TextStyle(
                                      color: _isPaused ? AppColors.warning : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const SizedBox(width: 16),
                      // Stop Button
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final session = sessionProvider.activeSession;
                            final cost = session?.currentCost ?? 0.0;
                            final units = session?.unitsConsumed ?? 0.0;

                            sessionProvider.stopSession();

                            final authProvider = context.read<AuthProvider>();
                            final walletProvider = context.read<WalletProvider>();
                            final uid = authProvider.user?.id ?? 'default_user';

                            if (cost > 0) {
                              await walletProvider.deduct(
                                uid,
                                cost,
                                'EV Charging Session - ${units.toStringAsFixed(1)} kWh',
                              );
                            }

                            if (context.mounted) {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: AppColors.card,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                  title: const Row(
                                    children: [
                                      Icon(Icons.check_circle, color: AppColors.secondary, size: 24),
                                      SizedBox(width: 10),
                                      Text('Session Completed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Energy Added: ${units.toStringAsFixed(1)} kWh', style: const TextStyle(color: Colors.white, fontSize: 14)),
                                      const SizedBox(height: 6),
                                      Text('Total Cost Deducted: ₹${cost.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(height: 6),
                                      const Text('Wallet Balance Updated.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                    ],
                                  ),
                                  actions: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Done', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF4D67), Color(0xFFFF2E4C)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: AppColors.neonShadow(color: AppColors.danger, blurRadius: 15),
                            ),
                            child: const Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.stop, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Stop Charge',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoActiveSession(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('CHARGER STATUS')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.card.withOpacity(0.5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: const Icon(Icons.flash_off, size: 72, color: Colors.white24),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Active Charging Session',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Go to the Maps view to select a station\nand initiate a CCS2 DC Fast Charge.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParameterItem(String title, String value, String unit, Color glowColor) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      borderRadius: 20,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(fontSize: 10, color: glowColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class ElectricityFlowPainter extends CustomPainter {
  final double progress;
  final Color flowColor;

  ElectricityFlowPainter({required this.progress, required this.flowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = flowColor.withOpacity(0.8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height / 2);
    
    // Wave calculations
    for (double i = 0; i <= size.width; i++) {
      final y = size.height / 2 + math.sin((i / size.width * 2 * math.pi) + (progress * 2 * math.pi)) * 6;
      path.lineTo(i, y);
    }
    canvas.drawPath(path, paint);

    // Glowing particles along the wave
    final dotPaint = Paint()..color = flowColor;
    final dotX = progress * size.width;
    final dotY = size.height / 2 + math.sin((dotX / size.width * 2 * math.pi) + (progress * 2 * math.pi)) * 6;
    
    canvas.drawCircle(Offset(dotX, dotY), 4, dotPaint);
    canvas.drawCircle(Offset(dotX, dotY), 8, Paint()..color = flowColor.withOpacity(0.3));
  }

  @override
  bool shouldRepaint(covariant ElectricityFlowPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.flowColor != flowColor;
  }
}

