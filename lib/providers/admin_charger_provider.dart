import 'dart:async';
import 'package:flutter/material.dart';
import '../models/map_marker_model.dart';
import '../models/user_model.dart';
import '../repositories/firestore_charger_repository.dart';
import '../repositories/user_repository.dart';

/// AdminChargerProvider
///
/// Manages charger administration and partner workflow state.
/// Performs loading, searching, filtering, creation, updates, deletion,
/// and verification approvals/rejections with clean state handling.
class AdminChargerProvider extends ChangeNotifier {
  final FirestoreChargerRepository _firestoreRepository;

  List<MapMarkerModel> _allChargers = [];
  List<MapMarkerModel> _filteredChargers = [];
  final List<UserModel> _partners = [];

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Filter & Sort States
  String _searchQuery = '';
  String _selectedNetworkFilter = 'All';
  String _selectedStatusFilter = 'All';
  String _selectedVerifiedFilter = 'All';
  String _selectedPartnerFilter = 'All';
  String _selectedSortBy = 'Newest'; // 'Name', 'Newest', 'Availability'

  StreamSubscription<List<MapMarkerModel>>? _chargersSubscription;

  AdminChargerProvider({
    FirestoreChargerRepository? firestoreRepository,
    UserRepository? userRepository,
  })  : _firestoreRepository = firestoreRepository ?? FirestoreChargerRepository();

  // Getters
  List<MapMarkerModel> get chargers => _filteredChargers;
  List<MapMarkerModel> get allChargers => _allChargers;
  List<UserModel> get partners => _partners;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  String get searchQuery => _searchQuery;
  String get selectedNetworkFilter => _selectedNetworkFilter;
  String get selectedStatusFilter => _selectedStatusFilter;
  String get selectedVerifiedFilter => _selectedVerifiedFilter;
  String get selectedPartnerFilter => _selectedPartnerFilter;
  String get selectedSortBy => _selectedSortBy;

  // Dashboard Aggregation Statistics (Part 2 Requirements)
  int get totalVerifiedChargersCount => _allChargers.where((c) => c.isVerified).length;
  int get availableChargersCount => _allChargers.where((c) => c.status == MarkerStatus.available).length;
  int get busyChargersCount => _allChargers.where((c) => c.status == MarkerStatus.busy).length;
  int get offlineChargersCount => _allChargers.where((c) => c.status == MarkerStatus.offline).length;
  int get unknownAvailabilityCount => _allChargers.where((c) => c.status == MarkerStatus.unknown).length;
  int get totalNetworksCount => _allChargers.map((c) => c.network.trim()).where((n) => n.isNotEmpty).toSet().length;

  // Retained helper getters for backward compatibility
  int get totalChargersCount => _allChargers.length;
  int get verifiedChargersCount => totalVerifiedChargersCount;
  int get pendingChargersCount => _allChargers.where((c) => c.verificationStatus == 'pending').length;
  int get activeChargersCount => availableChargersCount + busyChargersCount;
  int get partnersCount => _partners.isNotEmpty 
      ? _partners.length 
      : _allChargers.map((c) => c.ownerId).where((id) => id != null && id.isNotEmpty).toSet().length;

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// Initialize real-time streams for charger management screen
  void startRealtimeUpdates({required UserModel currentUser}) {
    _chargersSubscription?.cancel();

    if (currentUser.isAdmin) {
      _chargersSubscription = _firestoreRepository.streamAllChargers().listen(
        (updatedList) {
          _allChargers = updatedList;
          _applyFilters();
          notifyListeners();
        },
        onError: (error) {
          debugPrint('[AdminChargerProvider] Stream error: $error');
        },
      );
    } else if (currentUser.isPartner) {
      _chargersSubscription = _firestoreRepository.streamChargersByOwner(currentUser.id).listen(
        (updatedList) {
          _allChargers = updatedList;
          _applyFilters();
          notifyListeners();
        },
        onError: (error) {
          debugPrint('[AdminChargerProvider] Stream error: $error');
        },
      );
    }
  }

