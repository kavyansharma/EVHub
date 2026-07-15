import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/maps_provider.dart';
import '../../core/constants/map_constants.dart';
import '../../models/map_marker_model.dart';
import 'charger_details_screen.dart';

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MapsProvider>().fetchCurrentLocationAndStations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mapsProvider = context.watch<MapsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final CameraPosition initialCameraPosition = CameraPosition(
      target: LatLng(
        mapsProvider.currentLocation?['latitude'] ?? 28.6139,
        mapsProvider.currentLocation?['longitude'] ?? 77.2090, // Delhi Default
      ),
      zoom: 14.0,
    );

    final Set<Marker> mapMarkers = mapsProvider.markers.map((m) {
      return Marker(
        markerId: MarkerId(m.id),
        position: LatLng(m.latitude, m.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
            m.type.name == 'station' ? BitmapDescriptor.hueCyan : BitmapDescriptor.hueViolet),
        onTap: () {
          if (m.type.name == 'station') {
            _showStationDetails(context, m);
          }
        },
      );
    }).toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Charging Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (_mapController != null && mapsProvider.currentLocation != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newLatLng(
                    LatLng(
                      mapsProvider.currentLocation!['latitude']!,
                      mapsProvider.currentLocation!['longitude']!,
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: mapsProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: initialCameraPosition,
              onMapCreated: (controller) {
                _mapController = controller;
                if (isDark) {
                  controller.setMapStyle(MapConstants.darkMapStyle);
                }
              },
              markers: mapMarkers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              trafficEnabled: true,
            ),
    );
  }

  void _showStationDetails(BuildContext context, MapMarkerModel marker) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.4,
          maxChildSize: 0.8,
          minChildSize: 0.3,
          builder: (_, controller) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                        child: Text(
                          marker.network.substring(0, 1).toUpperCase(),
                          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(marker.network, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(marker.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(marker.description, style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildInfoChip('Available', marker.availableStalls, Icons.ev_station, Colors.green),
                      _buildInfoChip('Rating', marker.rating.toString(), Icons.star, Colors.orange),
                      _buildInfoChip('Power', marker.power, Icons.bolt, Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Nearby Amenities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 4, // Mock
                      itemBuilder: (context, index) {
                        return Container(
                          width: 140,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(index % 2 == 0 ? Icons.restaurant : Icons.local_cafe, color: Colors.orangeAccent),
                              const SizedBox(height: 8),
                              Text(index % 2 == 0 ? 'Food Court' : 'Cafe', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const Text('200m away', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.directions),
                    label: const Text('Navigate'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      side: BorderSide(color: Theme.of(context).colorScheme.primary),
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Close bottom sheet
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChargerDetailsScreen(marker: marker)));
                    },
                    icon: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                    label: Text('View Full Details', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
