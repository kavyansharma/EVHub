import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../models/map_marker_model.dart';
import 'bulk_data_source.dart';

/// Implements [BulkChargerDataSource] for the U.S. Department of Energy
/// NREL Alternative Fuel Stations API.
/// Documentation: https://developer.nrel.gov/docs/transportation/alt-fuel-stations-v1/
class NrelChargerDataSource implements BulkChargerDataSource {
  final http.Client _client;

  NrelChargerDataSource({http.Client? client}) : _client = client ?? http.Client();

  @override
  String get sourceId => 'nrel_api';

  @override
  String get sourceName => 'U.S. NREL Alternative Fuel Stations API';

  @override
  Future<List<MapMarkerModel>> fetchChargers({
    Map<String, dynamic>? options,
  }) async {
    final apiKey = (options?['apiKey'] as String?)?.trim();
    final effectiveApiKey = (apiKey != null && apiKey.isNotEmpty)
        ? apiKey
        : AppConstants.nrelApiKey;

    final state = (options?['state'] as String?)?.trim().toUpperCase();
    final limit = (options?['limit'] as int?) ?? 100;
    final status = (options?['status'] as String?) ?? 'E'; // E = Available/Existing

    final queryParameters = <String, String>{
      'api_key': effectiveApiKey,
      'fuel_type': 'ELEC',
      'status': status,
      'limit': limit.toString(),
    };

    if (state != null && state.isNotEmpty && state != 'ALL') {
      queryParameters['state'] = state;
    }

    final uri = Uri.parse(AppConstants.nrelApiBaseUrl).replace(
      queryParameters: queryParameters,
    );

    debugPrint('[NrelChargerDataSource] Fetching NREL API: $uri');

    http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('[NrelChargerDataSource] Network / Timeout Error: $e');
      throw Exception('Network timeout connecting to NREL API ($e)');
    }

    if (response.statusCode == 429) {
      debugPrint('[NrelChargerDataSource] ❌ NREL Rate Limit Exceeded (HTTP 429)');
      throw Exception('NREL API Rate limit exceeded (HTTP 429). Please use your own NREL API Key or try again later.');
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      debugPrint('[NrelChargerDataSource] ❌ Invalid API Key (HTTP ${response.statusCode})');
      throw Exception('Invalid NREL API key. Please check your API Key settings.');
    }

    if (response.statusCode != 200) {
      debugPrint('[NrelChargerDataSource] ❌ HTTP Error ${response.statusCode}: ${response.body}');
      throw Exception('NREL API returned error code HTTP ${response.statusCode}');
    }

    final Map<String, dynamic> body = json.decode(response.body) as Map<String, dynamic>;
    final List<dynamic> stationsJson = (body['fuel_stations'] as List<dynamic>?) ?? [];

    debugPrint('[NrelChargerDataSource] ✓ Received ${stationsJson.length} raw stations from NREL.');

    final List<MapMarkerModel> models = [];
    for (final raw in stationsJson) {
      if (raw is Map<String, dynamic>) {
        final model = _mapNrelJsonToModel(raw);
        if (model != null) {
          models.add(model);
        }
      }
    }

    return models;
  }

  /// Maps an individual station JSON object from NREL API into EVHub [MapMarkerModel].
  MapMarkerModel? _mapNrelJsonToModel(Map<String, dynamic> raw) {
    final rawId = raw['id']?.toString();
    final name = (raw['station_name'] as String?)?.trim() ?? '';
    final lat = (raw['latitude'] as num?)?.toDouble();
    final lng = (raw['longitude'] as num?)?.toDouble();

    // Validation: coordinates and name are strictly required
    if (name.isEmpty || lat == null || lng == null) return null;
    if (lat < -90.0 || lat > 90.0 || lng < -180.0 || lng > 180.0) return null;

    final id = 'nrel_${rawId ?? '${lat}_$lng'}';

    final street = (raw['street_address'] as String?)?.trim() ?? '';
    final city = (raw['city'] as String?)?.trim() ?? '';
    final state = (raw['state'] as String?)?.trim() ?? '';
    final country = (raw['country'] as String?)?.trim() ?? 'US';

    final networkRaw = (raw['ev_network'] as String?)?.trim() ?? 'Independent';
    final phone = (raw['station_phone'] as String?)?.trim();
    final web = (raw['ev_network_web'] as String?)?.trim() ?? (raw['ev_other_evse'] as String?)?.trim();

    final statusCode = raw['status_code'] as String?;
    MarkerStatus status = MarkerStatus.available;
    if (statusCode == 'P' || statusCode == 'T') {
      status = MarkerStatus.offline;
    }

    final numL2 = (raw['ev_level2_evse_num'] as num?)?.toInt() ?? 0;
    final numFast = (raw['ev_dc_fast_num'] as num?)?.toInt() ?? 0;
    final totalPorts = numL2 + numFast > 0 ? numL2 + numFast : 2;

    final rawConnectors = (raw['ev_connector_types'] as List<dynamic>?) ?? [];
    final List<String> mappedConnectors = [];

    for (final c in rawConnectors) {
      final str = c.toString().toUpperCase();
      if (str.contains('J1772COMBO') || str.contains('CCS')) {
        if (!mappedConnectors.contains('CCS2')) mappedConnectors.add('CCS2');
      } else if (str.contains('J1772')) {
        if (!mappedConnectors.contains('Type 2')) mappedConnectors.add('Type 2');
      } else if (str.contains('CHADEMO')) {
        if (!mappedConnectors.contains('CHAdeMO')) mappedConnectors.add('CHAdeMO');
      } else if (str.contains('TESLA') || str.contains('NACS')) {
        if (!mappedConnectors.contains('Tesla / NACS')) mappedConnectors.add('Tesla / NACS');
      }
    }

    if (mappedConnectors.isEmpty) {
      mappedConnectors.addAll(const ['CCS2', 'Type 2']);
    }

    final powerType = numFast > 0 ? 'Ultra Fast' : 'Fast';
    final powerRating = numFast > 0 ? '${numFast * 50}kW' : '22kW';

    return MapMarkerModel(
      id: id,
      title: name,
      description: '$networkRaw Public Charger in $city, $state',
      latitude: lat,
      longitude: lng,
      type: MarkerType.station,
      network: networkRaw,
      power: powerRating,
      availableStalls: '$totalPorts/$totalPorts',
      status: status,
      address: street,
      city: city.isNotEmpty ? city : null,
      state: state.isNotEmpty ? state : null,
      country: country.isNotEmpty ? country : 'US',
      connectorCount: totalPorts,
      connectors: mappedConnectors,
      powerType: powerType,
      source: 'bulk_import',
      isVerified: false,
      verificationStatus: 'approved',
      phoneNumber: phone,
      website: web,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );
  }
}
