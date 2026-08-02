// ignore_for_file: avoid_print
import 'url_launcher_helper.dart';

/// Helper service for launching external GPS navigation (e.g. Google Maps)
/// directly using charger coordinates.
class NavigationLauncherService {
  const NavigationLauncherService();

  /// Direct synchronous platform-safe Google Maps navigation launch.
  /// Uses existing charger [latitude] and [longitude] without requesting permissions.
  bool openGoogleMapsNavigation(
    double latitude,
    double longitude, {
    String? destinationName,
    String? destinationId,
    String? screenName,
    bool useSimpleDomain = false,
  }) {
    print("[EVHUB_NAV_RUNTIME]");
    print("NAVIGATE CLICK RECEIVED");
    print("");
    print("========== NAV CLICK ==========");
    print("TIME: ${DateTime.now().toIso8601String()}");
    print("SCREEN: ${screenName ?? 'ChargerDetails'}");
    print("BUTTON: OutlinedButton");
    print("CHARGER: ${destinationName ?? 'Charger'}");
    print("CHARGER ID: ${destinationId ?? 'N/A'}");
    print("LAT: $latitude");
    print("LNG: $longitude");

    if (latitude.isNaN ||
        longitude.isNaN ||
        latitude == 0.0 ||
        longitude == 0.0 ||
        latitude < -90.0 ||
        latitude > 90.0 ||
        longitude < -180.0 ||
        longitude > 180.0) {
      print("WINDOW OPEN RESULT: INVALID COORDINATES");
      return false;
    }

    final String targetUrl = useSimpleDomain
        ? 'https://www.google.com'
        : 'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving';

    print("URL: $targetUrl");

    final bool success = openWebWindow(targetUrl);

    if (success) {
      print("[EVHUB_NAV_RUNTIME]");
      print("GOOGLE MAPS OPEN SUCCESS");
    } else {
      print("[EVHUB_NAV_RUNTIME]");
      print("GOOGLE MAPS OPEN FAILED");
    }

    return success;
  }

  /// Backward-compatible alias for openGoogleMapsNavigation.
  bool launchNavigation(
    double latitude,
    double longitude, {
    String? destinationName,
    String? destinationId,
  }) {
    return openGoogleMapsNavigation(
      latitude,
      longitude,
      destinationName: destinationName,
      destinationId: destinationId,
    );
  }
}



