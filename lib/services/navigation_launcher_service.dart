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
  }) async {
    if (latitude.isNaN ||
        longitude.isNaN ||
        latitude == 0.0 ||
        longitude == 0.0 ||
        latitude < -90.0 ||
        latitude > 90.0 ||
        longitude < -180.0 ||
        longitude > 180.0) {
      debugPrint('[EVHUB_NAV_ERROR] Invalid navigation coordinates: ($latitude, $longitude)');
      return false;
    }

    final String googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving&dir_action=navigate';
    debugPrint('[EVHUB_NAV] Destination Name: ${destinationName ?? "Charger"}');
    debugPrint('[EVHUB_NAV] Destination Latitude: $latitude');
    debugPrint('[EVHUB_NAV] Destination Longitude: $longitude');
    debugPrint('[EVHUB_NAV] Google Maps URL: $googleMapsUrl');
    debugPrint('[EVHUB_NAV] Launching Google Maps');

    final Uri uri = Uri.parse(googleMapsUrl);

    try {
      bool launched = false;
      if (await canLaunchUrl(uri)) {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      debugPrint('[EVHUB_NAV] Google Maps Launch Result: ${launched ? "SUCCESS" : "FAILED"}');
      return launched;
    } catch (e) {
      debugPrint('[EVHUB_NAV] Google Maps Launch Result: FAILED ($e)');
      return false;
    }
  }
}
