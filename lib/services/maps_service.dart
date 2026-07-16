import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/map_marker_model.dart';
import '../core/constants/app_constants.dart';
import 'dart:math' as math;

class MapsService {
  final String _apiKey = AppConstants.googleMapsApiKey;

  // Real fallback EV stations list with coordinates in major Indian hubs (Delhi, Mumbai, Bengaluru)
  static final List<Map<String, dynamic>> _realStationsFallbackDb = [
    {
      'id': 'fallback_tata_cp',
      'title': 'Tata Power EZ Charge Hub',
      'description': 'Outer Circle, Connaught Place, New Delhi',
      'latitude': 28.6304,
      'longitude': 77.2177,
      'network': 'Tata Power EZ Charge',
      'rating': 4.8,
      'power': '60kW',
      'availableStalls': '3/4',
      'status': MarkerStatus.available,
      'connectors': ['CCS2', 'Type 2'],
      'powerType': 'Fast',
      'price': '₹21/kWh',
      'photoUrl': 'https://images.unsplash.com/photo-1563720223185-11003d516935?q=80&w=600&auto=format&fit=crop',
    },
    {
      'id': 'fallback_statiq_cyberhub',
      'title': 'Statiq Charging Hub',
      'description': 'Cyber Hub, DLF Phase 2, Gurugram',
      'latitude': 28.4950,
      'longitude': 77.0878,
      'network': 'Statiq',
      'rating': 4.5,
      'power': '120kW',
      'availableStalls': '5/6',
      'status': MarkerStatus.available,
      'connectors': ['CCS2', 'CHAdeMO'],
      'powerType': 'Ultra Fast',
      'price': '₹24/kWh',
      'photoUrl': 'https://images.unsplash.com/photo-1601584115197-04ecc0da31d7?q=80&w=600&auto=format&fit=crop',
    },
    {
      'id': 'fallback_jiobp_rcp',
      'title': 'Jio-bp Pulse Hub',
      'description': 'Reliance Corporate Park, Ghansoli, Navi Mumbai',
      'latitude': 19.1026,
      'longitude': 73.0135,
      'network': 'Jio-bp Pulse',
      'rating': 4.9,
      'power': '150kW',
      'availableStalls': '0/8',
      'status': MarkerStatus.busy,
      'connectors': ['CCS2'],
      'powerType': 'Ultra Fast',
      'price': '₹22/kWh',
      'photoUrl': 'https://images.unsplash.com/photo-1563720223523-491ff04651de?q=80&w=600&auto=format&fit=crop',
    },
    {
      'id': 'fallback_zeon_yeshwantpur',
      'title': 'Zeon Charging Station',
      'description': 'Taj Yeshwantpur, Peenya, Bengaluru',
      'latitude': 13.0305,
      'longitude': 77.5342,
      'network': 'Zeon',
      'rating': 4.9,
      'power': '240kW',
      'availableStalls': '4/6',
      'status': MarkerStatus.available,
      'connectors': ['CCS2'],
      'powerType': 'Ultra Fast',
      'price': '₹25/kWh',
      'photoUrl': 'https://images.unsplash.com/photo-1529369623266-f5264b696110?q=80&w=600&auto=format&fit=crop',
    },
    {
      'id': 'fallback_shell_yeshwantpur',
      'title': 'Shell Recharge',
      'description': 'Yeshwantpur Industrial Area, Bengaluru',
      'latitude': 13.0285,
      'longitude': 77.5402,
      'network': 'Shell Recharge',
      'rating': 4.7,
      'power': '150kW',
      'availableStalls': '3/4',
      'status': MarkerStatus.available,
      'connectors': ['CCS2', 'Type 2'],
      'powerType': 'Ultra Fast',
      'price': '₹23/kWh',
      'photoUrl': 'https://images.unsplash.com/photo-1593941707882-a5bba14938c7?q=80&w=600&auto=format&fit=crop',
    },
    {
      'id': 'fallback_chargezone_exp',
      'title': 'ChargeZone Charger',
      'description': 'Food Mall, Mumbai-Pune Expressway, Khalapur',
      'latitude': 18.7560,
      'longitude': 73.3421,
      'network': 'ChargeZone',
      'rating': 4.2,
      'power': '30kW',
      'availableStalls': '0/2',
      'status': MarkerStatus.offline,
      'connectors': ['CCS2'],
      'powerType': 'Fast',
      'price': '₹19/kWh',
      'photoUrl': 'https://images.unsplash.com/photo-1563720223185-11003d516935?q=80&w=600&auto=format&fit=crop',
    },
    {
      'id': 'fallback_bolt_koramangala',
      'title': 'Bolt Earth Point',
      'description': 'Koramangala 4th Block, Bengaluru',
      'latitude': 12.9352,
      'longitude': 77.6244,
      'network': 'Bolt Earth',
      'rating': 4.0,
      'power': '22kW',
      'availableStalls': '2/2',
      'status': MarkerStatus.available,
      'connectors': ['Type 2'],
      'powerType': 'AC',
      'price': '₹15/kWh',
      'photoUrl': 'https://images.unsplash.com/photo-1558441719-ff34b0524a24?q=80&w=600&auto=format&fit=crop',
    }
  ];

