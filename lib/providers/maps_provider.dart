import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ev_vehicle_model.dart';
import '../models/location_search_result.dart';
import '../models/map_marker_model.dart';
import '../models/recommended_charging_stop.dart';
import '../models/vehicle_model.dart';
import '../repositories/firestore_charger_repository.dart';
import '../repositories/hybrid_charger_repository.dart';
import '../repositories/maps_repository.dart';
import '../services/charging_stop_recommendation_service.dart';
import '../services/maps_service.dart';
import '../services/places_service.dart';
import '../services/trip_energy_calculator.dart';
import '../services/vehicle_service.dart';
import '../models/smart_trip_cost_settings.dart';
import '../services/smart_charger_ranking_service.dart';
import '../services/navigation_launcher_service.dart';
import 'dart:convert';

/// ╔═══════════════════════════════════════════════════════════════════
/// DEBUG FLAG: When true, disables the radius filter and shows EVERY
/// Firestore charger on the map regardless of distance from the user.
/// Set to false before shipping to production.
/// ╚═══════════════════════════════════════════════════════════════════
const bool debugShowAllChargers = true;

class MapsProvider extends ChangeNotifier {
  final HybridChargerRepository _hybridChargerRepository;

  // Retained for backward compatibility
  // ignore: unused_field
  final FirestoreChargerRepository _firestoreChargerRepository;

  // ignore: unused_field — retained as Google Places fallback for future use
  final MapsRepository _mapsRepository;
  final MapsService _mapsService;
  final PlacesService _placesService = PlacesService();

  /// Maximum distance (in km) from the user's GPS position within which
  /// chargers are shown on the map.
  static const double _chargerRadiusKm = 20.0;

  List<MapMarkerModel> _markers = [];
  Map<String, double>? _currentLocation;
  String _discoveryMode = 'gps'; // 'gps', 'search', 'route'
  bool _isLoading = false;
  bool _isLoadingPlaces = false;
  bool _isLoadingRoute = false;

  // GPS / location error state — shown in UI dialog
  String? _locationError;

  // Search autocomplete list & debounce timer
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _searchDebounceTimer;
  String? _searchStatusMessage;
  bool _isSearching = false;

  // Decoded routing & trip planner variables
  List<LatLng> _routePoints = [];
  String? _routeDistance;
  String? _routeDuration;
  LocationSearchResult? _tripOrigin;
  LocationSearchResult? _tripDestination;

  // Phase 4 Step 2A EV Vehicle & Battery Intelligence
  VehicleModel? _selectedVehicle;
  double _currentBatteryPct = 80.0;
  double _safetyBufferPct = 15.0;

  // Phase 4 Step 2B Smart Trip Planning
  SmartTripResult? _smartTripResult;
  bool _isCalculatingSmartTrip = false;
  bool _showAllChargersWhenNoCompatible = false;
  SmartTripCostSettings _costSettings = const SmartTripCostSettings();

  final ChargingStopRecommendationService _recommendationService =
      ChargingStopRecommendationService();

  // Phase 4 Step 4 — Ranking, Sorting, Favorites & Navigation
  SortOption _currentSortOption = SortOption.bestMatch;
  final Set<String> _favoriteChargerIds = {};
  final SmartChargerRankingService _rankingService = const SmartChargerRankingService();
  final NavigationLauncherService _navigationService = const NavigationLauncherService();

  // Selected station bottom sheet info
  MapMarkerModel? _selectedMarker;
  List<PlaceModel> _nearbyPlaces = [];

  // Active filters selection
  final Set<String> _selectedConnectors = {}; // 'CCS2', 'Type 2', 'CHAdeMO'
  final Set<String> _selectedSpeeds = {};      // 'Fast', 'Ultra Fast', 'AC'
  String? _selectedPriceType;                  // 'Free', 'Paid'
  String? _selectedStatusFilter;               // 'Available', 'Busy', 'Offline', 'Unknown'
  String? _selectedNetwork;                    // 'Tata Power', 'Statiq', etc.
  String? _selectedSourceFilter;                 // 'EVHub Verified', 'Google Places'

  // Phase 8 Multi-Combinable Filters
  bool _filterAvailableNow = false;
  bool _filterEVHubVerified = false;
  bool _filterFastCharging = false;
  bool _filterUltraFast = false;
  bool _filterOpenNow = false;
  double? _maxPriceFilter;
  double? _maxRadiusFilter;

  // ─── Real-time Streams ───────────────────────────────────────────────────
  Timer? _autoRefreshTimer;
  StreamSubscription<Position>? _positionStreamSub;
  StreamSubscription<List<MapMarkerModel>>? _firestoreStreamSub;

