import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/charging_session_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/charging_session_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';

class ChargingSessionScreen extends StatefulWidget {
  const ChargingSessionScreen({super.key});

  @override
  State<ChargingSessionScreen> createState() => _ChargingSessionScreenState();
}

class _ChargingSessionScreenState extends State<ChargingSessionScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChargingSessionProvider>();
    final session = provider.activeSession;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Live Charging Session')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (session == null)
              _buildStartView(context, provider, isDark)
            else ...[
              _buildStatusHeader(session, isDark),
              const SizedBox(height: 24),
              _buildMainMetrics(session),
              const SizedBox(height: 24),
              _buildLiveGraph(session),
              const SizedBox(height: 24),
              _buildSecondaryMetrics(session, isDark),
              const SizedBox(height: 32),
              _buildControls(provider, session),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildStartView(BuildContext context, ChargingSessionProvider provider, bool isDark) {
    return Center(
      child: GlassContainer(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.ev_station, size: 80, color: AppColors.primaryCyan),
            const SizedBox(height: 16),
            const Text('Ready to Charge', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Plug in your vehicle and start the session.', textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                final userId = context.read<AuthProvider>().user?.id ?? 'guest';
                provider.startSession(userId, 'st_demo', 'charger_1');
              },
              icon: const Icon(Icons.bolt),
              label: const Text('Start Charging (Simulated)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryCyan,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(ChargingSessionModel session, bool isDark) {
    Color statusColor;
    String statusText;
    switch (session.status) {
      case SessionStatus.charging:
        statusColor = AppColors.primaryCyan;
        statusText = 'CHARGING IN PROGRESS';
        break;
      case SessionStatus.paused:
        statusColor = Colors.orange;
        statusText = 'SESSION PAUSED';
        break;
      case SessionStatus.completed:
        statusColor = Colors.green;
        statusText = 'CHARGE COMPLETED';
        break;
      case SessionStatus.stopped:
        statusColor = Colors.red;
        statusText = 'SESSION STOPPED';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'PREPARING';
    }

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 12, color: statusColor),
          const SizedBox(width: 8),
          Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _buildMainMetrics(ChargingSessionModel session) {
    return Row(
      children: [
        Expanded(child: _buildMetricCard('Speed', '${session.currentKw.toStringAsFixed(1)} kW', Icons.speed, AppColors.primaryCyan)),
        const SizedBox(width: 16),
        Expanded(child: _buildMetricCard('Battery', '${session.batteryPercentage.toStringAsFixed(1)}%', Icons.battery_charging_full, Colors.green)),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSecondaryMetrics(ChargingSessionModel session, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildRow('Units Consumed', '${session.unitsConsumed.toStringAsFixed(3)} kWh', isDark),
          const Divider(),
          _buildRow('Current Cost', '₹${session.currentCost.toStringAsFixed(2)}', isDark),
          const Divider(),
          _buildRow('Temperature', '${session.temperature.toStringAsFixed(1)} °C', isDark),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildLiveGraph(ChargingSessionModel session) {
    if (session.powerGraph.isEmpty) {
      return const SizedBox();
    }

    List<FlSpot> spots = session.powerGraph.map((p) => FlSpot(p.timestampOffsetSeconds.toDouble(), p.kwValue)).toList();

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Charging Curve (kW)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 0,
                minY: 0,
                maxY: 60, // Max 60kW for graph ceiling
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (v, meta) => Text('${v.toInt()}s', style: const TextStyle(fontSize: 10)))),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10)))),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.withOpacity(0.2))),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primaryCyan,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primaryCyan.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(ChargingSessionProvider provider, ChargingSessionModel session) {
    final bool canPause = session.status == SessionStatus.charging;
    final bool canResume = session.status == SessionStatus.paused;
    final bool canStop = session.status == SessionStatus.charging || session.status == SessionStatus.paused;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (canPause)
          FloatingActionButton.extended(
            heroTag: 'btn_pause',
            onPressed: provider.pauseSession,
            backgroundColor: Colors.orange,
            icon: const Icon(Icons.pause, color: Colors.white),
            label: const Text('Pause', style: TextStyle(color: Colors.white)),
          ),
        if (canResume)
          FloatingActionButton.extended(
            heroTag: 'btn_resume',
            onPressed: provider.resumeSession,
            backgroundColor: AppColors.primaryCyan,
            icon: const Icon(Icons.play_arrow, color: Colors.black),
            label: const Text('Resume', style: TextStyle(color: Colors.black)),
          ),
        if (canStop)
          FloatingActionButton.extended(
            heroTag: 'btn_stop',
            onPressed: provider.stopSession,
            backgroundColor: Colors.red,
            icon: const Icon(Icons.stop, color: Colors.white),
            label: const Text('Stop', style: TextStyle(color: Colors.white)),
          ),
      ],
    );
  }
}
