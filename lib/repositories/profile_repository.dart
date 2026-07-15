import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/profile_model.dart';

class ProfileRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<ProfileModel> getProfile(String userId) async {
    final doc = await _firestore.collection('profiles').doc(userId).get();
    if (doc.exists) {
      return ProfileModel.fromFirestore(doc);
    } else {
      // Create empty profile
      final newProfile = ProfileModel(userId: userId);
      await _firestore.collection('profiles').doc(userId).set(newProfile.toMap());
      return newProfile;
    }
  }

  Future<void> updateProfile(ProfileModel profile) async {
    await _firestore
        .collection('profiles')
        .doc(profile.userId)
        .set(profile.toMap(), SetOptions(merge: true));
  }
}
