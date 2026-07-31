import 'package:flutter_test/flutter_test.dart';
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

    test('Test 5: Autocomplete returns Delhi suggestions with description containing Delhi', () async {
      final suggestions = await mapsService.getAutocompleteSuggestions('Delhi');
      expect(suggestions.isNotEmpty, isTrue);

      // Find any result that mentions Delhi
      final delhiResult = suggestions.firstWhere(
        (s) => s['description'].toString().toLowerCase().contains('delhi'),
        orElse: () => suggestions.first,
      );
      expect(delhiResult['description'].toString().toLowerCase(), contains('delhi'));

      // Google Places results have lat=0.0 (resolved on selection via Place Details API).
      // Local fallback results have valid coords directly.
      final lat = (delhiResult['latitude'] as num?)?.toDouble() ?? 0.0;
      final lng = (delhiResult['longitude'] as num?)?.toDouble() ?? 0.0;

      if (lat != 0.0) {
        // Local fallback result: must have valid Delhi coordinates
        expect(lat, closeTo(28.6139, 0.5));
        expect(lng, closeTo(77.2090, 0.5));
      } else {
        // Google Places result: resolve via Geocoding API
        final coords = await mapsService.getCoordinatesFromAddress(
            delhiResult['description'] as String);
        expect(coords, isNotNull);
        expect(coords!.latitude, closeTo(28.6, 1.0)); // Wider tolerance for geocoding
      }
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
