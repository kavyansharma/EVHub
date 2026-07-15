import 'dart:math';

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
  final Random _random = Random();

  Future<List<PlaceModel>> getNearbyPlaces(double lat, double lng) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    final types = ['restaurant', 'cafe', 'shopping_mall', 'washroom', 'atm', 'hotel'];
    final names = {
      'restaurant': ['Haldiram\'s', 'Bikanervala', 'Sagar Ratna', 'Barbeque Nation', 'Pizza Hut'],
      'cafe': ['Starbucks', 'Cafe Coffee Day', 'Blue Tokai', 'Third Wave Coffee'],
      'shopping_mall': ['Pacific Mall', 'Select Citywalk', 'DLF Promenade', 'Phoenix Marketcity'],
      'washroom': ['Public Restroom', 'Clean Toilet', 'Highway Rest Stop'],
      'atm': ['HDFC ATM', 'SBI ATM', 'ICICI ATM', 'Axis Bank ATM'],
      'hotel': ['Taj Hotel', 'Radisson Blu', 'Lemon Tree', 'Holiday Inn'],
    };
    
    final images = {
      'restaurant': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=500&auto=format&fit=crop',
      'cafe': 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?q=80&w=500&auto=format&fit=crop',
      'shopping_mall': 'https://images.unsplash.com/photo-1519567281027-615214041b61?q=80&w=500&auto=format&fit=crop',
      'washroom': 'https://images.unsplash.com/photo-1628156106631-f92dcb4a9699?q=80&w=500&auto=format&fit=crop',
      'atm': 'https://images.unsplash.com/photo-1620714223084-8fcacc6dfd8d?q=80&w=500&auto=format&fit=crop',
      'hotel': 'https://images.unsplash.com/photo-1566073771259-6a8506099945?q=80&w=500&auto=format&fit=crop',
    };

    List<PlaceModel> places = [];
    
    for (int i = 0; i < 8; i++) {
      final type = types[_random.nextInt(types.length)];
      final nameList = names[type]!;
      final name = nameList[_random.nextInt(nameList.length)];
      final distance = (_random.nextDouble() * 800) + 50; // 50m to 850m
      final rating = 3.5 + (_random.nextDouble() * 1.5); // 3.5 to 5.0
      
      places.add(PlaceModel(
        id: 'place_$i',
        name: name,
        type: type,
        distance: distance,
        rating: rating,
        imageUrl: images[type]!,
      ));
    }

    return places;
  }
}
