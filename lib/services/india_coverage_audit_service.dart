import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/map_marker_model.dart';

class CityCoverageMetrics {
  final String cityName;
  final double latitude;
  final double longitude;
  final int countWithin5km;
  final int countWithin10km;
  final int countWithin25km;
  final int countWithin50km;

  const CityCoverageMetrics({
    required this.cityName,
    required this.latitude,
    required this.longitude,
    required this.countWithin5km,
    required this.countWithin10km,
    required this.countWithin25km,
    required this.countWithin50km,
  });
}

class IndiaChargerAuditReport {
  final int totalChargers;
  final int indiaChargersCount;
  final int nonIndiaChargersCount;
  final int validCoordinatesCount;
  final int invalidCoordinatesCount;
  final int missingCoordinatesCount;

  // Source breakdown
  final int ocmCount;
  final int googlePlacesCount;
  final int evhubVerifiedCount;
  final int manualCount;

  // Metadata & Stale tracking
  final int sourceIdPresentCount;
  final int isStaleCount;

  // Duplicates & Anomaly checks
  final int duplicateSourceIdsCount;
  final int duplicateCoordinatesCount;
  final int outOfIndiaCoordinatesCount;

  // Geographic metrics
  final int totalCitiesCovered;
  final int totalStatesCovered;
  final List<CityCoverageMetrics> cityCoverageList;
  final Map<String, int> topStates;
  final Map<String, int> topCities;

  const IndiaChargerAuditReport({
    required this.totalChargers,
    required this.indiaChargersCount,
    required this.nonIndiaChargersCount,
    required this.validCoordinatesCount,
    required this.invalidCoordinatesCount,
    required this.missingCoordinatesCount,
    required this.ocmCount,
    required this.googlePlacesCount,
    required this.evhubVerifiedCount,
    required this.manualCount,
    required this.sourceIdPresentCount,
    required this.isStaleCount,
    required this.duplicateSourceIdsCount,
    required this.duplicateCoordinatesCount,
    required this.outOfIndiaCoordinatesCount,
    required this.totalCitiesCovered,
    required this.totalStatesCovered,
    required this.cityCoverageList,
    required this.topStates,
    required this.topCities,
  });

  String formattedReportText() {
    final StringBuffer sb = StringBuffer();
    sb.writeln('INDIA CHARGER DATA AUDIT');
    sb.writeln('------------------------');
    sb.writeln('Total chargers: $totalChargers');
    sb.writeln('India chargers: $indiaChargersCount');
    sb.writeln('Non-India chargers: $nonIndiaChargersCount');
    sb.writeln('Valid coordinates: $validCoordinatesCount');
    sb.writeln('Invalid coordinates: $invalidCoordinatesCount');
    sb.writeln('Missing coordinates: $missingCoordinatesCount');
    sb.writeln();
    sb.writeln('By source:');
    sb.writeln('OCM: $ocmCount');
    sb.writeln('Google Places: $googlePlacesCount');
    sb.writeln('EVHub Verified: $evhubVerifiedCount');
    sb.writeln('Manual: $manualCount');
    sb.writeln();
    sb.writeln('CITY COVERAGE REPORT');
    sb.writeln('City | 5km | 10km | 25km | 50km');
    for (final c in cityCoverageList) {
      sb.writeln('${c.cityName.padRight(12)} | ${c.countWithin5km.toString().padRight(3)} | ${c.countWithin10km.toString().padRight(4)} | ${c.countWithin25km.toString().padRight(4)} | ${c.countWithin50km}');
    }
    return sb.toString();
  }
}

class IndiaCoverageAuditService {
  static const double minLat = 6.0;
  static const double maxLat = 37.5;
  static const double minLng = 68.0;
  static const double maxLng = 97.5;

  static const Map<String, Map<String, double>> majorCities = {
    'Delhi': {'lat': 28.6139, 'lng': 77.2090},
    'Mumbai': {'lat': 19.0760, 'lng': 72.8777},
    'Bengaluru': {'lat': 12.9716, 'lng': 77.5946},
    'Chennai': {'lat': 13.0827, 'lng': 80.2707},
    'Hyderabad': {'lat': 17.3850, 'lng': 78.4867},
    'Pune': {'lat': 18.5204, 'lng': 73.8567},
    'Kolkata': {'lat': 22.5726, 'lng': 88.3639},
    'Ahmedabad': {'lat': 23.0225, 'lng': 72.5714},
    'Jaipur': {'lat': 26.9124, 'lng': 75.7873},
    'Lucknow': {'lat': 26.8467, 'lng': 80.9462},
    'Chandigarh': {'lat': 30.7333, 'lng': 76.7794},
    'Kochi': {'lat': 9.9312, 'lng': 76.2673},
    'Surat': {'lat': 21.1702, 'lng': 72.8311},
    'Indore': {'lat': 22.7196, 'lng': 75.8577},
    'Nagpur': {'lat': 21.1458, 'lng': 79.0882},
    'Bhopal': {'lat': 23.2599, 'lng': 77.4126},
    'Patna': {'lat': 25.5941, 'lng': 85.1376},
    'Bhubaneswar': {'lat': 20.2961, 'lng': 85.8245},
    'Coimbatore': {'lat': 11.0168, 'lng': 76.9558},
    'Visakhapatnam': {'lat': 17.6868, 'lng': 83.2185},
  };

