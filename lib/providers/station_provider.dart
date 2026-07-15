import 'dart:async';
import 'package:flutter/material.dart';
import '../models/station_model.dart';
import '../repositories/station_repository.dart';
import '../data/mock_data.dart';

/// Provides live charging station list, favorites, and search/filter logic.
/// Must be initialized with [loadForUser] after login.
/// Guests see stations but cannot favorite.
class StationProvider extends ChangeNotifier {
  final StationRepository _stationRepository;

  List<StationModel> _allStations = [];
  Set<String> _favoriteIds = {};
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedFilter = 'All';

  StreamSubscription<List<StationModel>>? _stationSub;
  StreamSubscription<Set<String>>? _favSub;

  StationProvider({required StationRepository stationRepository})
      : _stationRepository = stationRepository {
    _seedAndLoad();
  }

  // ─── Getters ───────────────────────────────────────────────────────────────

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get selectedFilter => _selectedFilter;

  List<StationModel> get filteredStations {
    return _allStations
        .map((st) => st.copyWith(isFavorite: _favoriteIds.contains(st.id)))
        .where((st) {
      final matchesSearch =
          st.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              st.location.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;
      if (_selectedFilter == 'Ultra Fast') return st.power >= 150.0;
      if (_selectedFilter == 'Tesla Compatible') return st.isTeslaCompatible;
      return true;
    }).toList();
  }

  List<StationModel> get favoriteStations =>
      _allStations
          .where((st) => _favoriteIds.contains(st.id))
          .map((st) => st.copyWith(isFavorite: true))
          .toList();

  // ─── Search / Filter ───────────────────────────────────────────────────────

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> _seedAndLoad() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Seed default stations to Firestore if collection is empty.
      await _stationRepository.seedStationsIfEmpty(MockData.defaultStations);
    } catch (_) {
      // Non-fatal: seed may fail offline; cached data will still show.
    }

    _stationSub = _stationRepository.watchStations().listen(
      (stations) {
        _allStations = stations;
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Load user-specific favorites. Call after login.
  void loadFavoritesForUser(String uid) {
    _favSub?.cancel();
    _favSub = _stationRepository.watchFavoriteIds(uid).listen(
      (ids) {
        _favoriteIds = ids;
        notifyListeners();
      },
    );
  }

  /// Clear favorites when user logs out.
  void clearUser() {
    _favSub?.cancel();
    _favoriteIds = {};
    notifyListeners();
  }

  // ─── Actions ───────────────────────────────────────────────────────────────

  Future<void> toggleFavorite(String uid, StationModel station) async {
    try {
      await _stationRepository.toggleFavorite(uid, station);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _stationSub?.cancel();
    _favSub?.cancel();
    super.dispose();
  }
}
