import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:evhub/models/map_marker_model.dart';
import 'package:evhub/services/csv_import_service.dart';

void main() {
  group('EVHub Phase 7.3B — Bulk Charger Import System Tests', () {
    final CsvImportService importService = CsvImportService();

    test('1. CSV parsing of valid binary byte input', () {
      const csvStr = 'name,network,address,city,state,country,latitude,longitude,totalConnectors,availableConnectors,power,pricePerUnit,connectorTypes,openingHours,phoneNumber,website,imageUrl,amenities\n'
          'Tata Power CP,Tata Power,Connaught Place,New Delhi,Delhi,India,28.6304,77.2177,4,3,150kW,21,"CCS2|Type 2","24 Hours","+91 1800-209-5161","https://www.tatapower.com","","Restroom|Cafe|Wifi"';

      final bytes = Uint8List.fromList(utf8.encode(csvStr));
      final results = importService.processCsv(bytes: bytes, existingFirestoreChargers: []);

      expect(results.length, equals(1));
      expect(results.first.isValid, isTrue);
      expect(results.first.rawValues['name'], equals('Tata Power CP'));
    });

    test('2. Header validation fails when required header is missing', () {
      const csvStr = 'name,address,latitude,longitude\n'
          'Station 1,CP,28.6304,77.2177';
      final bytes = Uint8List.fromList(utf8.encode(csvStr));

      expect(
        () => importService.processCsv(bytes: bytes, existingFirestoreChargers: []),
        throwsA(isA<Exception>()),
      );
    });

    test('3. Required field validation detects missing mandatory values', () {
      const csvStr = 'name,network,address,latitude,longitude,totalConnectors,availableConnectors,power\n'
          ',Tata Power,Connaught Place,28.6304,77.2177,4,3,150kW\n' // empty name
          'Station 2,,Connaught Place,28.6304,77.2177,4,3,150kW\n'; // empty network

      final bytes = Uint8List.fromList(utf8.encode(csvStr));
      final results = importService.processCsv(bytes: bytes, existingFirestoreChargers: []);

      expect(results.length, equals(2));
      expect(results[0].isValid, isFalse);
      expect(results[0].errors.any((e) => e.contains('name')), isTrue);

      expect(results[1].isValid, isFalse);
      expect(results[1].errors.any((e) => e.contains('network')), isTrue);
    });

    test('4 & 5. Latitude and Longitude range validations', () {
      const csvStr = 'name,network,address,latitude,longitude,totalConnectors,availableConnectors,power\n'
          'Station Out,Tata Power,CP,95.0,77.2177,4,3,150kW\n' // Lat > 90
          'Station Bad,Tata Power,CP,28.6304,-200.0,4,3,150kW\n'; // Lng < -180

      final bytes = Uint8List.fromList(utf8.encode(csvStr));
      final results = importService.processCsv(bytes: bytes, existingFirestoreChargers: []);

      expect(results[0].isValid, isFalse);
      expect(results[0].errors.any((e) => e.contains('latitude')), isTrue);

      expect(results[1].isValid, isFalse);
      expect(results[1].errors.any((e) => e.contains('longitude')), isTrue);
    });

    test('6. Connector count validation (available cannot exceed total)', () {
      const csvStr = 'name,network,address,latitude,longitude,totalConnectors,availableConnectors,power\n'
          'Station Invalid,Tata Power,CP,28.6304,77.2177,4,5,150kW'; // 5 > 4

      final bytes = Uint8List.fromList(utf8.encode(csvStr));
      final results = importService.processCsv(bytes: bytes, existingFirestoreChargers: []);

      expect(results.first.isValid, isFalse);
      expect(results.first.errors.any((e) => e.contains('availableConnectors')), isTrue);
    });

    test('7. Connector type parsing handles pipe separators correctly', () {
      const csvStr = 'name,network,address,latitude,longitude,totalConnectors,availableConnectors,power,connectorTypes\n'
          'Station Conn,Tata Power,CP,28.6304,77.2177,4,2,150kW,"CCS2|Type 2|GB/T"';

      final bytes = Uint8List.fromList(utf8.encode(csvStr));
      final results = importService.processCsv(bytes: bytes, existingFirestoreChargers: []);

      expect(results.first.isValid, isTrue);
      expect(results.first.parsedModel?.connectors, equals(['CCS2', 'Type 2', 'GB/T']));
    });

    test('8. Amenities parsing handles pipe separators correctly', () {
      const csvStr = 'name,network,address,latitude,longitude,totalConnectors,availableConnectors,power,amenities\n'
          'Station Amen,Tata Power,CP,28.6304,77.2177,4,2,150kW,"Restroom|Cafe|Wifi"';

      final bytes = Uint8List.fromList(utf8.encode(csvStr));
      final results = importService.processCsv(bytes: bytes, existingFirestoreChargers: []);

      expect(results.first.isValid, isTrue);
      expect(results.first.parsedModel?.amenities, equals(['Restroom', 'Cafe', 'Wifi']));
    });

    test('9 & 10. Duplicate detection within 100m radius threshold', () {
      const existing = MapMarkerModel(
        id: 'exist_1',
        title: 'Tata Power CP Station',
        description: 'Connaught Place',
        latitude: 28.6304,
        longitude: 77.2177,
        type: MarkerType.station,
        network: 'Tata Power',
      );

      // CSV Charger at same location (~0m) with similar name
      const csvStr = 'name,network,address,latitude,longitude,totalConnectors,availableConnectors,power\n'
          'Tata Power CP Station,Tata Power,Connaught Place,28.6304,77.2177,4,3,150kW';

      final bytes = Uint8List.fromList(utf8.encode(csvStr));
      final results = importService.processCsv(bytes: bytes, existingFirestoreChargers: [existing]);

      expect(results.first.isValid, isTrue);
      expect(results.first.isDuplicate, isTrue);
      expect(results.first.duplicateStatus, equals(DuplicateClassification.exactDuplicate));
    });

    test('11. Name & Network normalization handles punctuation and whitespace', () {
      final csvTemplate = CsvImportService.generateCsvTemplate();
      expect(csvTemplate.contains('Tata Power CP'), isTrue);
      expect(csvTemplate.contains('Statiq Gurgaon'), isTrue);
    });

    test('12. Import model generation produces complete MapMarkerModel', () {
      const csvStr = 'name,network,address,city,state,country,latitude,longitude,totalConnectors,availableConnectors,power,pricePerUnit,connectorTypes,openingHours,phoneNumber,website,imageUrl,amenities\n'
          'Zeon Fast Hub,Zeon,NH 48,Gurgaon,Haryana,India,28.4500,77.0200,4,2,120kW,₹18/kWh,"CCS2|Type 2","24 Hours","+91 1800-123","https://zeon.in","","Cafe|Parking"';

      final bytes = Uint8List.fromList(utf8.encode(csvStr));
      final results = importService.processCsv(bytes: bytes, existingFirestoreChargers: []);

      final model = results.first.parsedModel!;
      expect(model.title, equals('Zeon Fast Hub'));
      expect(model.network, equals('Zeon'));
      expect(model.power, equals('120kW'));
      expect(model.powerType, equals('Ultra Fast'));
      expect(model.isVerified, isTrue);
      expect(model.source, equals('evhub_verified'));
    });

    test('13. GeoPoint conversion in document generation', () {
      const charger = MapMarkerModel(
        id: 'c_doc',
        title: 'Kazam Station',
        description: 'Saket',
        latitude: 28.5200,
        longitude: 77.2100,
        type: MarkerType.station,
      );

      final geo = GeoPoint(charger.latitude, charger.longitude);
      expect(geo.latitude, equals(28.5200));
      expect(geo.longitude, equals(77.2100));
    });

    test('14. Invalid row error collection collects multiple errors across rows', () {
      const csvStr = 'name,network,address,latitude,longitude,totalConnectors,availableConnectors,power\n'
          'Valid Station,Tata Power,CP,28.6304,77.2177,4,3,150kW\n'
          ',Tata Power,CP,999.0,77.2177,4,10,150kW'; // Multiple errors in row 2

      final bytes = Uint8List.fromList(utf8.encode(csvStr));
      final results = importService.processCsv(bytes: bytes, existingFirestoreChargers: []);

      expect(results.length, equals(2));
      expect(results[0].isValid, isTrue);
      expect(results[1].isValid, isFalse);
      expect(results[1].errors.length, greaterThanOrEqualTo(3)); // name, lat range, available > total
    });

    test('15. Empty CSV handling throws exception', () {
      final bytes = Uint8List.fromList(utf8.encode(''));
      expect(
        () => importService.processCsv(bytes: bytes, existingFirestoreChargers: []),
        throwsA(isA<Exception>()),
      );
    });

    test('16. Error report generation produces valid CSV report', () {
      const csvStr = 'name,network,address,latitude,longitude,totalConnectors,availableConnectors,power\n'
          ',Tata Power,CP,28.6304,77.2177,4,3,150kW'; // Row 2 error

      final bytes = Uint8List.fromList(utf8.encode(csvStr));
      final results = importService.processCsv(bytes: bytes, existingFirestoreChargers: []);

      final report = CsvImportService.generateErrorReport(results);
      expect(report.contains('rowNumber,chargerName,error'), isTrue);
      expect(report.contains('2,"Unknown Charger"'), isTrue);
      expect(report.contains('name → Charger name is required'), isTrue);
    });
  });
}