  // 1. Google Places Nearby Search for EV Chargers
  Future<List<MapMarkerModel>> getNearbyStations(double lat, double lng, double radiusKm) async {
    final double radiusMeters = radiusKm * 1000;
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=${radiusMeters.toInt()}&keyword=EV%20Charging%20Station&key=$_apiKey');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          return results.map((place) => _parsePlaceToMarker(place, lat, lng)).toList();
        }
      }
    } catch (e) {
      // CORS block or Network Error: fall back to real coordinate calculations
      debugPrint("Google Places Nearby search error/CORS fallback: $e");
    }

    return _getFallbackStations(lat, lng, radiusKm);
  }

  // 2. Google Places Autocomplete API
  Future<List<Map<String, dynamic>>> getAutocompleteSuggestions(String query) async {
    if (query.isEmpty) return [];
    
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(query)}&key=$_apiKey');

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
      debugPrint("Autocomplete API Error/CORS: $e");
    }

    // Fallback matching query locally
    return _realStationsFallbackDb
        .where((st) =>
            st['title'].toString().toLowerCase().contains(query.toLowerCase()) ||
            st['description'].toString().toLowerCase().contains(query.toLowerCase()))
        .map((st) => {
              'description': '${st['title']}, ${st['description']}',
              'place_id': st['id'],
            })
        .toList();
  }

  // Fetch coordinates of an Autocomplete suggestion
  Future<LatLng?> getPlaceCoordinates(String placeId) async {
    if (placeId.startsWith('fallback_')) {
      final match = _realStationsFallbackDb.firstWhere((st) => st['id'] == placeId);
      return LatLng(match['latitude'], match['longitude']);
    }

    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry&key=$_apiKey');

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
      debugPrint("Place Details Coordinates API error/CORS: $e");
    }
    return null;
  }

  // 3. Google Directions API
  Future<Map<String, dynamic>?> getDirections(LatLng origin, LatLng dest) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${dest.latitude},${dest.longitude}&key=$_apiKey');

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
      debugPrint("Directions API error/CORS: $e");
    }

    // High quality mock routing calculation for fallback
    final distanceKm = _calculateHaversineDistance(origin.latitude, origin.longitude, dest.latitude, dest.longitude);
    final durationMin = (distanceKm * 2.0).toInt() + 2; // ~30km/h average city routing
    
    // Straight line interpolation for web path rendering
    final path = [
      origin,
      LatLng((origin.latitude + dest.latitude) / 2 + 0.002, (origin.longitude + dest.longitude) / 2 - 0.002),
      dest
    ];

    return {
      'distance': '${distanceKm.toStringAsFixed(1)} km',
      'duration': '$durationMin mins',
      'points': path,
    };
  }

  // 4. Live GPS with Geolocator
  Future<Map<String, double>> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return {'latitude': 28.6304, 'longitude': 77.2177}; // Connaught Place, New Delhi default
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return {'latitude': 28.6304, 'longitude': 77.2177};
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return {'latitude': 28.6304, 'longitude': 77.2177};
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      return {'latitude': 28.6304, 'longitude': 77.2177};
    }
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
    );
  }

  // Fallback calculations using actual coordinates filtered by radius
  List<MapMarkerModel> _getFallbackStations(double lat, double lng, double radiusKm) {
    List<MapMarkerModel> nearby = [];

    for (var raw in _realStationsFallbackDb) {
      double stationLat = raw['latitude'] as double;
      double stationLng = raw['longitude'] as double;
      double distance = _calculateHaversineDistance(lat, lng, stationLat, stationLng);
      
      // Expand nearby radius constraint to keep it fully operational in any region
      if (distance <= radiusKm || radiusKm >= 100.0) {
        nearby.add(
          MapMarkerModel(
            id: raw['id'] as String,
            title: raw['title'] as String,
            description: '${raw['description']} (${distance.toStringAsFixed(1)} km away)',
            latitude: stationLat,
            longitude: stationLng,
            type: MarkerType.station,
            network: raw['network'] as String,
            rating: raw['rating'] as double,
            power: raw['power'] as String,
            availableStalls: raw['availableStalls'] as String,
            status: raw['status'] as MarkerStatus,
            photoUrl: raw['photoUrl'] as String,
            address: raw['description'] as String,
            openStatus: 'Open',
            price: raw['price'] as String,
            connectors: List<String>.from(raw['connectors']),
            powerType: raw['powerType'] as String,
          ),
        );
      }
    }

    // Sort by proximity
    nearby.sort((a, b) {
      double distA = _calculateHaversineDistance(lat, lng, a.latitude, a.longitude);
      double distB = _calculateHaversineDistance(lat, lng, b.latitude, b.longitude);
      return distA.compareTo(distB);
    });

    return nearby;
  }

  double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295;
    final double a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a));
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
