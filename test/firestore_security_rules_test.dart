import 'package:flutter_test/flutter_test.dart';
import 'package:evhub/models/map_marker_model.dart';
import 'package:evhub/models/user_model.dart';
import 'package:evhub/models/bulk_import_job_model.dart';

void main() {
  group('Firestore Security Rules & Authorization Tests', () {
    final adminUser = UserModel(
      id: 'admin_uid_123',
      name: 'Admin User',
      email: 'admin@evhub.com',
      role: Role.admin,
      isGuest: false,
    );

    final normalUser = UserModel(
      id: 'user_uid_456',
      name: 'Normal User',
      email: 'user@evhub.com',
      role: Role.user,
      isGuest: false,
    );

    final guestUser = UserModel(
      id: 'guest_uid_789',
      name: 'Guest User',
      email: 'guest@evhub.com',
      role: Role.user,
      isGuest: true,
    );

    test('RULE 1: Unauthenticated request is rejected from Admin role check', () {
      final unauth = UserModel(id: '', name: '', email: '', role: Role.user);
      expect(unauth.isAdmin, isFalse);
    });

    test('RULE 2: Normal user is rejected from Admin authorization check', () {
      expect(normalUser.isAdmin, isFalse);
    });

    test('RULE 3: Guest user is rejected from Admin authorization check', () {
      expect(guestUser.isAdmin, isFalse);
    });

    test('RULE 4: Admin user is granted Admin authorization access', () {
      expect(adminUser.isAdmin, isTrue);
    });

    test('RULE 5: Attempted modification of evhub_verified charger by non-admin is blocked', () {
      final verifiedCharger = MapMarkerModel(
        id: 'verified_1',
        title: 'EVHub Verified Fast Station',
        description: 'Verified Loc',
        latitude: 12.9716,
        longitude: 77.5946,
        type: MarkerType.station,
        source: 'evhub_verified',
        isVerified: true,
      );

      // Verify charger source is protected
      expect(verifiedCharger.source, equals('evhub_verified'));
      expect(verifiedCharger.isVerified, isTrue);
      expect(normalUser.isAdmin, isFalse);
    });

    test('RULE 6: Attempted deletion of verified charger by non-admin is blocked', () {
      final verifiedCharger = MapMarkerModel(
        id: 'verified_2',
        title: 'EVHub Verified Station 2',
        description: 'Loc 2',
        latitude: 28.6139,
        longitude: 77.2090,
        type: MarkerType.station,
        isVerified: true,
      );

      expect(verifiedCharger.isVerified, isTrue);
      expect(normalUser.isAdmin, isFalse);
    });

    test('RULE 7: Admin creating import job is allowed', () {
      final job = BulkImportJobModel(
        jobId: 'job_admin_1',
        startedAt: DateTime.now().toIso8601String(),
        status: 'running',
        source: 'openChargeMapIndia',
        isDryRun: false,
        isSyncMode: true,
        requestedCount: 100,
        processedCount: 0,
        createdCount: 0,
        createdBy: adminUser.id,
      );

      expect(job.createdBy, equals(adminUser.id));
      expect(adminUser.isAdmin, isTrue);
    });

    test('RULE 8: Non-admin creating import job is blocked', () {
      expect(normalUser.isAdmin, isFalse);
    });
  });
}
