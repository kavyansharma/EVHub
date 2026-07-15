import 'package:flutter/material.dart';
import '../repositories/admin_repository.dart';
import '../services/admin_service.dart';

class AdminProvider extends ChangeNotifier {
  final AdminRepository _repository;
  final AdminService _service;

  Map<String, dynamic>? _systemStats;
  bool _isLoading = false;

  AdminProvider({
    required AdminRepository repository,
    required AdminService service,
  })  : _repository = repository,
        _service = service;

  Map<String, dynamic>? get systemStats => _systemStats;
  bool get isLoading => _isLoading;

  Future<void> fetchSystemStats() async {
    _isLoading = true;
    notifyListeners();

    _systemStats = await _repository.getSystemStats();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> makeUserAdmin(String targetUserId, String currentUserId) async {
    if (_service.canElevateRole(currentUserId, targetUserId)) {
      await _repository.elevateUserRole(targetUserId, 'admin');
    }
  }
}
