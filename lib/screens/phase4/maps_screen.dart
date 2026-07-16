import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../providers/maps_provider.dart';
import '../../core/constants/map_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
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
  bool _trafficEnabled = true;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MapsProvider>().fetchCurrentLocationAndStations().then((_) {
        _recenterCamera();
      });
    });
  }

  void _recenterCamera() {
    final mapsProvider = context.read<MapsProvider>();
    if (_mapController != null && mapsProvider.currentLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              mapsProvider.currentLocation!['latitude']!,
              mapsProvider.currentLocation!['longitude']!,
            ),
            zoom: 14.0,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapsProvider = context.watch<MapsProvider>();

    // Apply quick filters
    List<MapMarkerModel> filteredMarkers = mapsProvider.markers;
    if (_selectedFilter == 'Fast (50kW+)') {
      filteredMarkers = filteredMarkers.where((m) {
        final power = double.tryParse(m.power.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        return power >= 50.0;
      }).toList();
    } else if (_selectedFilter == 'Available') {
      filteredMarkers = filteredMarkers.where((m) {
        final available = int.tryParse(m.availableStalls.split('/')[0]) ?? 0;
        return available > 0;
      }).toList();
    } else if (_selectedFilter != 'All') {
      filteredMarkers = filteredMarkers.where((m) => m.network.toLowerCase().contains(_selectedFilter.toLowerCase())).toList();
    }

    final Set<Marker> mapMarkers = filteredMarkers.map((m) {
      // Determine charger hue based on power or availability
      double hue = BitmapDescriptor.hueCyan;
      if (m.network.contains('Tata')) hue = BitmapDescriptor.hueAzure;
      if (m.network.contains('Statiq')) hue = BitmapDescriptor.hueOrange;
      if (m.network.contains('Jio')) hue = BitmapDescriptor.hueViolet;

      return Marker(
        markerId: MarkerId(m.id),
        position: LatLng(m.latitude, m.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: m.title,
          snippet: '${m.network} • ${m.power} • ${m.availableStalls} stalls',
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChargerDetailsScreen(marker: m),
            ),
          );
        },
      );
    }).toSet();

    final CameraPosition initialCameraPosition = CameraPosition(
      target: LatLng(
        mapsProvider.currentLocation?['latitude'] ?? 28.6304,
        mapsProvider.currentLocation?['longitude'] ?? 77.2177,
      ),
      zoom: 14.0,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Google Map background
          mapsProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  initialCameraPosition: initialCameraPosition,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (_mapType == MapType.normal) {
                      controller.setMapStyle(MapConstants.darkMapStyle);
                    }
                  },
                  markers: mapMarkers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                  trafficEnabled: _trafficEnabled,
                  mapType: _mapType,
                ),

          // Header Glass Console overlay (Search & Quick Filters)
          Positioned(
            top: 24,
            left: 20,
            right: 20,
            child: SafeArea(
              child: Column(
                children: [
                  // Search Bar
                  GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    borderRadius: 20,
                    child: Row(
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedSearch01,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: TextField(
                            style: TextStyle(color: Colors.white, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: 'Search EV charging stations...',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              filled: false,
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          color: Colors.white10,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedFilter,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Quick Filters Carousel
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildFilterChip('All'),
                        _buildFilterChip('Available'),
                        _buildFilterChip('Fast (50kW+)'),
                        _buildFilterChip('Tata Power'),
                        _buildFilterChip('Statiq'),
                        _buildFilterChip('Jio-bp'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Map Control Panels (Right Float Console)
          Positioned(
            bottom: 40,
            right: 20,
            child: Column(
              children: [
                 _buildMapControlBtn(
                  icon: HugeIcons.strokeRoundedSatellite,
                  isActive: _mapType == MapType.satellite,
                  onTap: () {
                    setState(() {
                      _mapType = _mapType == MapType.normal
                          ? MapType.satellite
                          : MapType.normal;
                    });
                    if (_mapController != null) {
                      if (_mapType == MapType.normal) {
                        _mapController!.setMapStyle(MapConstants.darkMapStyle);
                      } else {
                        _mapController!.setMapStyle(null);
                      }
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildMapControlBtn(
                  icon: HugeIcons.strokeRoundedRoadLocation01,
                  isActive: _trafficEnabled,
                  onTap: () {
                    setState(() {
                      _trafficEnabled = !_trafficEnabled;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _buildMapControlBtn(
                  icon: HugeIcons.strokeRoundedLocation01,
                  isActive: true,
                  onTap: _recenterCamera,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = label;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.card.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.08),
              width: 1.2,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapControlBtn({
    required List<List<dynamic>> icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.card.withOpacity(0.8),
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.white.withOpacity(0.08),
            width: 1.2,
          ),
          boxShadow: AppColors.softShadow(),
        ),
        child: Center(
          child: HugeIcon(
            icon: icon,
            color: isActive ? AppColors.primary : Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

