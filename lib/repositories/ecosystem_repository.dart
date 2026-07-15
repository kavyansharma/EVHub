import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ecosystem_network_model.dart';

class EcosystemRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveNetwork(EcosystemNetworkModel network) async {
    await _firestore
        .collection('ecosystem_networks')
        .doc(network.networkId)
        .set(network.toMap());
  }

  Stream<List<EcosystemNetworkModel>> watchNetworks() {
    return _firestore
        .collection('ecosystem_networks')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => EcosystemNetworkModel.fromFirestore(doc)).toList());
  }
}
