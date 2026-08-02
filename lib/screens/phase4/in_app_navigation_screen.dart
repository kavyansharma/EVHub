import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/charger_marker_details_sheet.dart';
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
    final recommendedIds = mp.recommendedStops.map((s) => s.charger.id).toSet();

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

    // All corridor chargers (with recommended chargers visually distinct)
    final corridorChargers = mp.getFilteredMarkers();
    for (final c in corridorChargers) {
      final isRec = recommendedIds.contains(c.id);
      final recStop = isRec ? mp.recommendedStops.firstWhere((s) => s.charger.id == c.id) : null;

      markers.add(
        Marker(
          markerId: MarkerId('nav_charger_${c.id}'),
          position: LatLng(c.latitude, c.longitude),
          infoWindow: InfoWindow(
            title: isRec ? '⭐ Recommended Stop ${recStop?.stopIndex}: ${c.title}' : c.title,
            snippet: isRec
                ? '${c.networkName} • ${c.displayPower} • Target ${recStop?.recommendedChargingTargetPct.toStringAsFixed(0)}%'
                : '${c.networkName} • ${c.displayPower} • ${c.computedStatus.name.toUpperCase()}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isRec ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueCyan,
          ),
          onTap: () {
            mp.setSelectedMarker(c);
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => ChargerMarkerDetailsSheet(charger: c),
            );
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
    final batteryUsedDisplay = '${mp.tripEnergyAnalysis.tripEnergyRequiredKwh.toStringAsFixed(1)} kWh';

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
                            const SizedBox(height: 6),
                            // Top Summary Bar: Distance | ETA | Battery Used | Charging Stops
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildTopNavMetric('Distance', distanceDisplay),
                                  Text('|', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 12)),
                                  _buildTopNavMetric('ETA', durationDisplay),
                                  Text('|', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 12)),
                                  _buildTopNavMetric('Battery Used', batteryUsedDisplay),
                                  Text('|', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 12)),
                                  _buildTopNavMetric('Stops', '${stops.length} Stop${stops.length == 1 ? "" : "s"}'),
                                ],
                              ),
                            ),
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

                  // Route calculation failure banner with Retry & Google Maps options
                  if (mp.routePoints.isEmpty && !mp.isLoadingRoute && !mp.isLoading) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Unable to calculate a driving route right now. Please try again or open the destination in Google Maps.',
                                  style: GoogleFonts.outfit(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
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
                              const SizedBox(width: 8),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: _launchExternalGoogleMaps,
                                child: Text(
                                  'Open in Google Maps',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF3B82F6),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
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
                  // Next Charging Stop Card (Next Stop | Distance to Stop | Expected Battery at Arrival | Recommended Charge)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: stops.isNotEmpty ? const Color(0xFF10B981).withOpacity(0.4) : const Color(0xFF3B82F6).withOpacity(0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              stops.isNotEmpty ? Icons.bolt : Icons.check_circle_outline,
                              color: stops.isNotEmpty ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                stops.isNotEmpty ? 'Next Stop: ${stops.first.charger.title}' : 'Direct Trip — No Charging Required',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStopSubMetric(
                              label: 'Distance to Stop',
                              value: stops.isNotEmpty ? '${stops.first.distanceFromStartKm.toStringAsFixed(1)} km' : distanceDisplay,
                              color: const Color(0xFF3B82F6),
                            ),
                            _buildStopSubMetric(
                              label: 'Battery at Arrival',
                              value: stops.isNotEmpty
                                  ? '${stops.first.estimatedArrivalBatteryPct.toStringAsFixed(0)}%'
                                  : '${smartResult?.estimatedBatteryAtDestinationPct.clamp(0, 100).toStringAsFixed(0) ?? mp.currentBatteryPct.toInt()}%',
                              color: const Color(0xFF10B981),
                            ),
                            _buildStopSubMetric(
                              label: 'Recommended Charge',
                              value: stops.isNotEmpty
                                  ? 'Target ${stops.first.recommendedChargingTargetPct.toStringAsFixed(0)}% (~${stops.first.estimatedChargingDurationMinutesInt}m)'
                                  : 'No Charge Needed',
                              color: const Color(0xFFF59E0B),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

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

  Widget _buildTopNavMetric(String label, String value) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        Text(label, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 9)),
      ],
    );
  }

  Widget _buildStopSubMetric({required String label, required String value, required Color color}) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        Text(label, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 9)),
      ],
    );
  }
}
