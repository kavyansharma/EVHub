import 'package:flutter/material.dart';
import '../models/map_marker_model.dart';
import '../repositories/maps_repository.dart';
import '../services/maps_service.dart';

class MapsProvider extends ChangeNotifier {
  final MapsRepository _mapsRepository;
  final MapsService _mapsService;

  List<MapMarkerModel> _markers = [];
  Map<String, double>? _currentLocation;
  bool _isLoading = false;

  MapsProvider({
    required MapsRepository mapsRepository,
    required MapsService mapsService,
  })  : _mapsRepository = mapsRepository,
        _mapsService = mapsService;

  List<MapMarkerModel> get markers => _markers;
  Map<String, double>? get currentLocation => _currentLocation;
  bool get isLoading => _isLoading;

  Future<void> fetchCurrentLocationAndStations() async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentLocation = await _mapsService.getCurrentLocation();
      if (_currentLocation != null) {
        _markers = await _mapsRepository.getStationsNearLocation(
          _currentLocation!['latitude']!,
          _currentLocation!['longitude']!,
          10.0, // 10km radius
        );
      }
    } catch (e) {
      debugPrint("Error fetching maps data: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
