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

  // 10 Indian Charging Networks spread across 20 cities realistically
  static List<ChargingStation> get stations => [
        ChargingStation(
          id: 'st_1',
          name: 'Tata Power EZ Charge',
          location: 'Connaught Place, New Delhi',
          distance: 1.2,
          power: 60.0,
          plugs: ['CCS2', 'Type 2 AC'],
          pricePerKWh: 15.0,
          availableStalls: 4,
          totalStalls: 6,
          isTeslaCompatible: true,
        ),
        ChargingStation(
          id: 'st_2',
          name: 'Statiq Charging Hub',
          location: 'Sector 29, Gurugram',
          distance: 4.8,
          power: 150.0,
          plugs: ['CCS2'],
          pricePerKWh: 20.0,
          availableStalls: 5,
          totalStalls: 8,
          isTeslaCompatible: true,
        ),
        ChargingStation(
          id: 'st_3',
          name: 'ChargeZone Station',
          location: 'Bandra Kurla Complex, Mumbai',
          distance: 3.1,
          power: 120.0,
          plugs: ['CCS2', 'Bharat DC001'],
          pricePerKWh: 18.0,
          availableStalls: 8,
          totalStalls: 12,
          isTeslaCompatible: true,
        ),
        ChargingStation(
          id: 'st_4',
          name: 'Jio-bp Pulse',
          location: 'Indiranagar, Bengaluru',
          distance: 0.7,
          power: 60.0,
          plugs: ['CCS2', 'Type 2 AC'],
          pricePerKWh: 15.0,
          availableStalls: 0,
          totalStalls: 6,
          isTeslaCompatible: true,
        ),
        ChargingStation(
          id: 'st_5',
          name: 'Bolt.Earth Charger',
          location: 'Gachibowli, Hyderabad',
          distance: 2.5,
          power: 22.0,
          plugs: ['Type 2 AC', 'Bharat AC001'],
          pricePerKWh: 10.0,
          availableStalls: 3,
          totalStalls: 6,
          isTeslaCompatible: false,
        ),
        ChargingStation(
          id: 'st_6',
          name: 'Kazam EV Charging',
          location: 'Koregaon Park, Pune',
          distance: 3.5,
          power: 11.0,
          plugs: ['Bharat AC001', 'Type 2 AC'],
          pricePerKWh: 8.0,
          availableStalls: 2,
          totalStalls: 4,
          isTeslaCompatible: false,
        ),
        ChargingStation(
          id: 'st_7',
          name: 'Glida Charging Hub',
          location: 'SG Highway, Ahmedabad',
          distance: 5.2,
          power: 60.0,
          plugs: ['CCS2', 'Bharat DC001'],
          pricePerKWh: 15.0,
          availableStalls: 4,
          totalStalls: 8,
          isTeslaCompatible: true,
        ),
        ChargingStation(
          id: 'st_8',
          name: 'Zeon Charging',
          location: 'Coimbatore Road, Chennai',
          distance: 6.0,
          power: 150.0,
          plugs: ['CCS2'],
          pricePerKWh: 20.0,
          availableStalls: 3,
          totalStalls: 6,
          isTeslaCompatible: true,
        ),
        ChargingStation(
          id: 'st_9',
          name: 'Relux Electric Station',
          location: 'Vaishali Nagar, Jaipur',
          distance: 2.9,
          power: 50.0,
          plugs: ['CCS2', 'Bharat DC001'],
          pricePerKWh: 12.0,
          availableStalls: 1,
          totalStalls: 4,
          isTeslaCompatible: true,
        ),
        ChargingStation(
          id: 'st_10',
          name: 'LionCharge Hub',
          location: 'Gomti Nagar, Lucknow',
          distance: 4.1,
          power: 30.0,
          plugs: ['CCS2', 'Bharat DC001'],
          pricePerKWh: 10.0,
          availableStalls: 4,
          totalStalls: 6,
          isTeslaCompatible: true,
        ),
        ChargingStation(
          id: 'st_11',
          name: 'Tata Power EZ Charge',
          location: 'Salt Lake Sector V, Kolkata',
          distance: 3.8,
          power: 60.0,
          plugs: ['CCS2', 'Type 2 AC'],
          pricePerKWh: 15.0,
          availableStalls: 6,
          totalStalls: 8,
          isTeslaCompatible: true,
        ),
        ChargingStation(
          id: 'st_12',
          name: 'Jio-bp Pulse',
          location: 'Sector 62, Noida',
          distance: 5.5,
          power: 120.0,
          plugs: ['CCS2'],
          pricePerKWh: 18.0,
          availableStalls: 7,
          totalStalls: 10,
          isTeslaCompatible: true,
        ),
        ChargingStation(
          id: 'st_13',
          name: 'Statiq Hub',
          location: 'Vijay Nagar, Indore',
          distance: 2.1,
          power: 50.0,
          plugs: ['CCS2', 'Type 2 AC'],
          pricePerKWh: 13.0,
          availableStalls: 4,
          totalStalls: 8,
          isTeslaCompatible: true,
        ),
        ChargingStation(
          id: 'st_14',
          name: 'ChargeZone Hub',
          location: 'Maharana Pratap Nagar, Bhopal',
          distance: 3.4,
          power: 60.0,
          plugs: ['CCS2'],
          pricePerKWh: 14.0,
          availableStalls: 2,
          totalStalls: 6,
          isTeslaCompatible: true,
        ),
        ChargingStation(
          id: 'st_15',
          name: 'Relux Electric',
          location: 'Civil Lines, Nagpur',
          distance: 4.5,
          power: 50.0,
          plugs: ['CCS2', 'Bharat DC001'],
          pricePerKWh: 12.0,
          availableStalls: 3,
          totalStalls: 4,
          isTeslaCompatible: true,
        ),
        ChargingStation(
          id: 'st_16',
          name: 'Zeon Charging',
          location: 'Edappally, Kochi',
          distance: 6.2,
          power: 120.0,
          plugs: ['CCS2', 'Type 2 AC'],
          pricePerKWh: 20.0,
          availableStalls: 5,
          totalStalls: 8,
          isTeslaCompatible: true,
        ),
        ChargingStation(
          id: 'st_17',
          name: 'Glida Charging',
          location: 'Panaji Waterfront, Goa',
          distance: 1.8,
          power: 22.0,
          plugs: ['Type 2 AC'],
          pricePerKWh: 10.0,
          availableStalls: 4,
          totalStalls: 6,
          isTeslaCompatible: false,
        ),
        ChargingStation(
          id: 'st_18',
          name: 'Bolt.Earth Station',
          location: 'Dumas Road, Surat',
          distance: 3.9,
          power: 7.4,
          plugs: ['Type 2 AC', 'Bharat AC001'],
          pricePerKWh: 9.0,
          availableStalls: 3,
          totalStalls: 4,
          isTeslaCompatible: false,
        ),
        ChargingStation(
          id: 'st_19',
          name: 'Kazam Charging',
          location: 'Bailey Road, Patna',
          distance: 2.7,
          power: 3.3,
          plugs: ['Bharat AC001'],
          pricePerKWh: 8.0,
          availableStalls: 2,
          totalStalls: 4,
          isTeslaCompatible: false,
        ),
        ChargingStation(
          id: 'st_20',
          name: 'LionCharge Station',
          location: 'Sector 17, Chandigarh',
          distance: 4.0,
          power: 50.0,
          plugs: ['CCS2', 'Bharat DC001'],
          pricePerKWh: 12.0,
          availableStalls: 3,
          totalStalls: 6,
          isTeslaCompatible: true,
        ),
      ];

  // Resolve compilation error: defaultStations returns Firestore compatible models
  static List<StationModel> get defaultStations => stations
      .map((st) => StationModel(
            id: st.id,
            name: st.name,
            location: st.location,
            distance: st.distance,
            power: st.power,
            plugs: st.plugs,
            pricePerKWh: st.pricePerKWh,
            availableStalls: st.availableStalls,
            totalStalls: st.totalStalls,
            isTeslaCompatible: st.isTeslaCompatible,
            isFavorite: false,
          ))
      .toList();

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
