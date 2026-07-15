class DirectionsService {
  // TODO: Integrate Google Directions API

  Future<Map<String, dynamic>> calculateRoute(double startLat, double startLng, double endLat, double endLng) async {
    // Simulated calculation for directions
    await Future.delayed(const Duration(milliseconds: 800));

    return {
      'distanceMeters': 45000,
      'durationSeconds': 3600,
      'polyline': 'encoded_polyline_string_placeholder',
      'recommendedStops': [
        {
          'stationId': 'st_2',
          'delayMinutes': 25,
        }
      ]
    };
  }
}
