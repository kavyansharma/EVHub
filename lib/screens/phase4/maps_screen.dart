import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/maps_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/charging_session_provider.dart';
import '../../core/constants/map_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../models/map_marker_model.dart';
import '../../services/maps_service.dart';
import '../charging/live_charging_screen.dart';
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
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  StreamSubscription<Position>? _positionSubscription;
  final MapsService _mapsService = MapsService();
  bool _isSuggestionsVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MapsProvider>();
      provider.fetchCurrentLocationAndStations().then((_) {
        _recenterCamera();
      });
    });

    // Track real device location updates live
    _positionSubscription = _mapsService.getPositionStream().listen((pos) {
      if (mounted) {
        context.read<MapsProvider>().updateLiveLocation(pos.latitude, pos.longitude);
      }
    });

    _searchFocusNode.addListener(() {
      setState(() {
        _isSuggestionsVisible = _searchFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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
            zoom: 14.5,
          ),
        ),
      );
    }
  }

  void _zoomIn() {
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  @override
  Widget build(BuildContext context) {
    final mapsProvider = context.watch<MapsProvider>();

    // Build custom markers
    final Set<Marker> mapMarkers = mapsProvider.getFilteredMarkers().map((m) {
      double hue = BitmapDescriptor.hueCyan;
      if (m.status == MarkerStatus.busy) {
        hue = BitmapDescriptor.hueOrange;
      } else if (m.status == MarkerStatus.offline) {
        hue = BitmapDescriptor.hueRed;
      }

      return Marker(
        markerId: MarkerId(m.id),
        position: LatLng(m.latitude, m.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        onTap: () {
          mapsProvider.setSelectedMarker(m);
        },
      );
    }).toSet();

    // Directions routing polyline overlay
    final Set<Polyline> polylines = {};
    if (mapsProvider.routePoints.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('directions_route'),
          points: mapsProvider.routePoints,
          color: AppColors.primary,
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    }

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
          // Full Screen Google Map
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: initialCameraPosition,
              onMapCreated: (controller) {
                _mapController = controller;
                if (_mapType == MapType.normal) {
                  controller.setMapStyle(MapConstants.darkMapStyle);
                }
              },
              markers: mapMarkers,
              polylines: polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: true,
              trafficEnabled: _trafficEnabled,
              mapType: _mapType,
              onTap: (_) {
                // Clicking on empty map area resets selected card
                mapsProvider.setSelectedMarker(null);
                mapsProvider.clearRoute();
                _searchFocusNode.unfocus();
              },
            ),
          ),

          // Header Glass Overlay: Autocomplete Search Console & Chips
          Positioned(
            top: 24,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Column(
                children: [
                  // Top Search Console
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
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                            decoration: const InputDecoration(
                              hintText: 'Search city, area, network...',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              filled: false,
                            ),
                            onChanged: (val) {
                              mapsProvider.searchSuggestions(val);
                            },
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              mapsProvider.searchSuggestions('');
                            },
                          ),
                        Container(width: 1, height: 24, color: Colors.white10, margin: const EdgeInsets.symmetric(horizontal: 8)),
                        IconButton(
                          icon: const HugeIcon(icon: HugeIcons.strokeRoundedFilter, color: AppColors.textSecondary, size: 20),
                          onPressed: () => _showAdvancedFiltersModal(context, mapsProvider),
                        ),
                      ],
                    ),
                  ),

                  // Autocomplete Auto Suggestion overlay
                  if (_isSuggestionsVisible && mapsProvider.suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: GlassContainer(
                        borderRadius: 20,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: mapsProvider.suggestions.length,
                          itemBuilder: (context, idx) {
                            final sug = mapsProvider.suggestions[idx];
                            return ListTile(
                              leading: const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 18),
                              title: Text(
                                sug['description'] as String,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                _searchFocusNode.unfocus();
                                _searchController.text = sug['description'] as String;
                                mapsProvider.selectPlace(sug['place_id'] as String, (latLng) {
                                  _mapController?.animateCamera(
                                    CameraUpdate.newCameraPosition(
                                      CameraPosition(target: latLng, zoom: 15.0),
                                    ),
                                  );
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Floating Filter Chips Carousel
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildFilterBadge('CCS2', mapsProvider.selectedConnectors.contains('CCS2'), () {
                          mapsProvider.toggleConnectorFilter('CCS2');
                        }),
                        _buildFilterBadge('Fast', mapsProvider.selectedSpeeds.contains('Fast'), () {
                          mapsProvider.toggleSpeedFilter('Fast');
                        }),
                        _buildFilterBadge('Ultra Fast', mapsProvider.selectedSpeeds.contains('Ultra Fast'), () {
                          mapsProvider.toggleSpeedFilter('Ultra Fast');
                        }),
                        _buildFilterBadge('Available', mapsProvider.selectedStatusFilter == 'Available', () {
                          mapsProvider.setStatusFilter('Available');
                        }),
                        _buildFilterBadge('Tata Power', mapsProvider.selectedNetwork == 'Tata Power', () {
                          mapsProvider.setNetworkFilter('Tata Power');
                        }),
                        _buildFilterBadge('Statiq', mapsProvider.selectedNetwork == 'Statiq', () {
                          mapsProvider.setNetworkFilter('Statiq');
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Map Control Panels (Right Zoom/Recenter Float Console)
          Positioned(
            bottom: mapsProvider.selectedMarker != null ? 360 : 40,
            right: 16,
            child: Column(
              children: [
                _buildMapControlBtn(
                  icon: HugeIcons.strokeRoundedSatellite,
                  isActive: _mapType == MapType.satellite,
                  onTap: () {
                    setState(() {
                      _mapType = _mapType == MapType.normal ? MapType.satellite : MapType.normal;
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
                  icon: HugeIcons.strokeRoundedAddCircle,
                  isActive: false,
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 12),
                _buildMapControlBtn(
                  icon: HugeIcons.strokeRoundedMinusSignCircle,
                  isActive: false,
                  onTap: _zoomOut,
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

          // Google Directions route details HUD card
          if (mapsProvider.routeDistance != null)
            Positioned(
              bottom: mapsProvider.selectedMarker != null ? 340 : 20,
              left: 16,
              right: 80,
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                borderRadius: 16,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                      child: const HugeIcon(icon: HugeIcons.strokeRoundedRoute01, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ETA: ${mapsProvider.routeDuration}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Distance: ${mapsProvider.routeDistance} • Est. Battery Needed: 12%',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey, size: 16),
                      onPressed: () => mapsProvider.clearRoute(),
                    )
                  ],
                ),
              ),
            ),

          // Sliding Glassmorphic Charger Details Bottom Sheet
          if (mapsProvider.selectedMarker != null)
            _buildInteractiveBottomSheet(mapsProvider, context),
        ],
      ),
    );
  }

  // Filter Carousel Item Badge
  Widget _buildFilterBadge(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.card.withOpacity(0.4),
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
                fontSize: 11,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Right Side control console button
  Widget _buildMapControlBtn({
    required List<List<dynamic>> icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.card.withOpacity(0.85),
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
            size: 18,
          ),
        ),
      ),
    );
  }

  // Premium Tesla/Apple style sliding bottom sheet
  Widget _buildInteractiveBottomSheet(MapsProvider mapsProvider, BuildContext context) {
    final m = mapsProvider.selectedMarker!;
    final sessionProvider = context.watch<ChargingSessionProvider>();
    final activeSession = sessionProvider.activeSession;

    Color statusColor = AppColors.secondary;
    String statusText = 'Available';
    if (m.status == MarkerStatus.busy) {
      statusColor = AppColors.warning;
      statusText = 'Busy';
    } else if (m.status == MarkerStatus.offline) {
      statusColor = Colors.grey;
      statusText = 'Offline';
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.38,
      minChildSize: 0.20,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.card.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5)
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              children: [
                // Top notch bar
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),

                // Name & Brand Network Info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(m.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Specs list metrics
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSheetMetric('POWER', m.power, HugeIcons.strokeRoundedFlash, AppColors.primary),
                    _buildSheetMetric('CONNECTORS', m.availableStalls, HugeIcons.strokeRoundedFuelStation, AppColors.secondary),
                    _buildSheetMetric('RATING', m.rating.toString(), HugeIcons.strokeRoundedStar, AppColors.warning),
                    _buildSheetMetric('PRICE', m.price ?? '₹21/kWh', HugeIcons.strokeRoundedLicense, Colors.white),
                  ],
                ),
                const SizedBox(height: 24),

                // Primary action triggers
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          // Draw Directions polyline on Google Map
                          mapsProvider.calculateRoute(LatLng(m.latitude, m.longitude));
                        },
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.navigation_outlined, color: AppColors.primary, size: 18),
                                SizedBox(width: 8),
                                Text('Directions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () {
                          // If there's an active session, go directly to Live screen
                          if (activeSession != null) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveChargingScreen()));
                          } else {
                            // Start Charging sequence
                            final auth = context.read<AuthProvider>();
                            sessionProvider.startSession(
                              auth.user?.id ?? 'default_user',
                              m.id,
                              'ccs2_1',
                            );
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveChargingScreen()));
                          }
                        },
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: AppColors.chargingGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: AppColors.neonShadow(color: AppColors.primary, blurRadius: 10),
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.bolt, color: Colors.black, size: 20),
                                SizedBox(width: 8),
                                Text('Start Charging', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Google Places Nearby search lists overlay (Google Maps Style)
                const Text('NEARBY AMENITIES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70, letterSpacing: 1.0)),
                const SizedBox(height: 12),
                
                mapsProvider.isLoadingPlaces
                    ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
                    : mapsProvider.nearbyPlaces.isEmpty
                        ? const Text('No surrounding places discovered.', style: TextStyle(color: Colors.grey, fontSize: 13))
                        : SizedBox(
                            height: 110,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: mapsProvider.nearbyPlaces.length,
                              itemBuilder: (context, idx) {
                                final pl = mapsProvider.nearbyPlaces[idx];
                                return Container(
                                  width: 160,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                        child: Image.network(
                                          pl.imageUrl,
                                          height: 50,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(pl.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            Text('${pl.distance.toInt()}m away • ${pl.type.toUpperCase()}', style: const TextStyle(color: Colors.grey, fontSize: 8)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                const SizedBox(height: 24),
                // Detailed full screen info trigger
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChargerDetailsScreen(marker: m)));
                  },
                  child: const Text('View Full Specifications & Details', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetMetric(String label, String value, List<List<dynamic>> icon, Color color) {
    return Column(
      children: [
        HugeIcon(icon: icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 8, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // Advanced Filters full bottom modal
  void _showAdvancedFiltersModal(BuildContext context, MapsProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('FILTER OPTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 16),
                  
                  // Connectors
                  const Text('CONNECTORS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white60)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['CCS2', 'Type 2', 'CHAdeMO'].map((conn) {
                      final active = provider.selectedConnectors.contains(conn);
                      return ChoiceChip(
                        label: Text(conn),
                        selected: active,
                        onSelected: (_) {
                          provider.toggleConnectorFilter(conn);
                          setModalState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Power Speed
                  const Text('SPEED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white60)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Fast', 'Ultra Fast', 'AC'].map((spd) {
                      final active = provider.selectedSpeeds.contains(spd);
                      return ChoiceChip(
                        label: Text(spd),
                        selected: active,
                        onSelected: (_) {
                          provider.toggleSpeedFilter(spd);
                          setModalState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          child: const Text('Reset All', style: TextStyle(color: Colors.redAccent)),
                          onPressed: () {
                            provider.clearAllFilters();
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          child: const Text('Apply'),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}
