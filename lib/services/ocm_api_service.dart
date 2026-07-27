import 'dart:async';
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
  final FirebaseAuth? _auth;
  final String cloudFunctionEndpoint;
  final bool forceDirectFallback;

  OcmApiService({
    http.Client? client,
    OpenChargeMapChargerDataSource? directDataSource,
    FirebaseAuth? auth,
    this.cloudFunctionEndpoint = 'https://us-central1-evhub-9e25f.cloudfunctions.net/ocmProxy',
    this.forceDirectFallback = false, // Default: Always use secure production Cloud Function proxy
  })  : _client = client ?? http.Client(),
        _directDataSource = directDataSource ?? OpenChargeMapChargerDataSource(),
        _auth = auth;

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
    final bool useDirectMode = forceDirectFallback || (options?['useDirectMode'] == true);

    if (useDirectMode) {
      debugPrint('[OcmApiService] Using Direct OCM Data Source (Development / Demo Mode)');
      return await _directDataSource.fetchChargersWithStats(options: options);
    }

    try {
      User? currentUser;
      try {
        currentUser = (_auth ?? FirebaseAuth.instance).currentUser;
      } catch (_) {
        // Handle uninitialized Firebase in unit test environment
      }

      String? idToken;
      if (currentUser != null) {
        idToken = await currentUser.getIdToken();
      } else {
        // If testing or unauthenticated
        idToken = options?['mockIdToken'] as String?;
      }

      if (idToken == null || idToken.isEmpty) {
        throw Exception('Cloud Function HTTP 401: User is not authenticated. Admin login is required.');
      }
      final uri = Uri.parse(cloudFunctionEndpoint);

      final String correlationId = options?['correlationId'] as String? ??
          'ocm-cli-${DateTime.now().millisecondsSinceEpoch}';

      debugPrint('[OcmApiService] Requesting server-to-server OCM Proxy Cloud Function (CorrelationID: $correlationId)...');

      http.Response response;
      try {
        response = await _client.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: json.encode({
            'data': {
              'limit': options?['limit'] ?? 100,
              'offset': options?['offset'] ?? 0,
              'correlationId': correlationId,
            }
          }),
        ).timeout(const Duration(seconds: 25));
      } on TimeoutException {
        throw Exception('Network timeout connecting to Firebase Cloud Function proxy (25s timeout).');
      }

      if (response.statusCode == 401) {
        throw Exception('Cloud Function HTTP 401: Authentication is required. Admin credentials needed.');
      }

      if (response.statusCode == 403) {
        throw Exception('Cloud Function HTTP 403: Access denied. Only EVHub administrators can invoke OCM import operations.');
      }

      if (response.statusCode == 429) {
        throw Exception('OCM rate limit exceeded (HTTP 429). Please try again later.');
      }

      if (response.statusCode >= 500) {
        throw Exception('Cloud Function HTTP 500: Internal server error from ocmProxy Cloud Function.');
      }

      Map<String, dynamic> bodyJson;
      try {
        bodyJson = json.decode(response.body) as Map<String, dynamic>;
      } catch (e) {
        throw Exception('Invalid OCM API response: Failed to parse Cloud Function JSON response.');
      }

      if (bodyJson.containsKey('error')) {
        final errorMap = bodyJson['error'] as Map<String, dynamic>?;
        final String status = (errorMap?['status'] as String?) ?? 'ERROR';
        final String message = (errorMap?['message'] as String?) ?? 'Unknown Cloud Function error';

        if (status == 'FAILED_PRECONDITION' || message.contains('OPEN_CHARGE_MAP_API_KEY')) {
          throw Exception('Missing Secret Manager secret: OPEN_CHARGE_MAP_API_KEY is not configured in Firebase Secret Manager.');
        } else if (status == 'UNAUTHENTICATED') {
          throw Exception('Cloud Function HTTP 401: Authentication required.');
        } else if (status == 'PERMISSION_DENIED') {
          throw Exception('Cloud Function HTTP 403: Admin permission required.');
        } else if (status == 'RESOURCE_EXHAUSTED' || message.contains('429')) {
          throw Exception('OCM rate limit exceeded (HTTP 429). Please try again later.');
        }
        throw Exception('Cloud Function Error ($status): $message');
      }

      if (response.statusCode != 200) {
        throw Exception('Cloud Function proxy returned HTTP ${response.statusCode}: ${response.body}');
      }

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
      debugPrint('[OcmApiService] Cloud Function proxy error: $e');
      rethrow;
    }
  }
}
