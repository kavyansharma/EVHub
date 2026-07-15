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
  final bool isTeslaCompatible;
  final bool isFavorite;

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
    required this.isTeslaCompatible,
    this.isFavorite = false,
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
    bool? isTeslaCompatible,
    bool? isFavorite,
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
      isTeslaCompatible: isTeslaCompatible ?? this.isTeslaCompatible,
      isFavorite: isFavorite ?? this.isFavorite,
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
      isTeslaCompatible: (data['isTeslaCompatible'] ?? false) as bool,
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
      'isTeslaCompatible': isTeslaCompatible,
    };
  }
}
