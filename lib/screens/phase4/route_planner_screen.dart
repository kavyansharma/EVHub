import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/premium_button.dart';

class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  final TextEditingController _startController = TextEditingController(text: 'Connaught Place, Delhi');
  final TextEditingController _endController = TextEditingController();
  bool _isPlanning = false;
  bool _routePlanned = false;

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _planRoute() async {
    if (_endController.text.isEmpty) return;
    
    setState(() => _isPlanning = true);
    // Simulate AI routing calculation
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isPlanning = false;
        _routePlanned = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandColor = theme.colorScheme.primary;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Smart Route Planner', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              brandColor.withOpacity(0.15),
              AppColors.background,
            ],
            stops: const [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildInputSection(brandColor),
              
              if (_isPlanning)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Calculating topography & battery drain...', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              else if (_routePlanned)
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTripSummary(brandColor),
                        const SizedBox(height: 32),
                        const Text('Recommended Charging Stops', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _buildChargingStopsTimeline(brandColor),
                        const SizedBox(height: 32),
                        PremiumButton(
                          text: 'Start Navigation',
                          icon: Icons.navigation,
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.route, size: 100, color: Colors.white12),
                        const SizedBox(height: 24),
                        const Text('Enter destination to plan your trip', style: TextStyle(color: Colors.grey, fontSize: 16)),
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

  Widget _buildInputSection(Color brandColor) {
    return GlassContainer(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Column(
                children: [
                  const Icon(Icons.my_location, color: Colors.blue, size: 20),
                  const SizedBox(height: 4),
                  Container(height: 30, width: 2, color: Colors.grey),
                  const SizedBox(height: 4),
                  const Icon(Icons.location_on, color: Colors.red, size: 20),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    TextField(
                      controller: _startController,
                      decoration: const InputDecoration(
                        hintText: 'Start Location',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                    const Divider(height: 32, color: Colors.grey),
                    TextField(
                      controller: _endController,
                      decoration: const InputDecoration(
                        hintText: 'Where to?',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onSubmitted: (_) => _planRoute(),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.swap_vert),
                onPressed: () {
                  final temp = _startController.text;
                  _startController.text = _endController.text;
                  _endController.text = temp;
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: PremiumButton(
              text: 'Plan Trip',
              icon: Icons.electric_bolt,
              isPrimary: false,
              onPressed: _planRoute,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripSummary(Color brandColor) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Trip Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: brandColor.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Text('AI Optimized', style: TextStyle(color: brandColor, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Distance', '345 km', Icons.route, Colors.blue),
              _buildSummaryItem('Est. Time', '5h 30m', Icons.timer, Colors.orange),
              _buildSummaryItem('Battery Use', '82%', Icons.battery_charging_full, AppColors.success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildChargingStopsTimeline(Color brandColor) {
    final stops = [
      {'name': 'Statiq Fast Charger, Panipat', 'power': '120kW', 'time': '25 mins', 'cost': '₹450', 'charge': '20% → 80%'},
      {'name': 'Tata Power EZ, Ambala', 'power': '60kW', 'time': '15 mins', 'cost': '₹200', 'charge': '40% → 65%'},
    ];

    return Column(
      children: List.generate(stops.length, (index) {
        final stop = stops[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: brandColor.withOpacity(0.2), shape: BoxShape.circle),
                    child: Center(child: Text('${index + 1}', style: TextStyle(color: brandColor, fontWeight: FontWeight.bold))),
                  ),
                  if (index != stops.length - 1)
                    Container(height: 60, width: 2, color: brandColor.withOpacity(0.3)),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stop['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.bolt, color: Colors.orange, size: 16),
                              Text('${stop['power']} • ${stop['time']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                          Text(stop['charge']!, style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
