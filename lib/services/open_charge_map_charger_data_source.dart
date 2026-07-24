import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../models/map_marker_model.dart';
import 'bulk_data_source.dart';

/// Implements [BulkChargerDataSource] for Open Charge Map (OCM) API
/// specifically targeting EV Charging Stations in India (`CountryCode=IN`).
/// Official API Documentation: https://www.openchargemap.org/develop/api
class OpenChargeMapChargerDataSource implements BulkChargerDataSource {
  final http.Client _client;

  OpenChargeMapChargerDataSource({http.Client? client})
      : _client = client ?? http.Client();

  @override
  String get sourceId => 'open_charge_map';

  @override
  String get sourceName => 'Open Charge Map — India';

  // Geographic Bounding Box for India
  static const double minLat = 6.0;
  static const double maxLat = 37.5;
  static const double minLng = 68.0;
  static const double maxLng = 97.5;

  @override
  Future<List<MapMarkerModel>> fetchChargers({
    Map<String, dynamic>? options,
  }) async {
    final apiKey = (options?['apiKey'] as String?)?.trim();
    final effectiveApiKey = (apiKey != null && apiKey.isNotEmpty)
        ? apiKey
        : AppConstants.openChargeMapApiKey;

    final targetLimit = (options?['limit'] as int?) ?? 100;
    final onProgress = options?['onProgress'] as void Function(int fetched, int page)?;

    final List<MapMarkerModel> allChargers = [];
    const int pageSize = 100;
    int offset = 0;
    int pageIndex = 1;

    while (allChargers.length < targetLimit) {
      final int batchSize = (targetLimit - allChargers.length) < pageSize
          ? (targetLimit - allChargers.length)
          : pageSize;

      final queryParameters = <String, String>{
        'output': 'json',
        'countrycode': 'IN',
        'maxresults': batchSize.toString(),
        'compact': 'true',
        'verbose': 'false',
        'offset': offset.toString(),
      };

      if (effectiveApiKey.isNotEmpty) {
        queryParameters['key'] = effectiveApiKey;
      }

      final uri = Uri.parse(AppConstants.openChargeMapApiBaseUrl).replace(
        queryParameters: queryParameters,
      );

      debugPrint('[OpenChargeMapChargerDataSource] Fetching Page $pageIndex: $uri');

      http.Response response;
      try {
        response = await _client.get(uri).timeout(const Duration(seconds: 20));
      } catch (e) {
        debugPrint('[OpenChargeMapChargerDataSource] Network/Timeout Error: $e');
        if (allChargers.isNotEmpty) break; // Return what we have fetched so far
        throw Exception('Network timeout connecting to Open Charge Map API ($e)');
      }

      if (response.statusCode == 429) {
        debugPrint('[OpenChargeMapChargerDataSource] ❌ OCM Rate Limit Exceeded (HTTP 429)');
        if (allChargers.isNotEmpty) break;
        throw Exception('Open Charge Map API Rate limit exceeded (HTTP 429). Please provide an API Key or try again later.');
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('[OpenChargeMapChargerDataSource] ❌ Invalid API Key (HTTP ${response.statusCode})');
        if (allChargers.isNotEmpty) break;
        throw Exception('Invalid Open Charge Map API key. Please check your API key settings.');
      }

      if (response.statusCode != 200) {
        debugPrint('[OpenChargeMapChargerDataSource] ❌ HTTP Error ${response.statusCode}: ${response.body}');
        if (allChargers.isNotEmpty) break;
        throw Exception('Open Charge Map API returned HTTP ${response.statusCode}');
      }

      final dynamic decoded = json.decode(response.body);
      final List<dynamic> batchJson = (decoded is List) ? decoded : [];

      if (batchJson.isEmpty) {
        debugPrint('[OpenChargeMapChargerDataSource] No more records returned from OCM.');
        break;
      }

      for (final raw in batchJson) {
        if (raw is Map<String, dynamic>) {
          final model = mapOcmJsonToModel(raw);
          if (model != null) {
            allChargers.add(model);
          }
        }
      }

      if (onProgress != null) {
        onProgress(allChargers.length, pageIndex);
      }

      if (batchJson.length < batchSize) {
        break; // Reached end of available API dataset
      }

      offset += batchSize;
      pageIndex++;

      // Small delay between page requests to respect API rate limits
      await Future.delayed(const Duration(milliseconds: 200));
    }

    debugPrint('[OpenChargeMapChargerDataSource] ✓ Total valid India chargers parsed: ${allChargers.length}');
    return allChargers;
  }

