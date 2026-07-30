import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../models/charging_session_model.dart';
import '../../providers/charging_session_provider.dart';
import '../../providers/wallet_provider.dart';
import 'charging_final_bill_screen.dart';

class ChargingSessionScreen extends StatelessWidget {
  const ChargingSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<ChargingSessionProvider>();
    final walletProvider = context.watch<WalletProvider>();
    final session = sessionProvider.activeSession;

    if (session == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text('CHARGING CONSOLE', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold))),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.flash_off, size: 64, color: Colors.white38),
              const SizedBox(height: 16),
              Text('No Active Session', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('RETURN TO MAP', style: GoogleFonts.outfit()),
              ),
            ],
          ),
        ),
      );
    }

    final walletBalance = walletProvider.balance;
    final estRemainingBalance = walletBalance - session.estimatedCost;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'LIVE CHARGING CONSOLE',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          children: [
            // CHARGER & STATUS BANNER
            GlassContainer(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: sessionProvider.isPaused
                          ? AppColors.warning.withOpacity(0.15)
                          : AppColors.secondary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      sessionProvider.isPaused ? Icons.pause : Icons.bolt,
                      color: sessionProvider.isPaused ? AppColors.warning : AppColors.secondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.chargerName,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${session.networkName} • ${session.connectorType} • ${session.chargerPowerKw.toInt()} kW',
                          style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: sessionProvider.isPaused
                          ? AppColors.warning.withOpacity(0.2)
                          : AppColors.secondary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sessionProvider.isPaused ? AppColors.warning : AppColors.secondary,
                      ),
                    ),
                    child: Text(
                      session.status.displayName.toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: sessionProvider.isPaused ? AppColors.warning : AppColors.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // CIRCULAR SOC PROGRESS GAUGE
            GlassContainer(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  SizedBox(
                    width: 170,
                    height: 170,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: (session.currentSocPercent / 100.0).clamp(0.0, 1.0),
                          strokeWidth: 14,
                          backgroundColor: Colors.white.withOpacity(0.06),
                          color: sessionProvider.isPaused ? AppColors.warning : AppColors.secondary,
                          strokeCap: StrokeCap.round,
                        ),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${session.currentSocPercent.toInt()}%',
                                style: GoogleFonts.outfit(
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Target: ${session.targetSocPercent.toInt()}%',
                                style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer_outlined, color: Colors.white60, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${session.estimatedFinishTimeMinutes} mins remaining',
                        style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // LIVE METRICS GRID
            Row(
              children: [
                Expanded(child: _buildMetricTile('POWER', '${session.activePowerKw.toStringAsFixed(1)} kW', AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(child: _buildMetricTile('ENERGY', '${session.energyDeliveredKwh.toStringAsFixed(1)} kWh', AppColors.secondary)),
                const SizedBox(width: 12),
                Expanded(child: _buildMetricTile('EST. COST', '₹${session.estimatedCost.toInt()}', Colors.white)),
              ],
            ),
            const SizedBox(height: 16),

            // LIVE POWER GRAPH
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LIVE POWER OUTPUT (kW)',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 100,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(show: false),
                        titlesData: FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        minY: 0,
                        maxY: max(80.0, session.chargerPowerKw * 1.1),
                        lineBarsData: [
                          LineChartBarData(
                            spots: session.powerGraph.isNotEmpty
                                ? session.powerGraph
                                    .map((p) => FlSpot(p.timestampOffsetSeconds.toDouble(), p.kwValue))
                                    .toList()
                                : [const FlSpot(0, 0)],
                            isCurved: true,
                            color: AppColors.primary,
                            barWidth: 3,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.primary.withOpacity(0.12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // WALLET ESTIMATE PREVIEW
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Universal Wallet Balance', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                      Text('₹${walletBalance.toStringAsFixed(2)}', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Est. Remaining After Session', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                      Text(
                        '₹${estRemainingBalance.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          color: estRemainingBalance < 0 ? AppColors.danger : AppColors.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ESTIMATED — NO MONEY DEDUCTED YET',
                    style: GoogleFonts.spaceGrotesk(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // SESSION CONTROL BUTTONS
            if (session.status == ChargingSessionStatus.completing ||
                session.status == ChargingSessionStatus.paymentPending ||
                session.status == ChargingSessionStatus.paymentFailed) ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChargingFinalBillScreen()),
                    );
                  },
                  icon: const Icon(Icons.receipt_long, color: Colors.black, size: 22),
                  label: Text(
                    'VIEW FINAL BILL',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (sessionProvider.isPaused) {
                          sessionProvider.resumeSession();
                        } else {
                          sessionProvider.pauseSession();
                        }
                      },
                      icon: Icon(
                        sessionProvider.isPaused ? Icons.play_arrow : Icons.pause,
                        color: sessionProvider.isPaused ? AppColors.warning : Colors.white,
                      ),
                      label: Text(
                        sessionProvider.isPaused ? 'RESUME' : 'PAUSE',
                        style: GoogleFonts.outfit(
                          color: sessionProvider.isPaused ? AppColors.warning : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        side: BorderSide(
                          color: sessionProvider.isPaused ? AppColors.warning : Colors.white24,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await sessionProvider.stopSession();
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ChargingFinalBillScreen()),
                          );
                        }
                      },
                      icon: const Icon(Icons.stop, color: Colors.white, size: 20),
                      label: Text(
                        'STOP CHARGE',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        backgroundColor: AppColors.danger,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, Color color) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      borderRadius: 16,
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
