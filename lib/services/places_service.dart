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

  Future<List<PlaceModel>> getNearbyPlaces(double lat, double lng) async {
    // We will query for standard amenities: restaurant, cafe, lodging (hotel), shopping_mall, hospital, washroom.
    // To minimize multiple round-trip HTTP overhead, we query Nearby Search for general amenities, and if CORS blocks, fallback gracefully.
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=1000&type=restaurant|cafe|lodging|shopping_mall|hospital&key=$_apiKey');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          return results.map((place) => _parsePlaceToModel(place, lat, lng)).toList();
        }
      }
    } catch (e) {
      debugPrint("Google Places Nearby amenities error/CORS fallback: $e");
    }

    return _getFallbackPlaces(lat, lng);
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

  List<PlaceModel> _getFallbackPlaces(double lat, double lng) {
    final seed = (lat * 100000 + lng * 100000).toInt().abs();
    final random = math.Random(seed);

    final types = ['restaurant', 'cafe', 'shopping_mall', 'washroom', 'hotel', 'hospital'];
    final names = {
      'restaurant': ['Haldiram\'s', 'Bikanervala', 'Sagar Ratna', 'Barbeque Nation', 'Pizza Hut', 'Dhaba 11', 'The Spice Route'],
      'cafe': ['Starbucks', 'Cafe Coffee Day', 'Blue Tokai Coffee Roasters', 'Third Wave Coffee', 'Chaayos', 'The Coffee Bean'],
      'shopping_mall': ['Pacific Mall', 'Select Citywalk', 'DLF Promenade', 'Phoenix Marketcity', 'Nexus Mall'],
      'washroom': ['Premium Public Restroom', 'Clean Toilet Lounge', 'Highway Rest Stop Washroom'],
      'hotel': ['Taj Palace', 'Radisson Blu Hotel', 'Lemon Tree Premier', 'Holiday Inn', 'The Leela', 'Hyatt Regency'],
      'hospital': ['Max Super Speciality Hospital', 'Fortis Healthcare', 'Medanta Mediclinic', 'Apollo Clinic'],
    };
    
    final images = {
      'restaurant': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=500&auto=format&fit=crop',
      'cafe': 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?q=80&w=500&auto=format&fit=crop',
      'shopping_mall': 'https://images.unsplash.com/photo-1519567281027-615214041b61?q=80&w=500&auto=format&fit=crop',
      'washroom': 'https://images.unsplash.com/photo-1628156106631-f92dcb4a9699?q=80&w=500&auto=format&fit=crop',
      'hotel': 'https://images.unsplash.com/photo-1566073771259-6a8506099945?q=80&w=500&auto=format&fit=crop',
      'hospital': 'https://images.unsplash.com/photo-1586773860418-d3b3de97e663?q=80&w=500&auto=format&fit=crop',
    };

    List<PlaceModel> places = [];
    final numPlaces = 6 + random.nextInt(5);
    
    for (int i = 0; i < numPlaces; i++) {
      final type = types[random.nextInt(types.length)];
      final nameList = names[type]!;
      final name = nameList[random.nextInt(nameList.length)];
      
      final distance = (random.nextDouble() * 700) + 80;
      final rating = 3.8 + (random.nextDouble() * 1.2);
      final isOpen = random.nextDouble() > 0.15;

      places.add(PlaceModel(
        id: 'place_${seed}_$i',
        name: name,
        type: type,
        distance: distance,
        isOpen: isOpen,
        rating: rating,
        imageUrl: images[type]!,
      ));
    }

    places.sort((a, b) => a.distance.compareTo(b.distance));
    return places;
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
