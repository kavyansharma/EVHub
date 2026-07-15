import '../models/map_marker_model.dart';

class MapsService {
  // TODO: Add GoogleMaps SDK and API Key logic here once plugin is configured
  // static const String _googleMapsApiKey = "YOUR_API_KEY";

  Future<List<MapMarkerModel>> getNearbyStations(double lat, double lng, double radiusKm) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    // In a real scenario, this would query Google Maps Places API or your backend
    return [
      MapMarkerModel(
        id: 'st_1',
        title: 'Tata Power EZ Charge',
        description: 'Connaught Place',
        latitude: lat + 0.01,
        longitude: lng + 0.01,
        type: MarkerType.station,
        network: 'Tata Power',
        rating: 4.8,
        power: '60kW',
        availableStalls: '2/4',
      ),
      MapMarkerModel(
        id: 'st_2',
        title: 'Statiq Charging Station',
        description: 'Barakhamba Road',
        latitude: lat - 0.015,
        longitude: lng + 0.005,
        type: MarkerType.station,
        network: 'Statiq',
        rating: 4.5,
        power: '120kW',
        availableStalls: '4/6',
      ),
      MapMarkerModel(
        id: 'st_3',
        title: 'ChargeZone Fast Charger',
        description: 'New Delhi Railway Station',
        latitude: lat + 0.005,
        longitude: lng - 0.01,
        type: MarkerType.station,
        network: 'ChargeZone',
        rating: 4.2,
        power: '30kW',
        availableStalls: '1/2',
      ),
      MapMarkerModel(
        id: 'st_4',
        title: 'Jio-bp Pulse',
        description: 'India Gate Circle',
        latitude: lat - 0.02,
        longitude: lng - 0.015,
        type: MarkerType.station,
        network: 'Jio-bp',
        rating: 4.9,
        power: '150kW',
        availableStalls: '6/8',
      ),
    ];
  }

  Future<Map<String, double>> getCurrentLocation() async {
    // TODO: Integrate geolocator package here
    // Simulated location (Connaught Place, New Delhi)
    return {
      'latitude': 28.6304,
      'longitude': 77.2177,
    };
  }
}
