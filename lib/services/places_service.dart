class PlaceModel {
  final String id;
  final String name;
  final String type;
  final double distance; // in meters
  final bool isOpen;
  final double rating;

  const PlaceModel({
    required this.id,
    required this.name,
    required this.type,
    required this.distance,
    this.isOpen = true,
    this.rating = 4.0,
  });
}

class PlacesService {
  Future<List<PlaceModel>> getNearbyPlaces(double lat, double lng) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    // Mock Google Places API response
    return const [
      PlaceModel(id: 'p1', name: 'Haldiram\'s', type: 'restaurant', distance: 150, rating: 4.5),
      PlaceModel(id: 'p2', name: 'Starbucks', type: 'cafe', distance: 200, rating: 4.8),
      PlaceModel(id: 'p3', name: 'Pacific Mall', type: 'shopping_mall', distance: 500, rating: 4.2),
      PlaceModel(id: 'p4', name: 'Public Washroom', type: 'washroom', distance: 100, rating: 3.5),
    ];
  }
}
