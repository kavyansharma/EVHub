import 'package:cloud_firestore/cloud_firestore.dart';

enum Role { user, admin, fleetManager }

class UserModel {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final bool isGuest;
  final double walletBalance;
  final Role role; // Phase 5 Module 14: Super Admin Role

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.isGuest = false,
    this.walletBalance = 0.0,
    this.role = Role.user,
  });

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    bool? isGuest,
    double? walletBalance,
    Role? role,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isGuest: isGuest ?? this.isGuest,
      walletBalance: walletBalance ?? this.walletBalance,
      role: role ?? this.role,
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
      'email': email,
      'name': name,
      'avatarUrl': avatarUrl,
      'isGuest': isGuest,
      'role': role.name,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Deserialize from a Firestore document snapshot.
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? 'EV Driver',
      avatarUrl: data['avatarUrl'] as String?,
      isGuest: (data['isGuest'] ?? false) as bool,
      walletBalance: (data['walletBalance'] ?? 0.0).toDouble(),
      role: _roleFromString(data['role']),
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

  static Role _roleFromString(String? str) {
    if (str == 'admin') return Role.admin;
    if (str == 'fleetManager') return Role.fleetManager;
    return Role.user;
  }
}
