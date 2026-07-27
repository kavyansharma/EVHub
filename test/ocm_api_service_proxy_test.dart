import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:evhub/services/ocm_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OcmApiService Production Proxy Unit Tests', () {
    test('Proxy Mode throws HTTP 401 when no token is present', () async {
      final client = http_testing.MockClient((request) async {
        return http.Response('{"error": {"status": "UNAUTHENTICATED", "message": "Authentication required"}}', 401);
      });

      final service = OcmApiService(client: client);

      expect(
        () => service.fetchChargersWithStats(options: {'limit': 50}),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Cloud Function HTTP 401'),
        )),
      );
    });

    test('Proxy Mode throws clean exception when Secret Manager secret is missing', () async {
      final client = http_testing.MockClient((request) async {
        return http.Response(
          json.encode({
            'error': {
              'status': 'FAILED_PRECONDITION',
              'message': 'OPEN_CHARGE_MAP_API_KEY secret is not configured in Firebase Secret Manager.'
            }
          }),
          400,
        );
      });

      final service = OcmApiService(client: client);

      expect(
        () => service.fetchChargersWithStats(options: {'limit': 50, 'mockIdToken': 'valid_admin_token'}),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Missing Secret Manager secret'),
        )),
      );
    });

    test('Proxy Mode throws HTTP 403 when caller is not an admin', () async {
      final client = http_testing.MockClient((request) async {
        return http.Response('{"error": {"status": "PERMISSION_DENIED", "message": "Access denied"}}', 403);
      });

      final service = OcmApiService(client: client);

      expect(
        () => service.fetchChargersWithStats(options: {'limit': 50, 'mockIdToken': 'non_admin_token'}),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Cloud Function HTTP 403'),
        )),
      );
    });

    test('Proxy Mode throws HTTP 429 on rate limit', () async {
      final client = http_testing.MockClient((request) async {
        return http.Response('{"error": {"status": "RESOURCE_EXHAUSTED", "message": "Rate limit"}}', 429);
      });

      final service = OcmApiService(client: client);

      expect(
        () => service.fetchChargersWithStats(options: {'limit': 50, 'mockIdToken': 'admin_token'}),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('OCM rate limit exceeded'),
        )),
      );
    });

    test('Proxy Mode parses valid JSON payload returned from Cloud Function proxy', () async {
      final mockResponseJson = {
        'result': {
          'status': 'success',
          'totalApiRecords': 1,
          'validIndiaRecords': 1,
          'nonIndiaRejectedCount': 0,
          'invalidCoordCount': 0,
          'chargers': [
            {
              'ID': 10001,
              'AddressInfo': {
                'Title': 'Statiq Hub Delhi',
                'Latitude': 28.6139,
                'Longitude': 77.2090,
                'Country': {'ISOCode': 'IN', 'Title': 'India'},
              },
              'OperatorInfo': {'Title': 'Statiq'},
            }
          ]
        }
      };

      final client = http_testing.MockClient((request) async {
        expect(request.url.toString(), equals('https://us-central1-evhub-9e25f.cloudfunctions.net/ocmProxy'));
        expect(request.headers['Content-Type'], equals('application/json'));
        expect(request.headers['Authorization'], equals('Bearer valid_admin_token'));
        return http.Response(json.encode(mockResponseJson), 200);
      });

      final service = OcmApiService(client: client);
      final result = await service.fetchChargersWithStats(options: {
        'limit': 50,
        'useDirectMode': false,
        'mockIdToken': 'valid_admin_token',
      });

      expect(result.validChargers.length, equals(1));
      expect(result.validChargers.first.title, equals('Statiq Hub Delhi'));
      expect(result.totalApiRecords, equals(1));
    });
  });
}