  MapsProvider({
    required MapsRepository mapsRepository,
    required MapsService mapsService,
    FirestoreChargerRepository? firestoreChargerRepository,
    HybridChargerRepository? hybridChargerRepository,
  })  : _firestoreChargerRepository =
            firestoreChargerRepository ?? FirestoreChargerRepository(),
        _hybridChargerRepository = hybridChargerRepository ??
            HybridChargerRepository(
              firestoreRepository: firestoreChargerRepository,
              mapsService: mapsService,
            ),
        _mapsRepository = mapsRepository,
        _mapsService = mapsService {
    loadTripVehiclePreferences();
  }

  List<MapMarkerModel> get markers => _markers;

  void setMarkers(List<MapMarkerModel> markers) {
    _markers = markers;
    notifyListeners();
  }
  Map<String, double>? get currentLocation => _currentLocation;
  String get discoveryMode => _discoveryMode;
  bool get isLoading => _isLoading;
  bool get isLoadingPlaces => _isLoadingPlaces;
  bool get isLoadingRoute => _isLoadingRoute;
  String? get locationError => _locationError;
  List<Map<String, dynamic>> get suggestions => _suggestions;
  String? get searchStatusMessage => _searchStatusMessage;
  bool get isSearching => _isSearching;
  int get chargersFoundCount => _markers.length;
  List<LatLng> get routePoints => _routePoints;
  String? get routeDistance => _routeDistance;
  String? get routeDuration => _routeDuration;
  LocationSearchResult? get tripOrigin => _tripOrigin;
  LocationSearchResult? get tripDestination => _tripDestination;
  VehicleModel? get selectedVehicle => _selectedVehicle;
  double get currentBatteryPct => _currentBatteryPct;
  double get safetyBufferPct => _safetyBufferPct;

  // Phase 4 Step 2B — Smart Trip getters
  SmartTripResult? get smartTripResult => _smartTripResult;
  bool get isCalculatingSmartTrip => _isCalculatingSmartTrip;
  bool get showAllChargersWhenNoCompatible => _showAllChargersWhenNoCompatible;
  SmartTripCostSettings get costSettings => _costSettings;
  List<RecommendedChargingStop> get recommendedStops =>
      _smartTripResult?.recommendedStops ?? [];

  TripEnergyAnalysisResult get tripEnergyAnalysis {
    double? distKm;
    if (_routeDistance != null) {
      final cleanText = _routeDistance!.replaceAll(RegExp(r'[^0-9.]'), '');
      distKm = double.tryParse(cleanText);
    }

    return TripEnergyCalculator.analyze(
      vehicle: _selectedVehicle,
      batteryPct: _currentBatteryPct,
      tripDistanceKm: distKm,
      safetyBufferPct: _safetyBufferPct,
    );
  }
  MapMarkerModel? get selectedMarker => _selectedMarker;
  List<PlaceModel> get nearbyPlaces => _nearbyPlaces;

  Set<String> get selectedConnectors => _selectedConnectors;
  Set<String> get selectedSpeeds => _selectedSpeeds;
  String? get selectedPriceType => _selectedPriceType;
  String? get selectedStatusFilter => _selectedStatusFilter;
  String? get selectedNetwork => _selectedNetwork;
  String? get selectedSourceFilter => _selectedSourceFilter;

  bool get filterAvailableNow => _filterAvailableNow;
  bool get filterEVHubVerified => _filterEVHubVerified;
  bool get filterFastCharging => _filterFastCharging;
  bool get filterUltraFast => _filterUltraFast;
  bool get filterOpenNow => _filterOpenNow;
  double? get maxPriceFilter => _maxPriceFilter;
  double? get maxRadiusFilter => _maxRadiusFilter;

  // Phase 4 Step 4 — Getters & Actions
  SortOption get currentSortOption => _currentSortOption;
  Set<String> get favoriteChargerIds => _favoriteChargerIds;

  void setSortOption(SortOption option) {
    _currentSortOption = option;
    notifyListeners();
  }

  bool isFavorite(String chargerId) => _favoriteChargerIds.contains(chargerId);

  Future<void> toggleFavorite(String chargerId) async {
    if (_favoriteChargerIds.contains(chargerId)) {
      _favoriteChargerIds.remove(chargerId);
    } else {
      _favoriteChargerIds.add(chargerId);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('favorite_charger_ids', _favoriteChargerIds.toList());
    } catch (_) {}
  }

