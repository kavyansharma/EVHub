enum MarkerType { station, user, routePoint }

enum MarkerStatus { available, busy, offline, unknown }

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

  // Phase 7.2 Enhancements
  final double? distanceKm;
  final String? availabilityStatus;
  final String? lastUpdated;
  final bool isVerified;
  final String? placeId;

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
    this.distanceKm,
    this.availabilityStatus,
    this.lastUpdated,
    this.isVerified = true,
    this.placeId,
  });

  MapMarkerModel copyWith({
    String? id,
    String? title,
    String? description,
    double? latitude,
    double? longitude,
    MarkerType? type,
    String? iconPath,
    String? network,
    double? rating,
    String? power,
    String? availableStalls,
    MarkerStatus? status,
    String? photoUrl,
    String? address,
    String? openStatus,
    String? price,
    int? connectorCount,
    List<String>? connectors,
    String? powerType,
    String? openingHours,
    String? source,
    double? distanceKm,
    String? availabilityStatus,
    String? lastUpdated,
    bool? isVerified,
    String? placeId,
  }) {
    return MapMarkerModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      type: type ?? this.type,
      iconPath: iconPath ?? this.iconPath,
      network: network ?? this.network,
      rating: rating ?? this.rating,
      power: power ?? this.power,
      availableStalls: availableStalls ?? this.availableStalls,
      status: status ?? this.status,
      photoUrl: photoUrl ?? this.photoUrl,
      address: address ?? this.address,
      openStatus: openStatus ?? this.openStatus,
      price: price ?? this.price,
      connectorCount: connectorCount ?? this.connectorCount,
      connectors: connectors ?? this.connectors,
      powerType: powerType ?? this.powerType,
      openingHours: openingHours ?? this.openingHours,
      source: source ?? this.source,
      distanceKm: distanceKm ?? this.distanceKm,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isVerified: isVerified ?? this.isVerified,
      placeId: placeId ?? this.placeId,
    );
  }
}
