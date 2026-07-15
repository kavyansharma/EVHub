import '../models/ecosystem_network_model.dart';
import '../models/station_model.dart';

class EcosystemService {
  
  /// Aggregate chargers from different networks (Simulated)
  Future<List<StationModel>> fetchPartnerNetworkStations(EcosystemNetworkModel network) async {
    // In production, this would make an HTTP request to `network.apiEndpoint`
    await Future.delayed(const Duration(milliseconds: 500));

    if (network.isPartner) {
      return [
        StationModel(
          id: '${network.networkId}_1',
          name: '${network.name} Plaza Fast Charge',
          location: 'Pune',
          distance: 5.2,
          power: 50.0,
          plugs: ['CCS2', 'Type 2'],
          pricePerKWh: 15.0,
          availableStalls: 2,
          totalStalls: 4,
          isTeslaCompatible: false,
        ),
        StationModel(
          id: '${network.networkId}_2',
          name: '${network.name} Highway Stop',
          location: 'Pune Outskirts',
          distance: 12.0,
          power: 150.0,
          plugs: ['CCS2'],
          pricePerKWh: 18.0,
          availableStalls: 1,
          totalStalls: 2,
          isTeslaCompatible: true,
        )
      ];
    }
    
    return [];
  }
}