  /// Initial load of chargers from Firestore
  Future<void> loadChargers({required UserModel currentUser}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (currentUser.isAdmin) {
        _allChargers = await _firestoreRepository.getAllChargers();
      } else if (currentUser.isPartner) {
        _allChargers = await _firestoreRepository.getChargersByOwner(currentUser.id);
      } else {
        _allChargers = [];
      }

      _applyFilters();
    } catch (e) {
      _errorMessage = 'Failed to load chargers: ${e.toString().replaceAll("Exception: ", "")}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Filter setters
  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  void setNetworkFilter(String network) {
    _selectedNetworkFilter = network;
    _applyFilters();
    notifyListeners();
  }

  void setStatusFilter(String status) {
    _selectedStatusFilter = status;
    _applyFilters();
    notifyListeners();
  }

  void setVerifiedFilter(String filter) {
    _selectedVerifiedFilter = filter;
    _applyFilters();
    notifyListeners();
  }

  void setPartnerFilter(String partnerId) {
    _selectedPartnerFilter = partnerId;
    _applyFilters();
    notifyListeners();
  }

  void setSortBy(String sortBy) {
    _selectedSortBy = sortBy;
    _applyFilters();
    notifyListeners();
  }

  void resetFilters() {
    _searchQuery = '';
    _selectedNetworkFilter = 'All';
    _selectedStatusFilter = 'All';
    _selectedVerifiedFilter = 'All';
    _selectedPartnerFilter = 'All';
    _selectedSortBy = 'Newest';
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    final filtered = _allChargers.where((charger) {
      // 1. Search Query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesName = charger.title.toLowerCase().contains(q);
        final matchesNetwork = charger.network.toLowerCase().contains(q);
        final matchesAddress = (charger.address ?? charger.description).toLowerCase().contains(q);
        if (!matchesName && !matchesNetwork && !matchesAddress) return false;
      }

      // 2. Network Filter
      if (_selectedNetworkFilter != 'All') {
        if (charger.network.toLowerCase() != _selectedNetworkFilter.toLowerCase()) {
          return false;
        }
      }

      // 3. Status Filter
      if (_selectedStatusFilter != 'All') {
        if (charger.status.name.toLowerCase() != _selectedStatusFilter.toLowerCase()) {
          return false;
        }
      }

      // 4. Verification Status Filter
      if (_selectedVerifiedFilter != 'All') {
        final filter = _selectedVerifiedFilter.toLowerCase();
        if (filter == 'verified' || filter == 'approved') {
          if (!charger.isVerified || charger.verificationStatus != 'approved') return false;
        } else if (filter == 'pending') {
          if (charger.verificationStatus != 'pending') return false;
        } else if (filter == 'rejected') {
          if (charger.verificationStatus != 'rejected') return false;
        }
      }

      // 5. Partner Filter
      if (_selectedPartnerFilter != 'All') {
        if (charger.ownerId != _selectedPartnerFilter) return false;
      }

      return true;
    }).toList();

    // Apply Sorting
    if (_selectedSortBy == 'Name') {
      filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (_selectedSortBy == 'Availability') {
      filtered.sort((a, b) => b.availableConnectorsCount.compareTo(a.availableConnectorsCount));
    } else {
      // Default: 'Newest'
      filtered.sort((a, b) => b.id.compareTo(a.id));
    }

    _filteredChargers = filtered;
  }

  /// Create a new charger document
  Future<bool> createCharger(MapMarkerModel charger, UserModel user) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      // Enforce Role Rules
      final bool isAdmin = user.isAdmin;
      final MapMarkerModel preparedCharger = charger.copyWith(
        ownerId: charger.ownerId ?? user.id,
        createdBy: user.name,
        source: 'evhub_verified',
        isVerified: isAdmin,
        verificationStatus: isAdmin ? 'approved' : 'pending',
      );

      await _firestoreRepository.addCharger(preparedCharger);

      if (isAdmin) {
        _successMessage = 'Charger added and verified successfully!';
      } else {
        _successMessage = 'Charger submitted successfully! Pending admin approval.';
      }

      await loadChargers(currentUser: user);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to create charger: ${e.toString().replaceAll("Exception: ", "")}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update existing charger document
  Future<bool> updateCharger(MapMarkerModel charger, UserModel user) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      // Enforce Security Rule: Partner cannot modify verification status
      MapMarkerModel updatedCharger = charger;
      if (!user.isAdmin) {
        final existing = _allChargers.firstWhere((c) => c.id == charger.id);
        updatedCharger = charger.copyWith(
          isVerified: existing.isVerified,
          verificationStatus: existing.verificationStatus,
          verifiedBy: existing.verifiedBy,
          verifiedAt: existing.verifiedAt,
        );
      }

      await _firestoreRepository.updateCharger(updatedCharger);
      _successMessage = 'Charger details updated successfully!';
      await loadChargers(currentUser: user);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update charger: ${e.toString().replaceAll("Exception: ", "")}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Delete a charger document
  Future<bool> deleteCharger(String chargerId, UserModel user) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _firestoreRepository.deleteCharger(chargerId);
      _successMessage = 'Charger deleted successfully!';
      await loadChargers(currentUser: user);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete charger: ${e.toString().replaceAll("Exception: ", "")}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Admin Approve Charger
  Future<bool> approveCharger(String chargerId, UserModel adminUser) async {
    if (!adminUser.isAdmin) {
      _errorMessage = 'Only administrators can approve chargers.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreRepository.approveCharger(chargerId, adminUser.id);
      _successMessage = 'Charger approved and verified successfully!';
      await loadChargers(currentUser: adminUser);
      return true;
    } catch (e) {
      _errorMessage = 'Approval failed: ${e.toString().replaceAll("Exception: ", "")}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Admin Reject Charger
  Future<bool> rejectCharger(String chargerId, UserModel adminUser) async {
    if (!adminUser.isAdmin) {
      _errorMessage = 'Only administrators can reject chargers.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreRepository.rejectCharger(chargerId, adminUser.id);
      _successMessage = 'Charger rejected.';
      await loadChargers(currentUser: adminUser);
      return true;
    } catch (e) {
      _errorMessage = 'Rejection failed: ${e.toString().replaceAll("Exception: ", "")}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Reset admin provider state upon user logout
  void clearState() {
    _chargersSubscription?.cancel();
    _allChargers = [];
    _filteredChargers = [];
    _errorMessage = null;
    _successMessage = null;
    _isLoading = false;
    resetFilters();
  }

  @override
  void dispose() {
    _chargersSubscription?.cancel();
    super.dispose();
  }
}
