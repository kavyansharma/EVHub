class UserModel {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final bool isGuest;
  final double walletBalance;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.isGuest = false,
    this.walletBalance = 0.0,
  });

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    bool? isGuest,
    double? walletBalance,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isGuest: isGuest ?? this.isGuest,
      walletBalance: walletBalance ?? this.walletBalance,
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
    );
  }

  factory UserModel.guest() {
    return UserModel(
      id: 'guest_user',
      email: 'guest@evhub.com',
      name: 'Guest Driver',
      avatarUrl: null,
      isGuest: true,
      walletBalance: 0.0,
    );
  }
}
