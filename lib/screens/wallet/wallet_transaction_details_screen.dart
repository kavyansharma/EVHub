import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../models/wallet_transaction_model.dart';

class WalletTransactionDetailsScreen extends StatelessWidget {
  final WalletTransactionModel transaction;

  const WalletTransactionDetailsScreen({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.isCredit;

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
          'Transaction Details',
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
            // STATUS & AMOUNT HERO CARD
            GlassContainer(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: (isCredit ? AppColors.secondary : AppColors.primary).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCredit ? Icons.add_circle_outline : Icons.ev_station,
                      color: isCredit ? AppColors.secondary : AppColors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    transaction.formattedAmount,
                    style: GoogleFonts.outfit(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: isCredit ? AppColors.secondary : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    transaction.typeDisplayName,
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStatusBadge(transaction.status),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // LEDGER METADATA CARD
            GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildDetailRow('Description', transaction.description),
                  const Divider(color: Colors.white10, height: 24),
                  _buildDetailRow('Reference ID', transaction.referenceId),
                  const Divider(color: Colors.white10, height: 24),
                  _buildDetailRow(
                    'Date & Time',
                    '${transaction.createdAt.day}/${transaction.createdAt.month}/${transaction.createdAt.year} ${transaction.createdAt.hour.toString().padLeft(2, '0')}:${transaction.createdAt.minute.toString().padLeft(2, '0')}',
                  ),
                  if (transaction.networkName != null) ...[
                    const Divider(color: Colors.white10, height: 24),
                    _buildDetailRow('Charging Network', transaction.networkName!),
                  ],
                  if (transaction.chargerName != null) ...[
                    const Divider(color: Colors.white10, height: 24),
                    _buildDetailRow('Charging Station', transaction.chargerName!),
                  ],
                  if (transaction.chargerId != null) ...[
                    const Divider(color: Colors.white10, height: 24),
                    _buildDetailRow('Charger ID', transaction.chargerId!),
                  ],
                  if (transaction.chargingSessionId != null) ...[
                    const Divider(color: Colors.white10, height: 24),
                    _buildDetailRow('Session ID', transaction.chargingSessionId!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // MOCK DISCLAIMER
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Colors.white60, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Universal Wallet Foundation — Mock Ledger Transaction.',
                      style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(WalletTransactionStatus status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case WalletTransactionStatus.success:
        bg = Colors.green.withOpacity(0.2);
        fg = Colors.greenAccent;
        label = 'SUCCESS';
        break;
      case WalletTransactionStatus.pending:
        bg = Colors.amber.withOpacity(0.2);
        fg = Colors.amberAccent;
        label = 'PENDING';
        break;
      case WalletTransactionStatus.failed:
        bg = Colors.red.withOpacity(0.2);
        fg = Colors.redAccent;
        label = 'FAILED';
        break;
      case WalletTransactionStatus.reversed:
        bg = Colors.orange.withOpacity(0.2);
        fg = Colors.orangeAccent;
        label = 'CANCELLED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(color: Colors.white60, fontSize: 14),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
