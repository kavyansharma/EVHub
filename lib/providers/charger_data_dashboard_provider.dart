import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/map_marker_model.dart';
import '../models/user_model.dart';
import '../repositories/firestore_charger_repository.dart';

class NetworkStat {
  final String networkName;
  final int count;
  final double percentage;

  const NetworkStat({
    required this.networkName,
    required this.count,
    required this.percentage,
  });
}

class LocationGroupStat {
  final String name;
  final int count;
  final double percentage;

  const LocationGroupStat({
    required this.name,
    required this.count,
    required this.percentage,
  });
}

class LocationCoverage {
  final int totalCountries;
  final int totalStates;
  final int totalCities;
  final List<LocationGroupStat> topCities;
  final List<LocationGroupStat> topStates;

  const LocationCoverage({
    required this.totalCountries,
    required this.totalStates,
    required this.totalCities,
    required this.topCities,
    required this.topStates,
  });
}

class AvailabilityHealth {
  final int availableCount;
  final double availablePct;
  final int busyCount;
  final double busyPct;
  final int offlineCount;
  final double offlinePct;
  final int unknownCount;
  final double unknownPct;
  final int totalConnectors;
  final int availableConnectors;
  final int occupiedConnectors;
  final double connectorAvailabilityPercentage;

  const AvailabilityHealth({
    required this.availableCount,
    required this.availablePct,
    required this.busyCount,
    required this.busyPct,
    required this.offlineCount,
    required this.offlinePct,
    required this.unknownCount,
    required this.unknownPct,
    required this.totalConnectors,
    required this.availableConnectors,
    required this.occupiedConnectors,
    required this.connectorAvailabilityPercentage,
  });
}

class DataQualityHealth {
  final double score;
  final String ratingTier; // 'Excellent', 'Good', 'Needs Attention', 'Critical', 'N/A'
  final int totalChargers;
  final int missingName;
  final int missingNetwork;
  final int missingAddress;
  final int missingCity;
  final int missingState;
  final int missingCountry;
  final int missingGeoPoint;
  final int missingConnectorTypes;
  final int missingPower;
  final int missingPrice;
  final int missingPhone;
  final int missingWebsite;
  final int missingImage;
  final int missingAmenities;
  final int missingLastUpdated;
  final int unknownAvailabilityStatus;

  const DataQualityHealth({
    required this.score,
    required this.ratingTier,
    required this.totalChargers,
    required this.missingName,
    required this.missingNetwork,
    required this.missingAddress,
    required this.missingCity,
    required this.missingState,
    required this.missingCountry,
    required this.missingGeoPoint,
    required this.missingConnectorTypes,
    required this.missingPower,
    required this.missingPrice,
    required this.missingPhone,
    required this.missingWebsite,
    required this.missingImage,
    required this.missingAmenities,
    required this.missingLastUpdated,
    required this.unknownAvailabilityStatus,
  });
}

class DataQualityAlert {
  final String id;
  final String message;
  final int count;
  final String filterKey;
  final Color alertColor;

  const DataQualityAlert({
    required this.id,
    required this.message,
    required this.count,
    required this.filterKey,
    required this.alertColor,
  });
}

class StaleDataStats {
  final int freshCount;
  final int staleCount;
  final int neverUpdatedCount;
  final int thresholdDays;

  const StaleDataStats({
    required this.freshCount,
    required this.staleCount,
    required this.neverUpdatedCount,
    required this.thresholdDays,
  });
}

class ChargerDataDashboardProvider extends ChangeNotifier {
  final FirestoreChargerRepository _firestoreRepository;

  List<MapMarkerModel> _chargers = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _staleThresholdDays = 30;

  static const int staleDataDays = 30;

  ChargerDataDashboardProvider({
    FirestoreChargerRepository? firestoreRepository,
  }) : _firestoreRepository = firestoreRepository ?? FirestoreChargerRepository();

  // Getters
  List<MapMarkerModel> get chargers => _chargers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get staleThresholdDays => _staleThresholdDays;

