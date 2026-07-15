import 'package:cloud_firestore/cloud_firestore.dart';

/// Promoted from data/mock_data.dart ChargingStation.
/// Now supports Firestore serialization and favorites.
class StationModel {
  final String id;
  final String name;
  final String location;
  final double distance; // in km
  final double power; // in kW
  final List<String> plugs;
  final double pricePerKWh;
  final int availableStalls;
  final int totalStalls;
  // Real-time fields
  final int occupiedStalls;
  final int reservedStalls;
  final int offlineStalls;
  final int maintenanceStalls;
  final int queueLength;

  final bool isTeslaCompatible;
  final bool isFavorite;

  // New fields for Phase 5 Indian Networks
  final String network;
  final double rating;
  final int reviewCount;
  final List<String> images;
  final double latitude;
  final double longitude;

  const StationModel({
    required this.id,
    required this.name,
    required this.location,
    required this.distance,
    required this.power,
    required this.plugs,
    required this.pricePerKWh,
    required this.availableStalls,
    required this.totalStalls,
    this.occupiedStalls = 0,
    this.reservedStalls = 0,
    this.offlineStalls = 0,
    this.maintenanceStalls = 0,
    this.queueLength = 0,
    required this.isTeslaCompatible,
    this.isFavorite = false,
    this.network = 'Unknown',
    this.rating = 4.5,
    this.reviewCount = 0,
    this.images = const [],
    this.latitude = 0.0,
    this.longitude = 0.0,
  });

  StationModel copyWith({
    String? id,
    String? name,
    String? location,
    double? distance,
    double? power,
    List<String>? plugs,
    double? pricePerKWh,
    int? availableStalls,
    int? totalStalls,
    int? occupiedStalls,
    int? reservedStalls,
    int? offlineStalls,
    int? maintenanceStalls,
    int? queueLength,
    bool? isTeslaCompatible,
    bool? isFavorite,
    String? network,
    double? rating,
    int? reviewCount,
    List<String>? images,
    double? latitude,
    double? longitude,
  }) {
    return StationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      distance: distance ?? this.distance,
      power: power ?? this.power,
      plugs: plugs ?? this.plugs,
      pricePerKWh: pricePerKWh ?? this.pricePerKWh,
      availableStalls: availableStalls ?? this.availableStalls,
      totalStalls: totalStalls ?? this.totalStalls,
      occupiedStalls: occupiedStalls ?? this.occupiedStalls,
      reservedStalls: reservedStalls ?? this.reservedStalls,
      offlineStalls: offlineStalls ?? this.offlineStalls,
      maintenanceStalls: maintenanceStalls ?? this.maintenanceStalls,
      queueLength: queueLength ?? this.queueLength,
      isTeslaCompatible: isTeslaCompatible ?? this.isTeslaCompatible,
      isFavorite: isFavorite ?? this.isFavorite,
      network: network ?? this.network,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      images: images ?? this.images,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  factory StationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StationModel(
      id: doc.id,
      name: data['name'] ?? '',
      location: data['location'] ?? '',
      distance: (data['distance'] ?? 0.0).toDouble(),
      power: (data['power'] ?? 0.0).toDouble(),
      plugs: List<String>.from(data['plugs'] ?? []),
      pricePerKWh: (data['pricePerKWh'] ?? 0.0).toDouble(),
      availableStalls: (data['availableStalls'] ?? 0) as int,
      totalStalls: (data['totalStalls'] ?? 0) as int,
      occupiedStalls: (data['occupiedStalls'] ?? 0) as int,
      reservedStalls: (data['reservedStalls'] ?? 0) as int,
      offlineStalls: (data['offlineStalls'] ?? 0) as int,
      maintenanceStalls: (data['maintenanceStalls'] ?? 0) as int,
      queueLength: (data['queueLength'] ?? 0) as int,
      isTeslaCompatible: (data['isTeslaCompatible'] ?? false) as bool,
      network: data['network'] ?? 'Unknown',
      rating: (data['rating'] ?? 4.5).toDouble(),
      reviewCount: (data['reviewCount'] ?? 0) as int,
      images: List<String>.from(data['images'] ?? []),
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'location': location,
      'distance': distance,
      'power': power,
      'plugs': plugs,
      'pricePerKWh': pricePerKWh,
      'availableStalls': availableStalls,
      'totalStalls': totalStalls,
      'occupiedStalls': occupiedStalls,
      'reservedStalls': reservedStalls,
      'offlineStalls': offlineStalls,
      'maintenanceStalls': maintenanceStalls,
      'queueLength': queueLength,
      'isTeslaCompatible': isTeslaCompatible,
      'network': network,
      'rating': rating,
      'reviewCount': reviewCount,
      'images': images,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
