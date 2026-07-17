import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/map_marker_model.dart';
import '../repositories/firestore_charger_repository.dart';
import '../repositories/maps_repository.dart';
import '../services/maps_service.dart';
import '../services/places_service.dart';

class MapsProvider extends ChangeNotifier {
  // Firestore is now the PRIMARY source of EV charger data.
  // MapsRepository (Google Places) is retained for potential fallback use.
  final FirestoreChargerRepository _firestoreChargerRepository;
  // ignore: unused_field — retained as Google Places fallback for future use
  final MapsRepository _mapsRepository;
  final MapsService _mapsService;
  final PlacesService _placesService = PlacesService();

  /// Maximum distance (in km) from the user's GPS position within which
  /// Firestore chargers are shown on the map.
  static const double _chargerRadiusKm = 20.0;

  List<MapMarkerModel> _markers = [];
  Map<String, double>? _currentLocation;
  bool _isLoading = false;
  bool _isLoadingPlaces = false;
  bool _isLoadingRoute = false;

  // GPS / location error state — shown in UI dialog
  String? _locationError;

  // Search autocomplete list
  List<Map<String, dynamic>> _suggestions = [];

  // Decoded routing variables
  List<LatLng> _routePoints = [];
  String? _routeDistance;
  String? _routeDuration;

  // Selected station bottom sheet info
  MapMarkerModel? _selectedMarker;
  List<PlaceModel> _nearbyPlaces = [];

  // Active filters selection
  final Set<String> _selectedConnectors = {}; // 'CCS2', 'Type 2', 'CHAdeMO'
  final Set<String> _selectedSpeeds = {};      // 'Fast', 'Ultra Fast', 'AC'
  String? _selectedPriceType;                  // 'Free', 'Paid'
  String? _selectedStatusFilter;               // 'Available', 'Busy'
  String? _selectedNetwork;                    // 'Tata Power', 'Statiq', etc.

  // ─── 30-second Auto-Refresh ───────────────────────────────────────────────
  Timer? _autoRefreshTimer;

  MapsProvider({
    required MapsRepository mapsRepository,
    required MapsService mapsService,
    FirestoreChargerRepository? firestoreChargerRepository,
  })  : _firestoreChargerRepository =
            firestoreChargerRepository ?? FirestoreChargerRepository(),
        _mapsRepository = mapsRepository,
        _mapsService = mapsService;

  // Getters
  List<MapMarkerModel> get markers => _markers;
  Map<String, double>? get currentLocation => _currentLocation;
  bool get isLoading => _isLoading;
  bool get isLoadingPlaces => _isLoadingPlaces;
  bool get isLoadingRoute => _isLoadingRoute;
  String? get locationError => _locationError;
  List<Map<String, dynamic>> get suggestions => _suggestions;
  List<LatLng> get routePoints => _routePoints;
  String? get routeDistance => _routeDistance;
  String? get routeDuration => _routeDuration;
  MapMarkerModel? get selectedMarker => _selectedMarker;
  List<PlaceModel> get nearbyPlaces => _nearbyPlaces;

  Set<String> get selectedConnectors => _selectedConnectors;
  Set<String> get selectedSpeeds => _selectedSpeeds;
  String? get selectedPriceType => _selectedPriceType;
  String? get selectedStatusFilter => _selectedStatusFilter;
  String? get selectedNetwork => _selectedNetwork;

  int get estimatedBatteryUsage {
    if (_routeDistance == null) return 0;
    try {
      final distanceString = _routeDistance!.replaceAll(RegExp(r'[^0-9.]'), '');
      final distance = double.tryParse(distanceString);
      if (distance == null) return 0;
      final isMeters = _routeDistance!.contains('m') && !_routeDistance!.contains('km');
      final distanceKm = isMeters ? distance / 1000.0 : distance;
      final energyNeeded = distanceKm * 0.15; // 0.15 kWh per km
      final percentage = (energyNeeded / 40.0) * 100; // 40 kWh capacity
      return percentage.clamp(1.0, 100.0).round();
    } catch (e) {
      return 0;
    }
  }

