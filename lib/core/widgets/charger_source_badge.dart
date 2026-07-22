import 'package:flutter/material.dart';

/// Glassmorphic chip-style source badge displaying either:
/// • ⭐ EVHub Verified (for Firestore verified chargers)
/// • 🌐 Google Places (for Google Places discovered chargers)
class ChargerSourceBadge extends StatelessWidget {
  final String source;
  final bool isVerified;
  final bool compact;

  const ChargerSourceBadge({
    super.key,
    required this.source,
    this.isVerified = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEVHubVerified = source == 'evhub_verified' || isVerified;

    final Color badgeColor = isEVHubVerified ? const Color(0xFF10B981) : const Color(0xFF3B82F6);
    final Color backgroundColor = badgeColor.withOpacity(0.14);
    final Color borderColor = badgeColor.withOpacity(0.35);

    final String label = isEVHubVerified ? 'EVHub Verified' : 'Google Places';
    final String iconSymbol = isEVHubVerified ? '⭐' : '🌐';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withOpacity(0.15),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            iconSymbol,
            style: TextStyle(fontSize: compact ? 11 : 13),
          ),
          SizedBox(width: compact ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              color: isEVHubVerified ? const Color(0xFF6EE7B7) : const Color(0xFF93C5FD),
              fontWeight: FontWeight.bold,
              fontSize: compact ? 10 : 12,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
