import '../models/station_model.dart';

class ChargingStation {
  final String id;
  final String name;
  final String location;
  final double distance; // in km
  final double power; // in kW
  final List<String> plugs;
  final double pricePerKWh;
  final int availableStalls;
  final int totalStalls;
  final bool isTeslaCompatible;

  ChargingStation({
    required this.id,
    required this.name,
    required this.location,
    required this.distance,
    required this.power,
    required this.plugs,
    required this.pricePerKWh,
    required this.availableStalls,
    required this.totalStalls,
    required this.isTeslaCompatible,
  });
}

class TripStop {
  final String name;
  final double distanceFromStart; // in km
  final double estimatedBatteryPercent; // 0.0 to 1.0
  final double chargeTimeMinutes;

  TripStop({
    required this.name,
    required this.distanceFromStart,
    required this.estimatedBatteryPercent,
    required this.chargeTimeMinutes,
  });
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class IndianEV {
  final String name;
  final double batteryCapacity; // in kWh
  final double realRange; // in km
  final double chargingSpeed; // in kW
  final String acCharging;
  final String dcCharging;
  final String connectorType;
  final List<String> compatibleConnectors;

  const IndianEV({
    required this.name,
    required this.batteryCapacity,
    required this.realRange,
    required this.chargingSpeed,
    required this.acCharging,
    required this.dcCharging,
    required this.connectorType,
    required this.compatibleConnectors,
  });
}

class MockData {
  // 23 Indian EVs as specified
  static List<IndianEV> get vehicles => const [
        IndianEV(
          name: 'Tata Nexon EV',
          batteryCapacity: 40.5,
          realRange: 325.0,
          chargingSpeed: 50.0,
          acCharging: '7.2 kW AC (Type 2)',
          dcCharging: '50 kW DC (CCS2)',
          connectorType: 'CCS2 / Type 2 AC',
          compatibleConnectors: ['CCS2', 'Type 2 AC'],
        ),
        IndianEV(
          name: 'Tata Punch EV',
          batteryCapacity: 35.0,
          realRange: 275.0,
          chargingSpeed: 50.0,
          acCharging: '7.2 kW AC (Type 2)',
          dcCharging: '50 kW DC (CCS2)',
          connectorType: 'CCS2 / Type 2 AC',
          compatibleConnectors: ['CCS2', 'Type 2 AC'],
        ),
        IndianEV(
          name: 'Tata Tiago EV',
          batteryCapacity: 24.0,
          realRange: 250.0,
          chargingSpeed: 25.0,
          acCharging: '3.3 kW / 7.2 kW AC (Type 2)',
          dcCharging: '25 kW DC (CCS2)',
          connectorType: 'CCS2 / Type 2 AC',
          compatibleConnectors: ['CCS2', 'Type 2 AC', 'Bharat AC001'],
        ),
        IndianEV(
          name: 'Tata Curvv EV',
          batteryCapacity: 55.0,
          realRange: 450.0,
          chargingSpeed: 70.0,
          acCharging: '7.2 kW AC (Type 2)',
          dcCharging: '70 kW DC (CCS2)',
          connectorType: 'CCS2 / Type 2 AC',
          compatibleConnectors: ['CCS2', 'Type 2 AC'],
        ),
        IndianEV(
          name: 'Mahindra XUV400',
          batteryCapacity: 39.4,
          realRange: 359.0,
          chargingSpeed: 50.0,
          acCharging: '7.2 kW AC (Type 2)',
          dcCharging: '50 kW DC (CCS2)',
          connectorType: 'CCS2 / Type 2 AC',
          compatibleConnectors: ['CCS2', 'Type 2 AC'],
        ),
        IndianEV(
          name: 'Mahindra BE 6',
          batteryCapacity: 79.0,
          realRange: 500.0,
          chargingSpeed: 175.0,
          acCharging: '11 kW AC (Type 2)',
          dcCharging: '175 kW DC (CCS2)',
          connectorType: 'CCS2 / Type 2 AC',
          compatibleConnectors: ['CCS2', 'Type 2 AC'],
        ),
        IndianEV(
          name: 'Mahindra XEV 9e',
          batteryCapacity: 79.0,
          realRange: 500.0,
          chargingSpeed: 175.0,
          acCharging: '11 kW AC (Type 2)',
          dcCharging: '175 kW DC (CCS2)',
          connectorType: 'CCS2 / Type 2 AC',
          compatibleConnectors: ['CCS2', 'Type 2 AC'],
        ),
        IndianEV(
          name: 'MG ZS EV',
          batteryCapacity: 50.3,
          realRange: 340.0,
          chargingSpeed: 50.0,
          acCharging: '7.2 kW AC (Type 2)',
          dcCharging: '50 kW DC (CCS2)',
          connectorType: 'CCS2 / Type 2 AC',
          compatibleConnectors: ['CCS2', 'Type 2 AC'],
        ),
        IndianEV(
          name: 'MG Windsor EV',
          batteryCapacity: 38.0,
          realRange: 331.0,
          chargingSpeed: 45.0,
          acCharging: '7.2 kW AC (Type 2)',
          dcCharging: '45 kW DC (CCS2)',
          connectorType: 'CCS2 / Type 2 AC',
          compatibleConnectors: ['CCS2', 'Type 2 AC'],
        ),
        IndianEV(
          name: 'BYD Atto 3',
          batteryCapacity: 60.48,
          realRange: 420.0,
          chargingSpeed: 80.0,
          acCharging: '7 kW AC (Type 2)',
          dcCharging: '80 kW DC (CCS2)',
          connectorType: 'CCS2 / Type 2 AC',
          compatibleConnectors: ['CCS2', 'Type 2 AC'],
        ),
        IndianEV(
          name: 'BYD Seal',
          batteryCapacity: 82.56,
          realRange: 570.0,
          chargingSpeed: 150.0,
          acCharging: '7 kW AC (Type 2)',
          dcCharging: '150 kW DC (CCS2)',
          connectorType: 'CCS2 / Type 2 AC',
          compatibleConnectors: ['CCS2', 'Type 2 AC'],
        ),
        IndianEV(
          name: 'Hyundai Kona Electric',
          batteryCapacity: 39.2,
          realRange: 305.0,
          chargingSpeed: 50.0,
          acCharging: '7.2 kW AC (Type 2)',
          dcCharging: '50 kW DC (CCS2)',
          connectorType: 'CCS2 / Type 2 AC',
          compatibleConnectors: ['CCS2', 'Type 2 AC'],
        ),
        IndianEV(
          name: 'Hyundai Creta Electric',
          batteryCapacity: 45.0,
          realRange: 350.0,
          chargingSpeed: 50.0,
          acCharging: '7.2 kW AC (Type 2)',
          dcCharging: '50 kW DC (CCS2)',
          connectorType: 'CCS2 / Type 2 AC',
          compatibleConnectors: ['CCS2', 'Type 2 AC'],
        ),
        IndianEV(
          name: 'Citroen eC3',
          batteryCapacity: 29.2,
          realRange: 220.0,
          chargingSpeed: 30.0,
          acCharging: '3.3 kW AC (Type 2)',
          dcCharging: '30 kW DC (CCS2 / Bharat DC001)',
          connectorType: 'CCS2 / Type 2 AC / Bharat DC001',
          compatibleConnectors: ['CCS2', 'Type 2 AC', 'Bharat DC001'],
        ),
        IndianEV(
          name: 'Citroen Basalt EV',
          batteryCapacity: 35.0,
          realRange: 300.0,
          chargingSpeed: 50.0,
          acCharging: '7.2 kW AC (Type 2)',
          dcCharging: '50 kW DC (CCS2)',
          connectorType: 'CCS2 / Type 2 AC',
          compatibleConnectors: ['CCS2', 'Type 2 AC'],
        ),
        IndianEV(
          name: 'Kia EV6',
          batteryCapacity: 77.4,
          realRange: 528.0,
          chargingSpeed: 350.0,
          acCharging: '11 kW AC (Type 2)',
          dcCharging: '350 kW DC (CCS2)',
          connectorType: 'CCS2 / Type 2 AC',
          compatibleConnectors: ['CCS2', 'Type 2 AC'],
        ),
        IndianEV(
          name: 'Kia EV9',
          batteryCapacity: 99.8,
          realRange: 541.0,
          chargingSpeed: 350.0,
          acCharging: '11 kW AC (Type 2)',
          dcCharging: '350 kW DC (CCS2)',
          connectorType: 'CCS2 / Type 2 AC',
          compatibleConnectors: ['CCS2', 'Type 2 AC'],
        ),
        IndianEV(
          name: 'BMW i4',
          batteryCapacity: 83.9,
          realRange: 490.0,
          chargingSpeed: 205.0,
          acCharging: '11 kW AC (Type 2)',
          dcCharging: '205 kW DC (CCS2)',
          connectorType: 'CCS2 / Type 2 AC',
          compatibleConnectors: ['CCS2', 'Type 2 AC'],
        ),
        IndianEV(
          name: 'BMW iX',
          batteryCapacity: 76.6,
          realRange: 375.0,
          chargingSpeed: 150.0,
          acCharging: '11 kW AC (Type 2)',
          dcCharging: '150 kW DC (CCS2)',
          connectorType: 'CCS2 / Type 2 AC',
          compatibleConnectors: ['CCS2', 'Type 2 AC'],
        ),
        IndianEV(
          name: 'Mercedes EQS',
          batteryCapacity: 107.8,
          realRange: 700.0,
          chargingSpeed: 200.0,
          acCharging: '22 kW AC (Type 2)',
          dcCharging: '200 kW DC (CCS2)',
          connectorType: 'CCS2 / Type 2 AC',
          compatibleConnectors: ['CCS2', 'Type 2 AC'],
        ),
        IndianEV(
          name: 'Mercedes EQA',
          batteryCapacity: 66.5,
          realRange: 400.0,
          chargingSpeed: 100.0,
          acCharging: '11 kW AC (Type 2)',
          dcCharging: '100 kW DC (CCS2)',
          connectorType: 'CCS2 / Type 2 AC',
          compatibleConnectors: ['CCS2', 'Type 2 AC'],
        ),
        IndianEV(
          name: 'Volvo EX40',
          batteryCapacity: 69.0,
          realRange: 420.0,
          chargingSpeed: 150.0,
          acCharging: '11 kW AC (Type 2)',
          dcCharging: '150 kW DC (CCS2)',
          connectorType: 'CCS2 / Type 2 AC',
          compatibleConnectors: ['CCS2', 'Type 2 AC'],
        ),
        IndianEV(
          name: 'Volvo C40 Recharge',
          batteryCapacity: 78.0,
          realRange: 450.0,
          chargingSpeed: 150.0,
          acCharging: '11 kW AC (Type 2)',
          dcCharging: '150 kW DC (CCS2)',
          connectorType: 'CCS2 / Type 2 AC',
          compatibleConnectors: ['CCS2', 'Type 2 AC'],
        ),
      ];

