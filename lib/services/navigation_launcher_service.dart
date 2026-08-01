import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'url_launcher_helper.dart';

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

    debugPrint('[EVHUB_NAV_DEBUG] ========================================');
    debugPrint('[EVHUB_NAV_DEBUG] BUTTON CALLBACK ENTERED');
    debugPrint('[EVHUB_NAV_DEBUG] Charger Name: ${destinationName ?? "Charger"}');
    debugPrint('[EVHUB_NAV_DEBUG] Charger ID: ${destinationId ?? "N/A"}');
    debugPrint('[EVHUB_NAV_DEBUG] Latitude: $latitude');
    debugPrint('[EVHUB_NAV_DEBUG] Longitude: $longitude');

    if (latitude.isNaN ||
        longitude.isNaN ||
        latitude == 0.0 ||
        longitude == 0.0 ||
        latitude < -90.0 ||
        latitude > 90.0 ||
        longitude < -180.0 ||
        longitude > 180.0) {
      debugPrint('[EVHUB_NAV_DEBUG] INVALID COORDINATES');
      debugPrint('[EVHUB_NAV_DEBUG] ========================================');
      return false;
    }

    debugPrint('[EVHUB_NAV_DEBUG] VALID COORDINATES');
    debugPrint('[EVHUB_NAV_DEBUG] GOOGLE MAPS URL: $googleMapsUrl');
    debugPrint('[EVHUB_NAV_DEBUG] ATTEMPTING WEB LAUNCH');

    bool launched = false;

    // Platform-specific web window launch (synchronous via dart:html on Flutter Web)
    if (kIsWeb) {
      launched = openWebWindow(googleMapsUrl);
      if (launched) {
        debugPrint('[EVHUB_NAV_DEBUG] WEB LAUNCH RESULT: SUCCESS (openWebWindow)');
        debugPrint('[EVHUB_NAV_DEBUG] ========================================');
        return true;
      }
    }

    final Uri uri = Uri.parse(googleMapsUrl);

    try {
      launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!launched) {
        debugPrint('[EVHUB_NAV_DEBUG] WEB LAUNCH RESULT: FAILED (launchUrl returned false)');
      } else {
        debugPrint('[EVHUB_NAV_DEBUG] WEB LAUNCH RESULT: SUCCESS');
      }
      debugPrint('[EVHUB_NAV_DEBUG] ========================================');
      return launched;
    } catch (e) {
      debugPrint('[EVHUB_NAV_DEBUG] LAUNCH EXCEPTION: $e');
      debugPrint('[EVHUB_NAV_DEBUG] ========================================');
      return false;
    }
  }
}
