class MapMarkerModel {
  final String id;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final MarkerType type;
  final String? iconPath;
  final String network;
  final double rating;
  final String power;
  final String availableStalls;

  const MapMarkerModel({
    required this.id,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.iconPath,
    this.network = 'Unknown',
    this.rating = 4.5,
    this.power = '50kW',
    this.availableStalls = '3/5',
  });
}

enum MarkerType { station, user, routePoint }