  /// Maps an OCM raw POI JSON map into an EVHub [MapMarkerModel].
  /// Performs strict India country validation and coordinate bounds checking.
  static MapMarkerModel? mapOcmJsonToModel(Map<String, dynamic> raw) {
    final rawId = raw['ID']?.toString();
    final addressInfo = raw['AddressInfo'] as Map<String, dynamic>?;

    if (rawId == null || addressInfo == null) return null;

    final title = (addressInfo['Title'] as String?)?.trim() ?? '';
    final lat = (addressInfo['Latitude'] as num?)?.toDouble();
    final lng = (addressInfo['Longitude'] as num?)?.toDouble();

    // 1. Coordinates and title validation
    if (title.isEmpty || lat == null || lng == null) return null;

    // 2. India Bounding Box Validation
    if (lat < minLat || lat > maxLat || lng < minLng || lng > maxLng) {
      debugPrint('[OCM-REJECT] Out of India bounding box: ($lat, $lng) for "$title"');
      return null;
    }

    // 3. Country Metadata Validation
    final countryObj = addressInfo['Country'] as Map<String, dynamic>?;
    if (countryObj != null) {
      final iso = (countryObj['ISOCode'] as String?)?.trim().toUpperCase();
      final countryTitle = (countryObj['Title'] as String?)?.trim().toLowerCase();
      if (iso != null && iso.isNotEmpty && iso != 'IN') {
        debugPrint('[OCM-REJECT] Non-India country code: $iso for "$title"');
        return null;
      }
      if (countryTitle != null && countryTitle.isNotEmpty && !countryTitle.contains('india')) {
        debugPrint('[OCM-REJECT] Non-India country title: $countryTitle for "$title"');
        return null;
      }
    }

    final id = 'ocm_$rawId';
    final address = (addressInfo['AddressLine1'] as String?)?.trim() ?? '';
    final city = (addressInfo['Town'] as String?)?.trim() ?? '';
    final state = (addressInfo['StateOrProvince'] as String?)?.trim() ?? '';
    final phone = (addressInfo['ContactTelephone1'] as String?)?.trim();
    final website = (addressInfo['RelatedURL'] as String?)?.trim();

    // Operator / Network Mapping
    final operatorInfo = raw['OperatorInfo'] as Map<String, dynamic>?;
    String network = 'Unknown Network';
    if (operatorInfo != null) {
      final opTitle = (operatorInfo['Title'] as String?)?.trim();
      if (opTitle != null && opTitle.isNotEmpty && opTitle.toLowerCase() != '(unknown operator)') {
        network = _normalizeNetworkName(opTitle);
      }
    }

    // Connectors and Power Mapping
    final connections = (raw['Connections'] as List<dynamic>?) ?? [];
    final List<String> connectorTypes = [];
    double maxPowerKw = 0.0;
    int totalConnectorsCount = 0;

    for (final conn in connections) {
      if (conn is Map<String, dynamic>) {
        final connType = conn['ConnectionType'] as Map<String, dynamic>?;
        final connTitle = (connType?['Title'] as String?) ?? '';
        final connId = connType?['ID']?.toString() ?? '';
        final power = (conn['PowerKW'] as num?)?.toDouble() ?? 0.0;
        final quantity = (conn['Quantity'] as num?)?.toInt() ?? 1;

        totalConnectorsCount += quantity;
        if (power > maxPowerKw) maxPowerKw = power;

        final mappedType = _mapConnectorType(connTitle, connId);
        if (!connectorTypes.contains(mappedType)) {
          connectorTypes.add(mappedType);
        }
      }
    }

    if (connectorTypes.isEmpty) {
      connectorTypes.addAll(const ['CCS2', 'Type 2']);
    }

    final int totalPorts = totalConnectorsCount > 0 ? totalConnectorsCount : 2;
    final String powerRating = maxPowerKw > 0 ? '${maxPowerKw.toInt()}kW' : '50kW';
    final String powerType = maxPowerKw >= 100 ? 'Ultra Fast' : (maxPowerKw >= 22 ? 'Fast' : 'AC');

    // Status mapping
    final statusType = raw['StatusType'] as Map<String, dynamic>?;
    final isOperational = (statusType?['IsOperational'] as bool?) ?? true;
    final status = isOperational ? MarkerStatus.available : MarkerStatus.offline;

    return MapMarkerModel(
      id: id,
      title: title,
      description: address.isNotEmpty ? address : '$network Charger in $city, $state',
      latitude: lat,
      longitude: lng,
      type: MarkerType.station,
      network: network,
      power: powerRating,
      availableStalls: '$totalPorts/$totalPorts',
      status: status,
      address: address,
      city: city.isNotEmpty ? city : null,
      state: state.isNotEmpty ? state : null,
      country: 'India',
      connectorCount: totalPorts,
      connectors: connectorTypes,
      powerType: powerType,
      source: 'bulk_import',
      isVerified: false,
      verificationStatus: 'approved',
      phoneNumber: phone,
      website: website,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  /// Normalizes Indian EV Network Operator names.
  static String _normalizeNetworkName(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('tata')) return 'Tata Power';
    if (lower.contains('statiq')) return 'Statiq';
    if (lower.contains('jio') || lower.contains('bp pulse')) return 'Jio-bp';
    if (lower.contains('zeon')) return 'Zeon';
    if (lower.contains('chargezone') || lower.contains('charge zone')) return 'ChargeZone';
    if (lower.contains('chargemod')) return 'ChargeMOD';
    if (lower.contains('fortum')) return 'Fortum';
    if (lower.contains('shell')) return 'Shell Recharge';
    if (lower.contains('hpcl')) return 'HPCL';
    if (lower.contains('bpcl')) return 'BPCL';
    if (lower.contains('iocl')) return 'IOCL';
    if (lower.contains('kazam')) return 'Kazam';
    if (lower.contains('plugngo')) return 'PlugNgo';
    if (lower.contains('ather')) return 'Ather Grid';
    return raw;
  }

  /// Normalizes connector types for Indian EV charging standards.
  static String _mapConnectorType(String title, String typeId) {
    final t = title.toLowerCase();
    if (t.contains('ccs') || t.contains('j1772combo') || typeId == '33') return 'CCS2';
    if (t.contains('type 2') || t.contains('mennekes') || typeId == '25') return 'Type 2';
    if (t.contains('chademo') || typeId == '2') return 'CHAdeMO';
    if (t.contains('bharat dc') || t.contains('dc-001') || t.contains('dc001')) return 'Bharat DC-001';
    if (t.contains('bharat ac') || t.contains('ac-001') || t.contains('ac001')) return 'Bharat AC-001';
    if (t.contains('gb/t') || t.contains('gbt') || typeId == '27' || typeId == '32') return 'GB/T';
    if (t.contains('type 1') || t.contains('j1772') || typeId == '1') return 'Type 1';
    if (t.contains('tesla') || t.contains('nacs') || typeId == '30') return 'Tesla / NACS';
    return title.isNotEmpty ? title : 'CCS2';
  }
}
