import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/map_marker_model.dart';

enum DuplicateClassification { newCharger, exactDuplicate, possibleDuplicate }

class CsvRowValidationResult {
  final int rowNumber;
  final Map<String, String> rawValues;
  final bool isValid;
  final List<String> errors;
  final DuplicateClassification duplicateStatus;
  final MapMarkerModel? existingDuplicateCharger;
  final double? duplicateDistanceMeters;
  final MapMarkerModel? parsedModel;

  const CsvRowValidationResult({
    required this.rowNumber,
    required this.rawValues,
    required this.isValid,
    required this.errors,
    required this.duplicateStatus,
    this.existingDuplicateCharger,
    this.duplicateDistanceMeters,
    this.parsedModel,
  });

  bool get isDuplicate =>
      duplicateStatus == DuplicateClassification.exactDuplicate ||
      duplicateStatus == DuplicateClassification.possibleDuplicate;

  String get statusLabel {
    if (!isValid) return '❌ Invalid';
    if (duplicateStatus == DuplicateClassification.exactDuplicate) return '⚠️ Exact Duplicate';
    if (duplicateStatus == DuplicateClassification.possibleDuplicate) return '⚠️ Possible Duplicate';
    return '✅ Valid';
  }
}

class CsvImportService {
  static const List<String> requiredHeaders = [
    'name',
    'network',
    'address',
    'latitude',
    'longitude',
    'totalconnectors',
    'availableconnectors',
    'power',
  ];

  static const List<String> supportedConnectorTypes = [
    'CCS2',
    'Type 2',
    'CHAdeMO',
    'GB/T',
    'Other',
  ];

  /// Parses CSV byte data, validates header and every row, and performs duplicate checking against existing Firestore chargers.
  List<CsvRowValidationResult> processCsv({
    required Uint8List bytes,
    required List<MapMarkerModel> existingFirestoreChargers,
  }) {
    String content;
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      content = latin1.decode(bytes);
    }

    final normalizedContent = content.replaceAll('\r\n', '\n');
    final List<List<dynamic>> rows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(normalizedContent);

    if (rows.isEmpty) {
      throw Exception('CSV file is empty');
    }

    // Header validation
    final List<String> headers = rows.first
        .map((e) => e.toString().trim().toLowerCase())
        .toList();

    for (final req in requiredHeaders) {
      if (!headers.contains(req)) {
        throw Exception(
          'Missing required header "$req". Header row must include: name, network, address, latitude, longitude, totalConnectors, availableConnectors, power',
        );
      }
    }

    final Map<String, int> headerIndexMap = {};
    for (int i = 0; i < headers.length; i++) {
      headerIndexMap[headers[i]] = i;
    }

    final List<CsvRowValidationResult> results = [];
    final List<MapMarkerModel> batchProcessedChargers = [];

