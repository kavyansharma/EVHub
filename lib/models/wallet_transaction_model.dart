import 'package:cloud_firestore/cloud_firestore.dart';

enum WalletTransactionType {
  topUp,
  chargingPayment,
  refund,
  cashback,
  adjustment,
}

enum WalletTransactionStatus {
  pending,
  success,
  failed,
  reversed,
}

class WalletTransactionModel {
  final String transactionId;
  final String walletId;
  final String userId;
  final WalletTransactionType type;
  final WalletTransactionStatus status;
  final double amount;
  final String currency;
  final String description;
  final String? networkName;
  final String? chargerId;
  final String? chargerName;
  final String? chargingSessionId;
  final String referenceId;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  const WalletTransactionModel({
    required this.transactionId,
    required this.walletId,
    required this.userId,
    required this.type,
    required this.status,
    required this.amount,
    this.currency = 'INR',
    required this.description,
    this.networkName,
    this.chargerId,
    this.chargerName,
    this.chargingSessionId,
    required this.referenceId,
    required this.createdAt,
    this.metadata,
  });

  bool get isCredit =>
      type == WalletTransactionType.topUp ||
      type == WalletTransactionType.refund ||
      type == WalletTransactionType.cashback ||
      (type == WalletTransactionType.adjustment && amount > 0);

  bool get isSuccessful => status == WalletTransactionStatus.success;

  String get formattedAmount =>
      '${isCredit ? '+' : '-'}₹${amount.abs().toStringAsFixed(2)}';

  String get typeDisplayName {
    switch (type) {
      case WalletTransactionType.topUp:
        return 'Wallet Top-Up';
      case WalletTransactionType.chargingPayment:
        return 'Charging Payment';
      case WalletTransactionType.refund:
        return 'Refund Credit';
      case WalletTransactionType.cashback:
        return 'Cashback Reward';
      case WalletTransactionType.adjustment:
        return 'Balance Adjustment';
    }
  }

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return WalletTransactionModel(
      transactionId: json['transactionId'] ?? json['id'] ?? '',
      walletId: json['walletId'] ?? 'wallet_local',
      userId: json['userId'] ?? 'local_user',
      type: _typeFromString(json['type']),
      status: _statusFromString(json['status']),
      amount: (json['amount'] ?? 0.0).toDouble(),
      currency: json['currency'] ?? 'INR',
      description: json['description'] ?? '',
      networkName: json['networkName'],
      chargerId: json['chargerId'],
      chargerName: json['chargerName'],
      chargingSessionId: json['chargingSessionId'],
      referenceId: json['referenceId'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? now
          : (json['timestamp'] != null
              ? DateTime.tryParse(json['timestamp']) ?? now
              : now),
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactionId': transactionId,
      'walletId': walletId,
      'userId': userId,
      'type': type.name,
      'status': status.name,
      'amount': amount,
      'currency': currency,
      'description': description,
      if (networkName != null) 'networkName': networkName,
      if (chargerId != null) 'chargerId': chargerId,
      if (chargerName != null) 'chargerName': chargerName,
      if (chargingSessionId != null) 'chargingSessionId': chargingSessionId,
      'referenceId': referenceId,
      'createdAt': createdAt.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  factory WalletTransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final now = DateTime.now();
    return WalletTransactionModel(
      transactionId: doc.id,
      walletId: data['walletId'] ?? 'wallet_local',
      userId: data['userId'] ?? '',
      type: _typeFromString(data['type']),
      status: _statusFromString(data['status']),
      amount: (data['amount'] ?? 0.0).toDouble(),
      currency: data['currency'] ?? 'INR',
      description: data['description'] ?? '',
      networkName: data['networkName'],
      chargerId: data['chargerId'],
      chargerName: data['chargerName'],
      chargingSessionId: data['chargingSessionId'],
      referenceId: data['referenceId'] ?? doc.id,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
          (data['timestamp'] as Timestamp?)?.toDate() ??
          now,
      metadata: data['metadata'] != null
          ? Map<String, dynamic>.from(data['metadata'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'walletId': walletId,
      'userId': userId,
      'type': type.name,
      'status': status.name,
      'amount': amount,
      'currency': currency,
      'description': description,
      if (networkName != null) 'networkName': networkName,
      if (chargerId != null) 'chargerId': chargerId,
      if (chargerName != null) 'chargerName': chargerName,
      if (chargingSessionId != null) 'chargingSessionId': chargingSessionId,
      'referenceId': referenceId,
      'createdAt': FieldValue.serverTimestamp(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  WalletTransactionModel copyWith({
    String? transactionId,
    String? walletId,
    String? userId,
    WalletTransactionType? type,
    WalletTransactionStatus? status,
    double? amount,
    String? currency,
    String? description,
    String? networkName,
    String? chargerId,
    String? chargerName,
    String? chargingSessionId,
    String? referenceId,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return WalletTransactionModel(
      transactionId: transactionId ?? this.transactionId,
      walletId: walletId ?? this.walletId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      description: description ?? this.description,
      networkName: networkName ?? this.networkName,
      chargerId: chargerId ?? this.chargerId,
      chargerName: chargerName ?? this.chargerName,
      chargingSessionId: chargingSessionId ?? this.chargingSessionId,
      referenceId: referenceId ?? this.referenceId,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  static WalletTransactionType _typeFromString(String? typeStr) {
    if (typeStr == null) return WalletTransactionType.chargingPayment;
    final lower = typeStr.toLowerCase();
    if (lower == 'topup' || lower == 'top_up') return WalletTransactionType.topUp;
    if (lower == 'refund') return WalletTransactionType.refund;
    if (lower == 'cashback') return WalletTransactionType.cashback;
    if (lower == 'adjustment') return WalletTransactionType.adjustment;
    return WalletTransactionType.chargingPayment;
  }

  static WalletTransactionStatus _statusFromString(String? statusStr) {
    if (statusStr == null) return WalletTransactionStatus.success;
    final lower = statusStr.toLowerCase();
    if (lower == 'pending') return WalletTransactionStatus.pending;
    if (lower == 'failed') return WalletTransactionStatus.failed;
    if (lower == 'reversed') return WalletTransactionStatus.reversed;
    return WalletTransactionStatus.success;
  }
}