  void setStaleThresholdDays(int days) {
    _staleThresholdDays = days;
    notifyListeners();
  }

  /// Initial load and manual refresh
  Future<void> refreshDashboard({required UserModel currentUser}) async {
    debugPrint(
      '[FIRESTORE-DIAGNOSTIC] Refresh Dashboard Requested | UID: "${currentUser.id}" | '
      'Role: "${currentUser.role.name}" | IsAdmin: ${currentUser.isAdmin}',
    );

    if (!currentUser.isAdmin) {
      _errorMessage = 'Authentication successful, but your EVHub admin profile could not be loaded. Please contact the administrator.';
      _chargers = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _chargers = await _firestoreRepository.getAllChargers();
      debugPrint('''
[ADMIN-DASHBOARD-DIAGNOSTIC]
Auth UID: ${currentUser.id}
Email: ${currentUser.email}
Firestore Profile: Loaded
Role: ${currentUser.role.name}
IsAdmin: ${currentUser.isAdmin}
Dashboard Access: GRANTED
Dashboard Data Count: ${_chargers.length}
''');
    } catch (e) {
      debugPrint('[FIRESTORE-DIAGNOSTIC] ❌ Dashboard fetch error: $e');
      _errorMessage = 'Failed to load dashboard data: ${e.toString().replaceAll("Exception: ", "")}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =========================================================================
  // 1. DASHBOARD SUMMARY METRICS
  // =========================================================================
  int get totalVerifiedChargers => _chargers.where((c) => c.isVerified).length;
  int get totalActiveChargers => _chargers.where((c) => c.status == MarkerStatus.available || c.status == MarkerStatus.busy).length;
  int get availableChargers => _chargers.where((c) => c.status == MarkerStatus.available).length;
  int get busyChargers => _chargers.where((c) => c.status == MarkerStatus.busy).length;
  int get offlineChargers => _chargers.where((c) => c.status == MarkerStatus.offline).length;
  int get unknownAvailabilityChargers => _chargers.where((c) => c.status == MarkerStatus.unknown).length;

  int get chargersAddedLast7Days {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    return _chargers.where((c) {
      final dt = _extractDateTime(c.createdAt);
      return dt != null && dt.isAfter(sevenDaysAgo);
    }).length;
  }

  int get chargersUpdatedLast7Days {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    return _chargers.where((c) {
      final dt = _extractDateTime(c.updatedAt ?? c.lastUpdated);
      return dt != null && dt.isAfter(sevenDaysAgo);
    }).length;
  }

  // =========================================================================
  // 2. CHARGER SOURCE BREAKDOWN
  // =========================================================================
  int get evhubVerifiedCount => _chargers.where((c) => c.source == 'evhub_verified' || c.isVerified).length;
  double get evhubVerifiedPercentage => _chargers.isNotEmpty ? (evhubVerifiedCount / _chargers.length) * 100 : 0.0;
  int get bulkImportCount => _chargers.where((c) => c.source == 'bulk_import' && !c.isVerified).length;
  double get bulkImportPercentage => _chargers.isNotEmpty ? (bulkImportCount / _chargers.length) * 100 : 0.0;
  int get googlePlacesCount => _chargers.where((c) => c.source == 'google_places').length;
  double get googlePlacesPercentage => _chargers.isNotEmpty ? (googlePlacesCount / _chargers.length) * 100 : 0.0;

  // =========================================================================
  // 3. NETWORK BREAKDOWN
  // =========================================================================
  List<NetworkStat> get networkBreakdown {
    if (_chargers.isEmpty) return [];

    final Map<String, int> counts = {};
    for (final c in _chargers) {
      final net = c.network.trim().isNotEmpty ? c.network.trim() : 'Unknown Network';
      counts[net] = (counts[net] ?? 0) + 1;
    }

    final total = _chargers.length;
    final List<NetworkStat> stats = counts.entries.map((e) {
      return NetworkStat(
        networkName: e.key,
        count: e.value,
        percentage: (e.value / total) * 100,
      );
    }).toList();

    stats.sort((a, b) => b.count.compareTo(a.count));
    return stats;
  }

  // =========================================================================
  // 4. LOCATION COVERAGE
  // =========================================================================
  LocationCoverage get locationCoverage {
    if (_chargers.isEmpty) {
      return const LocationCoverage(
        totalCountries: 0,
        totalStates: 0,
        totalCities: 0,
        topCities: [],
        topStates: [],
      );
    }

    final total = _chargers.length;
    final Set<String> countries = {};
    final Set<String> states = {};
    final Set<String> cities = {};

    final Map<String, int> cityCounts = {};
    final Map<String, int> stateCounts = {};

    for (final c in _chargers) {
      final country = (c.country ?? '').trim().isNotEmpty ? c.country!.trim() : 'Unknown Country';
      final state = (c.state ?? '').trim().isNotEmpty ? c.state!.trim() : 'Unknown State';
      final city = (c.city ?? '').trim().isNotEmpty ? c.city!.trim() : 'Unknown City';

      countries.add(country);
      states.add(state);
      cities.add(city);

      cityCounts[city] = (cityCounts[city] ?? 0) + 1;
      stateCounts[state] = (stateCounts[state] ?? 0) + 1;
    }

    final List<LocationGroupStat> topCities = cityCounts.entries.map((e) {
      return LocationGroupStat(
        name: e.key,
        count: e.value,
        percentage: (e.value / total) * 100,
      );
    }).toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    final List<LocationGroupStat> topStates = stateCounts.entries.map((e) {
      return LocationGroupStat(
        name: e.key,
        count: e.value,
        percentage: (e.value / total) * 100,
      );
    }).toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return LocationCoverage(
      totalCountries: countries.where((c) => c != 'Unknown Country').length,
      totalStates: states.where((s) => s != 'Unknown State').length,
      totalCities: cities.where((c) => c != 'Unknown City').length,
      topCities: topCities.take(10).toList(),
      topStates: topStates.take(10).toList(),
    );
  }

  // =========================================================================
  // 5. AVAILABILITY HEALTH
  // =========================================================================
  AvailabilityHealth get availabilityHealth {
    final int total = _chargers.length;
    if (total == 0) {
      return const AvailabilityHealth(
        availableCount: 0,
        availablePct: 0.0,
        busyCount: 0,
        busyPct: 0.0,
        offlineCount: 0,
        offlinePct: 0.0,
        unknownCount: 0,
        unknownPct: 0.0,
        totalConnectors: 0,
        availableConnectors: 0,
        occupiedConnectors: 0,
        connectorAvailabilityPercentage: 0.0,
      );
    }

    final int avail = availableChargers;
    final int busy = busyChargers;
    final int offline = offlineChargers;
    final int unknown = unknownAvailabilityChargers;

    int totalConn = 0;
    int availConn = 0;
    int occupiedConn = 0;

    for (final c in _chargers) {
      totalConn += c.connectorCount;
      availConn += c.availableConnectorsCount;
      occupiedConn += c.occupiedConnectorsCount;
    }

    final double connAvailabilityPct = totalConn > 0 ? (availConn / totalConn) * 100 : 0.0;

    return AvailabilityHealth(
      availableCount: avail,
      availablePct: (avail / total) * 100,
      busyCount: busy,
      busyPct: (busy / total) * 100,
      offlineCount: offline,
      offlinePct: (offline / total) * 100,
      unknownCount: unknown,
      unknownPct: (unknown / total) * 100,
      totalConnectors: totalConn,
      availableConnectors: availConn,
      occupiedConnectors: occupiedConn,
      connectorAvailabilityPercentage: connAvailabilityPct,
    );
  }

  // =========================================================================
  // 6. DATA QUALITY HEALTH
  // =========================================================================
  DataQualityHealth get dataQualityHealth {
    final int total = _chargers.length;
    if (total == 0) {
      return const DataQualityHealth(
        score: 0.0,
        ratingTier: 'N/A',
        totalChargers: 0,
        missingName: 0,
        missingNetwork: 0,
        missingAddress: 0,
        missingCity: 0,
        missingState: 0,
        missingCountry: 0,
        missingGeoPoint: 0,
        missingConnectorTypes: 0,
        missingPower: 0,
        missingPrice: 0,
        missingPhone: 0,
        missingWebsite: 0,
        missingImage: 0,
        missingAmenities: 0,
        missingLastUpdated: 0,
        unknownAvailabilityStatus: 0,
      );
    }

    int mName = 0, mNet = 0, mAddr = 0, mCity = 0, mState = 0, mCountry = 0, mGeo = 0;
    int mConnTypes = 0, mPower = 0, mPrice = 0, mPhone = 0, mWeb = 0, mImg = 0, mAmen = 0, mUpdated = 0, mUnknownStatus = 0;

    int validRequiredFields = 0;
    const int requiredPerCharger = 8; // name, network, address, city, state, country, location, power

    for (final c in _chargers) {
      bool nameOk = c.title.trim().isNotEmpty;
      bool netOk = c.network.trim().isNotEmpty;
      bool addrOk = (c.address ?? c.description).trim().isNotEmpty;
      bool cityOk = (c.city ?? '').trim().isNotEmpty;
      bool stateOk = (c.state ?? '').trim().isNotEmpty;
      bool countryOk = (c.country ?? '').trim().isNotEmpty;
      bool geoOk = c.latitude >= -90.0 && c.latitude <= 90.0 && c.longitude >= -180.0 && c.longitude <= 180.0;
      bool powerOk = c.power.trim().isNotEmpty;

      if (nameOk) { validRequiredFields++; } else { mName++; }
      if (netOk) { validRequiredFields++; } else { mNet++; }
      if (addrOk) { validRequiredFields++; } else { mAddr++; }
      if (cityOk) { validRequiredFields++; } else { mCity++; }
      if (stateOk) { validRequiredFields++; } else { mState++; }
      if (countryOk) { validRequiredFields++; } else { mCountry++; }
      if (geoOk) { validRequiredFields++; } else { mGeo++; }
      if (powerOk) { validRequiredFields++; } else { mPower++; }

      if (c.connectors.isEmpty) mConnTypes++;
      if ((c.price ?? '').trim().isEmpty) mPrice++;
      if ((c.phoneNumber ?? '').trim().isEmpty) mPhone++;
      if ((c.website ?? '').trim().isEmpty) mWeb++;
      if ((c.photoUrl ?? '').trim().isEmpty) mImg++;
      if ((c.amenities ?? []).isEmpty) mAmen++;
      if (_extractDateTime(c.updatedAt ?? c.lastUpdated) == null) mUpdated++;
      if (c.status == MarkerStatus.unknown) mUnknownStatus++;
    }

    final double score = (validRequiredFields / (total * requiredPerCharger)) * 100;
    String ratingTier = 'Critical';
    if (score >= 90.0) {
      ratingTier = 'Excellent';
    } else if (score >= 75.0) {
      ratingTier = 'Good';
    } else if (score >= 50.0) {
      ratingTier = 'Needs Attention';
    }

    return DataQualityHealth(
      score: score,
      ratingTier: ratingTier,
      totalChargers: total,
      missingName: mName,
      missingNetwork: mNet,
      missingAddress: mAddr,
      missingCity: mCity,
      missingState: mState,
      missingCountry: mCountry,
      missingGeoPoint: mGeo,
      missingConnectorTypes: mConnTypes,
      missingPower: mPower,
      missingPrice: mPrice,
      missingPhone: mPhone,
      missingWebsite: mWeb,
      missingImage: mImg,
      missingAmenities: mAmen,
      missingLastUpdated: mUpdated,
      unknownAvailabilityStatus: mUnknownStatus,
    );
  }

  // =========================================================================
  // 7. DATA QUALITY ALERTS
  // =========================================================================
  List<DataQualityAlert> get dataQualityAlerts {
    final dq = dataQualityHealth;
    final stale = staleDataStats;
    final List<DataQualityAlert> alerts = [];

    if (dq.missingCity > 0) {
      alerts.add(DataQualityAlert(
        id: 'missing_city',
        message: '${dq.missingCity} chargers have missing city information',
        count: dq.missingCity,
        filterKey: 'missing_city',
        alertColor: const Color(0xFFFFB74D), // Warning Amber
      ));
    }

    if (dq.unknownAvailabilityStatus > 0) {
      alerts.add(DataQualityAlert(
        id: 'unknown_status',
        message: '${dq.unknownAvailabilityStatus} chargers have unknown availability status',
        count: dq.unknownAvailabilityStatus,
        filterKey: 'unknown_status',
        alertColor: const Color(0xFFFFB74D),
      ));
    }

    if (dq.missingGeoPoint > 0) {
      alerts.add(DataQualityAlert(
        id: 'missing_geo',
        message: '${dq.missingGeoPoint} chargers have invalid or missing coordinates',
        count: dq.missingGeoPoint,
        filterKey: 'missing_geo',
        alertColor: const Color(0xFFE57373), // Danger Red
      ));
    }

    if (stale.staleCount > 0) {
      alerts.add(DataQualityAlert(
        id: 'stale_data',
        message: '${stale.staleCount} chargers have not been updated in more than $_staleThresholdDays days',
        count: stale.staleCount,
        filterKey: 'stale_data',
        alertColor: const Color(0xFFFFB74D),
      ));
    }

    if (dq.missingConnectorTypes > 0) {
      alerts.add(DataQualityAlert(
        id: 'missing_connectors',
        message: '${dq.missingConnectorTypes} chargers have missing connector information',
        count: dq.missingConnectorTypes,
        filterKey: 'missing_connectors',
        alertColor: const Color(0xFFE57373),
      ));
    }

    return alerts;
  }

  // =========================================================================
  // 8. RECENT ACTIVITY
  // =========================================================================
  List<MapMarkerModel> get recentlyAddedChargers {
    final list = List<MapMarkerModel>.from(_chargers);
    list.sort((a, b) {
      final dtA = _extractDateTime(a.createdAt);
      final dtB = _extractDateTime(b.createdAt);
      if (dtA != null && dtB != null) {
        return dtB.compareTo(dtA);
      }
      return b.id.compareTo(a.id);
    });
    return list.take(10).toList();
  }

  List<MapMarkerModel> get recentlyUpdatedChargers {
    final list = List<MapMarkerModel>.from(_chargers);
    list.sort((a, b) {
      final dtA = _extractDateTime(a.updatedAt ?? a.lastUpdated);
      final dtB = _extractDateTime(b.updatedAt ?? b.lastUpdated);
      if (dtA != null && dtB != null) {
        return dtB.compareTo(dtA);
      }
      return b.id.compareTo(a.id);
    });
    return list.take(10).toList();
  }

  // =========================================================================
  // 9. STALE DATA DETECTION
  // =========================================================================
  StaleDataStats get staleDataStats {
    final now = DateTime.now();
    final threshold = now.subtract(Duration(days: _staleThresholdDays));

    int fresh = 0;
    int stale = 0;
    int neverUpdated = 0;

    for (final c in _chargers) {
      final dt = _extractDateTime(c.updatedAt ?? c.lastUpdated);
      if (dt == null) {
        neverUpdated++;
      } else if (dt.isBefore(threshold)) {
        stale++;
      } else {
        fresh++;
      }
    }

    return StaleDataStats(
      freshCount: fresh,
      staleCount: stale,
      neverUpdatedCount: neverUpdated,
      thresholdDays: _staleThresholdDays,
    );
  }

  DateTime? _extractDateTime(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  /// Reset dashboard provider state upon user logout
  void clearDashboard() {
    _chargers = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
