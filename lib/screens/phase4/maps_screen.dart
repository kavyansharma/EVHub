import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';

import '../../providers/maps_provider.dart';
import '../../core/constants/map_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/charger_source_badge.dart';
import '../../core/widgets/charger_marker_factory.dart';
import '../../models/map_marker_model.dart';
import '../../services/maps_service.dart';
import 'charger_details_screen.dart';

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  GoogleMapController? _mapController;
  MapType _mapType = MapType.normal;
  final bool _trafficEnabled = true;
  bool _showCountCard = true;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  StreamSubscription<Position>? _positionSubscription;
  final MapsService _mapsService = MapsService();
  bool _isSuggestionsVisible = false;

  @override
  void initState() {
    super.initState();
    debugPrint("[MAPS SCREEN] initState called");
    _initMarkerIcons();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MapsProvider>();
      provider.fetchCurrentLocationAndStations().then((_) {
        _recenterCamera();
        final err = provider.locationError;
        if (err != null && mounted) {
          _showLocationErrorDialog(err);
          provider.clearLocationError();
        }
      });
    });

    _positionSubscription = _mapsService.getPositionStream().listen((pos) {
      if (mounted) {
        context.read<MapsProvider>().updateLiveLocation(pos.latitude, pos.longitude);
      }
    });

    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus && _searchController.text.trim().length >= 2) {
        if (mounted) {
          setState(() {
            _isSuggestionsVisible = true;
          });
        }
      }
    });
  }

  Future<void> _initMarkerIcons() async {
    try {
      await ChargerMarkerFactory.init();
    } catch (e) {
      debugPrint("[MAPS SCREEN] Exception loading custom markers: $e");
    }
  }

  void _showLocationErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.location_off, color: Color(0xFFF59E0B), size: 22),
            const SizedBox(width: 10),
            Text(
              'Location Issue',
              style: GoogleFonts.outfit(color: const Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.outfit(color: const Color(0xFF475569), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: GoogleFonts.outfit(color: const Color(0xFF10B981), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
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
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: targetLatLng, zoom: 14.5),
        ),
      );
    }
  }

  void _fitCameraToChargers(List<MapMarkerModel> chargers) {
    if (_mapController == null || chargers.isEmpty) return;

    final validChargers = chargers.where((c) => c.hasValidCoordinates).toList();
    if (validChargers.isEmpty) return;

    final provider = context.read<MapsProvider>();

    if (validChargers.length == 1) {
      final single = validChargers.first;
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(single.latitude, single.longitude),
            zoom: 15.0,
          ),
        ),
      );
    } else {
      final List<LatLng> allTargetPoints = [];
      for (final c in validChargers) {
        allTargetPoints.add(LatLng(c.latitude, c.longitude));
      }
      if (provider.tripOrigin != null) {
        allTargetPoints.add(provider.tripOrigin!.coordinates);
      }
      if (provider.tripDestination != null) {
        allTargetPoints.add(provider.tripDestination!.coordinates);
      }
      if (provider.routePoints.isNotEmpty) {
        allTargetPoints.addAll(provider.routePoints);
      }

      double minLat = allTargetPoints.first.latitude;
      double maxLat = allTargetPoints.first.latitude;
      double minLng = allTargetPoints.first.longitude;
      double maxLng = allTargetPoints.first.longitude;

      for (final pt in allTargetPoints) {
        if (pt.latitude < minLat) minLat = pt.latitude;
        if (pt.latitude > maxLat) maxLat = pt.latitude;
        if (pt.longitude < minLng) minLng = pt.longitude;
        if (pt.longitude > maxLng) maxLng = pt.longitude;
      }

      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 60.0),
      );
    }
  }

  void _zoomIn() {
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  Color _getNetworkColor(String network) {
    if (network.toLowerCase().contains('tata')) return AppColors.brandTata;
    if (network.toLowerCase().contains('statiq')) return AppColors.primary;
    if (network.toLowerCase().contains('jio')) return AppColors.accentPurple;
    if (network.toLowerCase().contains('zeon')) return AppColors.secondary;
    return const Color(0xFF10B981);
  }

  @override
  Widget build(BuildContext context) {
    final mapsProvider = context.watch<MapsProvider>();
    final filtered = mapsProvider.getFilteredMarkers();

    // Render Compact EV Teardrop Pins anchored at Offset(0.5, 1.0)
    final Set<Marker> mapMarkers = filtered.map((m) {
      final isSelected = mapsProvider.selectedMarker?.id == m.id;
      final BitmapDescriptor icon = ChargerMarkerFactory.getIconForCharger(m, isSelected: isSelected);

      return Marker(
        markerId: MarkerId(m.id),
        position: LatLng(m.latitude, m.longitude),
        icon: icon,
        anchor: const Offset(0.5, 1.0),
        onTap: () {
          mapsProvider.setSelectedMarker(m);
          _searchFocusNode.unfocus();
          if (mounted) {
            setState(() {
              _isSuggestionsVisible = false;
            });
          }
          if (_mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: LatLng(m.latitude, m.longitude),
                  zoom: 15.5,
                ),
              ),
            );
          }
        },
      );
    }).toSet();

    // Add Trip Origin & Destination Markers in route mode
    if (mapsProvider.tripOrigin != null) {
      mapMarkers.add(
        Marker(
          markerId: const MarkerId('trip_origin'),
          position: mapsProvider.tripOrigin!.coordinates,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'Origin',
            snippet: mapsProvider.tripOrigin!.displayName,
          ),
        ),
      );
    }

    if (mapsProvider.tripDestination != null) {
      mapMarkers.add(
        Marker(
          markerId: const MarkerId('trip_destination'),
          position: mapsProvider.tripDestination!.coordinates,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Destination',
            snippet: mapsProvider.tripDestination!.displayName,
          ),
        ),
      );
    }

    // Directions routing polyline
    final Set<Polyline> polylines = {};
    if (mapsProvider.routePoints.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('directions_route'),
          points: mapsProvider.routePoints,
          color: const Color(0xFF10B981),
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

    String countText = '${filtered.length} chargers found in this area';
    if (mapsProvider.discoveryMode == 'route') {
      countText = '${filtered.length} chargers found along your route';
    } else if (mapsProvider.discoveryMode == 'gps') {
      countText = '${filtered.length} chargers found near you';
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. FULL SCREEN GOOGLE MAP
          Positioned.fill(
            child: GoogleMap(
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
              },
              initialCameraPosition: initialCameraPosition,
              onMapCreated: (controller) {
                _mapController = controller;
                if (_mapType == MapType.normal && !kIsWeb) {
                  try {
                    controller.setMapStyle(MapConstants.darkMapStyle);
                  } catch (_) {}
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
              onTap: (LatLng coords) {
                mapsProvider.setSelectedMarker(null);
                mapsProvider.clearRoute();
                _searchFocusNode.unfocus();
                if (mounted) {
                  setState(() {
                    _isSuggestionsVisible = false;
                  });
                }
              },
            ),
          ),

          // Loading Progress Bar
          if (mapsProvider.isLoading)
            const Positioned(
              top: 0, left: 0, right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: Color(0xFF10B981),
                minHeight: 3,
              ),
            ),

          // 2. TOP FLOATING SEARCH BAR & FILTERS HUD CONSOLE
          Positioned(
            top: 20,
            left: 16,
            right: 16,
            child: SafeArea(
              child: PointerInterceptor(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // PREMIUM WHITE SEARCH BAR
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          if (mapsProvider.isSearching)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF10B981)),
                            )
                          else
                            const HugeIcon(
                              icon: HugeIcons.strokeRoundedSearch01,
                              color: Color(0xFF10B981),
                              size: 22,
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              style: GoogleFonts.outfit(color: const Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w500),
                              decoration: InputDecoration(
                                hintText: 'Search city, area, charger or network',
                                hintStyle: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 14),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                filled: false,
                              ),
                              onChanged: (val) {
                                final query = val.trim();
                                if (mounted) {
                                  setState(() {
                                    _isSuggestionsVisible = query.length >= 2;
                                  });
                                }
                                mapsProvider.searchSuggestions(val);
                              },
                              onSubmitted: (val) {
                                if (val.trim().isNotEmpty) {
                                  _searchFocusNode.unfocus();
                                  setState(() {
                                    _isSuggestionsVisible = false;
                                  });
                                  mapsProvider.selectPlace(val.trim(), (latLng) {
                                    _mapController?.animateCamera(
                                      CameraUpdate.newCameraPosition(
                                        CameraPosition(target: latLng, zoom: 14.0),
                                      ),
                                    );
                                  });
                                }
                              },
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Color(0xFF64748B), size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _searchFocusNode.unfocus();
                                setState(() {
                                  _isSuggestionsVisible = false;
                                });
                                mapsProvider.searchSuggestions('');
                                mapsProvider.clearSearchStatus();
                                mapsProvider.refreshStations();
                              },
                            ),
                          Container(
                            width: 1,
                            height: 24,
                            color: const Color(0xFFE2E8F0),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          IconButton(
                            icon: const HugeIcon(
                              icon: HugeIcons.strokeRoundedFilter,
                              color: Color(0xFF334155),
                              size: 20,
                            ),
                            onPressed: () => _showAdvancedFiltersModal(context, mapsProvider),
                          ),
                        ],
                      ),
                    ),

                    // AUTOCOMPLETE SUGGESTIONS DROPDOWN CARD
                    if (_isSuggestionsVisible && mapsProvider.suggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        constraints: const BoxConstraints(maxHeight: 280),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: mapsProvider.suggestions.length,
                          itemBuilder: (context, idx) {
                            final sug = mapsProvider.suggestions[idx];
                            final type = sug['type'] as String? ?? 'location';
                            IconData leadingIcon = Icons.location_on_outlined;
                            Color iconColor = const Color(0xFF10B981);
                            if (type == 'network') {
                              leadingIcon = Icons.ev_station;
                              iconColor = const Color(0xFF3B82F6);
                            } else if (type == 'station') {
                              leadingIcon = Icons.electric_car;
                              iconColor = const Color(0xFF10B981);
                            }

                            return ListTile(
                              dense: true,
                              leading: Icon(leadingIcon, color: iconColor, size: 20),
                              title: Text(
                                sug['description'] as String,
                                style: GoogleFonts.outfit(color: const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: sug['subtitle'] != null
                                  ? Text(
                                      sug['subtitle'] as String,
                                      style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              onTap: () {
                                final desc = sug['description'] as String? ?? '';
                                _searchFocusNode.unfocus();
                                setState(() {
                                  _isSuggestionsVisible = false;
                                });
                                _searchController.text = desc;
                                mapsProvider.selectSuggestion(sug, (latLng, {zoom}) {
                                  _mapController?.animateCamera(
                                    CameraUpdate.newCameraPosition(
                                      CameraPosition(target: latLng, zoom: zoom ?? 14.5),
                                    ),
                                  );
                                });
                              },
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 10),

                    // FLOATING FILTER CHIPS ROW
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildFilterChip('⭐ EVHub Verified', mapsProvider.selectedSourceFilter == 'EVHub Verified', () {
                            mapsProvider.setSourceFilter(
                              mapsProvider.selectedSourceFilter == 'EVHub Verified' ? 'All Sources' : 'EVHub Verified',
                            );
                          }),
                          _buildFilterChip('🌐 Google Places', mapsProvider.selectedSourceFilter == 'Google Places', () {
                            mapsProvider.setSourceFilter(
                              mapsProvider.selectedSourceFilter == 'Google Places' ? 'All Sources' : 'Google Places',
                            );
                          }),
                          _buildFilterChip('⚡ CCS2', mapsProvider.selectedConnectors.contains('CCS2'), () {
                            mapsProvider.toggleConnectorFilter('CCS2');
                          }),
                          _buildFilterChip('🔌 Fast', mapsProvider.selectedSpeeds.contains('Fast'), () {
                            mapsProvider.toggleSpeedFilter('Fast');
                          }),
                          _buildFilterChip('🚀 Ultra Fast', mapsProvider.selectedSpeeds.contains('Ultra Fast'), () {
                            mapsProvider.toggleSpeedFilter('Ultra Fast');
                          }),
                          _buildFilterChip('🟢 Available', mapsProvider.selectedStatusFilter == 'Available', () {
                            mapsProvider.setStatusFilter(
                              mapsProvider.selectedStatusFilter == 'Available' ? null : 'Available',
                            );
                          }),
                          _buildFilterChip('🏢 All Networks', mapsProvider.selectedNetwork != null, () {
                            _showAdvancedFiltersModal(context, mapsProvider);
                          }),
                        ],
                      ),
                    ),

                    // DYNAMIC CHARGER COUNT CARD
                    if (_showCountCard) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                            const SizedBox(width: 8),
                            Text(
                              countText,
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF0F172A),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _showCountCard = false;
                                });
                              },
                              child: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // 3. FLOATING MAP LEGEND (LOWER LEFT)
          Positioned(
            bottom: mapsProvider.selectedMarker != null ? 360 : 30,
            left: 16,
            child: PointerInterceptor(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLegendItem(const Color(0xFF10B981), 'Available'),
                    const SizedBox(width: 10),
                    _buildLegendItem(const Color(0xFFF59E0B), 'Busy'),
                    const SizedBox(width: 10),
                    _buildLegendItem(const Color(0xFFEF4444), 'Offline'),
                    const SizedBox(width: 10),
                    _buildLegendItem(const Color(0xFF6B7280), 'Unknown'),
                  ],
                ),
              ),
            ),
          ),

          // 4. FLOATING MAP CONTROLS (RIGHT SIDE VERTICAL BUTTONS)
          Positioned(
            bottom: mapsProvider.selectedMarker != null ? 360 : 30,
            right: 16,
            child: PointerInterceptor(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCircularControlBtn(
                    icon: HugeIcons.strokeRoundedSatellite,
                    isActive: _mapType == MapType.satellite,
                    onTap: () {
                      setState(() {
                        _mapType = _mapType == MapType.normal ? MapType.satellite : MapType.normal;
                      });
                      if (_mapController != null && !kIsWeb) {
                        try {
                          _mapController!.setMapStyle(_mapType == MapType.normal ? MapConstants.darkMapStyle : null);
                        } catch (_) {}
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildCircularControlBtn(
                    icon: HugeIcons.strokeRoundedAddCircle,
                    isActive: false,
                    onTap: _zoomIn,
                  ),
                  const SizedBox(height: 10),
                  _buildCircularControlBtn(
                    icon: HugeIcons.strokeRoundedMinusSignCircle,
                    isActive: false,
                    onTap: _zoomOut,
                  ),
                  const SizedBox(height: 10),
                  _buildCircularControlBtn(
                    icon: HugeIcons.strokeRoundedLocation01,
                    isActive: true,
                    onTap: _recenterCamera,
                  ),
                  if (filtered.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildCircularControlBtn(
                      icon: HugeIcons.strokeRoundedMapsLocation01,
                      isActive: true,
                      onTap: () => _fitCameraToChargers(filtered),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Route Info HUD
          if (mapsProvider.routeDistance != null)
            Positioned(
              bottom: mapsProvider.selectedMarker != null ? 340 : 20,
              left: 16,
              right: 80,
              child: PointerInterceptor(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.alt_route, color: Color(0xFF10B981), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ETA: ${mapsProvider.routeDuration}',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Distance: ${mapsProvider.routeDistance} • Est. Battery Needed: ${mapsProvider.estimatedBatteryUsage}%',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF64748B),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 16),
                        onPressed: () => mapsProvider.clearRoute(),
                      )
                    ],
                  ),
                ),
              ),
            ),

          // Interactive Bottom Sheet for selected charger
          if (mapsProvider.selectedMarker != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              height: MediaQuery.of(context).size.height * 0.85,
              child: PointerInterceptor(
                child: _buildInteractiveBottomSheet(mapsProvider, context),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF10B981) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                color: isSelected ? Colors.black : const Color(0xFF334155),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircularControlBtn({
    required List<List<dynamic>> icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: HugeIcon(
            icon: icon,
            color: isActive ? const Color(0xFF10B981) : const Color(0xFF334155),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.outfit(
            color: const Color(0xFF334155),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildInteractiveBottomSheet(MapsProvider mapsProvider, BuildContext context) {
    final m = mapsProvider.selectedMarker!;
    final netColor = _getNetworkColor(m.network);

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.25,
      maxChildSize: 0.88,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1D2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, -4))
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: netColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.ev_station, color: netColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.title,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(m.network, style: GoogleFonts.outfit(color: netColor, fontWeight: FontWeight.bold, fontSize: 13)),
                              if (m.isVerified) ...[
                                const SizedBox(width: 8),
                                const ChargerSourceBadge(source: 'evhub_verified'),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => mapsProvider.setSelectedMarker(null),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ChargerDetailsScreen(marker: m)),
                      );
                    },
                    icon: const Icon(Icons.bolt, color: Colors.black, size: 20),
                    label: Text('START CHARGING & DETAILS', style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAdvancedFiltersModal(BuildContext context, MapsProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D2E),
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
                  Text(
                    'CONNECTORS',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white60),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['CCS2', 'Type 2', 'CHAdeMO'].map((conn) {
                      final active = provider.selectedConnectors.contains(conn);
                      return ChoiceChip(
                        label: Text(conn, style: GoogleFonts.outfit(color: active ? Colors.black : Colors.white)),
                        selected: active,
                        selectedColor: const Color(0xFF10B981),
                        backgroundColor: Colors.white.withOpacity(0.06),
                        onSelected: (_) {
                          provider.toggleConnectorFilter(conn);
                          setModalState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'SPEED',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white60),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Fast', 'Ultra Fast', 'AC'].map((spd) {
                      final active = provider.selectedSpeeds.contains(spd);
                      return ChoiceChip(
                        label: Text(spd, style: GoogleFonts.outfit(color: active ? Colors.black : Colors.white)),
                        selected: active,
                        selectedColor: const Color(0xFF10B981),
                        backgroundColor: Colors.white.withOpacity(0.06),
                        onSelected: (_) {
                          provider.toggleSpeedFilter(spd);
                          setModalState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          child: Text('Reset All', style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text('Apply', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
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
