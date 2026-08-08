// ignore_for_file: unused_element
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/premium_button.dart';
import '../../core/widgets/charger_marker_details_sheet.dart';
import '../../models/location_search_result.dart';
import '../../models/map_marker_model.dart';
import '../../models/vehicle_model.dart';
import '../../providers/maps_provider.dart';
import '../../services/maps_service.dart';
import '../../services/vehicle_service.dart';
import '../../services/charging_time_estimator_service.dart';
import 'in_app_navigation_screen.dart';

// ─── Color palette ──────────────────────────────────────────────────────────
const Color _kGreen  = Color(0xFF10B981);
const Color _kOrange = Color(0xFFF59E0B);
const Color _kRed    = Color(0xFFEF4444);
const Color _kBlue   = Color(0xFF3B82F6);
const Color _kYellow = Color(0xFFEAB308);
const Color _kCard   = Color(0xFF141724);

class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController   = TextEditingController();
  final FocusNode _startFocusNode = FocusNode();
  final FocusNode _endFocusNode   = FocusNode();

  MapsService get _mapsService => context.read<MapsProvider>().mapsService;
  GoogleMapController? _mapController;

  LocationSearchResult? _selectedOrigin;
  LocationSearchResult? _selectedDestination;

  List<LocationSearchResult> _startSuggestions = [];
  List<LocationSearchResult> _endSuggestions   = [];
  Timer? _debounceTimer;

  bool _isSearchingStart = false;
  bool _isSearchingEnd   = false;
  bool _isPlanningTrip   = false;
  bool _isNavigating     = false;
  bool _isGpsOrigin      = false;

  // Live navigation state
  int _currentRouteIndex = 0;
  Timer? _simulationTimer;
  StreamSubscription<Position>? _gpsStreamSubscription;
  bool _isTripCompleted  = false;
  bool _isOffRoute       = false;
  int _activeStopIndex   = 0;

  // Preset popular city routes
  static const List<Map<String, dynamic>> _quickRoutes = [
    {
      'label': 'Delhi → Jaipur',
      'origin': LocationSearchResult(
        displayName: 'New Delhi, Delhi',
        subtitle: 'Capital Region',
        latitude: 28.6139,
        longitude: 77.2090,
        source: LocationSearchResultSource.localFallback,
      ),
      'destination': LocationSearchResult(
        displayName: 'Jaipur, Rajasthan',
        subtitle: 'Pink City',
        latitude: 26.9124,
        longitude: 75.7873,
        source: LocationSearchResultSource.localFallback,
      ),
    },
    {
      'label': 'Mumbai → Pune',
      'origin': LocationSearchResult(
        displayName: 'Mumbai, Maharashtra',
        subtitle: 'Financial Capital',
        latitude: 19.0760,
        longitude: 72.8777,
        source: LocationSearchResultSource.localFallback,
      ),
      'destination': LocationSearchResult(
        displayName: 'Pune, Maharashtra',
        subtitle: 'Oxford of the East',
        latitude: 18.5204,
        longitude: 73.8567,
        source: LocationSearchResultSource.localFallback,
      ),
    },
    {
      'label': 'Bengaluru → Chennai',
      'origin': LocationSearchResult(
        displayName: 'Bengaluru, Karnataka',
        subtitle: 'Silicon Valley',
        latitude: 12.9716,
        longitude: 77.5946,
        source: LocationSearchResultSource.localFallback,
      ),
      'destination': LocationSearchResult(
        displayName: 'Chennai, Tamil Nadu',
        subtitle: 'Gateway to South',
        latitude: 13.0827,
        longitude: 80.2707,
        source: LocationSearchResultSource.localFallback,
      ),
    },
  ];

  @override
  void initState() {
    super.initState();
    _startFocusNode.addListener(() {
      if (!_startFocusNode.hasFocus) setState(() => _startSuggestions = []);
    });
    _endFocusNode.addListener(() {
      if (!_endFocusNode.hasFocus) setState(() => _endSuggestions = []);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MapsProvider>();
      if (provider.tripOrigin != null) {
        _selectedOrigin = provider.tripOrigin;
        _startController.text = provider.tripOrigin!.displayName;
      }
      if (provider.tripDestination != null) {
        _selectedDestination = provider.tripDestination;
        _endController.text = provider.tripDestination!.displayName;
      }
      if (provider.routePoints.isNotEmpty) {
        _fitMapBounds();
      }
    });
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _startFocusNode.dispose();
    _endFocusNode.dispose();
    _debounceTimer?.cancel();
    _simulationTimer?.cancel();
    _gpsStreamSubscription?.cancel();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GPS & LOCATION HANDLING (Explicit User Trigger ONLY)
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _useCurrentLocation() async {
    setState(() => _isSearchingStart = true);
    try {
      final permission = await _mapsService.requestLocationPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _showSnackbar(
          'Location access is required to use your current location. You can also enter a starting location manually.',
          isError: true,
        );
        return;
      }

      final loc = await _mapsService.getCurrentLocation();
      final lat = loc['latitude']!;
      final lng = loc['longitude']!;
      final address = await _mapsService.getAddressFromCoordinates(lat, lng);

      final result = LocationSearchResult(
        displayName: address,
        subtitle: 'GPS Location',
        latitude: lat,
        longitude: lng,
        source: LocationSearchResultSource.googlePlaces,
      );

      setState(() {
        _selectedOrigin = result;
        _startController.text = address;
        _isGpsOrigin = true;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), 14.0),
      );
      _showSnackbar('Current location set as starting point.');
    } catch (e) {
      _showSnackbar('Location access is required to use your current location. You can also enter a starting location manually.', isError: true);
    } finally {
      if (mounted) setState(() => _isSearchingStart = false);
    }
  }

  void _fitMapBounds() {
    if (_mapController == null) return;
    final mp = context.read<MapsProvider>();

    final origin = _selectedOrigin ?? mp.tripOrigin;
    final destination = _selectedDestination ?? mp.tripDestination;

    if (mp.routePoints.isEmpty) {
      if (origin == null || destination == null) return;
      final bounds = LatLngBounds(
        southwest: LatLng(
          math.min(origin.latitude, destination.latitude),
          math.min(origin.longitude, destination.longitude),
        ),
        northeast: LatLng(
          math.max(origin.latitude, destination.latitude),
          math.max(origin.longitude, destination.longitude),
        ),
      );
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
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
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 65));
    }
  }

  void _reCenterCamera(MapsProvider mp) {
    if (_mapController == null || mp.routePoints.isEmpty) return;
    final pos = mp.routePoints[_currentRouteIndex.clamp(0, mp.routePoints.length - 1)];
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(pos, 17.0),
    );
  }

  void _onQueryChanged(String query, bool isStart) {
    _debounceTimer?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        if (isStart) { _startSuggestions = []; _isSearchingStart = false; }
        else         { _endSuggestions   = []; _isSearchingEnd   = false; }
      });
      return;
    }

    setState(() {
      if (isStart) {
        _isSearchingStart = true;
      } else {
        _isSearchingEnd = true;
      }
    });

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      final cleanQuery = query.trim();
      final results = <LocationSearchResult>[];

      try {
        final rawPlaces = await _mapsService.getAutocompleteSuggestions(cleanQuery);
        for (final p in rawPlaces) {
          final desc = p['description'] as String? ?? cleanQuery;
          final lat  = (p['latitude']  as num?)?.toDouble() ?? 0.0;
          final lng  = (p['longitude'] as num?)?.toDouble() ?? 0.0;
          final pid  = p['place_id'] as String? ?? '';
          results.add(LocationSearchResult(
            displayName: desc,
            subtitle: p['subtitle'] as String? ?? 'Location search',
            latitude: lat,
            longitude: lng,
            placeId: pid,
            source: LocationSearchResultSource.googlePlaces,
          ));
        }
      } catch (e) {
        debugPrint('[RoutePlannerScreen] Autocomplete search error: $e');
      }

      const knownCities = [
        {'name': 'New Delhi, Delhi',       'lat': 28.6139, 'lng': 77.2090, 'sub': 'Capital Region'},
        {'name': 'Jaipur, Rajasthan',      'lat': 26.9124, 'lng': 75.7873, 'sub': 'Pink City'},
        {'name': 'Mumbai, Maharashtra',    'lat': 19.0760, 'lng': 72.8777, 'sub': 'Financial Capital'},
        {'name': 'Pune, Maharashtra',      'lat': 18.5204, 'lng': 73.8567, 'sub': 'Oxford of the East'},
        {'name': 'Bengaluru, Karnataka',   'lat': 12.9716, 'lng': 77.5946, 'sub': 'Silicon Valley'},
        {'name': 'Chennai, Tamil Nadu',    'lat': 13.0827, 'lng': 80.2707, 'sub': 'Gateway to South'},
        {'name': 'Hyderabad, Telangana',   'lat': 17.3850, 'lng': 78.4867, 'sub': 'Pearl City'},
      ];

      for (final city in knownCities) {
        final cName = city['name'] as String;
        if (cName.toLowerCase().contains(cleanQuery.toLowerCase()) &&
            !results.any((r) => r.displayName.toLowerCase() == cName.toLowerCase())) {
          results.add(LocationSearchResult(
            displayName: cName,
            subtitle: city['sub'] as String,
            latitude: city['lat'] as double,
            longitude: city['lng'] as double,
            source: LocationSearchResultSource.localFallback,
          ));
        }
      }

      if (mounted) {
        setState(() {
          if (isStart) { _startSuggestions = results; _isSearchingStart = false; }
          else         { _endSuggestions   = results; _isSearchingEnd   = false; }
        });
      }
    });
  }

  Future<void> _selectSuggestion(LocationSearchResult suggestion, bool isStart) async {
    setState(() {
      if (isStart) {
        _isSearchingStart = true;
        _startController.text = suggestion.displayName;
        _startSuggestions = [];
        _startFocusNode.unfocus();
        _isGpsOrigin = false;
      } else {
        _isSearchingEnd = true;
        _endController.text = suggestion.displayName;
        _endSuggestions = [];
        _endFocusNode.unfocus();
      }
    });

    LocationSearchResult resolved = suggestion;

    if (resolved.latitude == 0.0 || resolved.longitude == 0.0) {
      LatLng? coords;
      if (suggestion.placeId != null && suggestion.placeId!.isNotEmpty) {
        try {
          coords = await _mapsService.getPlaceCoordinates(suggestion.placeId!);
        } catch (_) {}
      }

      if (coords == null) {
        try {
          coords = await _mapsService.getCoordinatesFromAddress(suggestion.displayName);
        } catch (_) {}
      }

      if (coords != null) {
        resolved = LocationSearchResult(
          displayName: suggestion.displayName,
          subtitle: suggestion.subtitle,
          latitude: coords.latitude,
          longitude: coords.longitude,
          placeId: suggestion.placeId,
          source: suggestion.source,
        );
      } else {
        if (mounted) {
          setState(() {
            if (isStart) { _isSearchingStart = false; _startController.clear(); }
            else { _isSearchingEnd = false; _endController.clear(); }
          });
          _showSnackbar(
            isStart
                ? 'Could not find the starting location. Please try a more specific address.'
                : 'Could not find the destination. Please try a more specific location.',
            isError: true,
          );
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        if (isStart) {
          _selectedOrigin = resolved;
          _startController.text = resolved.displayName;
          _isSearchingStart = false;
        } else {
          _selectedDestination = resolved;
          _endController.text = resolved.displayName;
          _isSearchingEnd = false;
        }
      });
    }
  }

  void _swapLocations() {
    setState(() {
      final tmp = _selectedOrigin;
      _selectedOrigin = _selectedDestination;
      _selectedDestination = tmp;
      final tmpText = _startController.text;
      _startController.text = _endController.text;
      _endController.text = tmpText;
    });
  }

  void _applyQuickRoute(Map<String, dynamic> route) {
    setState(() {
      _selectedOrigin = route['origin'] as LocationSearchResult;
      _selectedDestination = route['destination'] as LocationSearchResult;
      _startController.text = _selectedOrigin!.displayName;
      _endController.text = _selectedDestination!.displayName;
      _startSuggestions = [];
      _endSuggestions = [];
      _isGpsOrigin = false;
    });
    _planTrip();
  }

  void _planTrip() async {
    if (_isPlanningTrip) return;
    final mp = context.read<MapsProvider>();
    if (mp.isLoadingRoute || mp.isLoading) return;

    setState(() => _isPlanningTrip = true);

    try {
      _startFocusNode.unfocus();
      _endFocusNode.unfocus();

      final startText = _startController.text.trim();
      final endText = _endController.text.trim();

      if (startText.isEmpty) {
        _showSnackbar('Please enter a starting location.', isError: true);
        return;
      }
      if (endText.isEmpty) {
        _showSnackbar('Could not find the destination. Please try a more specific location.', isError: true);
        return;
      }

      if (_selectedOrigin == null || (_selectedOrigin!.latitude == 0.0 && _selectedOrigin!.longitude == 0.0)) {
        try {
          final coords = await _mapsService.getCoordinatesFromAddress(startText);
          if (coords != null) {
            _selectedOrigin = LocationSearchResult(
              displayName: startText,
              subtitle: 'Address Location',
              latitude: coords.latitude,
              longitude: coords.longitude,
              source: LocationSearchResultSource.googlePlaces,
            );
          } else {
            _showSnackbar('Could not find the starting location. Please try a more specific address.', isError: true);
            return;
          }
        } catch (_) {
          _showSnackbar('Could not find the starting location. Please try a more specific address.', isError: true);
          return;
        }
      }

      if (_selectedDestination == null || (_selectedDestination!.latitude == 0.0 && _selectedDestination!.longitude == 0.0)) {
        try {
          final coords = await _mapsService.getCoordinatesFromAddress(endText);
          if (coords != null) {
            _selectedDestination = LocationSearchResult(
              displayName: endText,
              subtitle: 'Address Location',
              latitude: coords.latitude,
              longitude: coords.longitude,
              source: LocationSearchResultSource.googlePlaces,
            );
          } else {
            _showSnackbar('Could not find the destination. Please try a more specific location.', isError: true);
            return;
          }
        } catch (_) {
          _showSnackbar('Could not find the destination. Please try a more specific location.', isError: true);
          return;
        }
      }

      if (_selectedOrigin!.latitude == _selectedDestination!.latitude &&
          _selectedOrigin!.longitude == _selectedDestination!.longitude) {
        _showSnackbar('Start and destination must be different.', isError: true);
        return;
      }

      if (!mounted) return;
      await mp.planTrip(origin: _selectedOrigin!, destination: _selectedDestination!);

      if (mounted) {
        _fitMapBounds();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InAppNavigationScreen(
              origin: _selectedOrigin!,
              destination: _selectedDestination!,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPlanningTrip = false);
    }
  }

  void _clearTrip() {
    _simulationTimer?.cancel();
    _gpsStreamSubscription?.cancel();
    setState(() {
      _selectedOrigin = null;
      _selectedDestination = null;
      _startController.clear();
      _endController.clear();
      _startSuggestions = [];
      _endSuggestions = [];
      _isNavigating = false;
      _isGpsOrigin = false;
      _currentRouteIndex = 0;
      _isTripCompleted = false;
      _isOffRoute = false;
      _activeStopIndex = 0;
    });
    context.read<MapsProvider>().clearTrip();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // IN-APP NAVIGATION ENGINE (GPS vs SIMULATION)
  // ══════════════════════════════════════════════════════════════════════════
  void _startActiveNavigation(MapsProvider mp) {
    if (mp.routePoints.isEmpty) {
      _showSnackbar('No route points available to navigate.', isError: true);
      return;
    }

    setState(() {
      _isNavigating = true;
      _currentRouteIndex = 0;
      _isTripCompleted = false;
      _isOffRoute = false;
      _activeStopIndex = 0;
    });

    _simulationTimer?.cancel();
    _gpsStreamSubscription?.cancel();

    if (_isGpsOrigin) {
      // 1. Live GPS Navigation Tracking
      _gpsStreamSubscription = _mapsService.getPositionStream().listen((Position pos) {
        if (!mounted || !_isNavigating) return;
        final currentGps = LatLng(pos.latitude, pos.longitude);

        // Point-to-segment projection & off-route detection
        final minDistanceKm = _minDistanceToRoute(currentGps, mp.routePoints);
        if (minDistanceKm > 0.3) { // 300m off route
          setState(() {
            _isOffRoute = true;
          });
          _recalculateOffRoute(currentGps, mp);
          return;
        }

        // Project position onto nearest route segment
        final nearestIndex = _findNearestPolylineIndex(currentGps, mp.routePoints);
        setState(() {
          _currentRouteIndex = nearestIndex;
          _isOffRoute = false;
        });

        // Check if reached recommended charger stop (within 200m)
        _checkChargerStopReached(mp, currentGps);

        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: currentGps,
              zoom: 17.0,
              bearing: pos.heading,
              tilt: 45.0,
            ),
          ),
        );
      });
    } else {
      // 2. In-App Route Simulation Mode (Manual Start Origin)
      _simulationTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

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

          _checkChargerStopReached(mp, currentPos);

          _mapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: currentPos,
                zoom: 17.0,
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
    }
  }

  void _checkChargerStopReached(MapsProvider mp, LatLng vehiclePos) {
    if (mp.recommendedStops.isEmpty || _activeStopIndex >= mp.recommendedStops.length) return;
    final targetStop = mp.recommendedStops[_activeStopIndex];
    final distKm = _haversineKm(vehiclePos, LatLng(targetStop.charger.latitude, targetStop.charger.longitude));

    if (distKm <= 0.3) { // Within 300m of recommended charger stop
      _showChargingStopReachedDialog(mp, targetStop);
    }
  }

  void _showChargingStopReachedDialog(MapsProvider mp, dynamic stop) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141724),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.ev_station, color: _kGreen, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'CHARGING STOP REACHED',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stop.charger.title,
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            Text('Arrival Battery: ${stop.estimatedArrivalBatteryPct.toStringAsFixed(0)}%',
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
            Text('Target Charge: ${stop.recommendedChargingTargetPct.toStringAsFixed(0)}%',
                style: GoogleFonts.outfit(color: _kGreen, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _activeStopIndex++);
            },
            child: Text('SKIP STOP', style: GoogleFonts.outfit(color: Colors.white70, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kGreen, foregroundColor: Colors.black),
            onPressed: () {
              Navigator.pop(ctx);
              mp.setSelectedMarker(stop.charger);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ChargerMarkerDetailsSheet(charger: stop.charger),
              );
            },
            child: Text('START CHARGING', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _recalculateOffRoute(LatLng currentGps, MapsProvider mp) async {
    _showSnackbar('You\'re off route. Recalculating route...', isError: true);
    if (_selectedDestination != null) {
      final currentOrigin = LocationSearchResult(
        displayName: 'Current GPS Location',
        latitude: currentGps.latitude,
        longitude: currentGps.longitude,
        source: LocationSearchResultSource.googlePlaces,
      );
      await mp.planTrip(origin: currentOrigin, destination: _selectedDestination!);
      _fitMapBounds();
    }
  }

  void _exitActiveNavigation() {
    _simulationTimer?.cancel();
    _gpsStreamSubscription?.cancel();
    setState(() {
      _isNavigating = false;
      _currentRouteIndex = 0;
      _isTripCompleted = false;
      _isOffRoute = false;
    });
    _fitMapBounds();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // POINT-TO-SEGMENT PROJECTION & BEARING MATH
  // ══════════════════════════════════════════════════════════════════════════
  double _haversineKm(LatLng a, LatLng b) {
    const p = 0.017453292519943295;
    final aLat = a.latitude * p;
    final bLat = b.latitude * p;
    final dLat = (b.latitude - a.latitude) * p;
    final dLng = (b.longitude - a.longitude) * p;
    final val = 0.5 - math.cos(dLat) / 2 + math.cos(aLat) * math.cos(bLat) * (1 - math.cos(dLng)) / 2;
    return 12742 * math.asin(math.sqrt(val));
  }

  double _distanceToSegment(LatLng p, LatLng v, LatLng w) {
    final l2 = _haversineKm(v, w);
    if (l2 == 0) return _haversineKm(p, v);
    final t = (((p.latitude - v.latitude) * (w.latitude - v.latitude) +
                (p.longitude - v.longitude) * (w.longitude - v.longitude)) /
               (math.pow(w.latitude - v.latitude, 2) + math.pow(w.longitude - v.longitude, 2)))
        .clamp(0.0, 1.0);
    final projection = LatLng(
      v.latitude + t * (w.latitude - v.latitude),
      v.longitude + t * (w.longitude - v.longitude),
    );
    return _haversineKm(p, projection);
  }

  double _minDistanceToRoute(LatLng p, List<LatLng> polyline) {
    if (polyline.length < 2) return 0.0;
    double minDist = double.infinity;
    for (int i = 0; i < polyline.length - 1; i++) {
      final dist = _distanceToSegment(p, polyline[i], polyline[i + 1]);
      if (dist < minDist) minDist = dist;
    }
    return minDist;
  }

  int _findNearestPolylineIndex(LatLng p, List<LatLng> polyline) {
    if (polyline.isEmpty) return 0;
    int minIndex = 0;
    double minDist = double.infinity;
    for (int i = 0; i < polyline.length; i++) {
      final d = _haversineKm(p, polyline[i]);
      if (d < minDist) {
        minDist = d;
        minIndex = i;
      }
    }
    return minIndex;
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

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? Colors.amber : _kGreen, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: const Color(0xFF1A1D2E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MARKERS & POLYLINES
  // ══════════════════════════════════════════════════════════════════════════
  Set<Marker> _buildMapMarkers(MapsProvider mp) {
    final Set<Marker> markers = {};
    final origin = _selectedOrigin ?? mp.tripOrigin;
    final destination = _selectedDestination ?? mp.tripDestination;
    final recommendedIds = mp.recommendedStops.map((s) => s.charger.id).toSet();

    // 1. Origin Marker
    if (origin != null) {
      markers.add(Marker(
        markerId: const MarkerId('nav_origin'),
        position: LatLng(origin.latitude, origin.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Start: ${origin.displayName}'),
      ));
    }

    // 2. Destination Marker
    if (destination != null) {
      markers.add(Marker(
        markerId: const MarkerId('nav_destination'),
        position: LatLng(destination.latitude, destination.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'Destination: ${destination.displayName}'),
      ));
    }

    // 3. Travel-Ordered Corridor Chargers directly on Map
    final chargers = mp.getFilteredMarkers();
    for (final charger in chargers) {
      final isRec = recommendedIds.contains(charger.id);
      BitmapDescriptor icon;

      if (isRec) {
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      } else {
        final powerKw = ChargingTimeEstimatorService.parsePowerKW(charger.power);
        final isUltraFast = powerKw >= 50 || charger.powerType.toLowerCase().contains('dc');

        if (isUltraFast) {
          icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
        } else if (charger.status == MarkerStatus.busy || charger.status == MarkerStatus.offline) {
          icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
        } else {
          icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
        }
      }

      markers.add(Marker(
        markerId: MarkerId('nav_charger_${charger.id}'),
        position: LatLng(charger.latitude, charger.longitude),
        icon: icon,
        infoWindow: InfoWindow(
          title: '${isRec ? "⭐ Recommended: " : ""}${charger.name}',
          snippet: '${charger.networkName} • ${charger.power}',
        ),
        onTap: () {
          mp.setSelectedMarker(charger);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => ChargerMarkerDetailsSheet(charger: charger),
          );
        },
      ));
    }

    // 4. Moving Vehicle Marker during Active Navigation Mode
    if (_isNavigating && mp.routePoints.isNotEmpty) {
      final vehiclePos = mp.routePoints[_currentRouteIndex.clamp(0, mp.routePoints.length - 1)];
      markers.add(Marker(
        markerId: const MarkerId('moving_vehicle'),
        position: vehiclePos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        anchor: const Offset(0.5, 0.5),
        infoWindow: const InfoWindow(title: 'Your EV'),
      ));
    }

    return markers;
  }

  Set<Polyline> _buildMapPolylines(MapsProvider mp) {
    if (mp.routePoints.isEmpty) return {};
    return {
      Polyline(
        polylineId: const PolylineId('nav_route_polyline'),
        points: mp.routePoints,
        color: _isNavigating ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
        width: 6,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mp = context.watch<MapsProvider>();
    final brandColor = theme.colorScheme.primary;
    final isRouteActive = mp.discoveryMode == 'route' && mp.routePoints.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. FULL SCREEN GOOGLE MAP CANVAS (95%+ Viewport Dominant)
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(20.5937, 78.9629),
                zoom: 5.5,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                if (mp.routePoints.isNotEmpty) {
                  _fitMapBounds();
                }
              },
              markers: _buildMapMarkers(mp),
              polylines: _buildMapPolylines(mp),
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              compassEnabled: true,
              buildingsEnabled: true,
            ),
          ),

          // 2. TOP FLOATING HEADER / SEARCH BAR
          if (!_isNavigating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16, right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    borderRadius: 20,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (isRouteActive)
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                                onPressed: _clearTrip,
                              )
                            else
                              const Icon(Icons.directions_car, color: _kGreen, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isRouteActive
                                    ? '${_selectedOrigin?.displayName.split(',').first ?? "Start"} → ${_selectedDestination?.displayName.split(',').first ?? "Destination"}'
                                    : 'Smart EV Trip Planner',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _buildVehicleSelectorChip(brandColor, mp),
                          ],
                        ),

                        if (!isRouteActive) ...[
                          const SizedBox(height: 10),
                          _buildStartLocationSection(brandColor),
                          const SizedBox(height: 8),
                          _buildDestinationInputRow(brandColor),
                          const SizedBox(height: 8),
                          _buildQuickRouteChips(brandColor),
                        ],
                      ],
                    ),
                  ),

                  // Autocomplete Search Suggestions Dropdown Overlay
                  if (_startSuggestions.isNotEmpty)
                    _buildSuggestionList(_startSuggestions, true),
                  if (_endSuggestions.isNotEmpty)
                    _buildSuggestionList(_endSuggestions, false),
                ],
              ),
            ),

          // 3. TOP MANEUVER BANNER (NAVIGATION MODE)
          if (_isNavigating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16, right: 16,
              child: GlassContainer(
                padding: const EdgeInsets.all(16),
                borderRadius: 20,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: _kGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.navigation, color: Colors.black, size: 24),
                    ),
                    const SizedBox(width: 14),
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
                                  color: _kGreen.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(_isGpsOrigin ? 'LIVE GPS NAVIGATION' : 'ROUTE NAVIGATION',
                                    style: GoogleFonts.outfit(color: _kGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Text('In 400m',
                                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isOffRoute
                                ? 'Recalculating route from current position...'
                                : (_isTripCompleted ? 'Destination Reached!' : 'Turn right toward highway corridor'),
                            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 4. FLOATING BOTTOM SUMMARY CARD (TRIP PREVIEW MODE)
          if (isRouteActive && !_isNavigating)
            Positioned(
              left: 16, right: 16, bottom: 24,
              child: GlassContainer(
                padding: const EdgeInsets.all(18),
                borderRadius: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricItem(
                          'Distance',
                          mp.routeDistance ?? '${mp.smartTripResult?.tripDistanceKm.toStringAsFixed(0) ?? "0"} km',
                          Icons.straighten,
                          _kBlue,
                        ),
                        _buildMetricItem(
                          'ETA',
                          mp.routeDuration ?? '—',
                          Icons.schedule,
                          _kOrange,
                        ),
                        _buildMetricItem(
                          'Battery Usage',
                          '${mp.smartTripResult?.estimatedBatteryAtDestinationPct.clamp(0.0, 100.0).toStringAsFixed(0) ?? "50"}% Est.',
                          Icons.battery_charging_full,
                          _kGreen,
                        ),
                        _buildMetricItem(
                          'Charging Stops',
                          '${mp.recommendedStops.length} Stop${mp.recommendedStops.length == 1 ? "" : "s"}',
                          Icons.ev_station,
                          _kGreen,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: PremiumButton(
                        text: 'START NAVIGATION',
                        icon: Icons.navigation,
                        onPressed: () => _startActiveNavigation(mp),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 5. FLOATING BOTTOM NAVIGATION HUD (ACTIVE NAVIGATION MODE)
          if (_isNavigating)
            Positioned(
              left: 16, right: 16, bottom: 24,
              child: GlassContainer(
                padding: const EdgeInsets.all(18),
                borderRadius: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricItem('Speed', '65 km/h', Icons.speed, _kBlue),
                        _buildMetricItem(
                          'Remaining',
                          '${((1.0 - (_currentRouteIndex / math.max(1, mp.routePoints.length - 1))) * (mp.smartTripResult?.tripDistanceKm ?? 200)).toStringAsFixed(0)} km',
                          Icons.alt_route,
                          _kGreen,
                        ),
                        _buildMetricItem('ETA', mp.routeDuration ?? '—', Icons.access_time, _kOrange),
                        _buildMetricItem('Battery', '${mp.currentBatteryPct.toInt()}%', Icons.battery_charging_full, _kGreen),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _reCenterCamera(mp),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kBlue.withOpacity(0.2),
                              foregroundColor: _kBlue,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.my_location, size: 16),
                            label: Text('Re-center', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _exitActiveNavigation,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _kRed,
                              side: const BorderSide(color: _kRed, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.close, size: 16),
                            label: Text('EXIT NAVIGATION', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Loading overlay
          if (mp.isLoadingRoute || mp.isLoading || mp.isCalculatingSmartTrip || _isPlanningTrip)
            Positioned(
              left: 16, right: 16, bottom: 24,
              child: GlassContainer(
                padding: const EdgeInsets.all(20),
                borderRadius: 20,
                child: Row(
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Calculating EV route & scanning corridor chargers...',
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPER WIDGETS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildVehicleSelectorChip(Color brandColor, MapsProvider mp) {
    final availableVehicles = VehicleService.indianEVEcosystem;
    final selectedVeh = mp.selectedVehicle ?? availableVehicles.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<VehicleModel>(
          value: availableVehicles.any((v) => v.id == selectedVeh.id) ? selectedVeh : availableVehicles.first,
          dropdownColor: const Color(0xFF1A1D2E),
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 16),
          items: availableVehicles.map((v) => DropdownMenuItem<VehicleModel>(
            value: v,
            child: Text(
              '${v.manufacturer} ${v.model}',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          )).toList(),
          onChanged: (veh) {
            if (veh != null) mp.setSelectedVehicle(veh);
          },
        ),
      ),
    );
  }

  Widget _buildStartLocationSection(Color brandColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _useCurrentLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen.withOpacity(0.18),
                  foregroundColor: _kGreen,
                  elevation: 0,
                  side: BorderSide(color: _kGreen.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.my_location, size: 16, color: _kGreen),
                label: Text('📍 Use Current Location', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: _kGreen, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _startController,
                  focusNode: _startFocusNode,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Enter starting location',
                    hintStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (val) {
                    _selectedOrigin = null;
                    _isGpsOrigin = false;
                    _onQueryChanged(val, true);
                  },
                ),
              ),
              if (_isSearchingStart)
                const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _kGreen),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDestinationInputRow(Color brandColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: _kRed, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _endController,
              focusNode: _endFocusNode,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Enter destination (e.g. Jaipur)',
                hintStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (val) {
                _selectedDestination = null;
                _onQueryChanged(val, false);
              },
              onSubmitted: (_) => _planTrip(),
            ),
          ),
          if (_isSearchingEnd)
            const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kGreen),
            )
          else
            IconButton(
              icon: const Icon(Icons.arrow_forward, color: _kGreen, size: 18),
              onPressed: _planTrip,
            ),
        ],
      ),
    );
  }

  Widget _buildQuickRouteChips(Color brandColor) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _quickRoutes.map((qr) {
          final label = qr['label'] as String;
          return Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: ActionChip(
              label: Text(label, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600)),
              backgroundColor: const Color(0xFF1A1D2E),
              side: const BorderSide(color: Colors.white10),
              labelStyle: const TextStyle(color: Colors.white70),
              onPressed: () => _applyQuickRoute(qr),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSuggestionList(List<LocationSearchResult> items, bool isStart) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: items.length,
        itemBuilder: (_, idx) {
          final item = items[idx];
          return ListTile(
            dense: true,
            leading: Icon(isStart ? Icons.location_on_outlined : Icons.flag_outlined,
                color: isStart ? _kGreen : _kRed, size: 18),
            title: Text(item.displayName,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 13)),
            subtitle: Text(item.subtitle ?? 'Location',
                style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11)),
            onTap: () => _selectSuggestion(item, isStart),
          );
        },
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 10)),
      ],
    );
  }
}
