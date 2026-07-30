import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Helper service for launching external GPS navigation (e.g. Google Maps)
/// using charger coordinates.
class NavigationLauncherService {
  const NavigationLauncherService();

  /// Launches external Google Maps navigation to [latitude], [longitude].
  /// Returns true if launch succeeded, false otherwise.
  Future<bool> launchNavigation(double latitude, double longitude) async {
    final String googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';
    final Uri uri = Uri.parse(googleMapsUrl);

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        return await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('[NavigationLauncherService] Navigation launch error: $e');
      return false;
    }
  }
}
