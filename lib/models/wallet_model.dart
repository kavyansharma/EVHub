import 'package:cloud_firestore/cloud_firestore.dart';

class WalletModel {
  final String userId;
  final double balance;
  final String currency;
  final DateTime lastUpdated;

  const WalletModel({
    required this.userId,
    required this.balance,
    this.currency = 'INR',
    required this.lastUpdated,
  });

  factory WalletModel.initial(String userId) {
    return WalletModel(
      userId: userId,
      balance: 0.0,
      currency: 'INR',
      lastUpdated: DateTime.now(),
    );
  }

  factory WalletModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalletModel(
      userId: doc.id,
      balance: (data['balance'] ?? 0.0).toDouble(),
      currency: data['currency'] ?? 'INR',
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'balance': balance,
      'currency': currency,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  WalletModel copyWith({double? balance, String? currency}) {
    return WalletModel(
      userId: userId,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      lastUpdated: DateTime.now(),
    );
  }
}
