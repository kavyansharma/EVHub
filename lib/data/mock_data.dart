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

class MockData {
  static List<ChargingStation> get stations => [
        ChargingStation(
          id: 'st_1',
          name: 'EVHub Supercharger Alpha',
          location: 'Downtown Square, Terminal 2',
          distance: 1.2,
          power: 150.0,
          plugs: ['CCS2', 'Type 2'],
          pricePerKWh: 0.35,
          availableStalls: 4,
          totalStalls: 8,
          isTeslaCompatible: true,
        ),
        ChargingStation(
          id: 'st_2',
          name: 'Tesla Supercharger V4',
          location: 'Highway 101, Exit 45',
          distance: 4.8,
          power: 250.0,
          plugs: ['NACS', 'CCS2'],
          pricePerKWh: 0.42,
          availableStalls: 12,
          totalStalls: 16,
          isTeslaCompatible: true,
        ),
        ChargingStation(
          id: 'st_3',
          name: 'Greenway Rapid Charging',
          location: 'Metro Shopping Mall North',
          distance: 3.1,
          power: 50.0,
          plugs: ['CHAdeMO', 'CCS2'],
          pricePerKWh: 0.28,
          availableStalls: 1,
          totalStalls: 4,
          isTeslaCompatible: false,
        ),
        ChargingStation(
          id: 'st_4',
          name: 'EVHub Ultra Charger',
          location: 'Financial District, Block C',
          distance: 0.7,
          power: 350.0,
          plugs: ['CCS2'],
          pricePerKWh: 0.48,
          availableStalls: 0,
          totalStalls: 4,
          isTeslaCompatible: true,
        ),
        ChargingStation(
          id: 'st_5',
          name: 'VoltCorp Level 2 Station',
          location: 'Community Park West',
          distance: 2.5,
          power: 22.0,
          plugs: ['Type 2'],
          pricePerKWh: 0.18,
          availableStalls: 3,
          totalStalls: 6,
          isTeslaCompatible: false,
        ),
      ];

  static List<TripStop> get tripStops => [
        TripStop(
          name: 'Starting Point: San Francisco',
          distanceFromStart: 0,
          estimatedBatteryPercent: 1.0,
          chargeTimeMinutes: 0,
        ),
        TripStop(
          name: 'Stop 1: EVHub Supercharger Alpha',
          distanceFromStart: 120,
          estimatedBatteryPercent: 0.38,
          chargeTimeMinutes: 22,
        ),
        TripStop(
          name: 'Stop 2: Tesla Supercharger V4',
          distanceFromStart: 280,
          estimatedBatteryPercent: 0.25,
          chargeTimeMinutes: 18,
        ),
        TripStop(
          name: 'Destination: Los Angeles',
          distanceFromStart: 410,
          estimatedBatteryPercent: 0.45,
          chargeTimeMinutes: 0,
        ),
      ];

  static Map<String, String> get aiResponses => {
        'default':
            'Hello! I am your EVHub AI Assistant. I can help you find optimal charging stations, forecast queue times, or plan routes. Try asking: "Where is the fastest charger near me?" or "How can I optimize my battery life?"',
        'fastest':
            'The fastest charger near you is the **EVHub Ultra Charger** located at the Financial District. It offers up to **350 kW** charging speeds. However, all stalls are currently occupied. The next fastest is the **Tesla Supercharger V4** (4.8 mi away, 250 kW, 12/16 stalls available).',
        'wallet':
            'You can add money to your **Universal Wallet** in the Home Tab. Once funded, you can tap to initiate a charge at any EVHub, Tesla, or Greenway charger without using separate apps.',
        'battery':
            'To optimize battery life, try to keep your charge level between **20% and 80%** for daily driving. Avoid frequent ultra-fast DC charging if Level 2 AC is available, and precondition the battery before charging in cold temperatures.',
        'queue':
            'Queue times at **EVHub Supercharger Alpha** are expected to increase between 5:00 PM and 7:00 PM today. I recommend arriving before 4:30 PM to avoid a wait.',
      };

  static String getAiResponse(String query) {
    final lower = query.toLowerCase();
    if (lower.contains('fast') || lower.contains('speed') || lower.contains('nearest')) {
      return aiResponses['fastest']!;
    } else if (lower.contains('wallet') || lower.contains('pay') || lower.contains('money')) {
      return aiResponses['wallet']!;
    } else if (lower.contains('battery') || lower.contains('range') || lower.contains('life')) {
      return aiResponses['battery']!;
    } else if (lower.contains('queue') || lower.contains('busy') || lower.contains('wait')) {
      return aiResponses['queue']!;
    }
    return aiResponses['default']!;
  }
}
