import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/map_marker_model.dart';
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

  // 2. Google Places Autocomplete API with Location Bias
  Future<List<Map<String, dynamic>>> getAutocompleteSuggestions(String query, {double? currentLat, double? currentLng}) async {
    if (query.isEmpty) return [];

    final Map<String, String> queryParams = {
      'input': query,
      'key': _apiKey,
    };

    if (currentLat != null && currentLng != null) {
      queryParams['location'] = '$currentLat,$currentLng';
      queryParams['radius'] = '50000'; // 50km bias
    }

    final url = _buildUri('/maps/api/place/autocomplete/json', queryParams);

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final predictions = data['predictions'] as List<dynamic>?;
        if (predictions != null) {
          return predictions.map((pred) => {
            'description': pred['description'] as String,
            'place_id': pred['place_id'] as String,
          }).toList();
        }
      }
    } catch (e) {
      debugPrint("Autocomplete API Error: $e");
    }

    return [];
  }

  // Fetch coordinates of an Autocomplete suggestion
  Future<LatLng?> getPlaceCoordinates(String placeId) async {
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
          final lat = geometry['location']['lat'] as double;
          final lng = geometry['location']['lng'] as double;
          return LatLng(lat, lng);
        }
      }
    } catch (e) {
      debugPrint("Place Details Coordinates API error: $e");
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
  Future<Map<String, double>> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
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

    // Stable properties based on place ID hash
    final hash = placeId.hashCode.abs();
    final status = MarkerStatus.values[hash % MarkerStatus.values.length];
    
    final int stalls = 2 + (hash % 8);
    final int occupied = status == MarkerStatus.busy ? stalls : (hash % stalls);
    final String stallsText = '${stalls - occupied}/$stalls';

    final double powerVal = (50 + (hash % 15) * 10).toDouble(); // 50kW to 190kW
    final String power = '${powerVal.toInt()}kW';
    final powerType = powerVal >= 100.0 ? 'Ultra Fast' : 'Fast';

    final price = '₹${(15 + (hash % 12))}/kWh'; // ₹15 to ₹26

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
      connectorCount: stalls,
      connectors: stalls > 4 ? ['CCS2', 'Type 2'] : ['CCS2'],
      powerType: powerType,
      openingHours: '24 Hours',
      source: 'google_places',
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
