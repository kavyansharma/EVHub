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

  // Phase 7.3 Admin Charger Management Enhancements
  final String? ownerId;
  final String? createdBy;
  final String verificationStatus; // 'pending', 'approved', 'rejected'
  final String? verifiedBy;
  final String? verifiedAt;
  final String? phoneNumber;
  final String? website;
  final String? city;
  final String? state;
  final String? country;
  final List<String>? amenities;
  final dynamic createdAt;
  final dynamic updatedAt;

  // Phase 7.5B Production-Grade Sync Enhancements
  final String? sourceId;
  final String? lastSyncedAt;
  final String? lastSeenAt;
  final bool isStale;
  final String dataConfidence; // 'verified', 'external_unverified'
  final String? originalOperatorTitle;
  final String? sourceUrl;

  // Phase 8 Computed Helpers
  int get availableConnectorsCount {
    if (source == 'google_places' || !isVerified) return 0;
    final parts = availableStalls.split('/');
    if (parts.isNotEmpty) {
      return int.tryParse(parts[0].trim()) ?? 0;
    }
    return 0;
  }

  int get occupiedConnectorsCount {
    final total = connectorCount;
    final avail = availableConnectorsCount;
    return (total - avail).clamp(0, total);
  }

  MarkerStatus get computedStatus {
    if (status == MarkerStatus.offline) return MarkerStatus.offline;
    if (source == 'google_places' || !isVerified) return MarkerStatus.unknown;
    if (availableConnectorsCount > 0) return MarkerStatus.available;
    return MarkerStatus.busy;
  }

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
    this.ownerId,
    this.createdBy,
    this.verificationStatus = 'approved',
    this.verifiedBy,
    this.verifiedAt,
    this.phoneNumber,
    this.website,
    this.city,
    this.state,
    this.country,
    this.amenities,
    this.createdAt,
    this.updatedAt,
    this.sourceId,
    this.lastSyncedAt,
    this.lastSeenAt,
    this.isStale = false,
    this.dataConfidence = 'external_unverified',
    this.originalOperatorTitle,
    this.sourceUrl,
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
    String? ownerId,
    String? createdBy,
    String? verificationStatus,
    String? verifiedBy,
    String? verifiedAt,
    String? phoneNumber,
    String? website,
    String? city,
    String? state,
    String? country,
    List<String>? amenities,
    dynamic createdAt,
    dynamic updatedAt,
    String? sourceId,
    String? lastSyncedAt,
    String? lastSeenAt,
    bool? isStale,
    String? dataConfidence,
    String? originalOperatorTitle,
    String? sourceUrl,
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
      ownerId: ownerId ?? this.ownerId,
      createdBy: createdBy ?? this.createdBy,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      website: website ?? this.website,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      amenities: amenities ?? this.amenities,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sourceId: sourceId ?? this.sourceId,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isStale: isStale ?? this.isStale,
      dataConfidence: dataConfidence ?? this.dataConfidence,
      originalOperatorTitle: originalOperatorTitle ?? this.originalOperatorTitle,
      sourceUrl: sourceUrl ?? this.sourceUrl,
    );
  }
}

