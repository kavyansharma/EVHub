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
      vehicleImage: 'https://images.unsplash.com/photo-1619767886558-efdc259cde1a?auto=format&fit=crop&w=800&q=80',
      registrationNumber: 'DL-3C-AY-1244',
      nickname: 'Blue Lightning',
      isDefault: true,
      currentBatteryPct: 68.0,
    ),
    const VehicleModel(
      id: 'mg-windsor-ev',
      manufacturer: 'MG',
      model: 'Windsor EV',
      variant: 'Exclusive',
      year: 2024,
      batteryCapacity: 38.0,
      realRange: 285,
      connectorTypes: ['CCS2', 'Type 2'],
      maxAcChargingSpeed: 7.4,
      maxDcChargingSpeed: 50.0,
      vehicleImage: 'https://images.unsplash.com/photo-1606016159991-dfe4f2746ad5?auto=format&fit=crop&w=800&q=80',
      registrationNumber: 'MH-12-TX-8899',
      nickname: 'Windy',
      currentBatteryPct: 45.0,
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
      vehicleImage: 'https://images.unsplash.com/photo-1681283620953-73c38db5dfc8?auto=format&fit=crop&w=800&q=80',
      registrationNumber: 'KA-03-MY-7722',
      nickname: 'Blade',
      currentBatteryPct: 82.0,
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
      vehicleImage: 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=800&q=80',
      registrationNumber: 'MH-14-EV-0400',
      nickname: 'Copper Beast',
      currentBatteryPct: 90.0,
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
      maxDcChargingSpeed: 350.0,
      vehicleImage: 'https://images.unsplash.com/photo-1669062508887-21be148970e5?auto=format&fit=crop&w=800&q=80',
      registrationNumber: 'DL-1C-EV-9999',
      nickname: 'CyberShip',
      currentBatteryPct: 55.0,
    ),
    const VehicleModel(
      id: 'tesla-model-3',
      manufacturer: 'Tesla',
      model: 'Model 3',
      variant: 'Standard Range',
      year: 2024,
      batteryCapacity: 57.5,
      realRange: 380,
      connectorTypes: ['CCS2', 'Type 2'],
      maxAcChargingSpeed: 11.0,
      maxDcChargingSpeed: 170.0,
      vehicleImage: 'https://images.unsplash.com/photo-1563720223185-11003d516935?auto=format&fit=crop&w=800&q=80',
      registrationNumber: 'KA-51-EV-2024',
      nickname: 'Nikola',
      currentBatteryPct: 75.0,
    ),
  ];

  Future<List<VehicleModel>> getAvailableVehicles() async {
    // Simulating network delay
    await Future.delayed(const Duration(milliseconds: 300));
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

