import '../models/map_marker_model.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;

class MapsService {
  // A robust static database of actual Indian EV charging stations with real coordinates
  static final List<Map<String, dynamic>> _realStationsDb = [
    {
      'id': 'st_tata_cp',
      'title': 'Tata Power EZ Charge Hub',
      'description': 'Outer Circle, Connaught Place, New Delhi',
      'latitude': 28.6304,
      'longitude': 77.2177,
      'network': 'Tata Power EZ Charge',
      'rating': 4.8,
      'power': '60kW',
      'availableStalls': '3/4',
    },
    {
      'id': 'st_statiq_cyberhub',
      'title': 'Statiq Charging Station',
      'description': 'Cyber Hub, DLF Phase 2, Gurugram',
      'latitude': 28.4950,
      'longitude': 77.0878,
      'network': 'Statiq',
      'rating': 4.5,
      'power': '120kW',
      'availableStalls': '5/6',
    },
    {
      'id': 'st_jiobp_rcp',
      'title': 'Jio-bp Pulse Charging Station',
      'description': 'Reliance Corporate Park, Ghansoli, Navi Mumbai',
      'latitude': 19.1026,
      'longitude': 73.0135,
      'network': 'Jio-bp Pulse',
      'rating': 4.9,
      'power': '150kW',
      'availableStalls': '6/8',
    },
    {
      'id': 'st_zeon_yeshwantpur',
      'title': 'Zeon Charging Station',
      'description': 'Taj Yeshwantpur, Peenya, Bengaluru',
      'latitude': 13.0305,
      'longitude': 77.5342,
      'network': 'Zeon',
      'rating': 4.9,
      'power': '240kW',
      'availableStalls': '4/6',
    },
    {
      'id': 'st_shell_yeshwantpur',
      'title': 'Shell Recharge Station',
      'description': 'Yeshwantpur Industrial Area, Bengaluru',
      'latitude': 13.0285,
      'longitude': 77.5402,
      'network': 'Shell Recharge',
      'rating': 4.7,
      'power': '150kW',
      'availableStalls': '3/4',
    },
    {
      'id': 'st_chargezone_expressway',
      'title': 'ChargeZone Fast Charger',
      'description': 'Food Mall, Mumbai-Pune Expressway, Khalapur',
      'latitude': 18.7560,
      'longitude': 73.3421,
      'network': 'ChargeZone',
      'rating': 4.2,
      'power': '30kW',
      'availableStalls': '1/2',
    },
    {
      'id': 'st_bolt_koramangala',
      'title': 'Bolt Earth Charging Point',
      'description': 'Koramangala 4th Block, Bengaluru',
      'latitude': 12.9352,
      'longitude': 77.6244,
      'network': 'Bolt Earth',
      'rating': 4.0,
      'power': '22kW',
      'availableStalls': '2/2',
    },
    {
      'id': 'st_fortum_khanmkt',
      'title': 'Fortum Charge & Drive',
      'description': 'Khan Market Parking Lot, New Delhi',
      'latitude': 28.6002,
      'longitude': 77.2273,
      'network': 'Fortum',
      'rating': 4.6,
      'power': '50kW',
      'availableStalls': '2/4',
    },
    {
      'id': 'st_kazam_indiranagar',
      'title': 'Kazam AC Charger',
      'description': 'Indiranagar 100ft Road, Bengaluru',
      'latitude': 12.9719,
      'longitude': 77.6412,
      'network': 'Kazam',
      'rating': 4.1,
      'power': '7.2kW',
      'availableStalls': '1/2',
    },
    {
      'id': 'st_relux_guindy',
      'title': 'Relux Charging Station',
      'description': 'Guindy Industrial Estate, Chennai',
      'latitude': 13.0067,
      'longitude': 80.2206,
      'network': 'Relux',
      'rating': 4.4,
      'power': '60kW',
      'availableStalls': '2/2',
    },
    {
      'id': 'st_lion_okhla',
      'title': 'LionCharge Station',
      'description': 'Okhla Phase 3, New Delhi',
      'latitude': 28.5355,
      'longitude': 77.2711,
      'network': 'LionCharge',
      'rating': 3.9,
      'power': '30kW',
      'availableStalls': '0/2',
    },
    {
      'id': 'st_glida_saket',
      'title': 'GLIDA Charging Hub',
      'description': 'Select Citywalk Mall, Saket, New Delhi',
      'latitude': 28.5244,
      'longitude': 77.2166,
      'network': 'GLIDA',
      'rating': 4.3,
      'power': '50kW',
      'availableStalls': '3/4',
    },
    {
      'id': 'st_tata_bandra',
      'title': 'Tata Power EZ Charge Station',
      'description': 'Bandra Reclamation Parking, Mumbai',
      'latitude': 19.0433,
      'longitude': 72.8225,
      'network': 'Tata Power EZ Charge',
      'rating': 4.7,
      'power': '60kW',
      'availableStalls': '2/4',
    },
    {
      'id': 'st_statiq_janpath',
      'title': 'Statiq Fast Charger',
      'description': 'Janpath Road, New Delhi',
      'latitude': 28.6253,
      'longitude': 77.2215,
      'network': 'Statiq',
      'rating': 4.6,
      'power': '120kW',
      'availableStalls': '3/4',
    },
    {
      'id': 'st_chargezone_vk',
      'title': 'ChargeZone Charging Hub',
      'description': 'DLF Promenade Mall, Vasant Kunj, New Delhi',
      'latitude': 28.5398,
      'longitude': 77.1612,
      'network': 'ChargeZone',
      'rating': 4.4,
      'power': '60kW',
      'availableStalls': '2/2',
    },
    {
      'id': 'st_jiobp_bkc',
      'title': 'Jio-bp Pulse Hub',
      'description': 'G Block, Bandra Kurla Complex, Mumbai',
      'latitude': 19.0607,
      'longitude': 72.8634,
      'network': 'Jio-bp Pulse',
      'rating': 4.8,
      'power': '150kW',
      'availableStalls': '4/8',
    },
    {
      'id': 'st_bolt_whitefield',
      'title': 'Bolt Earth Smart Point',
      'description': 'ITPL Back Gate, Whitefield, Bengaluru',
      'latitude': 12.9698,
      'longitude': 77.7500,
      'network': 'Bolt Earth',
      'rating': 4.2,
      'power': '22kW',
      'availableStalls': '1/2',
    },
    {
      'id': 'st_kazam_hsr',
      'title': 'Kazam EV Charger',
      'description': 'HSR Layout Sector 3, Bengaluru',
      'latitude': 12.9101,
      'longitude': 77.6450,
      'network': 'Kazam',
      'rating': 4.3,
      'power': '7.2kW',
      'availableStalls': '2/2',
    },
    {
      'id': 'st_zeon_pune',
      'title': 'Zeon Charging Hub',
      'description': 'Airport Road, Yerwada, Pune',
      'latitude': 18.5793,
      'longitude': 73.9089,
      'network': 'Zeon',
      'rating': 4.8,
      'power': '120kW',
      'availableStalls': '4/4',
    },
    {
      'id': 'st_relux_gachibowli',
      'title': 'Relux Hub Gachibowli',
      'description': 'Gachibowli Flyover Plaza, Hyderabad',
      'latitude': 17.4483,
      'longitude': 78.3488,
      'network': 'Relux',
      'rating': 4.5,
      'power': '60kW',
      'availableStalls': '2/2',
    },
    {
      'id': 'st_fortum_noida',
      'title': 'Fortum Charge Plaza',
      'description': 'Sector 15 Metro Station, Noida',
      'latitude': 28.5792,
      'longitude': 77.3149,
      'network': 'Fortum',
      'rating': 4.4,
      'power': '50kW',
      'availableStalls': '1/4',
    },
    {
      'id': 'st_glida_andheri',
      'title': 'GLIDA Charging Point',
      'description': 'Link Road, Andheri West, Mumbai',
      'latitude': 19.1200,
      'longitude': 72.8300,
      'network': 'GLIDA',
      'rating': 4.2,
      'power': '50kW',
      'availableStalls': '2/4',
    },
    {
      'id': 'st_lion_saltlake',
      'title': 'LionCharge Hub',
      'description': 'Salt Lake Sector 5, Kolkata',
      'latitude': 22.5726,
      'longitude': 88.4256,
      'network': 'LionCharge',
      'rating': 4.0,
      'power': '30kW',
      'availableStalls': '1/2',
    },
    {
      'id': 'st_shell_hinjewadi',
      'title': 'Shell Recharge Hinjewadi',
      'description': 'Phase 1, Hinjewadi, Pune',
      'latitude': 18.5913,
      'longitude': 73.7389,
      'network': 'Shell Recharge',
      'rating': 4.8,
      'power': '150kW',
      'availableStalls': '2/4',
    },
  ];

  Future<List<MapMarkerModel>> getNearbyStations(double lat, double lng, double radiusKm) async {
    // Simulate minor network lag
    await Future.delayed(const Duration(milliseconds: 300));
    
    List<MapMarkerModel> nearby = [];

    for (var raw in _realStationsDb) {
      double stationLat = raw['latitude'] as double;
      double stationLng = raw['longitude'] as double;
      
      // Calculate real distance using Haversine formula
      double distance = _calculateHaversineDistance(lat, lng, stationLat, stationLng);
      
      // We will filter stations by radius or just return all stations when radius is large (e.g. 50km)
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

  Future<Map<String, double>> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Fallback to Connaught Place, New Delhi if service is off
        return {'latitude': 28.6304, 'longitude': 77.2177};
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
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 4),
      );
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      // Fallback in case of any issues/timeouts
      return {'latitude': 28.6304, 'longitude': 77.2177};
    }
  }

  double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // pi / 180
    final double a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a)); // Diameter of earth * asin(sqrt(a))
  }
}

