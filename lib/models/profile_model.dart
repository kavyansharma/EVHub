import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileModel {
  final String userId;
  final String phone;
  final int totalRewardPoints;
  final String membershipTier; // e.g. "Bronze", "Silver", "Gold"
  final List<String> badges;
  final List<String> preferredNetworks;
  final double totalKwhCharged;
  final int totalSessions;

  const ProfileModel({
    required this.userId,
    this.phone = '',
    this.totalRewardPoints = 0,
    this.membershipTier = 'Bronze',
    this.badges = const [],
    this.preferredNetworks = const [],
    this.totalKwhCharged = 0.0,
    this.totalSessions = 0,
  });

  factory ProfileModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ProfileModel(
      userId: doc.id,
      phone: data['phone'] ?? '',
      totalRewardPoints: data['totalRewardPoints'] ?? 0,
      membershipTier: data['membershipTier'] ?? 'Bronze',
      badges: List<String>.from(data['badges'] ?? []),
      preferredNetworks: List<String>.from(data['preferredNetworks'] ?? []),
      totalKwhCharged: (data['totalKwhCharged'] ?? 0.0).toDouble(),
      totalSessions: data['totalSessions'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phone': phone,
      'totalRewardPoints': totalRewardPoints,
      'membershipTier': membershipTier,
      'badges': badges,
      'preferredNetworks': preferredNetworks,
      'totalKwhCharged': totalKwhCharged,
      'totalSessions': totalSessions,
    };
  }

  ProfileModel copyWith({
    String? phone,
    int? totalRewardPoints,
    String? membershipTier,
    List<String>? badges,
    List<String>? preferredNetworks,
    double? totalKwhCharged,
    int? totalSessions,
  }) {
    return ProfileModel(
      userId: userId,
      phone: phone ?? this.phone,
      totalRewardPoints: totalRewardPoints ?? this.totalRewardPoints,
      membershipTier: membershipTier ?? this.membershipTier,
      badges: badges ?? this.badges,
      preferredNetworks: preferredNetworks ?? this.preferredNetworks,
      totalKwhCharged: totalKwhCharged ?? this.totalKwhCharged,
      totalSessions: totalSessions ?? this.totalSessions,
    );
  }
}
