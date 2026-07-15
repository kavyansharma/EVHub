import 'package:flutter/material.dart';
import '../models/profile_model.dart';
import '../repositories/profile_repository.dart';
import '../services/profile_service.dart';

class ProfileProvider extends ChangeNotifier {
  final ProfileRepository _profileRepository;

  ProfileModel? _profile;
  bool _isLoading = false;

  ProfileProvider({
    required ProfileRepository profileRepository,
    required ProfileService profileService,
  })  : _profileRepository = profileRepository;

  ProfileModel? get profile => _profile;
  bool get isLoading => _isLoading;

  Future<void> loadProfile(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _profile = await _profileRepository.getProfile(userId);
    } catch (e) {
      debugPrint("Error loading profile: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile(ProfileModel updatedProfile) async {
    try {
      await _profileRepository.updateProfile(updatedProfile);
      _profile = updatedProfile;
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating profile: $e");
    }
  }
}
