import 'package:cloud_firestore/cloud_firestore.dart';

class EcosystemNetworkModel {
  final String networkId;
  final String name; // e.g., Tata Power, Ather Grid
  final bool isPartner;
  final String apiEndpoint;
  final DateTime lastSynced;

  const EcosystemNetworkModel({
    required this.networkId,
    required this.name,
    this.isPartner = false,
    this.apiEndpoint = '',
    required this.lastSynced,
  });

  factory EcosystemNetworkModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EcosystemNetworkModel(
      networkId: doc.id,
      name: data['name'] ?? '',
      isPartner: data['isPartner'] ?? false,
      apiEndpoint: data['apiEndpoint'] ?? '',
      lastSynced: (data['lastSynced'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isPartner': isPartner,
      'apiEndpoint': apiEndpoint,
      'lastSynced': Timestamp.fromDate(lastSynced),
    };
  }
}