  Future<void> loadFavoritesFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('favorite_charger_ids');
      if (saved != null) {
        _favoriteChargerIds.clear();
        _favoriteChargerIds.addAll(saved);
        notifyListeners();
      }
    } catch (_) {}
  }

  List<SmartChargerRecommendation> getRankedChargers() {
    final filtered = getFilteredMarkers();
    return _rankingService.rankAndSort(
      chargers: filtered,
      sortOption: _currentSortOption,
      userLocation: _currentLocation,
      vehicleConnectors: _selectedVehicle?.connectorTypes,
      isRouteMode: _discoveryMode == 'route',
    );
  }

  Future<bool> launchExternalNavigation(MapMarkerModel charger) async {
    return _navigationService.launchNavigation(charger.latitude, charger.longitude);
  }

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

  // ─── Real-Time Stream Initialization ─────────────────────────────────────
  void startRealtimeStreams() {
    // 1. Live GPS tracking stream
    _positionStreamSub?.cancel();
    _positionStreamSub = _mapsService.getPositionStream().listen((pos) {
      updateLiveLocation(pos.latitude, pos.longitude);
    }, onError: (e) {
      debugPrint('[MapsProvider] GPS stream error: $e');
    });

    // 2. Real-time Firestore chargers stream
    _firestoreStreamSub?.cancel();
    _firestoreStreamSub = _firestoreChargerRepository.streamPublicVerifiedChargers().listen((verifiedChargers) {
      debugPrint('[MapsProvider] Real-time Firestore update: ${verifiedChargers.length} verified chargers');
      _updateFirestoreMarkersInList(verifiedChargers);
    }, onError: (e) {
      debugPrint('[MapsProvider] Firestore stream error: $e');
    });
  }

  void _updateFirestoreMarkersInList(List<MapMarkerModel> verifiedChargers) {
    if (_discoveryMode != 'gps') return; // Do not overwrite search or route markers
    if (_markers.isEmpty) {
      _markers = verifiedChargers;
      notifyListeners();
      return;
    }

    final Map<String, MapMarkerModel> markerMap = {for (var m in _markers) m.id: m};
    for (final v in verifiedChargers) {
      markerMap[v.id] = v;
    }

    _markers = markerMap.values.toList();
    if (_currentLocation != null) {
      final lat = _currentLocation!['latitude']!;
      final lng = _currentLocation!['longitude']!;
      updateLiveLocation(lat, lng);
    } else {
      notifyListeners();
    }
  }

  // ─── Start auto-refresh timer ─────────────────────────────────────────────
  void startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      debugPrint('[MapsProvider] Auto-refresh: fetching updated charger list');
      await refreshStations();
    });
    startRealtimeStreams();
  }

  void stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    _positionStreamSub?.cancel();
    _firestoreStreamSub?.cancel();
    _positionStreamSub = null;
    _firestoreStreamSub = null;
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    stopAutoRefresh();
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

      if (errMsg.contains('disabled')) {
        _locationError = 'Location services are disabled. Please enable GPS to find chargers near you.';
      } else if (errMsg.contains('permanently denied')) {
        _locationError = 'Location permission was permanently denied. Please enable it in App Settings.';
      } else if (errMsg.contains('denied')) {
        _locationError = 'Location permission was denied. Showing chargers near New Delhi.';
      } else {
        _locationError = 'Could not determine your location. Showing chargers near New Delhi.';
      }

      _currentLocation = {
        'latitude': 28.6304,
        'longitude': 77.2177,
      };
    }

    await refreshStations();
    _isLoading = false;
    notifyListeners();

    startAutoRefresh();
  }

  void clearLocationError() {
    _locationError = null;
    notifyListeners();
  }

  // ─── Refresh chargers listing (Hybrid: Firestore + Google Places) ──────────────
  Future<void> refreshStations({double? radiusKm}) async {
    if (_currentLocation == null) {
      debugPrint('[MapsProvider] refreshStations() skipped — currentLocation is null');
      return;
    }
    if (_discoveryMode != 'gps' && radiusKm == null) {
      debugPrint('[MapsProvider] refreshStations() skipped — active discovery mode is $_discoveryMode');
      return;
    }
    _discoveryMode = 'gps';
    try {
      debugPrint('[MapsProvider] ── refreshStations() START (Mode: GPS) ──');

      final userLat = _currentLocation!['latitude']!;
      final userLng = _currentLocation!['longitude']!;

      final rawFirestoreDocs = await _firestoreChargerRepository.getPublicVerifiedChargers();
      final validCoordsDocs = rawFirestoreDocs.where((c) => c.hasValidCoordinates).toList();

      final chargers = await _hybridChargerRepository.searchNearbyChargers(
        latitude: userLat,
        longitude: userLng,
        initialRadiusKm: radiusKm ?? _chargerRadiusKm,
      );

      _markers = chargers;
      final filteredCount = getFilteredMarkers().length;

      debugPrint(
        '[MAP-DIAGNOSTIC]\n'
        'Mode: GPS\n'
        'Number of chargers fetched from Firestore: ${rawFirestoreDocs.length}\n'
        'Number of valid chargers after coordinate validation: ${validCoordsDocs.length}\n'
        'Current map center: ($userLat, $userLng)\n'
        'Search location coordinates: N/A (GPS Mode)\n'
        'GPS coordinates: ($userLat, $userLng)\n'
        'Number of chargers returned by nearby filtering: ${_markers.length}\n'
        'Number of Google Maps Marker objects generated: $filteredCount',
      );

      _searchStatusMessage = '${_markers.length} chargers found near your location';
      notifyListeners();
    } catch (e) {
      debugPrint('[MapsProvider] Error refreshing stations: $e');
    }
  }

  void clearSearchStatus() {
    _searchStatusMessage = null;
    notifyListeners();
  }

  // ─── Search Autocomplete with Debounce & Unified Classification ───────────
  void searchSuggestions(String query) {
    _searchDebounceTimer?.cancel();
    if (query.trim().length < 2) {
      _suggestions = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final cleanQuery = query.trim();
      final List<Map<String, dynamic>> combinedSuggestions = [];

      try {
        // 1. Network & Connector Keyword Match
        final knownNetworks = ['Tata Power', 'Statiq', 'Jio-bp', 'Zeon', 'ChargeZone', 'Shell Recharge', 'Kazam', 'Ather Grid'];
        for (final net in knownNetworks) {
          if (net.toLowerCase().contains(cleanQuery.toLowerCase())) {
            combinedSuggestions.add({
              'description': '$net EV Network',
              'type': 'network',
              'network': net,
              'subtitle': 'Search all $net charging stations',
            });
          }
        }

        final knownConnectors = ['CCS2', 'Type 2', 'CHAdeMO', 'Bharat DC-001', 'Bharat AC-001', 'GB/T'];
        for (final conn in knownConnectors) {
          if (conn.toLowerCase().contains(cleanQuery.toLowerCase())) {
            combinedSuggestions.add({
              'description': '$conn Connectors',
              'type': 'connector',
              'connector': conn,
              'subtitle': 'Filter stations supporting $conn',
            });
          }
        }

        // 2. Query Firestore for matching chargers
        final firestoreMatches = await _firestoreChargerRepository.searchChargers(cleanQuery);
        for (final charger in firestoreMatches.take(4)) {
          combinedSuggestions.add({
            'description': charger.title,
            'type': 'station',
            'charger': charger,
            'subtitle': '${charger.network} • ${charger.city ?? charger.address ?? 'Station'}',
          });
        }

        // 3. Query Google Places Autocomplete API for location search suggestions
        final lat = _currentLocation?['latitude'];
        final lng = _currentLocation?['longitude'];
        final placePredictions = await _mapsService.getAutocompleteSuggestions(
          cleanQuery,
          currentLat: lat,
          currentLng: lng,
        );

        for (final pred in placePredictions) {
          combinedSuggestions.add({
            'description': pred['description'] as String,
            'place_id': pred['place_id'] as String? ?? '',
            'type': 'location',
            'subtitle': pred['subtitle'] as String? ?? 'Location search',
            'latitude': pred['latitude'],
            'longitude': pred['longitude'],
            'source': pred['source'] ?? 'google_places',
          });
        }
      } catch (e) {
        debugPrint('[MapsProvider] Combined search suggestions error: $e');
      }

      _suggestions = combinedSuggestions;
      _isSearching = false;
      debugPrint(
        '[SEARCH-REGRESSION-DIAGNOSTIC] Provider searchSuggestions finished for query: "$cleanQuery"\n'
        '[SEARCH-COMBINE-DIAGNOSTIC] Total provider suggestions: ${_suggestions.length}',
      );
      notifyListeners();
    });
  }

  /// Execute selected search suggestion (Location, Network, Station, Connector)
  Future<void> selectSuggestion(
    Map<String, dynamic> suggestion,
    Function(LatLng coordinates, {double? zoom}) onNavigate,
  ) async {
    debugPrint('[SEARCH-SELECTION-DIAGNOSTIC] selectSuggestion() called');
    _suggestions = [];
    _isLoading = true;
    notifyListeners();

    try {
      final type = suggestion['type'] as String?;

      if (type == 'location') {
        final placeId = suggestion['place_id'] as String?;
        final description = suggestion['description'] as String;
        final rawLat = suggestion['latitude'];
        final rawLng = suggestion['longitude'];

        LatLng? coords;
        if (rawLat is num && rawLng is num) {
          debugPrint('[SEARCH-SELECTION-DIAGNOSTIC] Using direct coordinates: ($rawLat, $rawLng)');
          coords = LatLng(rawLat.toDouble(), rawLng.toDouble());
        } else if (placeId != null && placeId.isNotEmpty && placeId.startsWith('ChI')) {
          debugPrint('[SEARCH-SELECTION-DIAGNOSTIC] Resolving coordinates for place_id: $placeId');
          coords = await _mapsService.getPlaceCoordinates(placeId);
        }
        coords ??= await _mapsService.getCoordinatesFromAddress(description);

        if (coords != null) {
          _discoveryMode = 'search';
          final cityName = description.split(',').first.trim();
          _currentLocation = {
            'latitude': coords.latitude,
            'longitude': coords.longitude,
          };

          debugPrint('[SEARCH-CAMERA-DIAGNOSTIC] Moving camera to: ${coords.latitude}, ${coords.longitude}');
          onNavigate(coords, zoom: 12.0);

          debugPrint(
            '[MAP-SEARCH-DIAGNOSTIC]\n'
            'Selected location: $cityName\n'
            'Latitude: ${coords.latitude}\n'
            'Longitude: ${coords.longitude}\n'
            'Camera moved: true',
          );

          final nearby = await _hybridChargerRepository.searchNearbyChargers(
            latitude: coords.latitude,
            longitude: coords.longitude,
          );

          _markers = nearby;
          final rawDocs = await _firestoreChargerRepository.getPublicVerifiedChargers();
          final visible = getFilteredMarkers();

          debugPrint(
            '[CHARGER-VISIBILITY-DIAGNOSTIC]\n'
            'Search location: $cityName\n'
            'Search latitude: ${coords.latitude}\n'
            'Search longitude: ${coords.longitude}\n'
            'Firestore documents fetched: ${rawDocs.length}\n'
            'Valid charger documents: ${rawDocs.where((c) => c.hasValidCoordinates).length}\n'
            'Chargers after coordinate parsing: ${rawDocs.where((c) => c.hasValidCoordinates).length}\n'
            'Chargers after radius filtering: ${_markers.length}\n'
            'Chargers returned: ${_markers.length}\n'
            'Markers generated: ${visible.length}\n'
            'Markers currently stored in provider: ${visible.length}\n'
            'Markers passed to GoogleMap: ${visible.length}'
          );

          for (final c in visible) {
            debugPrint(
              '[CHARGER-DETAILS-DIAGNOSTIC]\n'
              'Charger ID: ${c.id}\n'
              'Charger name: ${c.title}\n'
              'Latitude: ${c.latitude}\n'
              'Longitude: ${c.longitude}\n'
              'Distance from searched location: ${c.distanceKm ?? 0.0} km\n'
              'Source: ${c.source}\n'
              'Connector types: ${c.connectors.join(", ")}'
            );
          }

          if (visible.isNotEmpty) {
            _searchStatusMessage = '${visible.length} chargers found near $cityName';
          } else if (_markers.isNotEmpty) {
            _searchStatusMessage = '0 chargers match active filters (${_markers.length} nearby)';
          } else {
            _searchStatusMessage = 'No chargers found near $cityName. Try expanding your search.';
          }
        } else {
          _searchStatusMessage = 'Could not find location coordinates for "$description"';
        }
      } else if (type == 'network') {
        final network = suggestion['network'] as String;
        setNetworkFilter(network);
        _searchStatusMessage = 'Filtered by network: $network';
        
        final filtered = getFilteredMarkers();
        if (filtered.isNotEmpty) {
          final first = filtered.first;
          onNavigate(LatLng(first.latitude, first.longitude), zoom: 12.0);
        }
      } else if (type == 'station') {
        final charger = suggestion['charger'] as MapMarkerModel;
        _selectedMarker = charger;
        _currentLocation = {
          'latitude': charger.latitude,
          'longitude': charger.longitude,
        };
        _searchStatusMessage = 'Selected: ${charger.title}';
        onNavigate(LatLng(charger.latitude, charger.longitude), zoom: 16.0);
        fetchNearbyPlacesForSelected();
      } else if (type == 'connector') {
        final connector = suggestion['connector'] as String;
        toggleConnectorFilter(connector);
        _searchStatusMessage = 'Filtered by connector: $connector';
      }
    } catch (e) {
      debugPrint('[MapsProvider] Error executing suggestion: $e');
      _searchStatusMessage = 'Search failed, try again';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Select place from autocomplete or direct location search ─────────────
  Future<void> selectPlace(String placeIdOrQuery, Function(LatLng) onCoordinatesFetched) async {
    _isLoading = true;
    notifyListeners();
    try {
      LatLng? coords;
      if (placeIdOrQuery.startsWith('ChI') && placeIdOrQuery.length > 20) {
        coords = await _mapsService.getPlaceCoordinates(placeIdOrQuery);
      }
      coords ??= await _mapsService.getCoordinatesFromAddress(placeIdOrQuery);

      if (coords != null) {
        _discoveryMode = 'search';
        onCoordinatesFetched(coords);
        final cleanName = placeIdOrQuery.split(',').first.trim();
        _currentLocation = {
          'latitude': coords.latitude,
          'longitude': coords.longitude,
        };

        debugPrint(
          '[MAP-SEARCH-DIAGNOSTIC]\n'
          'Selected location: $cleanName\n'
          'Latitude: ${coords.latitude}\n'
          'Longitude: ${coords.longitude}\n'
          'Camera moved: true',
        );

        final nearby = await _hybridChargerRepository.searchNearbyChargers(
          latitude: coords.latitude,
          longitude: coords.longitude,
        );
        _markers = nearby;
        _suggestions = [];

        final rawDocs = await _firestoreChargerRepository.getPublicVerifiedChargers();

        debugPrint(
          '[CHARGER-SEARCH-DIAGNOSTIC]\n'
          'Search location: $cleanName\n'
          'Coordinates: ${coords.latitude}, ${coords.longitude}\n'
          'Firestore records fetched: ${rawDocs.length}\n'
          'Valid charger records: ${rawDocs.length}\n'
          'Chargers within radius: ${_markers.length}\n'
          'Final markers: ${getFilteredMarkers().length}',
        );

        if (_markers.isNotEmpty) {
          _searchStatusMessage = '${_markers.length} chargers found near $cleanName';
        } else {
          _searchStatusMessage = 'No chargers found near $cleanName. Try expanding your search.';
        }
      } else {
        _searchStatusMessage = 'Could not find location coordinates for "$placeIdOrQuery"';
      }
    } catch (e) {
      debugPrint('[MapsProvider] Error selecting place: $e');
      _searchStatusMessage = 'Search failed, try again';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Directions route ─────────────────────────────────────────────────────
  // ─── Mode 3: Route Chargers & Directions Corridor Engine ──────────────────
  Future<void> calculateRoute(LatLng dest) async {
    if (_currentLocation == null) return;
    final origin = LatLng(_currentLocation!['latitude']!, _currentLocation!['longitude']!);
    await calculateRouteBetween(origin, dest);
  }

  Future<void> calculateRouteBetween(LatLng origin, LatLng dest) async {
    _discoveryMode = 'route';
    _isLoadingRoute = true;
    _isLoading = true;
    notifyListeners();

    try {
      final directions = await _mapsService.getDirections(origin, dest);
      if (directions != null) {
        _routePoints = directions['points'] as List<LatLng>;
        _routeDistance = directions['distance'] as String;
        _routeDuration = directions['duration'] as String;

        final rawDocs = await _firestoreChargerRepository.getPublicVerifiedChargers();
        final validCoordsDocs = rawDocs.where((c) => c.hasValidCoordinates).toList();

        // Fetch route corridor chargers within 10 km corridor of the polyline
        final routeChargers = await _hybridChargerRepository.searchRouteCorridorChargers(
          polylinePoints: _routePoints,
          corridorRadiusKm: 10.0,
        );
        _markers = routeChargers;
        final visible = getFilteredMarkers();

        debugPrint(
          '[MAP-DIAGNOSTIC]\n'
          'Mode: Route\n'
          'Origin: (${origin.latitude}, ${origin.longitude})\n'
          'Destination: (${dest.latitude}, ${dest.longitude})\n'
          'Polyline points: ${_routePoints.length}\n'
          'Number of chargers fetched from Firestore: ${rawDocs.length}\n'
          'Number of valid chargers after coordinate validation: ${validCoordsDocs.length}\n'
          'Number of chargers returned by route corridor filtering (10km): ${_markers.length}\n'
          'Number of Google Maps Marker objects generated: ${visible.length}',
        );

        _searchStatusMessage = '${visible.length} chargers found along 10 km route corridor';
      }
    } catch (e) {
      debugPrint('[MapsProvider] Route corridor error: $e');
      _searchStatusMessage = 'Route calculation failed';
    } finally {
      _isLoadingRoute = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  void setTripOrigin(LocationSearchResult? origin) {
    _tripOrigin = origin;
    notifyListeners();
  }

  void setTripDestination(LocationSearchResult? dest) {
    _tripDestination = dest;
    notifyListeners();
  }

  Future<void> loadTripVehiclePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVehicleId = prefs.getString('trip_vehicle_id');
      final savedBatteryPct = prefs.getDouble('trip_battery_pct');
      final savedSafetyBufferPct = prefs.getDouble('trip_safety_buffer_pct');

      if (savedBatteryPct != null) {
        _currentBatteryPct = savedBatteryPct.clamp(0.0, 100.0);
      }
      if (savedSafetyBufferPct != null) {
        _safetyBufferPct = savedSafetyBufferPct;
      }

      final availableVehicles = VehicleService.indianEVEcosystem;
      if (savedVehicleId != null) {
        _selectedVehicle = availableVehicles.firstWhere(
          (v) => v.id == savedVehicleId,
          orElse: () => availableVehicles.first,
        );
      } else {
        _selectedVehicle = availableVehicles.first;
      }
      
      // Phase 4 Step 3 Cost Settings
      final savedCostSettings = prefs.getString('trip_cost_settings');
      if (savedCostSettings != null) {
        try {
          _costSettings = SmartTripCostSettings.fromJson(json.decode(savedCostSettings));
        } catch (e) {
          debugPrint('[MapsProvider] Error parsing cost settings: $e');
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[MapsProvider] Load vehicle preferences error: $e');
    }
  }

  Future<void> setSelectedVehicle(VehicleModel? vehicle) async {
    _selectedVehicle = vehicle;
    notifyListeners();

    if (vehicle != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('trip_vehicle_id', vehicle.id);
      } catch (e) {
        debugPrint('[MapsProvider] Save vehicle error: $e');
      }
    }

    // Phase 4 Step 2B: Recalculate smart trip when vehicle changes
    await recalculateSmartTripIfActive();
  }

  Future<void> setCurrentBatteryPct(double pct) async {
    _currentBatteryPct = pct.clamp(0.0, 100.0);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('trip_battery_pct', _currentBatteryPct);
    } catch (e) {
      debugPrint('[MapsProvider] Save battery % error: $e');
    }

    // Phase 4 Step 2B: Recalculate smart trip when battery changes
    await recalculateSmartTripIfActive();
  }

  Future<void> setSafetyBufferPct(double bufferPct) async {
    _safetyBufferPct = bufferPct;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('trip_safety_buffer_pct', _safetyBufferPct);
    } catch (e) {
      debugPrint('[MapsProvider] Save safety buffer error: $e');
    }
  }

  Future<void> updateCostSettings(SmartTripCostSettings newSettings) async {
    _costSettings = newSettings;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('trip_cost_settings', json.encode(_costSettings.toJson()));
    } catch (e) {
      debugPrint('[MapsProvider] Save cost settings error: $e');
    }

    // Recalculate smart trip since costs changed
    await recalculateSmartTripIfActive();
  }

  Future<void> planTrip({
    required LocationSearchResult origin,
    required LocationSearchResult destination,
  }) async {
    _tripOrigin = origin;
    _tripDestination = destination;
    _discoveryMode = 'route';
    _smartTripResult = null;
    notifyListeners();

    await calculateRouteBetween(origin.coordinates, destination.coordinates);

    // Phase 4 Step 2B: Calculate smart charging stop recommendations
    if (_routePoints.isNotEmpty && _selectedVehicle != null) {
      await _calculateSmartTrip(origin.coordinates, destination.coordinates);
    }
  }

  /// Calculates smart charging stop recommendations using the existing
  /// route corridor chargers already fetched into [_markers].
  Future<void> _calculateSmartTrip(LatLng origin, LatLng dest) async {
    if (_selectedVehicle == null || _routePoints.isEmpty) return;
    _isCalculatingSmartTrip = true;
    notifyListeners();

    try {
      final evVehicle = EVVehicleModel.fromVehicleModel(_selectedVehicle!);
      final result = _recommendationService.recommend(
        origin: origin,
        destination: dest,
        polylinePoints: _routePoints,
        vehicle: evVehicle,
        currentBatteryPct: _currentBatteryPct,
        routeChargers: _markers,
        costSettings: _costSettings,
        safetyReservePct: _safetyBufferPct,
        preferCompatibleOnly: !_showAllChargersWhenNoCompatible,
      );
      _smartTripResult = result;
      debugPrint(
          '[MapsProvider] Smart trip: ${result.recommendedStops.length} stops, '
          'charging required: ${result.chargingRequired}');
    } catch (e) {
      debugPrint('[MapsProvider] Smart trip calculation error: $e');
    } finally {
      _isCalculatingSmartTrip = false;
      notifyListeners();
    }
  }

  /// Recalculates smart trip when vehicle or battery changes after a route is active.
  Future<void> recalculateSmartTripIfActive() async {
    if (_discoveryMode != 'route' ||
        _routePoints.isEmpty ||
        _tripOrigin == null ||
        _tripDestination == null) {
      return;
    }
    await _calculateSmartTrip(
      _tripOrigin!.coordinates,
      _tripDestination!.coordinates,
    );
  }

  /// Toggle show-all-chargers fallback when no compatible charger found.
  Future<void> setShowAllChargersWhenNoCompatible(bool value) async {
    _showAllChargersWhenNoCompatible = value;
    notifyListeners();
    await recalculateSmartTripIfActive();
  }

  void clearRoute() {
    _discoveryMode = 'gps';
    _routePoints = [];
    _routeDistance = null;
    _routeDuration = null;
    _tripOrigin = null;
    _tripDestination = null;
    // Phase 4 Step 2B: Clear smart trip state
    _smartTripResult = null;
    _isCalculatingSmartTrip = false;
    _showAllChargersWhenNoCompatible = false;
    if (_currentLocation != null) {
      fetchCurrentLocationAndStations();
    } else {
      notifyListeners();
    }
  }

  void clearTrip() => clearRoute();

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
    _markers = _markers.map((m) {
      final distMeters = Geolocator.distanceBetween(lat, lng, m.latitude, m.longitude);
      return m.copyWith(distanceKm: distMeters / 1000.0);
    }).toList();
    notifyListeners();
  }

  // ─── Phase 8 Multi-Combinable Filter Toggles ─────────────────────────────
  void toggleFilterAvailableNow() {
    _filterAvailableNow = !_filterAvailableNow;
    notifyListeners();
  }

  void toggleFilterEVHubVerified() {
    _filterEVHubVerified = !_filterEVHubVerified;
    notifyListeners();
  }

  void toggleFilterFastCharging() {
    _filterFastCharging = !_filterFastCharging;
    notifyListeners();
  }

  void toggleFilterUltraFast() {
    _filterUltraFast = !_filterUltraFast;
    notifyListeners();
  }

  void toggleFilterOpenNow() {
    _filterOpenNow = !_filterOpenNow;
    notifyListeners();
  }

  void setMaxPriceFilter(double? price) {
    _maxPriceFilter = price;
    notifyListeners();
  }

  void setMaxRadiusFilter(double? radius) {
    _maxRadiusFilter = radius;
    notifyListeners();
  }

  // ─── Legacy Filters ──────────────────────────────────────────────────────
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

  void setSourceFilter(String? source) {
    _selectedSourceFilter = _selectedSourceFilter == source ? null : source;
    notifyListeners();
  }

  void clearAllFilters() {
    _selectedConnectors.clear();
    _selectedSpeeds.clear();
    _selectedPriceType = null;
    _selectedStatusFilter = null;
    _selectedNetwork = null;
    _selectedSourceFilter = null;
    _filterAvailableNow = false;
    _filterEVHubVerified = false;
    _filterFastCharging = false;
    _filterUltraFast = false;
    _filterOpenNow = false;
    _maxPriceFilter = null;
    _maxRadiusFilter = null;
    notifyListeners();
  }

  // ─── Multi-Combinable Filtered Markers Generator ────────────────────────
  List<MapMarkerModel> getFilteredMarkers() {
    return _markers.where((m) {
      // 0. Coordinate Validity Check
      if (!m.hasValidCoordinates) return false;

      // 1. Available Now
      if (_filterAvailableNow) {
        if (m.computedStatus != MarkerStatus.available || m.availableConnectorsCount <= 0) {
          return false;
        }
      }

      // 2. EVHub Verified
      if (_filterEVHubVerified) {
        if (m.source != 'evhub_verified' || !m.isVerified) return false;
      }

      // 3. Fast Charging
      if (_filterFastCharging) {
        final powerKw = double.tryParse(m.power.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        if (powerKw < 22.0 || powerKw >= 100.0) return false;
      }

      // 4. Ultra Fast
      if (_filterUltraFast) {
        final powerKw = double.tryParse(m.power.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        if (powerKw < 100.0) return false;
      }

      // 5. Open Now
      if (_filterOpenNow) {
        if (m.openStatus?.toLowerCase() != 'open') return false;
      }

      // 6. Max Price
      if (_maxPriceFilter != null) {
        final priceVal = double.tryParse(m.price?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '') ?? 0.0;
        if (priceVal > _maxPriceFilter!) return false;
      }

      // 7. Max Radius
      if (_maxRadiusFilter != null && m.distanceKm != null) {
        if (m.distanceKm! > _maxRadiusFilter!) return false;
      }

      // 8. Connectors
      if (_selectedConnectors.isNotEmpty) {
        if (!m.connectors.any((c) => _selectedConnectors.contains(c))) return false;
      }

      // 9. Speeds
      if (_selectedSpeeds.isNotEmpty) {
        if (!_selectedSpeeds.contains(m.powerType)) return false;
      }

      // 10. Price Type
      if (_selectedPriceType != null) {
        final isFree = m.price?.toLowerCase().contains('free') ?? false;
        if (_selectedPriceType == 'Free' && !isFree) return false;
        if (_selectedPriceType == 'Paid' && isFree) return false;
      }

      // 11. Status Filter
      if (_selectedStatusFilter != null) {
        if (_selectedStatusFilter == 'Available' && m.computedStatus != MarkerStatus.available) return false;
        if (_selectedStatusFilter == 'Busy' && m.computedStatus != MarkerStatus.busy) return false;
        if (_selectedStatusFilter == 'Offline' && m.computedStatus != MarkerStatus.offline) return false;
        if (_selectedStatusFilter == 'Unknown' && m.computedStatus != MarkerStatus.unknown) return false;
      }

      // 12. Network Filter
      if (_selectedNetwork != null) {
        if (!m.network.toLowerCase().contains(_selectedNetwork!.toLowerCase())) return false;
      }

      // 13. Source Filter
      if (_selectedSourceFilter != null) {
        if (_selectedSourceFilter == 'EVHub Verified' && m.source != 'evhub_verified') return false;
        if (_selectedSourceFilter == 'Google Places' && m.source != 'google_places') return false;
      }

      return true;
    }).toList();
  }
}
