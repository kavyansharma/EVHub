import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Helper service for launching external GPS navigation (e.g. Google Maps)
/// directly using charger coordinates.
class NavigationLauncherService {
  const NavigationLauncherService();

  /// Validates coordinates and launches external Google Maps turn-by-turn navigation
  /// to [latitude], [longitude].
  /// Returns true if launch succeeded, false otherwise.
  Future<bool> launchNavigation(
    double latitude,
    double longitude, {
    String? destinationName,
    String? destinationId,
  }) async {
    final String googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving&dir_action=navigate';

    debugPrint('[EVHUB_NAV] ========================================');
    debugPrint('[EVHUB_NAV] NAVIGATE BUTTON CLICKED');
    debugPrint('[EVHUB_NAV] Charger Name: ${destinationName ?? "Charger"}');
    debugPrint('[EVHUB_NAV] Charger ID: ${destinationId ?? "N/A"}');
    debugPrint('[EVHUB_NAV] Latitude: $latitude');
    debugPrint('[EVHUB_NAV] Longitude: $longitude');
    debugPrint('[EVHUB_NAV] Building Google Maps URL');
    debugPrint('[EVHUB_NAV] URL: $googleMapsUrl');
    debugPrint('[EVHUB_NAV] Calling launchUrl directly from user click');

    if (latitude.isNaN ||
        longitude.isNaN ||
        latitude == 0.0 ||
        longitude == 0.0 ||
        latitude < -90.0 ||
        latitude > 90.0 ||
        longitude < -180.0 ||
        longitude > 180.0) {
      debugPrint('[EVHUB_NAV_ERROR] Invalid navigation coordinates: ($latitude, $longitude)');
      debugPrint('[EVHUB_NAV] ========================================');
      return false;
    }

    final Uri uri = Uri.parse(googleMapsUrl);

    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!launched) {
        debugPrint('[EVHUB_NAV] LAUNCH FAILED: launchUrl returned false');
      } else {
        debugPrint('[EVHUB_NAV] Launch result: true');
      }
      debugPrint('[EVHUB_NAV] ========================================');
      return launched;
    } catch (e) {
      debugPrint('[EVHUB_NAV] LAUNCH EXCEPTION: $e');
      debugPrint('[EVHUB_NAV] ========================================');
      return false;
    }
  }
}