    // Row processing (start from row index 1)
    for (int i = 1; i < rows.length; i++) {
      final rowData = rows[i];
      // Skip completely empty trailing lines
      if (rowData.isEmpty || (rowData.length == 1 && rowData[0].toString().trim().isEmpty)) {
        continue;
      }

      final int rowNum = i + 1; // 1-based row number for display
      final Map<String, String> rawMap = {};

      for (final entry in headerIndexMap.entries) {
        final colIdx = entry.value;
        if (colIdx < rowData.length) {
          rawMap[entry.key] = rowData[colIdx].toString().trim();
        } else {
          rawMap[entry.key] = '';
        }
      }

      // Validate single row
      final List<String> errors = [];
      final name = rawMap['name'] ?? '';
      final network = rawMap['network'] ?? '';
      final address = rawMap['address'] ?? '';
      final latStr = rawMap['latitude'] ?? '';
      final lngStr = rawMap['longitude'] ?? '';
      final totalConnStr = rawMap['totalconnectors'] ?? rawMap['total_connectors'] ?? '';
      final availConnStr = rawMap['availableconnectors'] ?? rawMap['available_connectors'] ?? '';
      final powerStr = rawMap['power'] ?? '';

      if (name.isEmpty) errors.add('name → Charger name is required');
      if (network.isEmpty) errors.add('network → Network is required');
      if (address.isEmpty) errors.add('address → Address is required');

      double? lat;
      if (latStr.isEmpty) {
        errors.add('latitude → Latitude is required');
      } else {
        lat = double.tryParse(latStr);
        if (lat == null || lat < -90.0 || lat > 90.0) {
          errors.add('latitude → Invalid latitude (-90 to 90)');
        }
      }

      double? lng;
      if (lngStr.isEmpty) {
        errors.add('longitude → Longitude is required');
      } else {
        lng = double.tryParse(lngStr);
        if (lng == null || lng < -180.0 || lng > 180.0) {
          errors.add('longitude → Invalid longitude (-180 to 180)');
        }
      }

      int? totalConn;
      if (totalConnStr.isEmpty) {
        errors.add('totalConnectors → Total connectors is required');
      } else {
        totalConn = int.tryParse(totalConnStr);
        if (totalConn == null || totalConn < 1) {
          errors.add('totalConnectors → Must be an integer >= 1');
        }
      }

      int? availConn;
      if (availConnStr.isEmpty) {
        errors.add('availableConnectors → Available connectors is required');
      } else {
        availConn = int.tryParse(availConnStr);
        if (availConn == null || availConn < 0) {
          errors.add('availableConnectors → Cannot be negative');
        } else if (totalConn != null && availConn > totalConn) {
          errors.add('availableConnectors → Cannot be greater than totalConnectors ($totalConn)');
        }
      }

      if (powerStr.isEmpty) errors.add('power → Power is required (e.g. 150kW)');

      // Process optional fields
      final city = rawMap['city'] ?? '';
      final state = rawMap['state'] ?? '';
      final country = rawMap['country'] ?? 'India';
      final pricePerUnit = (rawMap['priceperunit'] ?? rawMap['price'] ?? '').isNotEmpty
          ? (rawMap['priceperunit'] ?? rawMap['price']!)
          : '₹21/kWh';
      final openingHours = (rawMap['openinghours'] ?? '').isNotEmpty
          ? rawMap['openinghours']!
          : '24 Hours';
      final phoneNumber = rawMap['phonenumber'] ?? rawMap['phone'] ?? '';
      final website = rawMap['website'] ?? '';
      final imageUrl = rawMap['imageurl'] ?? rawMap['image'] ?? '';

      final rawConnTypes = rawMap['connectortypes'] ?? rawMap['connectors'] ?? '';
      final List<String> connectorsList = rawConnTypes.isNotEmpty
          ? rawConnTypes.split('|').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
          : ['CCS2', 'Type 2'];

      final rawAmenities = rawMap['amenities'] ?? '';
      final List<String> amenitiesList = rawAmenities.isNotEmpty
          ? rawAmenities.split('|').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
          : [];

      MapMarkerModel? parsedModel;
      DuplicateClassification duplicateStatus = DuplicateClassification.newCharger;
      MapMarkerModel? duplicateMatch;
      double? minDistanceMeters;

      if (errors.isEmpty && lat != null && lng != null && totalConn != null && availConn != null) {
        final double powerKw = double.tryParse(RegExp(r'[0-9.]+').firstMatch(powerStr)?.group(0) ?? '50') ?? 50.0;
        final String powerType = powerKw >= 100.0 ? 'Ultra Fast' : powerKw >= 22.0 ? 'Fast' : 'AC';
        final MarkerStatus status = availConn > 0 ? MarkerStatus.available : (totalConn > 0 ? MarkerStatus.busy : MarkerStatus.unknown);
        final String availableStalls = '$availConn/$totalConn';

        parsedModel = MapMarkerModel(
          id: 'import_csv_${DateTime.now().millisecondsSinceEpoch}_$rowNum',
          title: name,
          description: address,
          latitude: lat,
          longitude: lng,
          type: MarkerType.station,
          network: network,
          rating: 4.8,
          power: powerStr,
          availableStalls: availableStalls,
          status: status,
          photoUrl: imageUrl,
          address: address,
          openStatus: status == MarkerStatus.offline ? 'Offline' : 'Open',
          price: pricePerUnit,
          connectorCount: totalConn,
          connectors: connectorsList,
          powerType: powerType,
          openingHours: openingHours,
          source: 'evhub_verified',
          isVerified: true,
          phoneNumber: phoneNumber,
          website: website,
          city: city,
          state: state,
          country: country.isNotEmpty ? country : 'India',
          amenities: amenitiesList,
          verificationStatus: 'approved',
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        );

        // Check for duplicates against existing Firestore chargers & current batch
        final List<MapMarkerModel> candidates = [
          ...existingFirestoreChargers,
          ...batchProcessedChargers,
        ];

        for (final existing in candidates) {
          final dist = Geolocator.distanceBetween(lat, lng, existing.latitude, existing.longitude);
          if (dist <= 100.0) { // Within 100 meters
            final bool nameSimilar = _areNamesSimilar(name, existing.title);
            final bool networkMatches = _normalize(network) == _normalize(existing.network);

            if (nameSimilar && networkMatches) {
              duplicateStatus = DuplicateClassification.exactDuplicate;
              duplicateMatch = existing;
              minDistanceMeters = dist;
              break;
            } else if (nameSimilar || networkMatches || dist <= 30.0) {
              duplicateStatus = DuplicateClassification.possibleDuplicate;
              duplicateMatch = existing;
              minDistanceMeters = dist;
            }
          }
        }

        if (duplicateStatus == DuplicateClassification.newCharger) {
          batchProcessedChargers.add(parsedModel);
        }
      }

      results.add(CsvRowValidationResult(
        rowNumber: rowNum,
        rawValues: rawMap,
        isValid: errors.isEmpty,
        errors: errors,
        duplicateStatus: duplicateStatus,
        existingDuplicateCharger: duplicateMatch,
        duplicateDistanceMeters: minDistanceMeters,
        parsedModel: parsedModel,
      ));
    }

