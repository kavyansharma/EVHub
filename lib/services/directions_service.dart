import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/trip_plan_model.dart';
import '../core/constants/app_constants.dart';

class DirectionsService {
  final String _apiKey = AppConstants.googleMapsApiKey;

  // Helper for web proxy
  Uri _buildUri(String path, Map<String, String> queryParameters) {
    final baseUri = Uri.https('maps.googleapis.com', path, queryParameters);
    if (kIsWeb) {
      return Uri.parse('https://corsproxy.io/?${Uri.encodeComponent(baseUri.toString())}');
    }
    return baseUri;
  }

  Future<TripPlanModel> calculateAdvancedTrip({
    required TripPlanModel basePlan,
    required double currentBatteryPct,
    required double vehicleEfficiency, // km/kWh
    required double batteryCapacityKw,
  }) async {
    double distanceKm = 120.0; // Fallback
    
    // Call Google Directions API to get actual distance between basePlan start and end coordinates
    final queryParams = {
      'origin': '${basePlan.startLat},${basePlan.startLng}',
      'destination': '${basePlan.endLat},${basePlan.endLng}',
      'key': _apiKey,
    };
    final url = _buildUri('/maps/api/directions/json', queryParams);

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final leg = routes[0]['legs'][0];
          final distanceMeters = (leg['distance']['value'] as num).toDouble();
          distanceKm = distanceMeters / 1000.0;
        }
      }
    } catch (e) {
      debugPrint("DirectionsService API error: $e");
    }

    // Environmental impacts
    double impactMultiplier = 1.0;
    
    if (basePlan.weatherImpact.contains('Rain') || basePlan.weatherImpact.contains('Cold')) {
      impactMultiplier *= 1.15; // 15% more consumption
    }
    
    if (basePlan.elevationImpact.contains('Uphill')) {
      impactMultiplier *= 1.25; // 25% more consumption
    }
    
    if (basePlan.trafficImpact.contains('Heavy')) {
      impactMultiplier *= 1.10; // 10% more consumption in heavy stop-go traffic
    }

    final adjustedEfficiency = vehicleEfficiency / impactMultiplier;
    final kwhNeeded = distanceKm / adjustedEfficiency;
    final batteryPctNeeded = (kwhNeeded / batteryCapacityKw) * 100;
    
    double estimatedEndBattery = currentBatteryPct - batteryPctNeeded;
    List<String> stops = [];

    // If battery drops below 15%, recommend a stop
    if (estimatedEndBattery < 15.0) {
      stops.add('st_1'); // Add a simulated station ID on route
      estimatedEndBattery += 40.0; // Assume they charge 40%
    }

    return TripPlanModel(
      id: basePlan.id,
      userId: basePlan.userId,
      destination: basePlan.destination,
      startLat: basePlan.startLat,
      startLng: basePlan.startLng,
      endLat: basePlan.endLat,
      endLng: basePlan.endLng,
      estimatedBatteryPrediction: estimatedEndBattery.clamp(0.0, 100.0),
      weatherImpact: basePlan.weatherImpact,
      elevationImpact: basePlan.elevationImpact,
      trafficImpact: basePlan.trafficImpact,
      returnTripIncluded: basePlan.returnTripIncluded,
      recommendedChargingStops: stops,
      plannedDate: basePlan.plannedDate,
    );
  }
}
