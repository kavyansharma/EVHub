import 'package:cloud_firestore/cloud_firestore.dart';

enum WalletType { personal, corporate, family }

class WalletModel {
  final String userId;
  final double balance;
  final String currency;
  final DateTime lastUpdated;
  
  // Phase 5 Module 8: Universal Wallet 2.0
  final WalletType walletType;
  final String? corporateId; // Link to FleetModel if corporate
  final String? gstNumber;
  final bool autoTopUpEnabled;

  const WalletModel({
    required this.userId,
    required this.balance,
    this.currency = 'INR',
    required this.lastUpdated,
    this.walletType = WalletType.personal,
    this.corporateId,
    this.gstNumber,
    this.autoTopUpEnabled = false,
  });

  factory WalletModel.initial(String userId) {
    return WalletModel(
      userId: userId,
      balance: 0.0,
      currency: 'INR',
      lastUpdated: DateTime.now(),
      walletType: WalletType.personal,
    );
  }

  factory WalletModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalletModel(
      userId: doc.id,
      balance: (data['balance'] ?? 0.0).toDouble(),
      currency: data['currency'] ?? 'INR',
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      walletType: _typeFromString(data['walletType']),
      corporateId: data['corporateId'],
      gstNumber: data['gstNumber'],
      autoTopUpEnabled: data['autoTopUpEnabled'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'balance': balance,
      'currency': currency,
      'lastUpdated': FieldValue.serverTimestamp(),
      'walletType': walletType.name,
      if (corporateId != null) 'corporateId': corporateId,
      if (gstNumber != null) 'gstNumber': gstNumber,
      'autoTopUpEnabled': autoTopUpEnabled,
    };
  }

  WalletModel copyWith({
    double? balance,
    String? currency,
    WalletType? walletType,
    String? corporateId,
    String? gstNumber,
    bool? autoTopUpEnabled,
  }) {
    return WalletModel(
      userId: userId,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      lastUpdated: DateTime.now(),
      walletType: walletType ?? this.walletType,
      corporateId: corporateId ?? this.corporateId,
      gstNumber: gstNumber ?? this.gstNumber,
      autoTopUpEnabled: autoTopUpEnabled ?? this.autoTopUpEnabled,
    );
  }

  static WalletType _typeFromString(String? type) {
    if (type == 'corporate') return WalletType.corporate;
    if (type == 'family') return WalletType.family;
    return WalletType.personal;
  }
}
