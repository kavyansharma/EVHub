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
  MapType _mapType = MapType.normal;

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
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChargerDetailsScreen(marker: m)),
            );
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
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: initialCameraPosition,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (isDark && _mapType == MapType.normal) {
                      controller.setMapStyle(MapConstants.darkMapStyle);
                    }
                  },
                  markers: mapMarkers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                  compassEnabled: true,
                  trafficEnabled: true,
                  mapType: _mapType,
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'mapTypeBtn',
                    backgroundColor: Theme.of(context).cardColor,
                    child: Icon(
                      _mapType == MapType.normal ? Icons.satellite : Icons.map,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    onPressed: () {
                      setState(() {
                        _mapType = _mapType == MapType.normal ? MapType.satellite : MapType.normal;
                      });
                      if (_mapController != null) {
                        if (isDark && _mapType == MapType.normal) {
                          _mapController!.setMapStyle(MapConstants.darkMapStyle);
                        } else {
                          _mapController!.setMapStyle(null);
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
    );
  }

}
