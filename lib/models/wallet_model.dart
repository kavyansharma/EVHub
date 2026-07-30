import 'package:cloud_firestore/cloud_firestore.dart';

enum WalletType { personal, corporate, family }

class WalletModel {
  final String walletId;
  final String userId;
  final double balance;
  final String currency;
  final DateTime createdAt;
  final DateTime lastUpdated;
  
  // Phase 5 Module 8 / Step 1: Universal Wallet Foundation
  final WalletType walletType;
  final String? corporateId; // Link to FleetModel if corporate
  final String? gstNumber;
  final bool autoTopUpEnabled;
  final double autoTopUpThreshold;
  final double autoTopUpAmount;

  const WalletModel({
    required this.walletId,
    required this.userId,
    required this.balance,
    this.currency = 'INR',
    required this.createdAt,
    required this.lastUpdated,
    this.walletType = WalletType.personal,
    this.corporateId,
    this.gstNumber,
    this.autoTopUpEnabled = false,
    this.autoTopUpThreshold = 200.0,
    this.autoTopUpAmount = 500.0,
  });

  factory WalletModel.initial(String userId, {String? walletId}) {
    final now = DateTime.now();
    return WalletModel(
      walletId: walletId ?? 'wallet_$userId',
      userId: userId,
      balance: 0.0,
      currency: 'INR',
      createdAt: now,
      lastUpdated: now,
      walletType: WalletType.personal,
      autoTopUpEnabled: false,
      autoTopUpThreshold: 200.0,
      autoTopUpAmount: 500.0,
    );
  }

  factory WalletModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final now = DateTime.now();
    return WalletModel(
      walletId: data['walletId'] ?? doc.id,
      userId: data['userId'] ?? doc.id,
      balance: (data['balance'] ?? 0.0).toDouble(),
      currency: data['currency'] ?? 'INR',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? now,
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? now,
      walletType: _typeFromString(data['walletType']),
      corporateId: data['corporateId'],
      gstNumber: data['gstNumber'],
      autoTopUpEnabled: data['autoTopUpEnabled'] ?? false,
      autoTopUpThreshold: (data['autoTopUpThreshold'] ?? 200.0).toDouble(),
      autoTopUpAmount: (data['autoTopUpAmount'] ?? 500.0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'walletId': walletId,
      'userId': userId,
      'balance': balance,
      'currency': currency,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdated': FieldValue.serverTimestamp(),
      'walletType': walletType.name,
      if (corporateId != null) 'corporateId': corporateId,
      if (gstNumber != null) 'gstNumber': gstNumber,
      'autoTopUpEnabled': autoTopUpEnabled,
      'autoTopUpThreshold': autoTopUpThreshold,
      'autoTopUpAmount': autoTopUpAmount,
    };
  }

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return WalletModel(
      walletId: json['walletId'] ?? 'wallet_local',
      userId: json['userId'] ?? 'local_user',
      balance: (json['balance'] ?? 0.0).toDouble(),
      currency: json['currency'] ?? 'INR',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? now
          : now,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated']) ?? now
          : now,
      walletType: _typeFromString(json['walletType']),
      corporateId: json['corporateId'],
      gstNumber: json['gstNumber'],
      autoTopUpEnabled: json['autoTopUpEnabled'] ?? false,
      autoTopUpThreshold: (json['autoTopUpThreshold'] ?? 200.0).toDouble(),
      autoTopUpAmount: (json['autoTopUpAmount'] ?? 500.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'walletId': walletId,
      'userId': userId,
      'balance': balance,
      'currency': currency,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'walletType': walletType.name,
      if (corporateId != null) 'corporateId': corporateId,
      if (gstNumber != null) 'gstNumber': gstNumber,
      'autoTopUpEnabled': autoTopUpEnabled,
      'autoTopUpThreshold': autoTopUpThreshold,
      'autoTopUpAmount': autoTopUpAmount,
    };
  }

  WalletModel copyWith({
    String? walletId,
    String? userId,
    double? balance,
    String? currency,
    DateTime? createdAt,
    DateTime? lastUpdated,
    WalletType? walletType,
    String? corporateId,
    String? gstNumber,
    bool? autoTopUpEnabled,
    double? autoTopUpThreshold,
    double? autoTopUpAmount,
  }) {
    return WalletModel(
      walletId: walletId ?? this.walletId,
      userId: userId ?? this.userId,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? DateTime.now(),
      walletType: walletType ?? this.walletType,
      corporateId: corporateId ?? this.corporateId,
      gstNumber: gstNumber ?? this.gstNumber,
      autoTopUpEnabled: autoTopUpEnabled ?? this.autoTopUpEnabled,
      autoTopUpThreshold: autoTopUpThreshold ?? this.autoTopUpThreshold,
      autoTopUpAmount: autoTopUpAmount ?? this.autoTopUpAmount,
    );
  }

  static WalletType _typeFromString(String? type) {
    if (type == 'corporate') return WalletType.corporate;
    if (type == 'family') return WalletType.family;
    return WalletType.personal;
  }
}
