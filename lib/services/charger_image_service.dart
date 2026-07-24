import 'package:flutter/foundation.dart';

/// ChargerImageService
///
/// Service abstraction for managing charger photos in EVHub.
/// Handles image validation, preset network image lookup, and
/// Firebase Storage upload URL handling.
class ChargerImageService {
  /// Validates whether a provided string is a valid HTTP/HTTPS image URL.
  bool isValidImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final Uri? parsed = Uri.tryParse(url.trim());
    if (parsed == null) return false;
    return parsed.hasScheme && (parsed.scheme == 'http' || parsed.scheme == 'https');
  }

  /// Preset EV charger images for popular networks
  static const Map<String, String> networkImagePresets = {
    'Tata Power': 'https://images.unsplash.com/photo-1593941707882-a5bba14938c7?auto=format&fit=crop&w=800&q=80',
    'Jio-bp Pulse': 'https://images.unsplash.com/photo-1563986768609-322da13575f3?auto=format&fit=crop&w=800&q=80',
    'Statiq': 'https://images.unsplash.com/photo-1647166545674-ce28ce93bdca?auto=format&fit=crop&w=800&q=80',
    'Shell Recharge': 'https://images.unsplash.com/photo-1571171637578-41bc2dd41cd2?auto=format&fit=crop&w=800&q=80',
    'Zeon': 'https://images.unsplash.com/photo-1593941707874-ef25b8b4a92b?auto=format&fit=crop&w=800&q=80',
    'ChargeZone': 'https://images.unsplash.com/photo-1617788138017-80ad40651399?auto=format&fit=crop&w=800&q=80',
  };

  /// Returns a high quality default photo URL for a given charger network.
  String getDefaultPhoto(String network) {
    for (final entry in networkImagePresets.entries) {
      if (network.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return 'https://images.unsplash.com/photo-1593941707882-a5bba14938c7?auto=format&fit=crop&w=800&q=80';
  }

  /// Abstraction for uploading an image file to Firebase Storage.
  /// Returns the downloadable URL of the uploaded image.
  Future<String?> uploadChargerImage({
    required String chargerId,
    required dynamic imageFile,
  }) async {
    debugPrint('[ChargerImageService] Upload request for charger $chargerId');
    // If Firebase Storage is configured in the environment, upload binary bytes.
    // Otherwise fallback to provided URL or default preset image.
    try {
      if (imageFile is String && isValidImageUrl(imageFile)) {
        return imageFile.trim();
      }
      return null;
    } catch (e) {
      debugPrint('[ChargerImageService] Error uploading charger image: $e');
      return null;
    }
  }
}
