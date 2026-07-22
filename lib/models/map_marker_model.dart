enum MarkerType { station, user, routePoint }

enum MarkerStatus { available, busy, offline }

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
  
  // Premium Details added in V2/6.1
  final MarkerStatus status;
  final String? photoUrl;
  final String? address;
  final String? openStatus;
  final String? price;
  final int connectorCount;
  final List<String> connectors;
  final String powerType; // 'Fast', 'Ultra Fast', 'AC'
  final String? openingHours;
  final String source; // 'evhub_verified' or 'google_places'

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
    this.status = MarkerStatus.available,
    this.photoUrl,
    this.address,
    this.openStatus = 'Open',
    this.price = '₹21/kWh',
    this.connectorCount = 4,
    this.connectors = const ['CCS2', 'Type 2'],
    this.powerType = 'Fast',
    this.openingHours = '24 Hours',
    this.source = 'evhub_verified',
  });
}
