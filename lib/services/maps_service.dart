import '../models/map_marker_model.dart';
import 'dart:math';

class MapsService {
  final Random _random = Random();

  Future<List<MapMarkerModel>> getNearbyStations(double lat, double lng, double radiusKm) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    final List<Map<String, dynamic>> operators = [
      {'net': 'Tata Power EZ Charge', 'pwr': '60kW', 'rat': 4.8, 'cap': 4},
      {'net': 'Statiq', 'pwr': '120kW', 'rat': 4.5, 'cap': 6},
      {'net': 'ChargeZone', 'pwr': '30kW', 'rat': 4.2, 'cap': 2},
      {'net': 'Jio-bp Pulse', 'pwr': '150kW', 'rat': 4.9, 'cap': 8},
      {'net': 'Bolt.Earth', 'pwr': '22kW', 'rat': 4.0, 'cap': 2},
      {'net': 'Kazam', 'pwr': '7.2kW', 'rat': 4.1, 'cap': 2},
      {'net': 'GLIDA', 'pwr': '50kW', 'rat': 4.3, 'cap': 4},
      {'net': 'Zeon', 'pwr': '240kW', 'rat': 4.9, 'cap': 6},
      {'net': 'Relux', 'pwr': '60kW', 'rat': 4.4, 'cap': 2},
      {'net': 'LionCharge', 'pwr': '30kW', 'rat': 3.9, 'cap': 2},
      {'net': 'Fortum', 'pwr': '50kW', 'rat': 4.6, 'cap': 4},
      {'net': 'Shell Recharge', 'pwr': '150kW', 'rat': 4.7, 'cap': 4},
    ];

    List<MapMarkerModel> markers = [];
    
    // Generate 20 random stations around the center
    for (int i = 0; i < 20; i++) {
      final op = operators[_random.nextInt(operators.length)];
      final dLat = (_random.nextDouble() - 0.5) * 0.1;
      final dLng = (_random.nextDouble() - 0.5) * 0.1;
      final capacity = op['cap'] as int;
      final available = _random.nextInt(capacity + 1);
      
      markers.add(
        MapMarkerModel(
          id: 'st_$i',
          title: '${op['net']} Hub',
          description: 'Public Charging Station',
          latitude: lat + dLat,
          longitude: lng + dLng,
          type: MarkerType.station,
          network: op['net'] as String,
          rating: op['rat'] as double,
          power: op['pwr'] as String,
          availableStalls: '$available/$capacity',
        ),
      );
    }
    return markers;
  }

  Future<Map<String, double>> getCurrentLocation() async {
    // Simulated location (Connaught Place, New Delhi)
    return {
      'latitude': 28.6304,
      'longitude': 77.2177,
    };
  }
}
