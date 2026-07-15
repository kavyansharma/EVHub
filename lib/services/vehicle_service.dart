import '../models/vehicle_model.dart';

class VehicleService {
  /// A seeded database of popular Indian EVs.
  static final List<VehicleModel> indianEVEcosystem = [
    const VehicleModel(
      id: 'tata-nexon-ev-lr',
      manufacturer: 'Tata Motors',
      model: 'Nexon EV',
      variant: 'Long Range (LR)',
      year: 2024,
      batteryCapacity: 40.5,
      realRange: 300,
      connectorTypes: ['CCS2', 'Type 2'],
      maxAcChargingSpeed: 7.2,
      maxDcChargingSpeed: 50.0,
      vehicleImage: 'https://example.com/nexon_ev.png', // Placeholder URL
      registrationNumber: '',
      nickname: '',
    ),
    const VehicleModel(
      id: 'mg-zs-ev',
      manufacturer: 'MG',
      model: 'ZS EV',
      variant: 'Exclusive',
      year: 2023,
      batteryCapacity: 50.3,
      realRange: 350,
      connectorTypes: ['CCS2', 'Type 2'],
      maxAcChargingSpeed: 7.4,
      maxDcChargingSpeed: 80.0,
      vehicleImage: 'https://example.com/mg_zs.png',
      registrationNumber: '',
      nickname: '',
    ),
    const VehicleModel(
      id: 'byd-atto-3',
      manufacturer: 'BYD',
      model: 'Atto 3',
      variant: 'Extended Range',
      year: 2023,
      batteryCapacity: 60.48,
      realRange: 420,
      connectorTypes: ['CCS2', 'Type 2'],
      maxAcChargingSpeed: 7.0,
      maxDcChargingSpeed: 80.0,
      vehicleImage: 'https://example.com/byd_atto3.png',
      registrationNumber: '',
      nickname: '',
    ),
    const VehicleModel(
      id: 'mahindra-xuv400',
      manufacturer: 'Mahindra',
      model: 'XUV400',
      variant: 'EL Pro',
      year: 2024,
      batteryCapacity: 39.4,
      realRange: 280,
      connectorTypes: ['CCS2', 'Type 2'],
      maxAcChargingSpeed: 7.2,
      maxDcChargingSpeed: 50.0,
      vehicleImage: 'https://example.com/xuv400.png',
      registrationNumber: '',
      nickname: '',
    ),
    const VehicleModel(
      id: 'hyundai-ioniq-5',
      manufacturer: 'Hyundai',
      model: 'Ioniq 5',
      variant: 'RWD',
      year: 2024,
      batteryCapacity: 72.6,
      realRange: 480,
      connectorTypes: ['CCS2', 'Type 2'],
      maxAcChargingSpeed: 11.0,
      maxDcChargingSpeed: 350.0, // 800V architecture
      vehicleImage: 'https://example.com/ioniq5.png',
      registrationNumber: '',
      nickname: '',
    ),
  ];

  Future<List<VehicleModel>> getAvailableVehicles() async {
    // Simulating network delay
    await Future.delayed(const Duration(milliseconds: 500));
    return indianEVEcosystem;
  }

  Future<VehicleModel?> getVehicleById(String id) async {
    try {
      return indianEVEcosystem.firstWhere((v) => v.id == id);
    } catch (e) {
      return null;
    }
  }
}
