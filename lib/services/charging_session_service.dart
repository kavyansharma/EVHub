import 'dart:async';
import 'dart:math';
import '../models/charging_session_model.dart';

class ChargingSessionService {
  Timer? _simulationTimer;
  
  /// In a real app, this would connect via WebSockets or MQTT to the charger/backend.
  /// Here we simulate a live charging session updating every second.
  Stream<ChargingSessionModel> startSimulatedSession(ChargingSessionModel initialSession) {
    StreamController<ChargingSessionModel> controller = StreamController<ChargingSessionModel>();
    
    ChargingSessionModel currentSession = initialSession;
    final random = Random();
    int secondsPassed = 0;

    _simulationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (currentSession.status == SessionStatus.paused) {
        // Do nothing while paused
        controller.add(currentSession);
        return;
      }

      if (currentSession.status == SessionStatus.stopped || currentSession.status == SessionStatus.completed) {
        timer.cancel();
        controller.close();
        return;
      }

      secondsPassed++;
      
      // Simulate fluctuation in kW (e.g., 20-25 kW for a 25kW charger)
      final kwFluctuation = 20.0 + random.nextDouble() * 5.0;
      
      // Calculate units consumed (kWh) = Power (kW) * Time (hours)
      final addedUnits = kwFluctuation * (1.0 / 3600.0);
      final newUnits = currentSession.unitsConsumed + addedUnits;

      // Simulate battery % increase
      final newBattery = (currentSession.batteryPercentage + (addedUnits * 2.5)).clamp(0.0, 100.0);

      // Temperature increase
      final tempFluctuation = currentSession.temperature + (random.nextDouble() * 0.2 - 0.05);

      // Add to graph every 5 seconds
      List<GraphPoint> newGraph = List.from(currentSession.powerGraph);
      if (secondsPassed % 5 == 0) {
        newGraph.add(GraphPoint(timestampOffsetSeconds: secondsPassed, kwValue: kwFluctuation));
      }

      currentSession = currentSession.copyWith(
        currentKw: kwFluctuation,
        unitsConsumed: newUnits,
        batteryPercentage: newBattery,
        temperature: tempFluctuation,
        powerGraph: newGraph,
        currentCost: newUnits * 15.0, // Base price simulation
      );

      if (currentSession.batteryPercentage >= 100.0) {
        currentSession = currentSession.copyWith(
          status: SessionStatus.completed,
          endTime: DateTime.now(),
          currentKw: 0.0,
        );
      }

      controller.add(currentSession);
    });

    return controller.stream;
  }

  void stopSimulation() {
    _simulationTimer?.cancel();
  }
}
