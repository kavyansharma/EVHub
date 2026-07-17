import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/map_marker_model.dart';
import '../repositories/maps_repository.dart';
import '../services/maps_service.dart';
import '../services/places_service.dart';

class MapsProvider extends ChangeNotifier {
  final MapsRepository _mapsRepository;
  final MapsService _mapsService;
  final PlacesService _placesService = PlacesService();

  List<MapMarkerModel> _markers = [];
  Map<String, double>? _currentLocation;
  bool _isLoading = false;
  bool _isLoadingPlaces = false;
  bool _isLoadingRoute = false;

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

  MapsProvider({
    required MapsRepository mapsRepository,
    required MapsService mapsService,
  })  : _mapsRepository = mapsRepository,
        _mapsService = mapsService;

  // Getters
  List<MapMarkerModel> get markers => _markers;
  Map<String, double>? get currentLocation => _currentLocation;
  bool get isLoading => _isLoading;
  bool get isLoadingPlaces => _isLoadingPlaces;
  bool get isLoadingRoute => _isLoadingRoute;
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

  // Fetch location and load real stations via Nearby Search API
  Future<void> fetchCurrentLocationAndStations() async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentLocation = await _mapsService.getCurrentLocation();
      if (_currentLocation != null) {
        await refreshStations();
      }
    } catch (e) {
      debugPrint("Error fetching maps location, falling back: $e");
      _currentLocation = {
        'latitude': 28.6304,
        'longitude': 77.2177, // Connaught Place, New Delhi default
      };
      await refreshStations();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refresh chargers listing
  Future<void> refreshStations() async {
    if (_currentLocation == null) return;
    try {
      _markers = await _mapsRepository.getStationsNearLocation(
        _currentLocation!['latitude']!,
        _currentLocation!['longitude']!,
        50.0, // 50km search radius
      );
    } catch (e) {
      debugPrint("Error refreshing stations: $e");
    }
  }

  // Search Autocomplete Suggestion triggers
  Future<void> searchSuggestions(String query) async {
    if (query.isEmpty) {
      _suggestions = [];
      notifyListeners();
      return;
    }
    try {
      double? lat = _currentLocation?['latitude'];
      double? lng = _currentLocation?['longitude'];
      _suggestions = await _mapsService.getAutocompleteSuggestions(
        query,
        currentLat: lat,
        currentLng: lng,
      );
      notifyListeners();
    } catch (e) {
      debugPrint("Autocomplete suggest error: $e");
    }
  }

  // Select place and trigger callback to center map camera
  Future<void> selectPlace(String placeId, Function(LatLng) onCoordinatesFetched) async {
    try {
      final coords = await _mapsService.getPlaceCoordinates(placeId);
      if (coords != null) {
        onCoordinatesFetched(coords);
        
        // Refresh stations nearby the selected search result
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
      debugPrint("Error selecting place autocomplete: $e");
    }
  }

  // Fetch directions route path
  Future<void> calculateRoute(LatLng dest) async {
    if (_currentLocation == null) return;
    _isLoadingRoute = true;
    notifyListeners();

    try {
      final origin = LatLng(_currentLocation!['latitude']!, _currentLocation!['longitude']!);
      final directions = await _mapsService.getDirections(origin, dest);
      if (directions != null) {
        _routePoints = directions['points'] as List<LatLng>;
        _routeDistance = directions['distance'] as String;
        _routeDuration = directions['duration'] as String;
      }
    } catch (e) {
      debugPrint("Error calculating route: $e");
    } finally {
      _isLoadingRoute = false;
      notifyListeners();
    }
  }

  // Clear polyline routes
  void clearRoute() {
    _routePoints = [];
    _routeDistance = null;
    _routeDuration = null;
    notifyListeners();
  }

  // Selected marker state management
  void setSelectedMarker(MapMarkerModel? marker) {
    _selectedMarker = marker;
    _nearbyPlaces = [];
    if (marker != null) {
      fetchNearbyPlacesForSelected();
    }
    notifyListeners();
  }

  // Query Google Places Nearby API for local restaurants/cafes/etc. surrounding selected station
  Future<void> fetchNearbyPlacesForSelected() async {
    if (_selectedMarker == null) return;
    _isLoadingPlaces = true;
    notifyListeners();

    try {
      _nearbyPlaces = await _placesService.getNearbyPlaces(
        _selectedMarker!.latitude,
        _selectedMarker!.longitude,
      );
    } catch (e) {
      debugPrint("Error fetching places nearby selected marker: $e");
    } finally {
      _isLoadingPlaces = false;
      notifyListeners();
    }
  }

  // Update Location coordinates during live tracking
  void updateLiveLocation(double lat, double lng) {
    _currentLocation = {
      'latitude': lat,
      'longitude': lng,
    };
    notifyListeners();
  }

  // Filters setup triggers
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

  // Get filtered markers list matching all active filter parameters
  List<MapMarkerModel> getFilteredMarkers() {
    return _markers.where((m) {
      // 1. Connector Type Filter
      if (_selectedConnectors.isNotEmpty) {
        final matches = m.connectors.any((c) => _selectedConnectors.contains(c));
        if (!matches) return false;
      }

      // 2. Speed Filter
      if (_selectedSpeeds.isNotEmpty) {
        if (!_selectedSpeeds.contains(m.powerType)) return false;
      }

      // 3. Pricing Filter
      if (_selectedPriceType != null) {
        final isFree = m.price?.toLowerCase().contains('free') ?? false;
        if (_selectedPriceType == 'Free' && !isFree) return false;
        if (_selectedPriceType == 'Paid' && isFree) return false;
      }

      // 4. Status Filter
      if (_selectedStatusFilter != null) {
        if (_selectedStatusFilter == 'Available' && m.status != MarkerStatus.available) return false;
        if (_selectedStatusFilter == 'Busy' && m.status != MarkerStatus.busy) return false;
      }

      // 5. Network Filter
      if (_selectedNetwork != null) {
        if (!m.network.toLowerCase().contains(_selectedNetwork!.toLowerCase())) return false;
      }

      return true;
    }).toList();
  }
}
