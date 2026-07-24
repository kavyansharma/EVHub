import 'package:cloud_firestore/cloud_firestore.dart';

enum Role { user, partner, admin, fleetManager }

class UserModel {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final bool isGuest;
  final double walletBalance;
  final Role role; // Role-based access: user, partner, admin, fleetManager
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.isGuest = false,
    this.walletBalance = 0.0,
    this.role = Role.user,
    this.createdAt,
    this.updatedAt,
  });

  bool get isAdmin => role == Role.admin;
  bool get isPartner => role == Role.partner;
  bool get isUser => role == Role.user;
  bool get canManageChargers => isAdmin || isPartner;

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    bool? isGuest,
    double? walletBalance,
    Role? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isGuest: isGuest ?? this.isGuest,
      walletBalance: walletBalance ?? this.walletBalance,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatarUrl': avatarUrl,
      'isGuest': isGuest,
      'walletBalance': walletBalance,
      'role': role.name,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      isGuest: (json['isGuest'] ?? false) as bool,
      walletBalance: (json['walletBalance'] ?? 0.0) as double,
      role: _roleFromString(json['role'] as String?),
    );
  }

  /// Firestore serialization — stores user profile in /users/{uid}
  Map<String, dynamic> toFirestore() {
    return {
      'uid': id,
      'email': email,
      'name': name,
      'avatarUrl': avatarUrl,
      'isGuest': isGuest,
      'role': role.name,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Deserialize from a Firestore document snapshot.
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? 'EV Driver',
      avatarUrl: data['avatarUrl'] as String?,
      isGuest: (data['isGuest'] ?? false) as bool,
      walletBalance: (data['walletBalance'] ?? 0.0).toDouble(),
      role: _roleFromString(data['role']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory UserModel.guest() {
    return const UserModel(
      id: 'guest_user',
      email: 'guest@evhub.com',
      name: 'Guest Driver',
      avatarUrl: null,
      isGuest: true,
      walletBalance: 1250.0,
      role: Role.user,
    );
  }

  static Role _roleFromString(dynamic value) {
    if (value == null) return Role.user;
    final str = value.toString().trim();
    if (str.isEmpty) return Role.user;
    final lower = str.toLowerCase();
    if (lower == 'admin' || lower == 'role.admin') return Role.admin;
    if (lower == 'partner' || lower == 'role.partner') return Role.partner;
    if (lower == 'fleetmanager' || lower == 'role.fleetmanager') return Role.fleetManager;
    return Role.user;
  }
}

