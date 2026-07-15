import 'dart:async';
import 'package:flutter/material.dart';
import '../models/fleet_model.dart';
import '../repositories/fleet_repository.dart';
import '../services/fleet_service.dart';

class FleetProvider extends ChangeNotifier {
  final FleetRepository _repository;

  List<FleetModel> _driverFleets = [];
  FleetModel? _activeFleet;
  StreamSubscription<List<FleetModel>>? _fleetsSub;

  FleetProvider({
    required FleetRepository repository,
    required FleetService service, // keeping the parameter so we don't break main.dart, or removing from main too
  })  : _repository = repository;

  List<FleetModel> get driverFleets => _driverFleets;
  FleetModel? get activeFleet => _activeFleet;

  void loadDriverFleets(String driverId) {
    _fleetsSub?.cancel();
    _fleetsSub = _repository.watchFleetsByDriver(driverId).listen((fleets) {
      _driverFleets = fleets;
      if (_driverFleets.isNotEmpty && _activeFleet == null) {
        _activeFleet = _driverFleets.first;
      }
      notifyListeners();
    });
  }

  void setActiveFleet(FleetModel fleet) {
    _activeFleet = fleet;
    notifyListeners();
  }

  @override
  void dispose() {
    _fleetsSub?.cancel();
    super.dispose();
  }
}
