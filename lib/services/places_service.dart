import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import 'dart:math' as math;

class PlaceModel {
  final String id;
  final String name;
  final String type;
  final double distance; // in meters
  final bool isOpen;
  final double rating;
  final String imageUrl;

  const PlaceModel({
    required this.id,
    required this.name,
    required this.type,
    required this.distance,
    this.isOpen = true,
    this.rating = 4.0,
    required this.imageUrl,
  });
}

class PlacesService {
  final String _apiKey = AppConstants.googleMapsApiKey;

  // Build the request URI, supporting CORS proxy on Web
  Uri _buildUri(String path, Map<String, String> queryParameters) {
    final baseUri = Uri.https('maps.googleapis.com', path, queryParameters);
    if (kIsWeb) {
      return Uri.parse('https://corsproxy.io/?${Uri.encodeComponent(baseUri.toString())}');
    }
    return baseUri;
  }

  Future<List<PlaceModel>> getNearbyPlaces(double lat, double lng) async {
    // Query for standard amenities: restaurant, cafe, lodging, shopping_mall, hospital, parking
    // We search for them using a keyword search containing these types.
    final queryParams = {
      'location': '$lat,$lng',
      'radius': '1000',
      'keyword': 'restaurant OR cafe OR hotel OR hospital OR mall OR parking',
      'key': _apiKey,
    };
    
    final url = _buildUri('/maps/api/place/nearbysearch/json', queryParams);

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>?;
        if (results != null) {
          return results.map((place) => _parsePlaceToModel(place, lat, lng)).toList();
        }
      }
    } catch (e) {
      debugPrint("Google Places Nearby amenities error: $e");
    }

    return [];
  }

  PlaceModel _parsePlaceToModel(Map<String, dynamic> place, double lat, double lng) {
    final placeId = place['place_id'] as String;
    final name = place['name'] as String;
    
    final types = place['types'] as List<dynamic>? ?? [];
    String type = 'restaurant';
    if (types.contains('cafe')) {
      type = 'cafe';
    } else if (types.contains('lodging')) {
      type = 'hotel';
    } else if (types.contains('shopping_mall')) {
      type = 'shopping_mall';
    } else if (types.contains('hospital')) {
      type = 'hospital';
    } else if (types.contains('parking')) {
      type = 'parking';
    }

    final geometry = place['geometry']?['location'];
    final destLat = (geometry?['lat'] as num?)?.toDouble() ?? lat;
    final destLng = (geometry?['lng'] as num?)?.toDouble() ?? lng;
    
    // Calculate distance in meters
    final double distance = _calculateDistanceMeters(lat, lng, destLat, destLng);
    final rating = (place['rating'] as num?)?.toDouble() ?? 4.2;

    final openNow = place['opening_hours']?['open_now'] as bool?;
    final isOpen = openNow ?? true;

    final images = {
      'restaurant': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=500&auto=format&fit=crop',
      'cafe': 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?q=80&w=500&auto=format&fit=crop',
      'shopping_mall': 'https://images.unsplash.com/photo-1519567281027-615214041b61?q=80&w=500&auto=format&fit=crop',
      'washroom': 'https://images.unsplash.com/photo-1628156106631-f92dcb4a9699?q=80&w=500&auto=format&fit=crop',
      'atm': 'https://images.unsplash.com/photo-1620714223084-8fcacc6dfd8d?q=80&w=500&auto=format&fit=crop',
      'hotel': 'https://images.unsplash.com/photo-1566073771259-6a8506099945?q=80&w=500&auto=format&fit=crop',
      'hospital': 'https://images.unsplash.com/photo-1586773860418-d3b3de97e663?q=80&w=500&auto=format&fit=crop',
      'parking': 'https://images.unsplash.com/photo-1506015391300-4802dc74de2e?q=80&w=500&auto=format&fit=crop',
    };

    String imageUrl = images[type] ?? images['restaurant']!;
    
    final photos = place['photos'] as List<dynamic>?;
    if (photos != null && photos.isNotEmpty) {
      final photoRef = photos[0]['photo_reference'] as String;
      imageUrl = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=$photoRef&key=$_apiKey';
    }

    return PlaceModel(
      id: placeId,
      name: name,
      type: type,
      distance: distance,
      isOpen: isOpen,
      rating: rating,
      imageUrl: imageUrl,
    );
  }

  double _calculateDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295;
    final double a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742000 * math.asin(math.sqrt(a)); // returns meters
  }
}