  // ─── Start auto-refresh timer ─────────────────────────────────────────────
  void startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      debugPrint('[MapsProvider] Auto-refresh: fetching updated charger list');
      await refreshStations();
    });
    debugPrint('[MapsProvider] Auto-refresh timer started (30s interval)');
  }

  void stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    debugPrint('[MapsProvider] Auto-refresh timer stopped');
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  // ─── Fetch location and load real stations via Nearby Search API ──────────
  Future<void> fetchCurrentLocationAndStations() async {
    _isLoading = true;
    _locationError = null;
    notifyListeners();

    try {
      debugPrint('[MapsProvider] Requesting live GPS position...');
      _currentLocation = await _mapsService.getCurrentLocation();
      debugPrint('[MapsProvider] GPS received: $_currentLocation');
    } catch (e) {
      final errMsg = e.toString();
      debugPrint('[MapsProvider] GPS error: $errMsg');

      // Surface a human-readable error for the UI
      if (errMsg.contains('disabled')) {
        _locationError = 'Location services are disabled. Please enable GPS to find chargers near you.';
      } else if (errMsg.contains('permanently denied')) {
        _locationError = 'Location permission was permanently denied. Please enable it in App Settings.';
      } else if (errMsg.contains('denied')) {
        _locationError = 'Location permission was denied. Showing chargers near New Delhi.';
      } else {
        _locationError = 'Could not determine your location. Showing chargers near New Delhi.';
      }

      // Fallback to New Delhi Connaught Place
      _currentLocation = {
        'latitude': 28.6304,
        'longitude': 77.2177,
      };
    }

    // Always load stations (even on GPS failure, use fallback coords)
    await refreshStations();

    _isLoading = false;
    notifyListeners();

    // Start the 30-second auto-refresh
    startAutoRefresh();
  }

  void clearLocationError() {
    _locationError = null;
    notifyListeners();
  }

  // ─── Refresh chargers listing (Firestore is primary source) ─────────────
  Future<void> refreshStations() async {
    if (_currentLocation == null) return;
    try {
      debugPrint('[MapsProvider] Fetching all EV chargers from Firestore...');

      final userLat = _currentLocation!['latitude']!;
      final userLng = _currentLocation!['longitude']!;

      // 1. Fetch ALL chargers from Firestore.
      final allChargers = await _firestoreChargerRepository.getAllChargers();

      // ── DEBUG: total returned ────────────────────────────────────────────
      debugPrint(
        '[MapsProvider] Firestore returned ${allChargers.length} total chargers',
      );

      // ── DEBUG: print every charger name + coordinates ────────────────────
      for (int i = 0; i < allChargers.length; i++) {
        final c = allChargers[i];
        debugPrint(
          '[MapsProvider]   [${i + 1}/${allChargers.length}] '
          'name="${c.title}" '
          'lat=${c.latitude.toStringAsFixed(6)} '
          'lng=${c.longitude.toStringAsFixed(6)}',
        );
      }

      if (allChargers.isEmpty) {
        debugPrint('[MapsProvider] Firestore contains zero chargers — showing empty state');
        _markers = [];
        notifyListeners();
        return;
      }

      // 2. Filter chargers within _chargerRadiusKm of the user's GPS position.
      final List<_ChargerWithDistance> withDistance = [];
      for (final charger in allChargers) {
        final distanceMeters = Geolocator.distanceBetween(
          userLat,
          userLng,
          charger.latitude,
          charger.longitude,
        );
        final distanceKm = distanceMeters / 1000.0;

        // ── DEBUG: per-charger distance verdict ────────────────────────────
        final verdict = distanceKm <= _chargerRadiusKm ? 'KEPT' : 'DISCARDED';
        debugPrint(
          '[MapsProvider]   "${charger.title}" → '
          '${distanceKm.toStringAsFixed(2)} km — $verdict '
          '(limit: ${_chargerRadiusKm.toInt()} km)',
        );

        if (distanceKm <= _chargerRadiusKm) {
          withDistance.add(_ChargerWithDistance(charger, distanceKm));
        }
      }

      // 3. Sort nearest-first.
      withDistance.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      _markers = withDistance.map((e) => e.charger).toList();

      // ── DEBUG: final displayed count ─────────────────────────────────────
      debugPrint(
        '[MapsProvider] ✓ Displaying ${_markers.length} markers on map '
        '(${allChargers.length - _markers.length} discarded beyond '
        '${_chargerRadiusKm.toInt()} km).',
      );

      notifyListeners();
    } catch (e) {
      debugPrint('[MapsProvider] Error refreshing Firestore stations: $e');
    }
  }

  // ─── Search Autocomplete ──────────────────────────────────────────────────
  Future<void> searchSuggestions(String query) async {
    if (query.isEmpty) {
      _suggestions = [];
      notifyListeners();
      return;
    }
    try {
      final lat = _currentLocation?['latitude'];
      final lng = _currentLocation?['longitude'];
      _suggestions = await _mapsService.getAutocompleteSuggestions(
        query,
        currentLat: lat,
        currentLng: lng,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[MapsProvider] Autocomplete error: $e');
    }
  }

  // ─── Select place from autocomplete ──────────────────────────────────────
  Future<void> selectPlace(String placeId, Function(LatLng) onCoordinatesFetched) async {
    try {
      final coords = await _mapsService.getPlaceCoordinates(placeId);
      if (coords != null) {
        onCoordinatesFetched(coords);
        _currentLocation = {
          'latitude': coords.latitude,
          'longitude': coords.longitude,
        };
        _isLoading = true;
        notifyListeners();
        await refreshStations();
        _isLoading = false;
        _suggestions = [];
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[MapsProvider] Error selecting place: $e');
    }
  }

  // ─── Directions route ─────────────────────────────────────────────────────
  Future<void> calculateRoute(LatLng dest) async {
    if (_currentLocation == null) return;
    _isLoadingRoute = true;
    notifyListeners();

    try {
      final origin = LatLng(_currentLocation!['latitude']!, _currentLocation!['longitude']!);
      debugPrint('[MapsProvider] Calculating route from $origin to $dest');
      final directions = await _mapsService.getDirections(origin, dest);
      if (directions != null) {
        _routePoints = directions['points'] as List<LatLng>;
        _routeDistance = directions['distance'] as String;
        _routeDuration = directions['duration'] as String;
        debugPrint('[MapsProvider] Route: $_routeDistance, ETA: $_routeDuration, points: ${_routePoints.length}');
      }
    } catch (e) {
      debugPrint('[MapsProvider] Route error: $e');
    } finally {
      _isLoadingRoute = false;
      notifyListeners();
    }
  }

  void clearRoute() {
    _routePoints = [];
    _routeDistance = null;
    _routeDuration = null;
    notifyListeners();
  }

  // ─── Selected marker ──────────────────────────────────────────────────────
  void setSelectedMarker(MapMarkerModel? marker) {
    _selectedMarker = marker;
    _nearbyPlaces = [];
    if (marker != null) {
      fetchNearbyPlacesForSelected();
    }
    notifyListeners();
  }

  Future<void> fetchNearbyPlacesForSelected() async {
    if (_selectedMarker == null) return;
    _isLoadingPlaces = true;
    notifyListeners();

    try {
      _nearbyPlaces = await _placesService.getNearbyPlaces(
        _selectedMarker!.latitude,
        _selectedMarker!.longitude,
      );
      debugPrint('[MapsProvider] ${_nearbyPlaces.length} nearby places loaded');
    } catch (e) {
      debugPrint('[MapsProvider] Error fetching nearby places: $e');
    } finally {
      _isLoadingPlaces = false;
      notifyListeners();
    }
  }

  // ─── Live location update ─────────────────────────────────────────────────
  void updateLiveLocation(double lat, double lng) {
    _currentLocation = {'latitude': lat, 'longitude': lng};
    notifyListeners();
  }

  // ─── Filters ─────────────────────────────────────────────────────────────
  void toggleConnectorFilter(String connector) {
    if (_selectedConnectors.contains(connector)) {
      _selectedConnectors.remove(connector);
    } else {
      _selectedConnectors.add(connector);
    }
    notifyListeners();
  }

  void toggleSpeedFilter(String speed) {
    if (_selectedSpeeds.contains(speed)) {
      _selectedSpeeds.remove(speed);
    } else {
      _selectedSpeeds.add(speed);
    }
    notifyListeners();
  }

  void setPriceFilter(String? priceType) {
    _selectedPriceType = _selectedPriceType == priceType ? null : priceType;
    notifyListeners();
  }

  void setStatusFilter(String? status) {
    _selectedStatusFilter = _selectedStatusFilter == status ? null : status;
    notifyListeners();
  }

  void setNetworkFilter(String? network) {
    _selectedNetwork = _selectedNetwork == network ? null : network;
    notifyListeners();
  }

  void clearAllFilters() {
    _selectedConnectors.clear();
    _selectedSpeeds.clear();
    _selectedPriceType = null;
    _selectedStatusFilter = null;
    _selectedNetwork = null;
    notifyListeners();
  }

  // ─── Filtered markers ─────────────────────────────────────────────────────
  List<MapMarkerModel> getFilteredMarkers() {
    return _markers.where((m) {
      if (_selectedConnectors.isNotEmpty) {
        if (!m.connectors.any((c) => _selectedConnectors.contains(c))) return false;
      }
      if (_selectedSpeeds.isNotEmpty) {
        if (!_selectedSpeeds.contains(m.powerType)) return false;
      }
      if (_selectedPriceType != null) {
        final isFree = m.price?.toLowerCase().contains('free') ?? false;
        if (_selectedPriceType == 'Free' && !isFree) return false;
        if (_selectedPriceType == 'Paid' && isFree) return false;
      }
      if (_selectedStatusFilter != null) {
        if (_selectedStatusFilter == 'Available' && m.status != MarkerStatus.available) return false;
        if (_selectedStatusFilter == 'Busy' && m.status != MarkerStatus.busy) return false;
      }
      if (_selectedNetwork != null) {
        if (!m.network.toLowerCase().contains(_selectedNetwork!.toLowerCase())) return false;
      }
      return true;
    }).toList();
  }
}

// ─── Private helper ───────────────────────────────────────────────────────────
/// Pairs a [MapMarkerModel] with its computed distance from the user's GPS,
/// used solely inside [MapsProvider.refreshStations] for filtering and sorting.
class _ChargerWithDistance {
  final MapMarkerModel charger;
  final double distanceKm;

  const _ChargerWithDistance(this.charger, this.distanceKm);
}
