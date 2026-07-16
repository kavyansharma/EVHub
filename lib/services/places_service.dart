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
  Future<List<PlaceModel>> getNearbyPlaces(double lat, double lng) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 250));

    // Seed Random with coordinates to ensure stable results for the same station
    final seed = (lat * 100000 + lng * 100000).toInt().abs();
    final random = math.Random(seed);

    final types = ['restaurant', 'cafe', 'shopping_mall', 'washroom', 'atm', 'hotel', 'hospital'];
    final names = {
      'restaurant': ['Haldiram\'s', 'Bikanervala', 'Sagar Ratna', 'Barbeque Nation', 'Pizza Hut', 'Dhaba 11', 'The Spice Route'],
      'cafe': ['Starbucks', 'Cafe Coffee Day', 'Blue Tokai Coffee Roasters', 'Third Wave Coffee', 'Chaayos', 'The Coffee Bean'],
      'shopping_mall': ['Pacific Mall', 'Select Citywalk', 'DLF Promenade', 'Phoenix Marketcity', 'Nexus Mall'],
      'washroom': ['Premium Public Restroom', 'Clean Toilet Lounge', 'Highway Rest Stop Washroom'],
      'atm': ['HDFC Bank ATM', 'SBI ATM', 'ICICI Bank ATM', 'Axis Bank ATM', 'Yes Bank ATM'],
      'hotel': ['Taj Palace', 'Radisson Blu Hotel', 'Lemon Tree Premier', 'Holiday Inn', 'The Leela', 'Hyatt Regency'],
      'hospital': ['Max Super Speciality Hospital', 'Fortis Healthcare', 'Medanta Mediclinic', 'Apollo Clinic'],
    };
    
    final images = {
      'restaurant': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=500&auto=format&fit=crop',
      'cafe': 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?q=80&w=500&auto=format&fit=crop',
      'shopping_mall': 'https://images.unsplash.com/photo-1519567281027-615214041b61?q=80&w=500&auto=format&fit=crop',
      'washroom': 'https://images.unsplash.com/photo-1628156106631-f92dcb4a9699?q=80&w=500&auto=format&fit=crop',
      'atm': 'https://images.unsplash.com/photo-1620714223084-8fcacc6dfd8d?q=80&w=500&auto=format&fit=crop',
      'hotel': 'https://images.unsplash.com/photo-1566073771259-6a8506099945?q=80&w=500&auto=format&fit=crop',
      'hospital': 'https://images.unsplash.com/photo-1586773860418-d3b3de97e663?q=80&w=500&auto=format&fit=crop',
    };

    List<PlaceModel> places = [];
    
    // Generate 6 to 10 unique amenities for this station
    final numPlaces = 6 + random.nextInt(5);
    for (int i = 0; i < numPlaces; i++) {
      final type = types[random.nextInt(types.length)];
      final nameList = names[type]!;
      final name = nameList[random.nextInt(nameList.length)];
      
      // Compute realistic distance from coordinates
      final distance = (random.nextDouble() * 700) + 80; // 80m to 780m
      final rating = 3.8 + (random.nextDouble() * 1.2); // 3.8 to 5.0
      final isOpen = random.nextDouble() > 0.15; // 85% chance of being open now

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

    // Sort by distance
    places.sort((a, b) => a.distance.compareTo(b.distance));

    return places;
  }
}

