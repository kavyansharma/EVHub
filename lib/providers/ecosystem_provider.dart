import 'dart:async';
import 'package:flutter/material.dart';
import '../models/ecosystem_network_model.dart';
import '../models/station_model.dart';
import '../repositories/ecosystem_repository.dart';
import '../services/ecosystem_service.dart';

class EcosystemProvider extends ChangeNotifier {
  final EcosystemRepository _repository;
  final EcosystemService _service;

  List<EcosystemNetworkModel> _networks = [];
  List<StationModel> _partnerStations = [];
  bool _isLoading = false;
  StreamSubscription<List<EcosystemNetworkModel>>? _netSub;

  EcosystemProvider({
    required EcosystemRepository repository,
    required EcosystemService service,
  })  : _repository = repository,
        _service = service;

  List<EcosystemNetworkModel> get networks => _networks;
  List<StationModel> get partnerStations => _partnerStations;
  bool get isLoading => _isLoading;

  void loadEcosystem() {
    _netSub?.cancel();
    _netSub = _repository.watchNetworks().listen((nets) {
      _networks = nets;
      _aggregatePartnerStations();
    });
  }

  Future<void> _aggregatePartnerStations() async {
    _isLoading = true;
    notifyListeners();
    
    List<StationModel> allPartnerStations = [];
    for (var net in _networks) {
      final stations = await _service.fetchPartnerNetworkStations(net);
      allPartnerStations.addAll(stations);
    }
    
    _partnerStations = allPartnerStations;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _netSub?.cancel();
    super.dispose();
  }
}
