import 'package:flutter/material.dart';
import '../models/vehicle_model.dart';
import '../repositories/garage_repository.dart';
import '../services/vehicle_service.dart';

class GarageProvider extends ChangeNotifier {
  final GarageRepository _garageRepository;
  final VehicleService _vehicleService;

  List<VehicleModel> _vehicles = [];
  List<VehicleModel> _ecosystemVehicles = []; // From Indian EV DB
  VehicleModel? _selectedVehicle;
  bool _isLoading = false;

  GarageProvider({
    required GarageRepository garageRepository,
    required VehicleService vehicleService,
  })  : _garageRepository = garageRepository,
        _vehicleService = vehicleService;

  List<VehicleModel> get vehicles => _vehicles;
  List<VehicleModel> get ecosystemVehicles => _ecosystemVehicles;
  VehicleModel? get selectedVehicle => _selectedVehicle;
  bool get isLoading => _isLoading;

  Future<void> fetchGarage(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _vehicles = await _garageRepository.getVehicles(userId);
      if (_vehicles.isNotEmpty) {
        _selectedVehicle = _vehicles.firstWhere((v) => v.isDefault, orElse: () => _vehicles.first);
      } else {
        _selectedVehicle = null;
      }
    } catch (e) {
      debugPrint("Error fetching garage: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadEcosystemVehicles() async {
    _isLoading = true;
    notifyListeners();
    try {
      _ecosystemVehicles = await _vehicleService.getAvailableVehicles();
    } catch (e) {
      debugPrint("Error loading ecosystem vehicles: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addVehicle(String userId, VehicleModel vehicle) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _garageRepository.addVehicle(userId, vehicle);
      await fetchGarage(userId);
    } catch (e) {
      debugPrint("Error adding vehicle: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> removeVehicle(String userId, String vehicleId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _garageRepository.deleteVehicle(userId, vehicleId);
      await fetchGarage(userId);
    } catch (e) {
      debugPrint("Error removing vehicle: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setDefaultVehicle(String userId, String vehicleId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _garageRepository.setDefaultVehicle(userId, vehicleId);
      await fetchGarage(userId);
    } catch (e) {
      debugPrint("Error setting default vehicle: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectVehicle(VehicleModel vehicle) {
    _selectedVehicle = vehicle;
    notifyListeners();
  }
}
