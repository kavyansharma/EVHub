import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/maps_provider.dart';

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
        infoWindow: InfoWindow(title: m.title, snippet: m.description),
        icon: BitmapDescriptor.defaultMarkerWithHue(
            m.type.name == 'station' ? BitmapDescriptor.hueCyan : BitmapDescriptor.hueViolet),
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
                  // Apply a dark theme JSON string here if desired
                  // controller.setMapStyle(_darkMapStyle);
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
}
