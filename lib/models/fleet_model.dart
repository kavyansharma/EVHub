import 'package:cloud_firestore/cloud_firestore.dart';

class FleetModel {
  final String fleetId;
  final String companyName;
  final String adminUserId;
  final List<String> driverUserIds;
  final List<String> vehicleIds;
  final double fleetWalletBalance;
  final DateTime createdAt;

  const FleetModel({
    required this.fleetId,
    required this.companyName,
    required this.adminUserId,
    this.driverUserIds = const [],
    this.vehicleIds = const [],
    this.fleetWalletBalance = 0.0,
    required this.createdAt,
  });

  factory FleetModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FleetModel(
      fleetId: doc.id,
      companyName: data['companyName'] ?? '',
      adminUserId: data['adminUserId'] ?? '',
      driverUserIds: List<String>.from(data['driverUserIds'] ?? []),
      vehicleIds: List<String>.from(data['vehicleIds'] ?? []),
      fleetWalletBalance: (data['fleetWalletBalance'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyName': companyName,
      'adminUserId': adminUserId,
      'driverUserIds': driverUserIds,
      'vehicleIds': vehicleIds,
      'fleetWalletBalance': fleetWalletBalance,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
