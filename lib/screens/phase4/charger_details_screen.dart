import 'package:flutter/material.dart';
import '../../models/map_marker_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/premium_button.dart';

class ChargerDetailsScreen extends StatelessWidget {
  final MapMarkerModel marker;

  const ChargerDetailsScreen({super.key, required this.marker});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandColor = theme.colorScheme.primary;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Image
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: brandColor.withOpacity(0.1),
                image: const DecorationImage(
                  image: NetworkImage('https://images.unsplash.com/photo-1593941707882-a5bba14938cb?auto=format&fit=crop&w=800&q=80'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, AppColors.background.withOpacity(0.8), AppColors.background],
                  ),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: brandColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          marker.network,
                          style: TextStyle(color: brandColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.orange, size: 20),
                          const SizedBox(width: 4),
                          Text('${marker.rating} (${marker.title.length * 12} reviews)', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(marker.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(marker.description, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                  
                  const SizedBox(height: 32),
                  const Text('Charger Status', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(child: _buildStatusCard('Available', marker.availableStalls, Icons.ev_station, Colors.green)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatusCard('Power', marker.power, Icons.bolt, Colors.orange)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatusCard('Price', '₹18/kWh', Icons.currency_rupee, Colors.blue)),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  const Text('Connector Types', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.electrical_services, size: 40, color: Colors.grey),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('CCS2 (DC Fast)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Text('Up to 150kW', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Available', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  PremiumButton(
                    text: 'Book Slot',
                    icon: Icons.book_online,
                    onPressed: () {},
                  ),
                  const SizedBox(height: 16),
                  PremiumButton(
                    text: 'Navigate',
                    icon: Icons.directions,
                    isPrimary: false,
                    onPressed: () {},
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String title, String value, IconData icon, Color color) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
