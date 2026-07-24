import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:evhub/models/map_marker_model.dart';
import 'package:evhub/models/user_model.dart';

void main() {
  group('EVHub Phase 7.3A — Admin Charger Management System Tests', () {
    test('1. Admin charger model creation', () {
      const charger = MapMarkerModel(
        id: 'admin_charger_101',
        title: 'Tata Power Fast EV Station',
        description: 'Aerocity, New Delhi',
        latitude: 28.5562,
        longitude: 77.1200,
        type: MarkerType.station,
        network: 'Tata Power',
        rating: 4.9,
        power: '150kW',
        availableStalls: '3/4',
        status: MarkerStatus.available,
        photoUrl: 'https://example.com/charger.jpg',
        address: 'Aerocity Worldmark 1, New Delhi',
        price: '₹22/kWh',
        connectorCount: 4,
        connectors: ['CCS2', 'Type 2'],
        powerType: 'Ultra Fast',
        openingHours: '24 Hours',
        source: 'evhub_verified',
        isVerified: true,
        city: 'New Delhi',
        state: 'Delhi',
        country: 'India',
        amenities: ['Restroom', 'Café', 'Wifi'],
      );

      expect(charger.id, equals('admin_charger_101'));
      expect(charger.title, equals('Tata Power Fast EV Station'));
      expect(charger.network, equals('Tata Power'));
      expect(charger.isVerified, isTrue);
      expect(charger.source, equals('evhub_verified'));
      expect(charger.city, equals('New Delhi'));
      expect(charger.country, equals('India'));
      expect(charger.amenities, contains('Café'));
    });

    test('2. GeoPoint conversion', () {
      const GeoPoint point = GeoPoint(28.6304, 77.2177);
      expect(point.latitude, equals(28.6304));
      expect(point.longitude, equals(77.2177));

      final charger = MapMarkerModel(
        id: 'c_geo',
        title: 'Connaught Place Charger',
        description: 'CP Outer Circle',
        latitude: point.latitude,
        longitude: point.longitude,
        type: MarkerType.station,
      );

      expect(charger.latitude, equals(28.6304));
      expect(charger.longitude, equals(77.2177));
    });

    test('3 & 4. Connector count & Available connector calculations', () {
      const charger = MapMarkerModel(
        id: 'c_stalls',
        title: 'Statiq Hub',
        description: 'Cyber City Gurgaon',
        latitude: 28.4900,
        longitude: 77.0900,
        type: MarkerType.station,
        availableStalls: '2/6',
        connectorCount: 6,
        isVerified: true,
        source: 'evhub_verified',
        status: MarkerStatus.available,
      );

      expect(charger.connectorCount, equals(6));
      expect(charger.availableConnectorsCount, equals(2));
      expect(charger.occupiedConnectorsCount, equals(4));
      expect(charger.computedStatus, equals(MarkerStatus.available));
    });

    test('5. Firestore document serialization format', () {
      const charger = MapMarkerModel(
        id: 'c_serialize',
        title: 'Jio-bp Pulse Hub',
        description: 'Sector 29 Gurgaon',
        latitude: 28.4700,
        longitude: 77.0700,
        type: MarkerType.station,
        network: 'Jio-bp Pulse',
        price: '₹18/kWh',
        power: '60kW',
        connectorCount: 4,
        availableStalls: '4/4',
        connectors: ['CCS2'],
        source: 'evhub_verified',
        isVerified: true,
        city: 'Gurgaon',
        state: 'Haryana',
      );

      final Map<String, dynamic> doc = {
        'id': charger.id,
        'name': charger.title,
        'address': charger.address ?? charger.description,
        'city': charger.city ?? '',
        'state': charger.state ?? '',
        'country': charger.country ?? 'India',
        'network': charger.network,
        'location': GeoPoint(charger.latitude, charger.longitude),
        'totalConnectors': charger.connectorCount,
        'availableConnectors': charger.availableConnectorsCount,
        'occupiedConnectors': charger.occupiedConnectorsCount,
        'status': 'available',
        'isVerified': charger.isVerified,
        'source': charger.source,
      };

      expect(doc['id'], equals('c_serialize'));
      expect(doc['name'], equals('Jio-bp Pulse Hub'));
      expect(doc['network'], equals('Jio-bp Pulse'));
      expect(doc['location'], isA<GeoPoint>());
      expect((doc['location'] as GeoPoint).latitude, equals(28.4700));
      expect(doc['totalConnectors'], equals(4));
      expect(doc['availableConnectors'], equals(4));
      expect(doc['occupiedConnectors'], equals(0));
    });

    test('6. Backward-compatible document parsing from raw Firestore maps', () {
      final Map<String, dynamic> rawDoc = {
        'id': 'legacy_101',
        'name': 'Legacy ChargeStation',
        'address': 'MG Road Metro Station',
        'network': 'ChargeZone',
        'location': const GeoPoint(28.4800, 77.0800),
        'power': '50kW',
        'pricePerUnit': '₹20/kWh',
        'status': 'available',
        'totalConnectors': 2,
        'availableConnectors': 1,
        // Legacy document missing city, state, country, source, isVerified
      };

      final GeoPoint loc = rawDoc['location'] as GeoPoint;
      final bool isVerified = (rawDoc['isVerified'] as bool?) ?? true;
      final String source = (rawDoc['source'] as String?) ?? 'evhub_verified';
      final int total = (rawDoc['totalConnectors'] as num?)?.toInt() ?? 4;
      final int avail = (rawDoc['availableConnectors'] as num?)?.toInt() ?? total;

      final model = MapMarkerModel(
        id: rawDoc['id'] as String,
        title: rawDoc['name'] as String,
        description: rawDoc['address'] as String,
        latitude: loc.latitude,
        longitude: loc.longitude,
        type: MarkerType.station,
        network: rawDoc['network'] as String,
        power: rawDoc['power'] as String,
        price: rawDoc['pricePerUnit'] as String,
        connectorCount: total,
        availableStalls: '$avail/$total',
        source: source,
        isVerified: isVerified,
        city: rawDoc['city'] as String?,
        state: rawDoc['state'] as String?,
        country: (rawDoc['country'] as String?) ?? 'India',
      );

      expect(model.id, equals('legacy_101'));
      expect(model.title, equals('Legacy ChargeStation'));
      expect(model.latitude, equals(28.4800));
      expect(model.longitude, equals(77.0800));
      expect(model.availableConnectorsCount, equals(1));
      expect(model.occupiedConnectorsCount, equals(1));
      expect(model.country, equals('India'));
    });

    test('7. Admin authorization logic', () {
      const adminUser = UserModel(
        id: 'admin_uid_123',
        email: 'admin@evhub.com',
        name: 'EVHub Operations Admin',
        role: Role.admin,
      );

      const normalUser = UserModel(
        id: 'user_uid_456',
        email: 'driver@evhub.com',
        name: 'John EV Driver',
        role: Role.user,
      );

      const partnerUser = UserModel(
        id: 'partner_uid_789',
        email: 'partner@tatapower.com',
        name: 'Tata Partner',
        role: Role.partner,
      );

      expect(adminUser.isAdmin, isTrue);
      expect(adminUser.canManageChargers, isTrue);

      expect(normalUser.isAdmin, isFalse);
      expect(normalUser.canManageChargers, isFalse);

      expect(partnerUser.isAdmin, isFalse);
      expect(partnerUser.isPartner, isTrue);
      expect(partnerUser.canManageChargers, isTrue);
    });
  });
}