  /// Computes a read-only data quality and coverage audit on [chargers].
  /// MUST NOT perform any Firestore writes.
  static IndiaChargerAuditReport runAudit(List<MapMarkerModel> chargers) {
    int total = chargers.length;
    int indiaCount = 0;
    int nonIndiaCount = 0;
    int validCoords = 0;
    int invalidCoords = 0;
    int missingCoords = 0;

    int ocmCount = 0;
    int googlePlacesCount = 0;
    int evhubVerifiedCount = 0;
    int manualCount = 0;

    int sourceIdPresentCount = 0;
    int isStaleCount = 0;

    final Set<String> seenSourceIds = {};
    int duplicateSourceIds = 0;

    final Set<String> seenCoords = {};
    int duplicateCoords = 0;
    int outOfIndiaCoords = 0;

    final Map<String, int> stateCounts = {};
    final Map<String, int> cityCounts = {};

    for (final c in chargers) {
      // 1. Source Classification
      final src = (c.source).toLowerCase();
      if (src == 'open_charge_map' || src == 'bulk_import') {
        ocmCount++;
      } else if (src == 'google_places') {
        googlePlacesCount++;
      } else if (src == 'evhub_verified' || c.isVerified) {
        evhubVerifiedCount++;
      } else {
        manualCount++;
      }

      // 2. Metadata tracking
      if (c.id.isNotEmpty) sourceIdPresentCount++;
      if (c.openStatus == 'Offline' || (c.lastUpdated != null && c.lastUpdated!.contains('Stale'))) {
        isStaleCount++;
      }

      // 3. Duplicate Source ID Check
      if (c.id.isNotEmpty) {
        if (seenSourceIds.contains(c.id)) {
          duplicateSourceIds++;
        } else {
          seenSourceIds.add(c.id);
        }
      }

      // 4. Coordinates Check
      final lat = c.latitude;
      final lng = c.longitude;
      if (lat == 0.0 && lng == 0.0) {
        missingCoords++;
      } else if (lat < -90.0 || lat > 90.0 || lng < -180.0 || lng > 180.0) {
        invalidCoords++;
      } else {
        validCoords++;

        // Deduplicate coordinates key (formatted to 4 decimals ~11 meters)
        final coordKey = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
        if (seenCoords.contains(coordKey)) {
          duplicateCoords++;
        } else {
          seenCoords.add(coordKey);
        }

        // Bounding Box Check for India
        final isInsideIndiaBox = lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
        final countryName = (c.country ?? '').toLowerCase();
        final isIndiaCountry = countryName.contains('india') || countryName == 'in';

        if (isInsideIndiaBox || isIndiaCountry) {
          indiaCount++;
        } else {
          nonIndiaCount++;
          outOfIndiaCoords++;
        }
      }

      // 5. State & City aggregation
      final st = (c.state ?? '').trim();
      if (st.isNotEmpty) {
        stateCounts[st] = (stateCounts[st] ?? 0) + 1;
      }
      final ct = (c.city ?? '').trim();
      if (ct.isNotEmpty) {
        cityCounts[ct] = (cityCounts[ct] ?? 0) + 1;
      }
    }

    // 6. Calculate 20-City Coverage Metrics (5km, 10km, 25km, 50km)
    final List<CityCoverageMetrics> cityCoverageList = [];
    for (final entry in majorCities.entries) {
      final cityName = entry.key;
      final cLat = entry.value['lat']!;
      final cLng = entry.value['lng']!;

      int r5 = 0;
      int r10 = 0;
      int r25 = 0;
      int r50 = 0;

      for (final c in chargers) {
        final distMeters = Geolocator.distanceBetween(cLat, cLng, c.latitude, c.longitude);
        final distKm = distMeters / 1000.0;
        if (distKm <= 5.0) r5++;
        if (distKm <= 10.0) r10++;
        if (distKm <= 25.0) r25++;
        if (distKm <= 50.0) r50++;
      }

      cityCoverageList.add(CityCoverageMetrics(
        cityName: cityName,
        latitude: cLat,
        longitude: cLng,
        countWithin5km: r5,
        countWithin10km: r10,
        countWithin25km: r25,
        countWithin50km: r50,
      ));
    }

    final report = IndiaChargerAuditReport(
      totalChargers: total,
      indiaChargersCount: indiaCount,
      nonIndiaChargersCount: nonIndiaCount,
      validCoordinatesCount: validCoords,
      invalidCoordinatesCount: invalidCoords,
      missingCoordinatesCount: missingCoords,
      ocmCount: ocmCount,
      googlePlacesCount: googlePlacesCount,
      evhubVerifiedCount: evhubVerifiedCount,
      manualCount: manualCount,
      sourceIdPresentCount: sourceIdPresentCount,
      isStaleCount: isStaleCount,
      duplicateSourceIdsCount: duplicateSourceIds,
      duplicateCoordinatesCount: duplicateCoords,
      outOfIndiaCoordinatesCount: outOfIndiaCoords,
      totalCitiesCovered: cityCounts.length,
      totalStatesCovered: stateCounts.length,
      cityCoverageList: cityCoverageList,
      topStates: stateCounts,
      topCities: cityCounts,
    );

    debugPrint(
      '[INDIA-DATA-AUDIT]\n'
      'ocmRecordsReceived: ${report.ocmCount}\n'
      'ocmRecordsValid: ${report.indiaChargersCount}\n'
      'nonIndiaRejected: ${report.nonIndiaChargersCount}\n'
      'invalidCoordinates: ${report.invalidCoordinatesCount}\n'
      'duplicates: ${report.duplicateSourceIdsCount}\n'
      'validMapMarkers: ${report.validCoordinatesCount}\n'
      'citiesCovered: ${report.totalCitiesCovered}\n'
      'statesCovered: ${report.totalStatesCovered}',
    );

    return report;
  }
}
