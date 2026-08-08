import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/charger_marker_details_sheet.dart';
import '../../models/location_search_result.dart';
import '../../models/map_marker_model.dart';
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
          math.min(widget.origin.latitude, widget.destination.latitude),
          math.min(widget.origin.longitude, widget.destination.longitude),
        ),
        northeast: LatLng(
          math.max(widget.origin.latitude, widget.destination.latitude),
          math.max(widget.origin.longitude, widget.destination.longitude),
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

  double _calculateBearing(LatLng start, LatLng end) {
    final startLat = start.latitude * (math.pi / 180.0);
    final startLng = start.longitude * (math.pi / 180.0);
    final endLat = end.latitude * (math.pi / 180.0);
    final endLng = end.longitude * (math.pi / 180.0);

    final dLng = endLng - startLng;
    final y = math.sin(dLng) * math.cos(endLat);
    final x = math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(dLng);
    final brng = math.atan2(y, x);
    return (brng * (180.0 / math.pi) + 360.0) % 360.0;
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

    // Start in-app navigation progress inside EVHub:
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
        double bearing = 0.0;
        if (_currentRouteIndex < mp.routePoints.length - 1) {
          final nextPos = mp.routePoints[_currentRouteIndex + 1];
          bearing = _calculateBearing(currentPos, nextPos);
        }
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: currentPos,
              zoom: 16.5,
              bearing: bearing,
              tilt: 45.0,
            ),
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

  void _handleExit() {
    _simulationTimer?.cancel();
    context.read<MapsProvider>().clearTrip();
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
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

    // 1. Green Start Marker (Origin)
    markers.add(
      Marker(
        markerId: const MarkerId('nav_origin'),
        position: LatLng(widget.origin.latitude, widget.origin.longitude),
        infoWindow: InfoWindow(title: 'START: ${widget.origin.displayName}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    );

    // 2. Red Destination Marker
    markers.add(
      Marker(
        markerId: const MarkerId('nav_destination'),
        position: LatLng(widget.destination.latitude, widget.destination.longitude),
        infoWindow: InfoWindow(
          title: 'DESTINATION: ${widget.destination.displayName}',
          snippet: widget.destination.subtitle ?? 'Destination',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    // 3. Moving EV Vehicle Marker (Violet hue - Active Navigation mode only)
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

    // 4. EV Chargers along route corridor
    final corridorChargers = mp.getFilteredMarkers();
    for (final c in corridorChargers) {
      final isRec = recommendedIds.contains(c.id);
      final recStop = isRec ? mp.recommendedStops.firstWhere((s) => s.charger.id == c.id) : null;

      final powerKw = double.tryParse(c.power.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      final isUltraFast = powerKw >= 50.0 || c.powerType.toLowerCase().contains('dc');

      double hue;
      if (isRec) {
        hue = BitmapDescriptor.hueGreen;
      } else if (isUltraFast) {
        hue = BitmapDescriptor.hueYellow;
      } else if (c.computedStatus == MarkerStatus.busy || c.status == MarkerStatus.busy) {
        hue = BitmapDescriptor.hueRed;
      } else {
        hue = BitmapDescriptor.hueBlue;
      }

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
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
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

    final distanceToStopKm = activeStop != null
        ? (activeStop.distanceFromStartKm - coveredDistanceKm).clamp(0.0, totalDistanceKm)
        : 0.0;

    final expectedBatteryAtStopPct = activeStop != null
        ? (startingBatteryPct - ((activeStop.distanceFromStartKm / (totalDistanceKm > 0 ? totalDistanceKm : 1)) * totalPctUsed) + _chargedBatteryBoostPct).clamp(0.0, 100.0)
        : 0.0;

    final expectedBatteryAtDestPct = (startingBatteryPct - totalPctUsed + _chargedBatteryBoostPct + stops.fold(0.0, (sum, s) => sum + s.batteryGainPct)).clamp(0.0, 100.0);

    final originNameShort = widget.origin.displayName.split(',').first.trim();
    final destNameShort = widget.destination.displayName.split(',').first.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. FULL SCREEN GOOGLE MAP CANVAS (Fills ~95% of screen)
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

          // 2. TOP FLOATING HEADER (Google Maps Style: ← Origin → Destination)
          Positioned(
            top: 40, left: 16, right: 16,
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              borderRadius: 20,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _handleExit,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$originNameShort → $destNameShort',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (_isNavigatingActive ? const Color(0xFF3B82F6) : const Color(0xFF10B981)).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _isNavigatingActive ? 'LIVE NAVIGATION' : 'TRIP PREVIEW MODE',
                                style: GoogleFonts.outfit(
                                  color: _isNavigatingActive ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_isNavigatingActive) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.navigation, color: Color(0xFF3B82F6), size: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${_getManeuverInstruction(mp, distanceToStopKm, remainingDistanceKm)} (${_getDistanceToManeuver(distanceToStopKm, remainingDistanceKm, activeStop != null)})',
                                  style: GoogleFonts.outfit(color: const Color(0xFF60A5FA), fontSize: 11, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. RIGHT FLOATING CONTROLS (Recenter & Zoom)
          Positioned(
            right: 16,
            top: 110,
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

          // 4. BOTTOM FLOATING CARD (Minimal Google Maps Floating Route Summary)
          Positioned(
            left: 16, right: 16, bottom: 24,
            child: GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Minimal Metric Bar: Distance | ETA | Battery Consumption | Charging Stops
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildTopNavMetric(
                          _isNavigatingActive ? 'Remaining' : 'Distance',
                          _isNavigatingActive ? remainingDistanceDisplay : totalDistanceDisplay,
                        ),
                        Text('|', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 14)),
                        _buildTopNavMetric(
                          _isNavigatingActive ? 'ETA' : 'Est. Time',
                          _isNavigatingActive ? remainingEtaDisplay : totalDurationDisplay,
                        ),
                        Text('|', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 14)),
                        _buildTopNavMetric(
                          _isNavigatingActive ? 'Battery' : 'Consumption',
                          _isNavigatingActive ? '${currentBatteryPct.toStringAsFixed(0)}%' : '${totalPctUsed.toStringAsFixed(0)}%',
                        ),
                        Text('|', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 14)),
                        _buildTopNavMetric('Stops', '${stops.length} Stop${stops.length == 1 ? "" : "s"}'),
                      ],
                    ),
                  ),

                  // Next Charger Guidance Snippet (Compact)
                  if (activeStop != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt, color: Color(0xFF10B981), size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Next Stop: ${activeStop.charger.title} (${(activeStop.distanceFromStartKm - (_isNavigatingActive ? coveredDistanceKm : 0)).clamp(0, totalDistanceKm).toStringAsFixed(1)} km) • Arr ${expectedBatteryAtStopPct.toStringAsFixed(0)}% (Dest ${expectedBatteryAtDestPct.toStringAsFixed(0)}%)',
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'Target ${activeStop.recommendedChargingTargetPct.toStringAsFixed(0)}%',
                            style: GoogleFonts.outfit(color: const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // START CHARGING / SKIP STOP buttons during active navigation
                  if (_isNavigatingActive && activeStop != null) ...[
                    const SizedBox(height: 10),
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

                  const SizedBox(height: 12),

                  // MAIN ACTION BUTTON: START NAVIGATION (Preview Mode) or LIVE NAVIGATION / EXIT NAV (Active Mode)
                  if (!_isNavigatingActive) ...[
                    Row(
                      children: [
                        Expanded(
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
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                          tooltip: 'End Trip Plan',
                          onPressed: _handleExit,
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showSnackbar('Navigation guidance active along route.'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: const Icon(Icons.directions_car, color: Colors.white, size: 18),
                            label: Text(
                              'LIVE NAVIGATION',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
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
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
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
                  ],
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
}