    return results;
  }

  /// Processes a list of pre-parsed models (e.g. from NREL API or external source)
  /// and performs deduplication against existing Firestore chargers.
  List<CsvRowValidationResult> processFetchedChargers({
    required List<MapMarkerModel> fetchedChargers,
    required List<MapMarkerModel> existingFirestoreChargers,
  }) {
    final List<CsvRowValidationResult> results = [];
    final List<MapMarkerModel> batchProcessedChargers = [];

    for (int i = 0; i < fetchedChargers.length; i++) {
      final charger = fetchedChargers[i];
      final int rowNum = i + 1;

      final Map<String, String> rawMap = {
        'id': charger.id,
        'name': charger.title,
        'network': charger.network,
        'address': charger.address ?? charger.description,
        'latitude': charger.latitude.toString(),
        'longitude': charger.longitude.toString(),
        'city': charger.city ?? '',
        'state': charger.state ?? '',
        'country': charger.country ?? '',
        'source': charger.source,
      };

      final List<String> errors = [];
      if (charger.title.isEmpty) errors.add('name → Charger name is required');
      if (charger.latitude < -90.0 || charger.latitude > 90.0) errors.add('latitude → Invalid latitude');
      if (charger.longitude < -180.0 || charger.longitude > 180.0) errors.add('longitude → Invalid longitude');

      DuplicateClassification duplicateStatus = DuplicateClassification.newCharger;
      MapMarkerModel? duplicateMatch;
      double? minDistanceMeters;

      if (errors.isEmpty) {
        final List<MapMarkerModel> candidates = [
          ...existingFirestoreChargers,
          ...batchProcessedChargers,
        ];

        for (final existing in candidates) {
          // Check 1: External ID / sourceId Match
          final bool sameSourceId = (charger.sourceId != null && existing.sourceId != null && charger.sourceId == existing.sourceId);
          final bool sameId = charger.id.isNotEmpty && charger.id == existing.id;
          if (sameId || sameSourceId) {
            duplicateStatus = DuplicateClassification.exactDuplicate;
            duplicateMatch = existing;
            minDistanceMeters = 0.0;
            break;
          }

          // Check 2: 100m Distance + Name Similarity Match
          final dist = Geolocator.distanceBetween(
            charger.latitude,
            charger.longitude,
            existing.latitude,
            existing.longitude,
          );

          if (dist <= 100.0) {
            final bool nameSimilar = _areNamesSimilar(charger.title, existing.title);
            final bool networkMatches = _normalize(charger.network) == _normalize(existing.network);

            if (nameSimilar && networkMatches) {
              duplicateStatus = DuplicateClassification.exactDuplicate;
              duplicateMatch = existing;
              minDistanceMeters = dist;
              break;
            } else if (nameSimilar || networkMatches || dist <= 30.0) {
              duplicateStatus = DuplicateClassification.possibleDuplicate;
              duplicateMatch = existing;
              minDistanceMeters = dist;
            }
          }
        }

        if (duplicateStatus == DuplicateClassification.newCharger) {
          batchProcessedChargers.add(charger);
        }
      }

      results.add(CsvRowValidationResult(
        rowNumber: rowNum,
        rawValues: rawMap,
        isValid: errors.isEmpty,
        errors: errors,
        duplicateStatus: duplicateStatus,
        existingDuplicateCharger: duplicateMatch,
        duplicateDistanceMeters: minDistanceMeters,
        parsedModel: charger,
      ));
    }

    return results;
  }

  /// Batch writes valid chargers to Firestore in chunks of <= 400 documents.
  Future<int> performBatchImport({
    required List<MapMarkerModel> chargersToImport,
    required String adminUid,
    required String adminName,
    required void Function(int processed, int total) onProgress,
  }) async {
    if (chargersToImport.isEmpty) return 0;

    final firestore = FirebaseFirestore.instance;
    int successfullyImported = 0;
    const int chunkSize = 400; // Safe chunk size below Firestore 500-operation limit

    for (int i = 0; i < chargersToImport.length; i += chunkSize) {
      final chunk = chargersToImport.sublist(
        i,
        i + chunkSize > chargersToImport.length ? chargersToImport.length : i + chunkSize,
      );

      final batch = firestore.batch();

      for (final charger in chunk) {
        final docRef = firestore.collection('chargers').doc(charger.id);
        final int avail = charger.availableConnectorsCount;
        final int total = charger.connectorCount;
        final int occupied = charger.occupiedConnectorsCount;

        final Map<String, dynamic> docData = {
          'id': charger.id,
          'name': charger.title,
          'address': charger.address ?? charger.description,
          'city': charger.city ?? '',
          'state': charger.state ?? '',
          'country': charger.country ?? 'India',
          'network': charger.network,
          'location': GeoPoint(charger.latitude, charger.longitude),
          'rating': charger.rating,
          'power': charger.power,
          'powerType': charger.powerType,
          'pricePerUnit': charger.price ?? '₹21/kWh',
          'status': charger.status.name,
          'totalConnectors': total,
          'availableConnectors': avail,
          'occupiedConnectors': occupied,
          'imageUrl': charger.photoUrl,
          'connectorTypes': charger.connectors,
          'openingHours': charger.openingHours,
          'phoneNumber': charger.phoneNumber,
          'website': charger.website,
          'amenities': charger.amenities ?? [],
          'description': charger.description,
          'ownerId': adminUid,
          'createdBy': adminName,
          'isVerified': charger.isVerified,
          'verificationStatus': charger.verificationStatus,
          'verifiedBy': charger.isVerified ? adminUid : null,
          'source': charger.source,
          'sourceId': charger.sourceId ?? charger.id,
          'lastSyncedAt': charger.lastSyncedAt ?? DateTime.now().toIso8601String(),
          'lastSeenAt': charger.lastSeenAt ?? DateTime.now().toIso8601String(),
          'isStale': charger.isStale,
          'dataConfidence': charger.dataConfidence,
          'originalOperatorTitle': charger.originalOperatorTitle,
          'sourceUrl': charger.sourceUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        };

        batch.set(docRef, docData);
      }

      await batch.commit();
      successfullyImported += chunk.length;
      onProgress(successfullyImported, chargersToImport.length);
    }

    return successfullyImported;
  }

  /// Generates sample CSV template content for EVHub admins.
  static String generateCsvTemplate() {
    final StringBuffer sb = StringBuffer();
    sb.writeln('name,network,address,city,state,country,latitude,longitude,totalConnectors,availableConnectors,power,pricePerUnit,connectorTypes,openingHours,phoneNumber,website,imageUrl,amenities');
    sb.writeln('Tata Power CP,Tata Power,Connaught Place,New Delhi,Delhi,India,28.6304,77.2177,4,3,150kW,21,"CCS2|Type 2","24 Hours","+91 1800-209-5161","https://www.tatapower.com","","Restroom|Cafe|Wifi"');
    sb.writeln('Statiq Gurgaon,Statiq,MG Road,Gurgaon,Haryana,India,28.4595,77.0266,6,4,120kW,18,"CCS2|Type 2","24 Hours","","https://www.statiq.in","","Cafe|Parking"');
    return sb.toString();
  }

  /// Generates downloadable CSV error report string from row validation results.
  static String generateErrorReport(List<CsvRowValidationResult> results) {
    final StringBuffer sb = StringBuffer();
    sb.writeln('rowNumber,chargerName,error');
    for (final res in results) {
      if (!res.isValid) {
        final rawName = res.rawValues['name'] ?? '';
        final name = rawName.trim().isNotEmpty ? rawName.trim() : 'Unknown Charger';
        final errText = res.errors.join('; ');
        sb.writeln('${res.rowNumber},"${name.replaceAll('"', '""')}","${errText.replaceAll('"', '""')}"');
      }
    }
    return sb.toString();
  }

  bool _areNamesSimilar(String name1, String name2) {
    final norm1 = _normalize(name1);
    final norm2 = _normalize(name2);
    if (norm1.isEmpty || norm2.isEmpty) return false;
    if (norm1 == norm2 || norm1.contains(norm2) || norm2.contains(norm1)) return true;

    final words1 = norm1.split(' ').where((w) => w.length > 2).toSet();
    final words2 = norm2.split(' ').where((w) => w.length > 2).toSet();
    if (words1.isEmpty || words2.isEmpty) return false;

    final intersection = words1.intersection(words2);
    return intersection.length / (words1.length < words2.length ? words1.length : words2.length) >= 0.5;
  }

  String _normalize(String str) {
    return str
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
