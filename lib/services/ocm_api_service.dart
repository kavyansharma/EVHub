import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/map_marker_model.dart';
import 'bulk_data_source.dart';
import 'open_charge_map_charger_data_source.dart';

/// Production API Gateway Service for Open Charge Map (OCM) India data operations.
/// Proxies server-to-server requests via Firebase Cloud Functions (`ocmProxy`)
/// authenticated with the Admin's Firebase ID Token.
class OcmApiService implements BulkChargerDataSource {
  final http.Client _client;
  final OpenChargeMapChargerDataSource _directDataSource;
  final String cloudFunctionEndpoint;
  final bool forceDirectFallback;

  OcmApiService({
    http.Client? client,
    OpenChargeMapChargerDataSource? directDataSource,
    this.cloudFunctionEndpoint = 'https://us-central1-evhub-9e25f.cloudfunctions.net/ocmProxy',
    this.forceDirectFallback = kDebugMode, // Default fallback for dev/testing
  })  : _client = client ?? http.Client(),
        _directDataSource = directDataSource ?? OpenChargeMapChargerDataSource();

  @override
  String get sourceId => 'open_charge_map';

  @override
  String get sourceName => 'Open Charge Map — India (Production Proxy)';

  @override
  Future<List<MapMarkerModel>> fetchChargers({
    Map<String, dynamic>? options,
  }) async {
    final result = await fetchChargersWithStats(options: options);
    return result.validChargers;
  }

  Future<OcmFetchResult> fetchChargersWithStats({
    Map<String, dynamic>? options,
  }) async {
    if (forceDirectFallback) {
      debugPrint('[OcmApiService] Using Direct Fallback Data Source (Dev/Demo Mode)');
      return await _directDataSource.fetchChargersWithStats(options: options);
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User is not authenticated. Admin login is required.');
      }

      final idToken = await currentUser.getIdToken();
      final uri = Uri.parse(cloudFunctionEndpoint);

      debugPrint('[OcmApiService] Requesting server-to-server OCM Proxy Cloud Function...');
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode({
          'data': {
            'limit': options?['limit'] ?? 100,
            'offset': options?['offset'] ?? 0,
          }
        }),
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Unauthorized access (HTTP ${response.statusCode}). Admin credentials required.');
      }

      if (response.statusCode != 200) {
        throw Exception('Cloud Function proxy returned HTTP ${response.statusCode}: ${response.body}');
      }

      final Map<String, dynamic> bodyJson = json.decode(response.body);
      final Map<String, dynamic> resultData = (bodyJson['result'] as Map<String, dynamic>?) ?? bodyJson;
      final rawList = (resultData['chargers'] as List<dynamic>?) ?? [];
      final List<MapMarkerModel> validChargers = [];

      for (final raw in rawList) {
        if (raw is Map<String, dynamic>) {
          final model = OpenChargeMapChargerDataSource.mapOcmJsonToModel(raw);
          if (model != null) {
            validChargers.add(model);
          }
        }
      }

      return OcmFetchResult(
        validChargers: validChargers,
        totalApiRecords: (resultData['totalApiRecords'] as num?)?.toInt() ?? rawList.length,
        nonIndiaRejectedCount: (resultData['nonIndiaRejectedCount'] as num?)?.toInt() ?? 0,
        invalidCoordCount: (resultData['invalidCoordCount'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      debugPrint('[OcmApiService] Cloud Function proxy error: $e. Falling back to direct fetch.');
      return await _directDataSource.fetchChargersWithStats(options: options);
    }
  }
}
