import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/maps_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/charging_session_provider.dart';
import '../../core/constants/map_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/charger_source_badge.dart';
import '../../models/map_marker_model.dart';
import '../../services/maps_service.dart';
import '../charging/live_charging_screen.dart';
import 'charger_details_screen.dart';

// Helper function to dynamically generate circular glow markers
Future<BitmapDescriptor> createCustomMarker(Color color, bool isSelected, {bool isVerified = false}) async {
  final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);
  final double radius = isSelected ? 30.0 : 22.0;
  
  // Paint shadow/glow
  final Paint shadowPaint = Paint()
    ..color = isVerified 
        ? const Color(0xFF10B981).withOpacity(isSelected ? 0.7 : 0.4)
        : color.withOpacity(isSelected ? 0.6 : 0.3)
    ..maskFilter = const MaskFilter.blur(ui.BlurStyle.normal, 6);
  canvas.drawCircle(Offset(radius + 10, radius + 10), radius, shadowPaint);

  // Outer border ring: Emerald/gold for verified, White for discovered
  final Paint borderPaint = Paint()
    ..color = isVerified ? const Color(0xFF10B981) : Colors.white
    ..style = PaintingStyle.fill;
  canvas.drawCircle(Offset(radius + 10, radius + 10), radius, borderPaint);

  // Paint inner circle
  final Paint fillPaint = Paint()
    ..color = color
    ..style = PaintingStyle.fill;
  canvas.drawCircle(Offset(radius + 10, radius + 10), radius - (isSelected ? 5 : 3), fillPaint);

  // If selected, draw center core
  if (isSelected) {
    final Paint centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(radius + 10, radius + 10), radius - 15, centerPaint);
  }

  final ui.Image image = await pictureRecorder.endRecording().toImage(
    (radius * 2 + 20).toInt(),
    (radius * 2 + 20).toInt(),
  );
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
}

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

  // Caching marker icons
  BitmapDescriptor? _markerAvailable;
  BitmapDescriptor? _markerBusy;
  BitmapDescriptor? _markerOffline;
  BitmapDescriptor? _markerUnknown;
  BitmapDescriptor? _markerVerifiedAvailable;
  BitmapDescriptor? _markerSelected;
  bool _markersLoaded = false;

  @override
  void initState() {
    super.initState();
    debugPrint("[MAPS SCREEN] initState called");
    _initMarkerIcons();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MapsProvider>();
      provider.fetchCurrentLocationAndStations().then((_) {
        _recenterCamera();
        // Show GPS error dialog AFTER map has loaded (non-blocking)
        final err = provider.locationError;
        if (err != null && mounted) {
          _showLocationErrorDialog(err);
          provider.clearLocationError();
        }
      });
    });

    // Track real device location updates live
    _positionSubscription = _mapsService.getPositionStream().listen((pos) {
      if (mounted) {
        debugPrint("[MAPS SCREEN] Live GPS update received: ${pos.latitude}, ${pos.longitude}");
        context.read<MapsProvider>().updateLiveLocation(pos.latitude, pos.longitude);
      }
    });

    _searchFocusNode.addListener(() {
      setState(() {
        _isSuggestionsVisible = _searchFocusNode.hasFocus;
      });
    });
  }

  Future<void> _initMarkerIcons() async {
    debugPrint("[MAPS SCREEN] Initializing custom marker icons...");
    try {
      _markerAvailable = await createCustomMarker(const Color(0xFF10B981), false); // Green
      _markerBusy = await createCustomMarker(const Color(0xFFF59E0B), false);      // Orange
      _markerOffline = await createCustomMarker(const Color(0xFFEF4444), false);   // Red
      _markerUnknown = await createCustomMarker(const Color(0xFF6B7280), false);   // Grey
      _markerVerifiedAvailable = await createCustomMarker(const Color(0xFF10B981), false, isVerified: true);
      _markerSelected = await createCustomMarker(const Color(0xFF3B82F6), true);    // Blue
      if (mounted) {
        setState(() {
          _markersLoaded = true;
        });
      }
      debugPrint("[MAPS SCREEN] Custom marker icons loaded successfully.");
    } catch (e) {
      debugPrint("[MAPS SCREEN] Exception caught loading custom markers (falling back to defaults): $e");
    }
  }

  void _showLocationErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.location_off, color: Color(0xFFF59E0B), size: 22),
            const SizedBox(width: 10),
            const Text(
              'Location Issue',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: Color(0xFF10B981))),
          ),
        ],
      ),
    );
  }
  @override
  void dispose() {
    debugPrint("[MAPS SCREEN] dispose called");
    context.read<MapsProvider>().stopAutoRefresh();
    _positionSubscription?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _recenterCamera() {
    final mapsProvider = context.read<MapsProvider>();
    if (_mapController != null && mapsProvider.currentLocation != null) {
      final targetLatLng = LatLng(
        mapsProvider.currentLocation!['latitude']!,
        mapsProvider.currentLocation!['longitude']!,
      );
      debugPrint("[MAPS SCREEN] Recentering camera to user GPS: $targetLatLng");
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: targetLatLng,
            zoom: 14.5,
          ),
        ),
      );
    } else {
      debugPrint("[MAPS SCREEN] Unable to recenter camera: controller is $_mapController, currentLocation is ${mapsProvider.currentLocation}");
    }
  }

  void _zoomIn() {
    debugPrint("[MAPS SCREEN] Zoom In triggered");
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    debugPrint("[MAPS SCREEN] Zoom Out triggered");
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  Color _getNetworkColor(String network) {
    if (network.toLowerCase().contains('tata')) return AppColors.brandTata;
    if (network.toLowerCase().contains('statiq')) return AppColors.primary;
    if (network.toLowerCase().contains('jio')) return AppColors.accentPurple;
    if (network.toLowerCase().contains('zeon')) return AppColors.secondary;
    return AppColors.accent;
  }

  String _getHeroImage(String network) {
    if (network.toLowerCase().contains('tata')) {
      return 'https://images.unsplash.com/photo-1563720223185-11003d516935?auto=format&fit=crop&w=800&q=80';
    }
    if (network.toLowerCase().contains('statiq')) {
      return 'https://images.unsplash.com/photo-1620891549027-942fdc95d3f5?auto=format&fit=crop&w=800&q=80';
    }
    if (network.toLowerCase().contains('jio')) {
      return 'https://images.unsplash.com/photo-1617783921319-7977eb780131?auto=format&fit=crop&w=800&q=80';
    }
    return 'https://images.unsplash.com/photo-1593941707882-a5bba14938cb?auto=format&fit=crop&w=800&q=80';
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("[MAPS SCREEN] Widget build lifecycle started");
    final mapsProvider = context.watch<MapsProvider>();

    // Build custom markers dynamically
    final Set<Marker> mapMarkers = mapsProvider.getFilteredMarkers().map((m) {
      final isSelected = mapsProvider.selectedMarker?.id == m.id;
      BitmapDescriptor icon = BitmapDescriptor.defaultMarker;
      if (_markersLoaded) {
        if (isSelected) {
          icon = _markerSelected!;
        } else if (m.isVerified || m.source == 'evhub_verified') {
          icon = _markerVerifiedAvailable ?? _markerAvailable!;
        } else {
          switch (m.status) {
            case MarkerStatus.available:
              icon = _markerAvailable!;
              break;
            case MarkerStatus.busy:
              icon = _markerBusy!;
              break;
            case MarkerStatus.offline:
              icon = _markerOffline!;
              break;
            case MarkerStatus.unknown:
              icon = _markerUnknown ?? _markerAvailable!;
              break;
          }
        }
      }

      return Marker(
        markerId: MarkerId(m.id),
        position: LatLng(m.latitude, m.longitude),
        icon: icon,
        onTap: () {
          debugPrint("[MAPS SCREEN] Marker tapped: ${m.title}");
          mapsProvider.setSelectedMarker(m);
        },
      );
    }).toSet();

    debugPrint("[MAPS SCREEN] Markers loaded count: ${mapMarkers.length}");

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

    debugPrint("[MAPS SCREEN] initialCameraPosition initialized: ${initialCameraPosition.target}");

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Full Screen Google Map rendered FIRST inside Stack
          Positioned.fill(
            child: Builder(
              builder: (context) {
                debugPrint("[MAPS SCREEN] GoogleMap widget rendering in build tree");
                return GoogleMap(
                  initialCameraPosition: initialCameraPosition,
                  onMapCreated: (controller) {
                    debugPrint("[MAPS SCREEN] GoogleMap successfully created and controller initialized");
                    _mapController = controller;
                    if (_mapType == MapType.normal) {
                      if (kIsWeb) {
                        debugPrint("[MAPS SCREEN] Skipping setMapStyle on Web to prevent PlatformException");
                      } else {
                        try {
                          debugPrint("[MAPS SCREEN] Applying dark map style configuration on mobile");
                          controller.setMapStyle(MapConstants.darkMapStyle);
                        } catch (e) {
                          debugPrint("[MAPS SCREEN] Exception caught applying map style: $e");
                        }
                      }
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
                  buildingsEnabled: true,
                  onTap: (_) {
                    debugPrint("[MAPS SCREEN] Map tapped on empty area; clearing selection");
                    mapsProvider.setSelectedMarker(null);
                    mapsProvider.clearRoute();
                    _searchFocusNode.unfocus();
                  },
                );
              }
            ),
          ),

          // Loading indicator overlay (non-blocking — map still renders)
          if (mapsProvider.isLoading)
            Positioned(
              top: 0, left: 0, right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: AppColors.primary,
                minHeight: 3,
              ),
            ),

          // "No chargers nearby" empty state — shown only when fully loaded and empty
          if (!mapsProvider.isLoading && mapsProvider.markers.isEmpty)
            Positioned(
              bottom: 100,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1D2E).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.ev_station, color: Color(0xFF10B981), size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No EV Chargers Found Nearby',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Try searching for a different area or expand the search radius.',
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
                    borderRadius: 24,
                    animateBorder: true,
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
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: 'Search city, area, charger, network...',
                              hintStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 14),
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
                        Container(
                          width: 1,
                          height: 24,
                          color: Colors.white10,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        IconButton(
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedFilter,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () => _showAdvancedFiltersModal(context, mapsProvider),
                        ),
                      ],
                    ),
                  ),

                  // Autocomplete Suggestion List overlay
                  if (_isSuggestionsVisible && mapsProvider.suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: GlassContainer(
                        borderRadius: 24,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        animateBorder: false,
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: mapsProvider.suggestions.length,
                          itemBuilder: (context, idx) {
                            final sug = mapsProvider.suggestions[idx];
                            return ListTile(
                              leading: const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 18),
                              title: Text(
                                sug['description'] as String,
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
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
                        _buildFilterBadge('⭐ EVHub Verified', mapsProvider.selectedSourceFilter == 'EVHub Verified', () {
                          mapsProvider.setSourceFilter('EVHub Verified');
                        }),
                        _buildFilterBadge('🌐 Google Places', mapsProvider.selectedSourceFilter == 'Google Places', () {
                          mapsProvider.setSourceFilter('Google Places');
                        }),
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
                        if (kIsWeb) {
                          debugPrint("[MAPS SCREEN] Skipping setMapStyle on Web satellite switch");
                        } else {
                          try {
                            _mapController!.setMapStyle(MapConstants.darkMapStyle);
                          } catch (e) {
                            debugPrint("[MAPS SCREEN] Error setting map style: $e");
                          }
                        }
                      } else {
                        if (kIsWeb) {
                          debugPrint("[MAPS SCREEN] Skipping clearMapStyle on Web satellite switch");
                        } else {
                          try {
                            _mapController!.setMapStyle(null);
                          } catch (e) {
                            debugPrint("[MAPS SCREEN] Error clearing map style: $e");
                          }
                        }
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
                animateBorder: true,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const HugeIcon(
                        icon: HugeIcons.strokeRoundedRoute01,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ETA: ${mapsProvider.routeDuration}',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Distance: ${mapsProvider.routeDistance} • Est. Battery Needed: ${mapsProvider.estimatedBatteryUsage}%',
                            style: GoogleFonts.outfit(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
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

          // Draggable Bottom Sheet for selected station
          if (mapsProvider.selectedMarker != null)
            _buildInteractiveBottomSheet(mapsProvider, context),
        ],
      ),
    );
  }

  // Filter Chip Badge
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
              style: GoogleFonts.outfit(
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

  // Map control buttons
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

  // Draggable Bottom Sheet redesign
  Widget _buildInteractiveBottomSheet(MapsProvider mapsProvider, BuildContext context) {
    final m = mapsProvider.selectedMarker!;
    final sessionProvider = context.watch<ChargingSessionProvider>();
    final activeSession = sessionProvider.activeSession;
    final netColor = _getNetworkColor(m.network);

    Color statusColor = AppColors.secondary;
    String statusText = 'Available';
    if (m.status == MarkerStatus.busy) {
      statusColor = AppColors.warning;
      statusText = 'Busy';
    } else if (m.status == MarkerStatus.offline) {
      statusColor = Colors.grey;
      statusText = 'Offline';
    } else if (m.status == MarkerStatus.unknown) {
      statusColor = const Color(0xFF6B7280);
      statusText = 'Unknown';
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
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 30,
                spreadRadius: 8,
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // Pull drag bar
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),

                // Station Hero image
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    _getHeroImage(m.network),
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),

                // Title & Network Brand
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ChargerSourceBadge(source: m.source, isVerified: m.isVerified, compact: true),
                              if (m.distanceKm != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Text(
                                    '${m.distanceKm!.toStringAsFixed(1)} km away',
                                    style: GoogleFonts.outfit(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            m.title,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: netColor, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                m.network,
                                style: GoogleFonts.outfit(
                                  color: netColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.star, color: AppColors.warning, size: 12),
                              const SizedBox(width: 2),
                              Text(
                                m.rating.toString(),
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            m.description,
                            style: GoogleFonts.outfit(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        statusText,
                        style: GoogleFonts.outfit(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
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
                    _buildSheetMetric('STALLS AVAILABLE', m.availableStalls, HugeIcons.strokeRoundedFuelStation, AppColors.secondary),
                    _buildSheetMetric('RATING', m.rating.toString(), HugeIcons.strokeRoundedStar, AppColors.warning),
                    _buildSheetMetric('PRICE', m.price ?? '₹21/kWh', HugeIcons.strokeRoundedLicense, Colors.white),
                  ],
                ),
                const SizedBox(height: 24),

                // Primary Actions Grid
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          // Route navigation polyline drawing
                          mapsProvider.calculateRoute(LatLng(m.latitude, m.longitude));
                        },
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.navigation_outlined, color: AppColors.primary, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Navigate',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Reservation scheduled for ${m.title}!'),
                              backgroundColor: AppColors.secondary,
                            ),
                          );
                        },
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.calendar_today_outlined, color: AppColors.warning, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Book Slot',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
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
                const SizedBox(height: 12),

                // Charge Now Primary Action
                GestureDetector(
                  onTap: () {
                    if (activeSession != null) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveChargingScreen()));
                    } else {
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
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: AppColors.chargingGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppColors.neonShadow(color: AppColors.primary, blurRadius: 12),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.bolt, color: Colors.black, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Start Charging',
                            style: GoogleFonts.outfit(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Nearby places list
                Text(
                  'NEARBY AMENITIES',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.white70,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),

                mapsProvider.isLoadingPlaces
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : mapsProvider.nearbyPlaces.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'No surrounding places found.',
                              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
                            ),
                          )
                        : SizedBox(
                            height: 130,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: mapsProvider.nearbyPlaces.length,
                              itemBuilder: (context, idx) {
                                final pl = mapsProvider.nearbyPlaces[idx];
                                return Container(
                                  width: 170,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                        child: Image.network(
                                          pl.imageUrl,
                                          height: 60,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              pl.name,
                                              style: GoogleFonts.outfit(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                fontSize: 11,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${pl.distance.toInt()}m away • ${pl.type.toUpperCase()}',
                                              style: GoogleFonts.outfit(
                                                color: Colors.grey,
                                                fontSize: 9,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                const SizedBox(height: 20),

                // Link to full screen specs
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChargerDetailsScreen(marker: m)));
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'View Full Specifications & Details',
                        style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward, color: AppColors.primary, size: 14),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
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
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 8,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // Advanced Filters Bottom Modal redesign
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
                  Text(
                    'FILTER OPTIONS',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Connectors
                  Text(
                    'CONNECTORS',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['CCS2', 'Type 2', 'CHAdeMO'].map((conn) {
                      final active = provider.selectedConnectors.contains(conn);
                      return ChoiceChip(
                        label: Text(
                          conn,
                          style: GoogleFonts.outfit(color: active ? Colors.black : Colors.white),
                        ),
                        selected: active,
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.white.withOpacity(0.06),
                        onSelected: (_) {
                          provider.toggleConnectorFilter(conn);
                          setModalState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Power Speed
                  Text(
                    'SPEED',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Fast', 'Ultra Fast', 'AC'].map((spd) {
                      final active = provider.selectedSpeeds.contains(spd);
                      return ChoiceChip(
                        label: Text(
                          spd,
                          style: GoogleFonts.outfit(color: active ? Colors.black : Colors.white),
                        ),
                        selected: active,
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.white.withOpacity(0.06),
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
                          child: Text(
                            'Reset All',
                            style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            provider.clearAllFilters();
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Apply',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                          ),
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
