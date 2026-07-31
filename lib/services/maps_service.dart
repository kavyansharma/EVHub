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
    };

    if (currentLat != null && currentLng != null) {
      queryParams['location'] = '$currentLat,$currentLng';
      queryParams['radius'] = '50000'; // 50km bias
    }

    final url = _buildUri('/maps/api/place/autocomplete/json', queryParams);

    try {
      apiCalled = true;
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      apiResponseStatus = 'HTTP ${response.statusCode}';

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'] as String? ?? 'UNKNOWN';
        apiResponseStatus = 'API Status: $status';

        final predictions = data['predictions'] as List<dynamic>?;
        if (predictions != null && predictions.isNotEmpty) {
          googleResultsCount = predictions.length;
          for (final pred in predictions) {
            suggestions.add({
              'description': pred['description'] as String,
              'place_id': pred['place_id'] as String,
              'type': 'location',
              'subtitle': 'Location search',
              'source': 'google_places',
            });
          }
        }
      }
    } catch (e) {
      apiResponseStatus = 'ERROR: $e';
      debugPrint("Autocomplete API Error (falling back to local index): $e");
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

  // Fetch coordinates of an Autocomplete suggestion
  Future<LatLng?> getPlaceCoordinates(String placeId) async {
    if (placeId.isEmpty || !placeId.startsWith('ChI')) {
      return null;
    }
    final queryParams = {
      'place_id': placeId,
      'fields': 'geometry',
      'key': _apiKey,
    };
    final url = _buildUri('/maps/api/place/details/json', queryParams);

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final geometry = data['result']?['geometry'];
        if (geometry != null) {
          final lat = (geometry['location']['lat'] as num).toDouble();
          final lng = (geometry['location']['lng'] as num).toDouble();
          return LatLng(lat, lng);
        }
      }
    } catch (e) {
      debugPrint("Place Details Coordinates API error: $e");
    }
    return null;
  }

  // Fetch coordinates using Google Geocoding API with robust Indian City Fallback
  Future<LatLng?> getCoordinatesFromAddress(String address) async {
    final cleanQuery = address.trim().toLowerCase();
    if (cleanQuery.isEmpty) return null;

    // 1. Check local search index first
    final localMatches = searchLocalLocationIndex(cleanQuery);
    if (localMatches.isNotEmpty) {
      final match = localMatches.first;
      debugPrint('[MapsService] Found city match in local geocode index: "${match.displayName}" -> ${match.coordinates}');
      return match.coordinates;
    }

    final queryParams = {
      'address': address,
      'key': _apiKey,
    };
    final url = _buildUri('/maps/api/geocode/json', queryParams);

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          final loc = results[0]['geometry']?['location'];
          if (loc != null) {
            final lat = (loc['lat'] as num).toDouble();
            final lng = (loc['lng'] as num).toDouble();
            return LatLng(lat, lng);
          }
        }
      }
    } catch (e) {
      debugPrint("Geocoding API error: $e");
    }

    return null;
  }

  // 3. Google Directions API
  Future<Map<String, dynamic>?> getDirections(LatLng origin, LatLng dest) async {
    final queryParams = {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${dest.latitude},${dest.longitude}',
      'key': _apiKey,
    };
    final url = _buildUri('/maps/api/directions/json', queryParams);

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final leg = routes[0]['legs'][0];
          final points = routes[0]['overview_polyline']['points'] as String;
          final path = _decodePolyline(points);
          
          return {
            'distance': leg['distance']['text'] as String,
            'duration': leg['duration']['text'] as String,
            'points': path,
          };
        }
      }
    } catch (e) {
      debugPrint("Directions API error: $e");
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
