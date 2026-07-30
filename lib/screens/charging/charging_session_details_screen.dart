import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../models/charging_session_model.dart';

class ChargingSessionDetailsScreen extends StatelessWidget {
  final ChargingSessionModel session;

  const ChargingSessionDetailsScreen({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final finalCost = session.finalCost > 0 ? session.finalCost : session.estimatedCost;

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
          'Session Details',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // HERO CARD
            GlassContainer(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.ev_station, color: AppColors.secondary, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '₹${finalCost.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${session.energyDeliveredKwh.toStringAsFixed(1)} kWh Delivered',
                    style: GoogleFonts.outfit(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
                    ),
                    child: Text(
                      session.status.name.toUpperCase(),
                      style: GoogleFonts.outfit(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // DETAILS LIST CARD
            GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildDetailRow('Charging Station', session.chargerName),
                  const Divider(color: Colors.white10, height: 24),
                  _buildDetailRow('Charging Network', session.networkName),
                  const Divider(color: Colors.white10, height: 24),
                  _buildDetailRow('Vehicle Profile', session.vehicleName),
                  const Divider(color: Colors.white10, height: 24),
                  _buildDetailRow('Connector & Speed', '${session.connectorType} (${session.chargerPowerKw.toInt()} kW)'),
                  const Divider(color: Colors.white10, height: 24),
                  _buildDetailRow('Session ID', session.sessionId),
                  const Divider(color: Colors.white10, height: 24),
                  _buildDetailRow(
                    'Start Time',
                    '${session.startTime.day}/${session.startTime.month}/${session.startTime.year} ${session.startTime.hour.toString().padLeft(2, '0')}:${session.startTime.minute.toString().padLeft(2, '0')}',
                  ),
                  if (session.endTime != null) ...[
                    const Divider(color: Colors.white10, height: 24),
                    _buildDetailRow(
                      'End Time',
                      '${session.endTime!.day}/${session.endTime!.month}/${session.endTime!.year} ${session.endTime!.hour.toString().padLeft(2, '0')}:${session.endTime!.minute.toString().padLeft(2, '0')}',
                    ),
                  ],
                  if (session.referenceId != null) ...[
                    const Divider(color: Colors.white10, height: 24),
                    _buildDetailRow('Payment Reference ID', session.referenceId!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
