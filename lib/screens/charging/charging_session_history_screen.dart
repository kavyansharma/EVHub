import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../providers/charging_session_provider.dart';
import 'charging_session_details_screen.dart';

class ChargingSessionHistoryScreen extends StatelessWidget {
  const ChargingSessionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<ChargingSessionProvider>();
    final historyList = sessionProvider.sessionHistory;

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
          'CHARGING SESSION HISTORY',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: historyList.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, color: Colors.white38, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'No Past Sessions Found',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Completed EV charging sessions will appear here.',
                    style: GoogleFonts.outfit(color: Colors.white60, fontSize: 14),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20.0),
              itemCount: historyList.length,
              itemBuilder: (context, index) {
                final session = historyList[index];
                final finalCost = session.finalCost > 0 ? session.finalCost : session.estimatedCost;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChargingSessionDetailsScreen(session: session),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: GlassContainer(
                      padding: const EdgeInsets.all(16),
                      borderRadius: 18,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.ev_station, color: AppColors.secondary, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session.chargerName,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      session.networkName,
                                      style: GoogleFonts.outfit(color: AppColors.primary, fontSize: 12),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${session.startTime.day}/${session.startTime.month}/${session.startTime.year}',
                                      style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${finalCost.toStringAsFixed(0)}',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${session.energyDeliveredKwh.toStringAsFixed(1)} kWh',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
