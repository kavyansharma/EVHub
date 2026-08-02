import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/map_marker_model.dart';
import '../models/location_search_result.dart';
import '../core/constants/app_constants.dart';

class MapsService {
  final String _apiKey = AppConstants.googleMapsApiKey;

  // Build the request URI, supporting CORS proxy on Web
  Uri _buildUri(String path, Map<String, String> queryParameters) {
    final baseUri = Uri.https('maps.googleapis.com', path, queryParameters);
    if (kIsWeb) {
      return Uri.parse('https://corsproxy.io/?${Uri.encodeComponent(baseUri.toString())}');
    }
    return baseUri;
  }

  // 1. Google Places Nearby Search for EV Chargers
  Future<List<MapMarkerModel>> getNearbyStations(double lat, double lng, double radiusKm) async {
    final double radiusMeters = radiusKm * 1000;
    final queryParams = {
      'location': '$lat,$lng',
      'radius': '${radiusMeters.toInt()}',
      'keyword': 'EV Charging Station',
      'key': _apiKey,
    };
    final url = _buildUri('/maps/api/place/nearbysearch/json', queryParams);

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>?;
        if (results != null) {
          return results.map((place) => _parsePlaceToMarker(place, lat, lng)).toList();
        }
      }
    } catch (e) {
      debugPrint("Google Places Nearby search error: $e");
    }

    return [];
  }

  static final Map<String, Map<String, dynamic>> _cityMetadataLookup = {
    'delhi': {'title': 'Delhi', 'subtitle': 'National Capital Territory, India', 'lat': 28.6139, 'lng': 77.2090, 'aliases': ['new delhi', 'delhi ncr', 'newdelhi', 'dilli']},
    'new delhi': {'title': 'New Delhi', 'subtitle': 'Delhi, India', 'lat': 28.6139, 'lng': 77.2090, 'aliases': ['delhi', 'dilli']},
    'connaught place': {'title': 'Connaught Place', 'subtitle': 'New Delhi, Delhi, India', 'lat': 28.6304, 'lng': 77.2177, 'aliases': ['cp delhi', 'cp']},
    'gurugram': {'title': 'Gurugram', 'subtitle': 'Haryana, India', 'lat': 28.4595, 'lng': 77.0266, 'aliases': ['gurgaon']},
    'gurgaon': {'title': 'Gurugram (Gurgaon)', 'subtitle': 'Haryana, India', 'lat': 28.4595, 'lng': 77.0266, 'aliases': ['gurugram']},
    'noida': {'title': 'Noida', 'subtitle': 'Uttar Pradesh, India', 'lat': 28.5355, 'lng': 77.3910, 'aliases': ['greater noida', 'noida ncr']},
    'bengaluru': {'title': 'Bengaluru', 'subtitle': 'Karnataka, India', 'lat': 12.9716, 'lng': 77.5946, 'aliases': ['bangalore']},
    'bangalore': {'title': 'Bengaluru (Bangalore)', 'subtitle': 'Karnataka, India', 'lat': 12.9716, 'lng': 77.5946, 'aliases': ['bengaluru']},
    'chennai': {'title': 'Chennai', 'subtitle': 'Tamil Nadu, India', 'lat': 13.0827, 'lng': 80.2707, 'aliases': ['madras']},
    'mumbai': {'title': 'Mumbai', 'subtitle': 'Maharashtra, India', 'lat': 19.0760, 'lng': 72.8777, 'aliases': ['bombay']},
    'hyderabad': {'title': 'Hyderabad', 'subtitle': 'Telangana, India', 'lat': 17.3850, 'lng': 78.4867, 'aliases': ['secunderabad']},
    'pune': {'title': 'Pune', 'subtitle': 'Maharashtra, India', 'lat': 18.5204, 'lng': 73.8567, 'aliases': ['poona']},
    'kolkata': {'title': 'Kolkata', 'subtitle': 'West Bengal, India', 'lat': 22.5726, 'lng': 88.3639, 'aliases': ['calcutta']},
    'ahmedabad': {'title': 'Ahmedabad', 'subtitle': 'Gujarat, India', 'lat': 23.0225, 'lng': 72.5714, 'aliases': ['amdavad']},
    'jaipur': {'title': 'Jaipur', 'subtitle': 'Rajasthan, India', 'lat': 26.9124, 'lng': 75.7873, 'aliases': ['pink city']},
    'surat': {'title': 'Surat', 'subtitle': 'Gujarat, India', 'lat': 21.1702, 'lng': 72.8311, 'aliases': []},
    'kochi': {'title': 'Kochi', 'subtitle': 'Kerala, India', 'lat': 9.9312, 'lng': 76.2673, 'aliases': ['cochin']},
    'coimbatore': {'title': 'Coimbatore', 'subtitle': 'Tamil Nadu, India', 'lat': 11.0168, 'lng': 76.9558, 'aliases': []},
    'chandigarh': {'title': 'Chandigarh', 'subtitle': 'Punjab/Haryana, India', 'lat': 30.7333, 'lng': 76.7794, 'aliases': []},
  };

  /// Local Indian location fallback search supporting alias, partial, and case-insensitive matches
  List<LocationSearchResult> searchLocalLocationIndex(String query) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return [];

    final List<LocationSearchResult> results = [];
    final Set<String> addedKeys = {};

    for (final entry in _cityMetadataLookup.entries) {
      final key = entry.key;
      final meta = entry.value;
      final title = meta['title'] as String;
      final subtitle = meta['subtitle'] as String;
      final lat = meta['lat'] as double;
      final lng = meta['lng'] as double;
      final List<String> aliases = (meta['aliases'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

      final matchesKey = key.contains(cleanQuery) || cleanQuery.contains(key);
      final matchesAlias = aliases.any((a) => a.contains(cleanQuery) || cleanQuery.contains(a));

      if ((matchesKey || matchesAlias) && !addedKeys.contains(key)) {
        addedKeys.add(key);
        results.add(LocationSearchResult(
          displayName: title,
          subtitle: subtitle,
          latitude: lat,
          longitude: lng,
          source: LocationSearchResultSource.localFallback,
        ));
      }
    }

    return results;
  }

  // 2. Google Places Autocomplete API with Automatic Local Fallback
  // Biased to India (components=country:in) for better results.
  Future<List<Map<String, dynamic>>> getAutocompleteSuggestions(String query, {double? currentLat, double? currentLng}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    bool apiCalled = false;
    String apiResponseStatus = 'SKIPPED';
    int googleResultsCount = 0;
    bool fallbackAttempted = false;
    int fallbackResultsCount = 0;

    final List<Map<String, dynamic>> suggestions = [];

    final Map<String, String> queryParams = {
      'input': cleanQuery,
      'key': _apiKey,
      'components': 'country:in', // Bias to India for exact address support
      'language': 'en',
    };

    // Add location bias if we have a reference point
    if (currentLat != null && currentLng != null) {
      queryParams['location'] = '$currentLat,$currentLng';
      queryParams['radius'] = '50000'; // 50km bias
    }

    debugPrint('[TRIP_DEBUG] Origin query: $cleanQuery');
    final url = _buildUri('/maps/api/place/autocomplete/json', queryParams);

    try {
      apiCalled = true;
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      apiResponseStatus = 'HTTP ${response.statusCode}';

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'] as String? ?? 'UNKNOWN';
        apiResponseStatus = 'API Status: $status';
        debugPrint('[TRIP_DEBUG] Autocomplete API status: $status for query "$cleanQuery"');

        final predictions = data['predictions'] as List<dynamic>?;
        if (predictions != null && predictions.isNotEmpty) {
          googleResultsCount = predictions.length;
          for (final pred in predictions) {
            final description = pred['description'] as String? ?? cleanQuery;
            final placeId = pred['place_id'] as String? ?? '';
            // Extract secondary text for subtitle (e.g. "Haryana, India")
            final structuredFormatting = pred['structured_formatting'] as Map<String, dynamic>?;
            final secondaryText = structuredFormatting?['secondary_text'] as String? ?? 'India';
            suggestions.add({
              'description': description,
              'place_id': placeId,
              'type': 'location',
              'subtitle': secondaryText,
              'source': 'google_places',
              // Latitude/longitude are 0.0 here; they get resolved in _selectSuggestion
              'latitude': 0.0,
              'longitude': 0.0,
            });
          }
          debugPrint('[TRIP_DEBUG] Autocomplete returned $googleResultsCount Google results for "$cleanQuery"');
        } else {
          debugPrint('[TRIP_DEBUG] Autocomplete returned no predictions. Status=$status');
        }
      }
    } catch (e) {
      apiResponseStatus = 'ERROR: $e';
      debugPrint('[TRIP_DEBUG] Autocomplete API Error: $e');
    }

    // Always query local fallback dictionary so Indian cities are available alongside Google Places
    fallbackAttempted = true;
    final localMatches = searchLocalLocationIndex(cleanQuery);
    fallbackResultsCount = localMatches.length;

    final Set<String> existingDesc = suggestions.map((s) => (s['description'] as String).toLowerCase()).toSet();
    for (final match in localMatches) {
      if (!existingDesc.contains(match.displayName.toLowerCase())) {
        suggestions.add(match.toSuggestionMap());
      }
    }

    debugPrint(
      '[SEARCH-REGRESSION-DIAGNOSTIC] Query: "$cleanQuery"\n'
      '[SEARCH-API-DIAGNOSTIC] Google API called: $apiCalled | Result count: $googleResultsCount | Status: $apiResponseStatus\n'
      '[SEARCH-FALLBACK-DIAGNOSTIC] Local fallback called: $fallbackAttempted | Result count: $fallbackResultsCount\n'
      '[SEARCH-COMBINE-DIAGNOSTIC] Google results: $googleResultsCount | Local results: $fallbackResultsCount | Combined results: ${suggestions.length}',
    );

    return suggestions;
  }

  // Fetch coordinates of an Autocomplete suggestion via Place Details API.
  // FIXED: Removed the incorrect startsWith('ChI') guard — all non-empty Google Place IDs are valid.
  Future<LatLng?> getPlaceCoordinates(String placeId) async {
    if (placeId.isEmpty) return null;
    return (await getPlaceDetails(placeId))?['coordinates'] as LatLng?;
  }

  // Full Place Details fetch: returns geometry + formatted_address
  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    if (placeId.isEmpty) return null;

    final queryParams = {
      'place_id': placeId,
      'fields': 'geometry,formatted_address,name',
      'key': _apiKey,
    };
    final url = _buildUri('/maps/api/place/details/json', queryParams);
    debugPrint('[TRIP_DEBUG] Fetching Place Details for placeId: $placeId');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'] as String? ?? 'UNKNOWN';
        debugPrint('[TRIP_DEBUG] Place Details API status: $status for placeId: $placeId');
        final result = data['result'] as Map<String, dynamic>?;
        if (result != null) {
          final geometry = result['geometry'] as Map<String, dynamic>?;
          final location = geometry?['location'] as Map<String, dynamic>?;
          if (location != null) {
            final lat = (location['lat'] as num).toDouble();
            final lng = (location['lng'] as num).toDouble();
            debugPrint('[TRIP_DEBUG] Place Details resolved: ($lat, $lng)');
            return {
              'coordinates': LatLng(lat, lng),
              'formattedAddress': result['formatted_address'] as String? ?? '',
              'name': result['name'] as String? ?? '',
            };
          }
        }
      }
    } catch (e) {
      debugPrint('[TRIP_DEBUG] Place Details API error: $e');
    }
    return null;
  }

  // OpenStreetMap Nominatim Fallback for exact address & landmark geocoding
  Future<LatLng?> _getNominatimCoordinates(String address) async {
    try {
      final encoded = Uri.encodeComponent(address);
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$encoded&format=json&limit=1');
      final response = await http.get(
        url,
        headers: {'User-Agent': 'EVHub-App/1.0'},
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>?;
        if (data != null && data.isNotEmpty) {
          final first = data[0] as Map<String, dynamic>;
          final lat = double.tryParse(first['lat']?.toString() ?? '');
          final lng = double.tryParse(first['lon']?.toString() ?? '');
          if (lat != null && lng != null) {
            debugPrint('[MapsService] Nominatim OSM Geocoded "$address" -> ($lat, $lng)');
            return LatLng(lat, lng);
          }
        }
      }
    } catch (e) {
      debugPrint('[MapsService] Nominatim geocoding error: $e');
    }
    return null;
  }

  // Fetch coordinates using Google Geocoding API, OpenStreetMap Nominatim, with robust Indian City Fallback
  Future<LatLng?> getCoordinatesFromAddress(String address) async {
    final cleanQuery = address.trim().toLowerCase();
    if (cleanQuery.isEmpty) return null;

    // 1. Try Google Geocoding API for exact address resolution
    final queryParams = {
      'address': address,
      'key': _apiKey,
    };
    final url = _buildUri('/maps/api/geocode/json', queryParams);

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'] as String? ?? 'UNKNOWN';
        if (status == 'OK') {
          final results = data['results'] as List<dynamic>?;
          if (results != null && results.isNotEmpty) {
            final loc = results[0]['geometry']?['location'];
            if (loc != null) {
              final lat = (loc['lat'] as num).toDouble();
              final lng = (loc['lng'] as num).toDouble();
              debugPrint('[MapsService] Google Geocoded "$address" -> ($lat, $lng)');
              return LatLng(lat, lng);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[MapsService] Google Geocoding API error: $e');
    }

    // 2. OpenStreetMap Nominatim Fallback for real-world street addresses & landmarks
    final osmCoords = await _getNominatimCoordinates(address);
    if (osmCoords != null) {
      return osmCoords;
    }

    // 3. Fall back to local city dictionary index
    final localMatches = searchLocalLocationIndex(cleanQuery);
    if (localMatches.isNotEmpty) {
      final match = localMatches.first;
      debugPrint('[MapsService] Found city match in local geocode index: "${match.displayName}" -> ${match.coordinates}');
      return match.coordinates;
    }

    return null;
  }

  // 3. Google Directions API with OSRM Public Fallback & Haversine Route Generator
  Future<Map<String, dynamic>?> getDirections(LatLng origin, LatLng dest) async {
    final queryParams = {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${dest.latitude},${dest.longitude}',
      'key': _apiKey,
    };
    final url = _buildUri('/maps/api/directions/json', queryParams);

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final leg = routes[0]['legs'][0];
          final points = routes[0]['overview_polyline']['points'] as String;
          final path = _decodePolyline(points);
          if (path.isNotEmpty) {
            final distText = leg['distance']['text'] as String;
            final durText = leg['duration']['text'] as String;
            debugPrint('[EVHUB_NAV] Google Directions route decoded: $distText, $durText, points: ${path.length}');
            return {
              'distance': distText,
              'duration': durText,
              'points': path,
            };
          }
        }
      }
    } catch (e) {
      debugPrint('[EVHUB_NAV] Google Directions API error: $e');
    }

    // Fallback 1: OSRM Public Driving Routing Service
    debugPrint('[EVHUB_NAV] Querying OSRM public route service fallback...');
    final osrmResult = await _getOSRMDirections(origin, dest);
    if (osrmResult != null) {
      return osrmResult;
    }

    debugPrint('[EVHUB_NAV] Both Google Directions and OSRM public route services failed. No fake route generated.');
    return null;
  }

  Future<Map<String, dynamic>?> _getOSRMDirections(LatLng origin, LatLng dest) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${origin.longitude},${origin.latitude};${dest.longitude},${dest.latitude}'
      '?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes[0];
          final double distanceMeters = (route['distance'] as num).toDouble();
          final double durationSeconds = (route['duration'] as num).toDouble();
          final geometry = route['geometry'] as Map<String, dynamic>;
          final coords = geometry['coordinates'] as List<dynamic>;

          final List<LatLng> path = coords.map((c) {
            final List<dynamic> pair = c as List<dynamic>;
            return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
          }).toList();

          final double distKm = distanceMeters / 1000.0;
          final int totalMins = (durationSeconds / 60.0).round();
          final int hours = totalMins ~/ 60;
          final int mins = totalMins % 60;

          final distText = '${distKm.toStringAsFixed(1)} km';
          final durText = hours > 0 ? '$hours hr $mins min' : '$mins mins';

          debugPrint('[EVHUB_NAV] OSRM Directions route decoded: $distText, $durText, points: ${path.length}');

          return {
            'distance': distText,
            'duration': durText,
            'points': path,
          };
        }
      }
    } catch (e) {
      debugPrint('[EVHUB_NAV] OSRM Directions fetch error: $e');
    }
    return null;
  }

  // 4. Live GPS with Geolocator
  Future<LocationPermission> checkLocationPermission() async {
    return await Geolocator.checkPermission();
  }

  Future<bool> isLocationGranted() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse || permission == LocationPermission.always;
  }

  Future<LocationPermission> requestLocationPermission() async {
    return await Geolocator.requestPermission();
  }

  Future<Map<String, double>> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    final isGranted = await isLocationGranted();
    if (!isGranted) {
      throw Exception('Location permission is not granted.');
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 4),
    );
    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
    };
  }

  // 5. Reverse Geocoding — LatLng to formatted address
  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    final queryParams = {
      'latlng': '$lat,$lng',
      'key': _apiKey,
    };
    final url = _buildUri('/maps/api/geocode/json', queryParams);

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          return results[0]['formatted_address'] as String;
        }
      }
    } catch (e) {
      debugPrint("Reverse Geocoding error: $e");
    }

    return 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}';
  }

  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  // Google Places Parser
  MapMarkerModel _parsePlaceToMarker(Map<String, dynamic> place, double currentLat, double currentLng) {
    final placeId = place['place_id'] as String;
    final name = place['name'] as String;
    final address = place['vicinity'] as String? ?? 'Nearby Charger';
    
    final geometry = place['geometry']?['location'];
    final lat = (geometry?['lat'] as num?)?.toDouble() ?? currentLat;
    final lng = (geometry?['lng'] as num?)?.toDouble() ?? currentLng;
    
    final rating = (place['rating'] as num?)?.toDouble() ?? 4.4;
    
    // Stable parsing of brand based on name keywords
    String network = 'Independent';
    if (name.toLowerCase().contains('tata')) {
      network = 'Tata Power';
    } else if (name.toLowerCase().contains('statiq')) {
      network = 'Statiq';
    } else if (name.toLowerCase().contains('jio')) {
      network = 'Jio-bp Pulse';
    } else if (name.toLowerCase().contains('shell')) {
      network = 'Shell Recharge';
    } else if (name.toLowerCase().contains('zeon')) {
      network = 'Zeon';
    } else if (name.toLowerCase().contains('kazam')) {
      network = 'Kazam';
    } else if (name.toLowerCase().contains('bolt')) {
      network = 'Bolt Earth';
    } else if (name.toLowerCase().contains('chargezone')) {
      network = 'ChargeZone';
    }

    // Live real-time availability is unavailable from standard Google Places API
    const status = MarkerStatus.unknown;
    const availabilityStatus = 'Live availability unavailable';
    const stallsText = 'Availability Unknown';
    const power = 'Details Unavailable';
    const powerType = 'Fast';
    const price = 'Details Unavailable';
    const connectorCount = 0;
    const connectors = ['Details Unavailable'];

    String? photoUrl;
    final photos = place['photos'] as List<dynamic>?;
    if (photos != null && photos.isNotEmpty) {
      final photoRef = photos[0]['photo_reference'] as String;
      photoUrl = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=$photoRef&key=$_apiKey';
    }

    final openNow = place['opening_hours']?['open_now'] as bool?;
    final openStatus = openNow == null ? 'Unknown' : (openNow ? 'Open' : 'Closed');

    return MapMarkerModel(
      id: placeId,
      title: name,
      description: address,
      latitude: lat,
      longitude: lng,
      type: MarkerType.station,
      network: network,
      rating: rating,
      power: power,
      availableStalls: stallsText,
      status: status,
      photoUrl: photoUrl,
      address: address,
      openStatus: openStatus,
      price: price,
      connectorCount: connectorCount,
      connectors: connectors,
      powerType: powerType,
      openingHours: '24 Hours',
      source: 'google_places',
      isVerified: false,
      availabilityStatus: availabilityStatus,
      placeId: placeId,
    );
  }

  // Encoded Polyline decoder algorithm
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polyline;
  }
}