  static List<ChargingStation> get stations => [];

  // Resolve compilation error: defaultStations returns Firestore compatible models
  static List<StationModel> get defaultStations => [];

  // Indian Routes
  static List<TripStop> get tripStops => [
        TripStop(
          name: 'Starting Point: Delhi',
          distanceFromStart: 0,
          estimatedBatteryPercent: 1.0,
          chargeTimeMinutes: 0,
        ),
        TripStop(
          name: 'Stop 1: Statiq Charging Hub (Sector 29, Gurugram)',
          distanceFromStart: 30,
          estimatedBatteryPercent: 0.88,
          chargeTimeMinutes: 15,
        ),
        TripStop(
          name: 'Stop 2: Relux Electric Station (Vaishali Nagar, Jaipur)',
          distanceFromStart: 250,
          estimatedBatteryPercent: 0.25,
          chargeTimeMinutes: 30,
        ),
        TripStop(
          name: 'Destination: Jaipur Center',
          distanceFromStart: 270,
          estimatedBatteryPercent: 0.80,
          chargeTimeMinutes: 0,
        ),
      ];

  static Map<String, String> get aiResponses => {
        'default':
            'Namaste! I am your EVHub India AI Assistant. I can help you find optimal charging stations across India, check EV model connector compatibility, or calculate trip costs. Try asking: "Which are the fastest chargers in India?" or "Recommend a good Indian EV with specs."',
        'fastest':
            'The fastest chargers near you in the EVHub India network are the **Statiq Charging Hub** (Sector 29, Gurugram) and the **Zeon Charging Hub** (Chennai), both offering up to **150 kW** charging speeds. Other excellent options include the **BKC G-Block ChargeZone** in Mumbai (120 kW) and the **Jio-bp Pulse** in Bengaluru (60 kW).',
        'wallet':
          'You can add money to your **Universal Wallet** in Indian Rupees (₹) using Indian payment methods such as **UPI (GPay, PhonePe, Paytm, BHIM)**, **Debit/Credit Card**, or **Net Banking**. Tap to charge instantly at any provider like Tata Power EZ Charge, Statiq, or Zeon.',
        'battery':
            'To optimize your Indian EV battery (such as a Tata Nexon EV or MG ZS EV), try to keep your charge level between **20% and 80%** for daily driving. Limit ultra-fast DC charging when Level 2 AC (Type 2) is available, and avoid charging immediately after driving in hot Indian summers to let the battery cool.',
        'queue':
            'Queue times at **Tata Power EZ Charge** (Connaught Place, Delhi) typically increase between 5:30 PM and 7:30 PM. I recommend arriving before 5:00 PM to ensure stall availability.',
        'evs':
            'Here are popular Indian EVs: \n\n• **Tata Nexon EV**: 40.5 kWh, 325 km real range, CCS2 (50 kW DC charging).\n• **Tata Punch EV**: 35 kWh, 275 km real range, CCS2.\n• **Mahindra XUV400**: 39.4 kWh, 359 km real range, CCS2.\n• **MG ZS EV**: 50.3 kWh, 340 km real range, CCS2.\n• **BYD Seal**: 82.56 kWh, 570 km range, CCS2 (150 kW DC).\n• **Citroen eC3**: 29.2 kWh, 220 km real range, CCS2 & Bharat DC001.\n\nAll support CCS2/Type 2 standard charging networks.',
        'trip':
            'To plan a trip from Delhi to Jaipur (approx. 270 km) using a Tata Nexon EV (40.5 kWh, 325 km range): \n- One stop at **Relux Electric (Jaipur)** for 30 minutes is recommended.\n- Total energy consumed: ~34 kWh.\n- Total charging cost: ~₹510 (calculated at ₹15/kWh fast charging rate).'
      };

  static String getAiResponse(String query) {
    final lower = query.toLowerCase();
    if (lower.contains('fast') || lower.contains('speed') || lower.contains('nearest')) {
      return aiResponses['fastest']!;
    } else if (lower.contains('wallet') || lower.contains('pay') || lower.contains('money') || lower.contains('inr') || lower.contains('rupee')) {
      return aiResponses['wallet']!;
    } else if (lower.contains('battery') || lower.contains('range') || lower.contains('life') || lower.contains('celsius')) {
      return aiResponses['battery']!;
    } else if (lower.contains('queue') || lower.contains('busy') || lower.contains('wait')) {
      return aiResponses['queue']!;
    } else if (lower.contains('recommend') || lower.contains('ev') || lower.contains('car') || lower.contains('nexon') || lower.contains('tata') || lower.contains('vehicle')) {
      return aiResponses['evs']!;
    } else if (lower.contains('trip') || lower.contains('route') || lower.contains('delhi') || lower.contains('jaipur') || lower.contains('cost') || lower.contains('plan')) {
      return aiResponses['trip']!;
    }
    return aiResponses['default']!;
  }
}
