class MapMarkerModel {
  final String id;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final MarkerType type;
  final String? iconPath;

  const MapMarkerModel({
    required this.id,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.iconPath,
  });
}

enum MarkerType { station, user, routePoint }
