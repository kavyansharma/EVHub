import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:evhub/services/maps_service.dart';

void main() {
  group('Location Search & Fallback Engine Unit Tests', () {
    late MapsService mapsService;

    setUp(() {
      mapsService = MapsService();
    });

    test('Test 1: Search "Delhi" returns valid Delhi coordinates (~28.6139, 77.2090)', () async {
      final results = mapsService.searchLocalLocationIndex('Delhi');
      expect(results.isNotEmpty, isTrue);

      final delhi = results.first;
      expect(delhi.displayName.contains('Delhi'), isTrue);
      expect(delhi.latitude, closeTo(28.6139, 0.05));
      expect(delhi.longitude, closeTo(77.2090, 0.05));
    });

    test('Test 2: Search "New Delhi" resolves correctly', () async {
      final results = mapsService.searchLocalLocationIndex('New Delhi');
      expect(results.isNotEmpty, isTrue);

      final newDelhi = results.first;
      expect(newDelhi.displayName.contains('Delhi'), isTrue);
      expect(newDelhi.latitude, closeTo(28.6139, 0.05));
    });

    test('Test 3: Search "Delhi NCR" resolves correctly via alias', () async {
      final results = mapsService.searchLocalLocationIndex('Delhi NCR');
      expect(results.isNotEmpty, isTrue);

      final delhiNcr = results.first;
      expect(delhiNcr.displayName.contains('Delhi'), isTrue);
      expect(delhiNcr.latitude, closeTo(28.6139, 0.05));
    });

    test('Test 4: Search "delhi" (lowercase) resolves correctly', () async {
      final results = mapsService.searchLocalLocationIndex('delhi');
      expect(results.isNotEmpty, isTrue);

      final lowerDelhi = results.first;
      expect(lowerDelhi.displayName.contains('Delhi'), isTrue);
      expect(lowerDelhi.latitude, closeTo(28.6139, 0.05));
    });

    test('Test 5: Google Places API or Local Fallback returns valid Delhi search suggestion', () async {
      final suggestions = await mapsService.getAutocompleteSuggestions('Delhi');
      expect(suggestions.isNotEmpty, isTrue);

      final first = suggestions.first;
      expect(first['description'].toString().contains('Delhi'), isTrue);

      final coords = (first['latitude'] != null)
          ? LatLng(first['latitude'] as double, first['longitude'] as double)
          : await mapsService.getCoordinatesFromAddress(first['description'] as String);

      expect(coords, isNotNull);
      expect(coords!.latitude, closeTo(28.6139, 0.05));
    });

    test('Test 6: Search "Gurgaon" returns Gurugram coordinates (28.4595, 77.0266)', () async {
      final results = mapsService.searchLocalLocationIndex('Gurgaon');
      expect(results.isNotEmpty, isTrue);

      final gurugram = results.first;
      expect(gurugram.displayName.contains('Gurugram'), isTrue);
      expect(gurugram.latitude, closeTo(28.4595, 0.05));
      expect(gurugram.longitude, closeTo(77.0266, 0.05));
    });

    test('Test 7: Search "Bangalore" returns Bengaluru coordinates (12.9716, 77.5946)', () async {
      final results = mapsService.searchLocalLocationIndex('Bangalore');
      expect(results.isNotEmpty, isTrue);

      final bengaluru = results.first;
      expect(bengaluru.displayName.contains('Bengaluru'), isTrue);
      expect(bengaluru.latitude, closeTo(12.9716, 0.05));
      expect(bengaluru.longitude, closeTo(77.5946, 0.05));
    });
  });
}
