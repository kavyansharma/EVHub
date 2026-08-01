import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../models/location_search_result.dart';
import '../../providers/maps_provider.dart';

class InAppNavigationScreen extends StatefulWidget {
  final LocationSearchResult origin;
  final LocationSearchResult destination;

  const InAppNavigationScreen({
    super.key,
    required this.origin,
    required this.destination,
  });

  @override
  State<InAppNavigationScreen> createState() => _InAppNavigationScreenState();
}

class _InAppNavigationScreenState extends State<InAppNavigationScreen> {
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    debugPrint('[EVHUB_NAV] InAppNavigationScreen opened');
    debugPrint('[EVHUB_NAV] Origin: (${widget.origin.latitude}, ${widget.origin.longitude}) - ${widget.origin.displayName}');
    debugPrint('[EVHUB_NAV] Destination: (${widget.destination.latitude}, ${widget.destination.longitude}) - ${widget.destination.displayName}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitMapBounds();
    });
  }

  void _fitMapBounds() {
    if (_mapController == null) return;
    final mp = context.read<MapsProvider>();
    if (mp.routePoints.isEmpty) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          widget.origin.latitude < widget.destination.latitude ? widget.origin.latitude : widget.destination.latitude,
          widget.origin.longitude < widget.destination.longitude ? widget.origin.longitude : widget.destination.longitude,
        ),
        northeast: LatLng(
          widget.origin.latitude > widget.destination.latitude ? widget.origin.latitude : widget.destination.latitude,
          widget.origin.longitude > widget.destination.longitude ? widget.origin.longitude : widget.destination.longitude,
        ),
      );
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
    } else {
      double minLat = mp.routePoints.first.latitude;
      double maxLat = mp.routePoints.first.latitude;
      double minLng = mp.routePoints.first.longitude;
      double maxLng = mp.routePoints.first.longitude;

      for (final p in mp.routePoints) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  Future<void> _launchExternalGoogleMaps() async {
    final destLat = widget.destination.latitude;
    final destLng = widget.destination.longitude;
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showSnackbar('Unable to open Google Maps.');
      }
    } catch (e) {
      debugPrint('[InAppNavigationScreen] Error launching Google Maps: $e');
      _showSnackbar('Unable to open Google Maps.');
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.outfit(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1D2E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Set<Marker> _buildNavigationMarkers(MapsProvider mp) {
    final markers = <Marker>{};

    // Origin marker
    markers.add(
      Marker(
        markerId: const MarkerId('nav_origin'),
        position: LatLng(widget.origin.latitude, widget.origin.longitude),
        infoWindow: InfoWindow(title: 'Start: ${widget.origin.displayName}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    );

    // Destination marker
    markers.add(
      Marker(
        markerId: const MarkerId('nav_destination'),
        position: LatLng(widget.destination.latitude, widget.destination.longitude),
        infoWindow: InfoWindow(
          title: 'Navigating to: ${widget.destination.displayName}',
          snippet: widget.destination.subtitle ?? 'Destination',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    // Recommended charger markers
    for (final stop in mp.recommendedStops) {
      markers.add(
        Marker(
          markerId: MarkerId('nav_stop_${stop.charger.id}'),
          position: LatLng(stop.charger.latitude, stop.charger.longitude),
          infoWindow: InfoWindow(
            title: 'Stop ${stop.stopIndex}: ${stop.charger.title}',
            snippet: '${stop.charger.power} • Charge to ${stop.recommendedChargingTargetPct.toStringAsFixed(0)}%',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          onTap: () {
            mp.setSelectedMarker(stop.charger);
          },
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MapsProvider>();
    final smartResult = mp.smartTripResult;
    final stops = mp.recommendedStops;

    final initialPos = CameraPosition(
      target: LatLng(widget.origin.latitude, widget.origin.longitude),
      zoom: 11.0,
    );

    final Set<Polyline> polylines = {};
    if (mp.routePoints.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('nav_route_polyline'),
          points: mp.routePoints,
          color: const Color(0xFF10B981),
          width: 5,
        ),
      );
    }

    final distanceDisplay = mp.routeDistance ?? '${smartResult?.tripDistanceKm.toStringAsFixed(1) ?? "0"} km';
    final durationDisplay = mp.routeDuration ?? 'Route Preview';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. FULL SCREEN GOOGLE MAP (In-App Navigation View)
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: initialPos,
              onMapCreated: (controller) {
                _mapController = controller;
                _fitMapBounds();
              },
              markers: _buildNavigationMarkers(mp),
              polylines: polylines,
              myLocationEnabled: mp.hasLocationPermission,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: true,
              buildingsEnabled: true,
            ),
          ),

          // 2. TOP NAVIGATION HUD CARD
          Positioned(
            top: 40, left: 16, right: 16,
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              borderRadius: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'ROUTE PREVIEW',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF10B981),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Navigating to ${widget.destination.displayName}',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.destination.subtitle != null && widget.destination.subtitle!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.destination.subtitle!,
                                style: GoogleFonts.outfit(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Location warning banner when GPS is off (NO automatic permission request)
                  if (!mp.hasLocationPermission) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_off_outlined, color: Colors.amber, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Live location is unavailable.',
                              style: GoogleFonts.outfit(
                                color: Colors.amber,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              _fitMapBounds();
                            },
                            child: Text(
                              'Use Current Map Location',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF3B82F6),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Route calculation failure banner with Retry
                  if (mp.routePoints.isEmpty && !mp.isLoadingRoute && !mp.isLoading) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Unable to calculate route.',
                              style: GoogleFonts.outfit(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              mp.planTrip(origin: widget.origin, destination: widget.destination);
                            },
                            child: Text(
                              'Retry Route',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF10B981),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 3. RIGHT FLOATING CONTROLS (Recenter & Zoom)
          Positioned(
            right: 16,
            top: 220,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'nav_recenter',
                  backgroundColor: const Color(0xFF1A1D2E),
                  onPressed: _fitMapBounds,
                  child: const Icon(Icons.my_location, color: Colors.white, size: 18),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'nav_zoom_in',
                  backgroundColor: const Color(0xFF1A1D2E),
                  onPressed: () => _mapController?.animateCamera(CameraUpdate.zoomIn()),
                  child: const Icon(Icons.add, color: Colors.white, size: 18),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'nav_zoom_out',
                  backgroundColor: const Color(0xFF1A1D2E),
                  onPressed: () => _mapController?.animateCamera(CameraUpdate.zoomOut()),
                  child: const Icon(Icons.remove, color: Colors.white, size: 18),
                ),
              ],
            ),
          ),

          // 4. BOTTOM NAVIGATION CONTROL CONSOLE HUD
          Positioned(
            left: 16, right: 16, bottom: 24,
            child: GlassContainer(
              padding: const EdgeInsets.all(20),
              borderRadius: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Corridor Metrics Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavMetric(
                        label: 'Distance',
                        value: distanceDisplay,
                        icon: Icons.straighten,
                        color: const Color(0xFF3B82F6),
                      ),
                      _buildNavMetric(
                        label: 'ETA / Time',
                        value: durationDisplay,
                        icon: Icons.schedule,
                        color: const Color(0xFFF59E0B),
                      ),
                      _buildNavMetric(
                        label: 'Battery Dest.',
                        value: '${smartResult?.estimatedBatteryAtDestinationPct.clamp(0, 100).toStringAsFixed(0) ?? 0}%',
                        icon: Icons.battery_charging_full,
                        color: const Color(0xFF10B981),
                      ),
                      _buildNavMetric(
                        label: 'Stops',
                        value: '${stops.length}',
                        icon: Icons.ev_station,
                        color: const Color(0xFF10B981),
                      ),
                    ],
                  ),

                  // Next Charging Stop Card (if stops exist)
                  if (stops.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.bolt, color: Color(0xFF10B981), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Next Stop: ${stops.first.charger.title}',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${stops.first.distanceFromStartKm.toStringAsFixed(0)} km from start • Charge to ${stops.first.recommendedChargingTargetPct.toStringAsFixed(0)}% (~${stops.first.estimatedChargingDurationMinutesInt} min)',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Primary START NAVIGATION & Secondary Open in Google Maps
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showSnackbar('In-app navigation guidance active.');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.navigation, color: Colors.black, size: 20),
                      label: Text(
                        'START NAVIGATION',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _launchExternalGoogleMaps,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.open_in_new, size: 16, color: Color(0xFF3B82F6)),
                          label: Text(
                            'Open in Google Maps',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.withOpacity(0.2),
                          foregroundColor: Colors.redAccent,
                          elevation: 0,
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: Text(
                          'End',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(
            color: Colors.grey,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
