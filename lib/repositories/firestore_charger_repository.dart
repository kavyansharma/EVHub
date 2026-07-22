import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/map_marker_model.dart';

/// FirestoreChargerRepository
///
/// Production Firestore repository for EV charger data.
/// Reads from the 'chargers' Firestore collection and converts
/// every document into a [MapMarkerModel].
///
/// Firestore Document Schema:
/// ```
/// Field               | Firestore Type    | Maps To
/// --------------------|-------------------|---------------------
/// id                  | String            | id
/// name                | String            | title
/// address             | String            | description/address
/// network             | String            | network
/// location            | GeoPoint          | latitude, longitude
/// rating              | Number            | rating
/// power               | String            | power
/// pricePerUnit        | String            | price
/// status              | String            | status (enum)
/// totalConnectors     | Number            | connectorCount
/// availableConnectors | Number            | availableStalls
/// imageUrl            | String            | photoUrl
/// connectorTypes      | Array of Strings  | connectors
/// ```
class FirestoreChargerRepository {
  final FirebaseFirestore _firestore;

  /// Collection name in Firestore
  static const String _collection = 'chargers';

  FirestoreChargerRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ───────────────────────────────────────────────────────────
  // READ: getAllChargers
  // ───────────────────────────────────────────────────────────

  /// Fetches all EV chargers from the Firestore 'chargers' collection.
  ///
  /// Returns an empty list if the collection is empty or if an error occurs.
  Future<List<MapMarkerModel>> getAllChargers() async {
    debugPrint('[FirestoreChargerRepository] ── getAllChargers() START ──');
    debugPrint(
      '[FirestoreChargerRepository] Fetching from collection="$_collection" '
      'in Firestore project: ${_firestore.app.options.projectId}',
    );
    try {
      final snapshot = await _firestore.collection(_collection).get();

      debugPrint(
        '[FirestoreChargerRepository] Raw snapshot: '
        '${snapshot.docs.length} documents found in "$_collection".',
      );

      if (snapshot.docs.isEmpty) {
        debugPrint(
          '[FirestoreChargerRepository] ⚠ Collection "$_collection" is EMPTY. '
          'No chargers to show.',
        );
        return [];
      }

      // Log every document for diagnostics
      for (int i = 0; i < snapshot.docs.length; i++) {
        final doc = snapshot.docs[i];
        final d = doc.data();
        final loc = d['location'];
        debugPrint(
          '[FirestoreChargerRepository]   [$i] id="${doc.id}" '
          'name="${d['name']}" '
          'status="${d['status']}" '
          'location=${loc != null ? '(${(loc as dynamic).latitude}, ${(loc as dynamic).longitude})' : 'MISSING'} '
          'connectors=${d['connectorTypes']}',
        );
      }

      final chargers = snapshot.docs
          .map((doc) => _documentToModel(doc.id, doc.data()))
          .whereType<MapMarkerModel>()
          .toList();
      debugPrint(
        '[FirestoreChargerRepository] ✓ Loaded ${chargers.length}/${snapshot.docs.length} '
        'chargers successfully (${snapshot.docs.length - chargers.length} failed to parse).',
      );
      return chargers;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint(
          '[FirestoreChargerRepository] ❌ Firestore read BLOCKED by security rules. '
          'Error: permission-denied. Check firestore.rules in the Firebase Console.',
        );
      } else {
        debugPrint(
          '[FirestoreChargerRepository] FirebaseException in getAllChargers: '
          'code=${e.code}, message=${e.message}',
        );
      }
      return [];
    } catch (e) {
      debugPrint('[FirestoreChargerRepository] Unexpected error in getAllChargers: $e');
      return [];
    }
  }

  // ───────────────────────────────────────────────────────────
  // READ: getChargerById
  // ───────────────────────────────────────────────────────────

  /// Fetches a single EV charger by its Firestore document ID.
  ///
  /// Returns `null` if not found or if an error occurs.
  Future<MapMarkerModel?> getChargerById(String id) async {
    debugPrint('[FirestoreChargerRepository] Fetching charger by id: $id');
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (!doc.exists || doc.data() == null) {
        debugPrint('[FirestoreChargerRepository] Charger not found: $id');
        return null;
      }
      final model = _documentToModel(doc.id, doc.data()!);
      debugPrint('[FirestoreChargerRepository] Charger fetched: ${model?.title}');
      return model;
    } on FirebaseException catch (e) {
      debugPrint(
        '[FirestoreChargerRepository] FirebaseException in getChargerById($id): '
        'code=${e.code}, message=${e.message}',
      );
      return null;
    } catch (e) {
      debugPrint('[FirestoreChargerRepository] Unexpected error in getChargerById($id): $e');
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────
  // WRITE: addCharger
  // ───────────────────────────────────────────────────────────

  /// Adds a new EV charger document to the Firestore 'chargers' collection.
  ///
  /// Uses the [MapMarkerModel.id] as the Firestore document ID.
  Future<void> addCharger(MapMarkerModel charger) async {
    debugPrint('[FirestoreChargerRepository] Adding charger: ${charger.title}');
    try {
      await _firestore
          .collection(_collection)
          .doc(charger.id)
          .set(_modelToDocument(charger));
      debugPrint(
        '[FirestoreChargerRepository] Charger added successfully: ${charger.id}',
      );
    } on FirebaseException catch (e) {
      debugPrint(
        '[FirestoreChargerRepository] FirebaseException in addCharger(${charger.id}): '
        'code=${e.code}, message=${e.message}',
      );
      rethrow;
    } catch (e) {
      debugPrint(
        '[FirestoreChargerRepository] Unexpected error in addCharger(${charger.id}): $e',
      );
      rethrow;
    }
  }

  // ───────────────────────────────────────────────────────────
  // WRITE: updateCharger
  // ───────────────────────────────────────────────────────────

  /// Updates an existing charger document in Firestore.
  ///
  /// Performs a full overwrite of all mapped fields using [SetOptions(merge: false)].
  Future<void> updateCharger(MapMarkerModel charger) async {
    debugPrint('[FirestoreChargerRepository] Updating charger: ${charger.id}');
    try {
      await _firestore
          .collection(_collection)
          .doc(charger.id)
          .update(_modelToDocument(charger));
      debugPrint(
        '[FirestoreChargerRepository] Charger updated successfully: ${charger.id}',
      );
    } on FirebaseException catch (e) {
      debugPrint(
        '[FirestoreChargerRepository] FirebaseException in updateCharger(${charger.id}): '
        'code=${e.code}, message=${e.message}',
      );
      rethrow;
    } catch (e) {
      debugPrint(
        '[FirestoreChargerRepository] Unexpected error in updateCharger(${charger.id}): $e',
      );
      rethrow;
    }
  }

  // ───────────────────────────────────────────────────────────
  // WRITE: deleteCharger
  // ───────────────────────────────────────────────────────────

  /// Deletes a charger document from Firestore by its document ID.
  Future<void> deleteCharger(String id) async {
    debugPrint('[FirestoreChargerRepository] Deleting charger: $id');
    try {
      await _firestore.collection(_collection).doc(id).delete();
      debugPrint('[FirestoreChargerRepository] Charger deleted successfully: $id');
    } on FirebaseException catch (e) {
      debugPrint(
        '[FirestoreChargerRepository] FirebaseException in deleteCharger($id): '
        'code=${e.code}, message=${e.message}',
      );
      rethrow;
    } catch (e) {
      debugPrint(
        '[FirestoreChargerRepository] Unexpected error in deleteCharger($id): $e',
      );
      rethrow;
    }
  }

  // ───────────────────────────────────────────────────────────
  // PRIVATE: Firestore Document → MapMarkerModel
  // ───────────────────────────────────────────────────────────

  /// Converts a raw Firestore document map to a [MapMarkerModel].
  ///
  /// Every field access is null-safe and falls back to a sensible default,
  /// so missing fields never cause a crash.
  MapMarkerModel? _documentToModel(String docId, Map<String, dynamic> data) {
    try {
      // ── ID ──────────────────────────────────────────────────────────────
      // Prefer the stored 'id' field; fall back to the Firestore document ID.
      final String id = (data['id'] as String?)?.trim().isNotEmpty == true
          ? data['id'] as String
          : docId;

      // ── Name / title ─────────────────────────────────────────────────────
      final String name = (data['name'] as String?) ?? 'Unknown Charger';

      // ── Address ───────────────────────────────────────────────────────────
      final String address = (data['address'] as String?) ?? 'Address not available';

      // ── Network ───────────────────────────────────────────────────────────
      final String network = (data['network'] as String?) ?? 'Independent';

      // ── GeoPoint → latitude / longitude ──────────────────────────────────
      double latitude = 28.6304;  // Default: New Delhi Connaught Place
      double longitude = 77.2177;
      final dynamic locationField = data['location'];
      if (locationField is GeoPoint) {
        latitude = locationField.latitude;
        longitude = locationField.longitude;
      } else {
        debugPrint(
          '[FirestoreChargerRepository] Warning: "location" field missing or not a '
          'GeoPoint for document $docId. Using default coordinates.',
        );
      }

      // ── Rating ────────────────────────────────────────────────────────────
      final double rating = (data['rating'] as num?)?.toDouble() ?? 4.5;

      // ── Power ─────────────────────────────────────────────────────────────
      final String power = (data['power'] as String?) ?? '50kW';

      // ── Price per unit ────────────────────────────────────────────────────
      final String price = (data['pricePerUnit'] as String?) ?? '₹21/kWh';

      // ── Status (string → enum) ────────────────────────────────────────────
      final String? rawStatus = data['status'] as String?;
      final MarkerStatus status = _parseStatus(rawStatus);

      // ── Connector counts ─────────────────────────────────────────────────
      final int? rawTotal = (data['totalConnectors'] as num?)?.toInt();
      final int? rawAvailable = (data['availableConnectors'] as num?)?.toInt();
      final int totalConnectors = rawTotal ?? 4;
      final int availableConnectors = rawAvailable ?? totalConnectors;

      final String availableStalls = (rawStatus != null && rawTotal != null)
          ? '$availableConnectors/$totalConnectors'
          : 'Availability Unknown';

      final String availabilityStatus = (rawStatus != null && rawTotal != null)
          ? '$availableConnectors/$totalConnectors Available'
          : 'Availability Unknown';

      // ── Timestamp / lastUpdated ─────────────────────────────────────────
      final dynamic rawUpdatedAt = data['updatedAt'] ?? data['lastUpdated'];
      String? lastUpdated;
      if (rawUpdatedAt is Timestamp) {
        final dt = rawUpdatedAt.toDate();
        lastUpdated = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } else if (rawUpdatedAt is String) {
        lastUpdated = rawUpdatedAt;
      }

      // ── Image URL ─────────────────────────────────────────────────────────
      final String? imageUrl = data['imageUrl'] as String?;

      // ── Connector types ───────────────────────────────────────────────────
      final List<String> connectorTypes =
          (data['connectorTypes'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              ['CCS2', 'Type 2'];

      // ── Derived: powerType ────────────────────────────────────────────────
      // Parse kW numeric value from the power string (e.g. "150kW" → 150)
      final powerKw = double.tryParse(
            power.replaceAll(RegExp(r'[^0-9.]'), ''),
          ) ??
          50.0;
      final String powerType = powerKw >= 100.0
          ? 'Ultra Fast'
          : powerKw >= 22.0
              ? 'Fast'
              : 'AC';

      return MapMarkerModel(
        id: id,
        title: name,
        description: address,
        latitude: latitude,
        longitude: longitude,
        type: MarkerType.station,
        network: network,
        rating: rating.clamp(0.0, 5.0),
        power: power,
        availableStalls: availableStalls,
        status: status,
        photoUrl: imageUrl,
        address: address,
        openStatus: status == MarkerStatus.offline ? 'Offline' : 'Open',
        price: price,
        connectorCount: totalConnectors,
        connectors: connectorTypes,
        powerType: powerType,
        openingHours: '24 Hours',
        source: 'evhub_verified',
        isVerified: true,
        availabilityStatus: availabilityStatus,
        lastUpdated: lastUpdated,
      );
    } catch (e) {
      debugPrint(
        '[FirestoreChargerRepository] Failed to parse document $docId: $e',
      );
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────
  // PRIVATE: MapMarkerModel → Firestore Document
  // ───────────────────────────────────────────────────────────

  /// Converts a [MapMarkerModel] into a Firestore-compatible map for writes.
  Map<String, dynamic> _modelToDocument(MapMarkerModel charger) {
    return {
      'id': charger.id,
      'name': charger.title,
      'address': charger.address ?? charger.description,
      'network': charger.network,
      'location': GeoPoint(charger.latitude, charger.longitude),
      'rating': charger.rating,
      'power': charger.power,
      'pricePerUnit': charger.price ?? '₹21/kWh',
      'status': _statusToString(charger.status),
      'totalConnectors': charger.connectorCount,
      'availableConnectors': _parseAvailableCount(charger.availableStalls),
      'imageUrl': charger.photoUrl,
      'connectorTypes': charger.connectors,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ───────────────────────────────────────────────────────────
  // PRIVATE: Helper utilities
  // ───────────────────────────────────────────────────────────

  /// Converts a Firestore status string to [MarkerStatus] enum.
  /// Accepts: "available", "busy", "offline" (case-insensitive).
  /// Defaults to [MarkerStatus.available] for any unknown value.
  MarkerStatus _parseStatus(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return MarkerStatus.unknown;
    }
    switch (raw.toLowerCase().trim()) {
      case 'busy':
        return MarkerStatus.busy;
      case 'offline':
        return MarkerStatus.offline;
      case 'available':
        return MarkerStatus.available;
      case 'unknown':
      default:
        return MarkerStatus.unknown;
    }
  }

  /// Converts a [MarkerStatus] enum to the Firestore string value.
  String _statusToString(MarkerStatus status) {
    switch (status) {
      case MarkerStatus.busy:
        return 'busy';
      case MarkerStatus.offline:
        return 'offline';
      case MarkerStatus.available:
        return 'available';
      case MarkerStatus.unknown:
        return 'unknown';
    }
  }

  /// Parses the available count from a stalls string like "3/5" → 3.
  int _parseAvailableCount(String stallsText) {
    try {
      final parts = stallsText.split('/');
      if (parts.isNotEmpty) {
        return int.tryParse(parts[0].trim()) ?? 0;
      }
    } catch (_) {}
    return 0;
  }
}
