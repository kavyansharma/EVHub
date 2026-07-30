/// EVVehicleRepository
///
/// Phase 4 Step 2 spec-required repository.
/// Loads the EV vehicle catalog from [VehicleService] and exposes it
/// as [EVVehicleModel] instances. Supports search/filter so the UI can
/// remain decoupled from the data source.
///
/// Design: Adding more vehicles later only requires updating [VehicleService.indianEVEcosystem].
/// The trip planner UI never needs to change.
library;

import '../models/ev_vehicle_model.dart';
import '../services/vehicle_service.dart';

class EVVehicleRepository {
  /// In-memory cache of converted models.
  List<EVVehicleModel>? _cache;

  /// Returns all available EV models from the vehicle catalog.
  Future<List<EVVehicleModel>> getAllVehicles() async {
    _cache ??= VehicleService.indianEVEcosystem
        .map(EVVehicleModel.fromVehicleModel)
        .toList();
    return List.unmodifiable(_cache!);
  }

  /// Returns vehicles whose display name matches [query] (case-insensitive).
  /// Empty [query] returns all vehicles.
  Future<List<EVVehicleModel>> searchVehicles(String query) async {
    final all = await getAllVehicles();
    if (query.trim().isEmpty) return all;
    final q = query.trim().toLowerCase();
    return all
        .where((v) =>
            v.brand.toLowerCase().contains(q) ||
            v.model.toLowerCase().contains(q) ||
            v.displayName.toLowerCase().contains(q))
        .toList();
  }

  /// Returns the vehicle with the given [id], or null if not found.
  Future<EVVehicleModel?> getById(String id) async {
    final all = await getAllVehicles();
    try {
      return all.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Returns vehicles compatible with the given connector type.
  Future<List<EVVehicleModel>> getByConnectorType(String connectorType) async {
    final all = await getAllVehicles();
    return all
        .where((v) => v.connectorTypes
            .any((c) => c.toLowerCase() == connectorType.toLowerCase()))
        .toList();
  }

  /// Clears the internal cache (useful for testing).
  void clearCache() => _cache = null;
}
