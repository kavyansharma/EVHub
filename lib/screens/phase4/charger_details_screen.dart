import 'package:flutter/material.dart';
import '../../models/map_marker_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/premium_button.dart';
import '../../services/places_service.dart';

class ChargerDetailsScreen extends StatefulWidget {
  final MapMarkerModel marker;

  const ChargerDetailsScreen({super.key, required this.marker});

  @override
  State<ChargerDetailsScreen> createState() => _ChargerDetailsScreenState();
}

class _ChargerDetailsScreenState extends State<ChargerDetailsScreen> {
  final PlacesService _placesService = PlacesService();
  List<PlaceModel> _places = [];
  bool _isLoadingPlaces = true;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    final places = await _placesService.getNearbyPlaces(widget.marker.latitude, widget.marker.longitude);
    if (mounted) {
      setState(() {
        _places = places;
        _isLoadingPlaces = false;
      });
    }
  }

  String _getHeroImage(String network) {
    if (network.toLowerCase().contains('tata')) return 'https://images.unsplash.com/photo-1593941707882-a5bba14938cb?auto=format&fit=crop&w=800&q=80';
    if (network.toLowerCase().contains('statiq')) return 'https://images.unsplash.com/photo-1620891549027-942fdc95d3f5?auto=format&fit=crop&w=800&q=80';
    if (network.toLowerCase().contains('jio')) return 'https://images.unsplash.com/photo-1617783921319-7977eb780131?auto=format&fit=crop&w=800&q=80';
    return 'https://images.unsplash.com/photo-1593941707882-a5bba14938cb?auto=format&fit=crop&w=800&q=80'; // Default
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandColor = theme.colorScheme.primary;
    final marker = widget.marker;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
          child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
            child: IconButton(icon: const Icon(Icons.favorite_border, color: Colors.white), onPressed: () {}),
          ),
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
            child: IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () {}),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120), // Space for bottom action bar
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero Image
                Container(
                  height: 350,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(_getHeroImage(marker.network)),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black54, Colors.transparent, AppColors.background.withOpacity(0.9), AppColors.background],
                        stops: const [0.0, 0.3, 0.8, 1.0],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: brandColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(marker.network, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.orange, size: 16),
                                    const SizedBox(width: 4),
                                    Text('${marker.rating}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(marker.title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, height: 1.1, color: Colors.white)),
                          const SizedBox(height: 8),
                          Text(marker.description, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Key Stats Row
                      Row(
                        children: [
                          Expanded(child: _buildStatusCard('Available', marker.availableStalls, Icons.ev_station, Colors.greenAccent)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildStatusCard('Power', marker.power, Icons.bolt, brandColor)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildStatusCard('Price', '₹18/U', Icons.currency_rupee, Colors.white)),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      const Text('Connector Types', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      GlassContainer(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.electrical_services, size: 40, color: Colors.white70),
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
                                color: Colors.greenAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text('Available', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      const Text('Nearby Amenities', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _buildAmenitiesCarousel(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Fixed Bottom Action Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [AppColors.background, AppColors.background.withOpacity(0.0)],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: PremiumButton(
                      text: 'Navigate',
                      icon: Icons.directions,
                      isPrimary: false,
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: PremiumButton(
                      text: 'Book Slot',
                      icon: Icons.bolt,
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String title, String value, IconData icon, Color color) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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

  Widget _buildAmenitiesCarousel() {
    if (_isLoadingPlaces) {
      return const SizedBox(height: 140, child: Center(child: CircularProgressIndicator()));
    }
    
    if (_places.isEmpty) {
      return const Text('No amenities found nearby.', style: TextStyle(color: Colors.grey));
    }

    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _places.length,
        itemBuilder: (context, index) {
          final place = _places[index];
          IconData icon;
          if (place.type == 'restaurant') icon = Icons.restaurant;
          else if (place.type == 'cafe') icon = Icons.local_cafe;
          else if (place.type == 'shopping_mall') icon = Icons.shopping_bag;
          else if (place.type == 'washroom') icon = Icons.wc;
          else if (place.type == 'atm') icon = Icons.local_atm;
          else icon = Icons.hotel;
          
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              image: DecorationImage(
                image: NetworkImage(place.imageUrl),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                    child: Icon(icon, color: Colors.white, size: 16),
                  ),
                  const Spacer(),
                  Text(
                    place.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${place.distance.toInt()}m away', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.orange, size: 12),
                          Text('${place.rating.toStringAsFixed(1)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
