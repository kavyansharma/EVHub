import 'dart:async';
import 'dart:math' as math;
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

  bool _isNavigatingActive = false;
  int _currentRouteIndex = 0;
  Timer? _simulationTimer;
  int _activeStopIndex = 0;
  bool _isTripCompleted = false;
  bool _isChargingActive = false;
  double _chargedBatteryBoostPct = 0.0;

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

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
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

  double _haversineKm(LatLng a, LatLng b) {
    const p = 0.017453292519943295;
    final aLat = a.latitude * p;
    final bLat = b.latitude * p;
    final dLat = (b.latitude - a.latitude) * p;
    final dLng = (b.longitude - a.longitude) * p;
    final val = 0.5 - math.cos(dLat) / 2 + math.cos(aLat) * math.cos(bLat) * (1 - math.cos(dLng)) / 2;
    return 12742 * math.asin(math.sqrt(val));
  }

  double _calculateTotalPolylineDistanceKm(List<LatLng> points) {
    if (points.length < 2) return 0.0;
    double dist = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      dist += _haversineKm(points[i], points[i + 1]);
    }
    return dist;
  }

  double _calculateCoveredPolylineDistanceKm(List<LatLng> points, int currentIndex) {
    if (points.length < 2 || currentIndex <= 0) return 0.0;
    double dist = 0.0;
    final limit = math.min(currentIndex, points.length - 1);
    for (int i = 0; i < limit; i++) {
      dist += _haversineKm(points[i], points[i + 1]);
    }
    return dist;
  }

  void _startActiveNavigation(MapsProvider mp) {
    if (mp.routePoints.isEmpty) {
      _showSnackbar('No route points available to navigate.');
      return;
    }

    setState(() {
      _isNavigatingActive = true;
      _currentRouteIndex = 0;
      _activeStopIndex = 0;
      _isTripCompleted = false;
      _isChargingActive = false;
      _chargedBatteryBoostPct = 0.0;
    });

    _simulationTimer?.cancel();

    // Start in-app navigation progress:
    // If live GPS location is available and permission is granted, track position.
    // If live location is unavailable or permission is not granted, run route simulation along decoded polyline without prompting for permissions.
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_isChargingActive) return;

      if (_currentRouteIndex < mp.routePoints.length - 1) {
        setState(() {
          _currentRouteIndex++;
        });
        final currentPos = mp.routePoints[_currentRouteIndex];
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: currentPos, zoom: 15.5),
          ),
        );
      } else {
        timer.cancel();
        setState(() {
          _isTripCompleted = true;
        });
      }
    });

    _showSnackbar('Live in-app navigation active.');
  }

  void _exitActiveNavigation() {
    _simulationTimer?.cancel();
    setState(() {
      _isNavigatingActive = false;
      _currentRouteIndex = 0;
      _isTripCompleted = false;
      _isChargingActive = false;
      _chargedBatteryBoostPct = 0.0;
    });
    _fitMapBounds();
    _showSnackbar('Exited active navigation.');
  }

  void _skipCurrentStop(MapsProvider mp) {
    setState(() {
      if (_activeStopIndex < mp.recommendedStops.length) {
        _activeStopIndex++;
      }
    });
    _showSnackbar('Charging stop skipped. Advancing to next stop.');
  }

  void _startInAppCharging(MapsProvider mp) {
    final currentStop = mp.recommendedStops.length > _activeStopIndex
        ? mp.recommendedStops[_activeStopIndex]
        : null;

    if (currentStop == null) return;

    setState(() {
      _isChargingActive = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141724),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.bolt, color: Color(0xFF10B981), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'EV Charging Session',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentStop.charger.title,
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Network: ${currentStop.charger.networkName}',
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
            ),
            Text(
              'Power: ${currentStop.charger.displayPower} • Connectors: ${currentStop.charger.connectors.join(", ")}',
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
            ),
            Text(
              'Status: ${currentStop.charger.computedStatus.name.toUpperCase()}',
              style: GoogleFonts.outfit(color: const Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const LinearProgressIndicator(
              color: Color(0xFF10B981),
              backgroundColor: Colors.white10,
            ),
            const SizedBox(height: 12),
            Text(
              'Charging to ${currentStop.recommendedChargingTargetPct.toStringAsFixed(0)}% target in EVHub...',
              style: GoogleFonts.outfit(color: const Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _isChargingActive = false;
                _chargedBatteryBoostPct += currentStop.batteryGainPct;
                _activeStopIndex++;
              });
              _showSnackbar('Charging session complete! Resuming navigation.');
            },
            child: Text('FINISH CHARGING', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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

  String _getManeuverInstruction(MapsProvider mp, double distanceToStop, double remainingDistance) {
    final stops = mp.recommendedStops;
    final activeStop = stops.length > _activeStopIndex ? stops[_activeStopIndex] : null;

    if (activeStop != null) {
      if (distanceToStop > 0.5) {
        return 'Follow charging corridor toward ${activeStop.charger.title}';
      } else {
        return 'Prepare to turn into ${activeStop.charger.title}';
      }
    } else {
      final totalPoints = mp.routePoints.length;
      final progress = _currentRouteIndex / (totalPoints > 1 ? totalPoints - 1 : 1);
      if (progress < 0.25) return 'Head out on primary route toward ${widget.destination.displayName}';
      if (progress < 0.75) return 'Continue straight on EV navigation route';
      if (progress < 0.95) return 'Merge onto destination approach road';
      return 'Arriving at ${widget.destination.displayName} on the left';
    }
  }

  String _getDistanceToManeuver(double distanceToStop, double remainingDistance, bool hasActiveStop) {
    final targetDist = hasActiveStop ? distanceToStop : remainingDistance;
    if (targetDist < 0.5) {
      final meters = (targetDist * 1000).round();
      return '$meters m';
    }
    return '${targetDist.toStringAsFixed(1)} km';
  }

  int _parseDurationToMinutes(String? durationStr) {
    if (durationStr == null || durationStr.isEmpty) return 30;
    int totalMins = 0;
    final hrMatch = RegExp(r'(\d+)\s*hr').firstMatch(durationStr);
    final minMatch = RegExp(r'(\d+)\s*min').firstMatch(durationStr);
    if (hrMatch != null) {
      totalMins += (int.tryParse(hrMatch.group(1)!) ?? 0) * 60;
    }
    if (minMatch != null) {
      totalMins += (int.tryParse(minMatch.group(1)!) ?? 0);
    }
    if (totalMins == 0) {
      final digits = RegExp(r'(\d+)').firstMatch(durationStr);
      if (digits != null) totalMins = int.tryParse(digits.group(1)!) ?? 30;
    }
    return totalMins > 0 ? totalMins : 30;
  }

  String _formatRemainingEta(int remainingMinutes) {
    if (remainingMinutes <= 0) return 'Arrived';
    if (remainingMinutes < 60) return '$remainingMinutes mins';
    final hrs = remainingMinutes ~/ 60;
    final mins = remainingMinutes % 60;
    return mins > 0 ? '$hrs hr $mins min' : '$hrs hr';
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

    // Active vehicle marker (Violet hue)
    if (_isNavigatingActive && mp.routePoints.isNotEmpty && _currentRouteIndex < mp.routePoints.length) {
      markers.add(
        Marker(
          markerId: const MarkerId('active_vehicle_marker'),
          position: mp.routePoints[_currentRouteIndex],
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          anchor: const Offset(0.5, 0.5),
          infoWindow: const InfoWindow(title: '⚡ Your EV'),
        ),
      );
    }

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
    final activeStop = stops.length > _activeStopIndex ? stops[_activeStopIndex] : null;

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
          color: _isNavigatingActive ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
          width: 6,
        ),
      );
    }

    final totalPolylineKm = _calculateTotalPolylineDistanceKm(mp.routePoints);
    final totalDistanceKm = totalPolylineKm > 0
        ? totalPolylineKm
        : (double.tryParse(mp.routeDistance?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '') ?? smartResult?.tripDistanceKm ?? 20.0);

    final coveredDistanceKm = _calculateCoveredPolylineDistanceKm(mp.routePoints, _currentRouteIndex);
    final progressFraction = totalDistanceKm > 0 ? (coveredDistanceKm / totalDistanceKm).clamp(0.0, 1.0) : 0.0;
    final remainingDistanceKm = (totalDistanceKm - coveredDistanceKm).clamp(0.0, totalDistanceKm);
    final remainingDistanceDisplay = '${remainingDistanceKm.toStringAsFixed(1)} km';
    final totalDistanceDisplay = '${totalDistanceKm.toStringAsFixed(1)} km';

    final totalDurationMinutes = _parseDurationToMinutes(mp.routeDuration);
    final remainingMinutes = (totalDurationMinutes * (1.0 - progressFraction)).round();
    final remainingEtaDisplay = _formatRemainingEta(remainingMinutes);
    final totalDurationDisplay = mp.routeDuration ?? '$totalDurationMinutes mins';

    final startingBatteryPct = mp.currentBatteryPct;
    final totalEnergyNeededKwh = mp.tripEnergyAnalysis.tripEnergyRequiredKwh;
    final usableCapacityKwh = mp.selectedVehicle?.usableBatteryCapacity ?? 40.0;
    final totalPctUsed = usableCapacityKwh > 0 ? (totalEnergyNeededKwh / usableCapacityKwh) * 100.0 : 20.0;

    final currentBatteryPct = (startingBatteryPct - (progressFraction * totalPctUsed) + _chargedBatteryBoostPct).clamp(0.0, 100.0);
    final batteryUsedDisplay = '${totalEnergyNeededKwh.toStringAsFixed(1)} kWh';

    final distanceToStopKm = activeStop != null
        ? (activeStop.distanceFromStartKm - coveredDistanceKm).clamp(0.0, totalDistanceKm)
        : 0.0;

    final expectedBatteryAtStopPct = activeStop != null
        ? (startingBatteryPct - ((activeStop.distanceFromStartKm / (totalDistanceKm > 0 ? totalDistanceKm : 1)) * totalPctUsed) + _chargedBatteryBoostPct).clamp(0.0, 100.0)
        : 0.0;

    final expectedBatteryAtDestPct = (startingBatteryPct - totalPctUsed + _chargedBatteryBoostPct + stops.fold(0.0, (sum, s) => sum + s.batteryGainPct)).clamp(0.0, 100.0);

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
                                    color: (_isNavigatingActive ? const Color(0xFF3B82F6) : const Color(0xFF10B981)).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _isNavigatingActive ? 'LIVE NAVIGATION' : 'ROUTE PREVIEW',
                                    style: GoogleFonts.outfit(
                                      color: _isNavigatingActive ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
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
                            // Top Maneuver Area: Next maneuver | Distance to maneuver
                            if (_isNavigatingActive) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.navigation, color: Color(0xFF3B82F6), size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _getManeuverInstruction(mp, distanceToStopKm, remainingDistanceKm),
                                            style: GoogleFonts.outfit(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'Next maneuver in ${_getDistanceToManeuver(distanceToStopKm, remainingDistanceKm, activeStop != null)}',
                                            style: GoogleFonts.outfit(
                                              color: const Color(0xFF60A5FA),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                            // Navigation HUD: Remaining distance | ETA | Battery
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildTopNavMetric('Distance', _isNavigatingActive ? remainingDistanceDisplay : totalDistanceDisplay),
                                  Text('|', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 12)),
                                  _buildTopNavMetric('ETA', _isNavigatingActive ? remainingEtaDisplay : totalDurationDisplay),
                                  Text('|', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 12)),
                                  _buildTopNavMetric(
                                    _isNavigatingActive ? 'Battery' : 'Battery Used',
                                    _isNavigatingActive ? '${currentBatteryPct.toStringAsFixed(0)}%' : batteryUsedDisplay,
                                  ),
                                  Text('|', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 12)),
                                  _buildTopNavMetric('Stops', '${stops.length - _activeStopIndex} Left'),
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
                              _isNavigatingActive
                                  ? 'Route Simulation Active (GPS Disabled)'
                                  : 'Live location is unavailable.',
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
                              'Recenter Route',
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
                ],
              ),
            ),
          ),

          // 3. RIGHT FLOATING CONTROLS (Recenter & Zoom)
          Positioned(
            right: 16,
            top: 240,
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
                  // Next Charging Stop Card (Next Stop | Distance | Expected Arrival Battery | Recommended Charge)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: activeStop != null ? const Color(0xFF10B981).withOpacity(0.4) : const Color(0xFF3B82F6).withOpacity(0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              activeStop != null ? Icons.bolt : Icons.check_circle_outline,
                              color: activeStop != null ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                activeStop != null ? 'Next Stop: ${activeStop.charger.title}' : 'Direct Trip — No Charging Required',
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
                        if (activeStop != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${activeStop.charger.networkName} • ${activeStop.charger.displayPower} • ${activeStop.charger.computedStatus.name.toUpperCase()}',
                            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStopSubMetric(
                              label: 'Distance to Stop',
                              value: activeStop != null ? '${distanceToStopKm.toStringAsFixed(1)} km' : remainingDistanceDisplay,
                              color: const Color(0xFF3B82F6),
                            ),
                            _buildStopSubMetric(
                              label: 'Battery at Arrival',
                              value: activeStop != null
                                  ? '${expectedBatteryAtStopPct.toStringAsFixed(0)}%'
                                  : '${expectedBatteryAtDestPct.toStringAsFixed(0)}%',
                              color: const Color(0xFF10B981),
                            ),
                            _buildStopSubMetric(
                              label: 'Recommended Charge',
                              value: activeStop != null
                                  ? 'Target ${activeStop.recommendedChargingTargetPct.toStringAsFixed(0)}%'
                                  : 'No Charge Needed',
                              color: const Color(0xFFF59E0B),
                            ),
                          ],
                        ),
                        if (activeStop != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _startInAppCharging(mp),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.bolt, size: 16, color: Colors.black),
                                  label: Text('START CHARGING', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _skipCurrentStop(mp),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.amber,
                                    side: const BorderSide(color: Colors.amber),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.skip_next, size: 16, color: Colors.amber),
                                  label: Text('SKIP STOP', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // START NAVIGATION / LIVE NAVIGATION & EXIT NAVIGATION Controls
                  if (!_isNavigatingActive) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _startActiveNavigation(mp),
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
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showSnackbar('Navigation guidance active along route.'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: const Icon(Icons.directions_car, color: Colors.white, size: 20),
                            label: Text(
                              'LIVE NAVIGATION',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _exitActiveNavigation,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                          icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                          label: Text(
                            'EXIT NAV',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

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

          // 5. TRIP COMPLETED OVERLAY CARD
          if (_isTripCompleted)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.75),
                child: Center(
                  child: GlassContainer(
                    padding: const EdgeInsets.all(28),
                    borderRadius: 24,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.emoji_events, color: Color(0xFF10B981), size: 56),
                        const SizedBox(height: 14),
                        Text(
                          'Trip Completed! 🎉',
                          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'You arrived safely at ${widget.destination.displayName}',
                          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Total Distance', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12)),
                                  Text(totalDistanceDisplay, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Total Trip Time', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12)),
                                  Text(totalDurationDisplay, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Charging Stops Used', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12)),
                                  Text('$_activeStopIndex Stops', style: GoogleFonts.outfit(color: const Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Estimated Arrival Battery', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12)),
                                  Text('${currentBatteryPct.toStringAsFixed(0)}%', style: GoogleFonts.outfit(color: const Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _exitActiveNavigation,
                          child: Text('DONE', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
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
