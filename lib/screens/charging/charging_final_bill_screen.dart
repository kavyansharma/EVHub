import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../models/charging_session_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/charging_session_provider.dart';
import '../../providers/wallet_provider.dart';
import '../wallet/add_money_screen.dart';
import '../wallet/wallet_transaction_details_screen.dart';

class ChargingFinalBillScreen extends StatelessWidget {
  const ChargingFinalBillScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<ChargingSessionProvider>();
    final walletProvider = context.watch<WalletProvider>();
    final authProvider = context.watch<AuthProvider>();
    final session = sessionProvider.activeSession;

    if (session == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text('CHARGING RECEIPT', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold))),
        body: Center(
          child: Text('No session bill available.', style: GoogleFonts.outfit(color: Colors.white60)),
        ),
      );
    }

    final finalCost = session.finalCost > 0 ? session.finalCost : session.estimatedCost;
    final walletBalance = walletProvider.balance;
    final isInsufficient = walletBalance < finalCost;
    final isPaid = session.status == ChargingSessionStatus.completed;
    final isFailed = session.status == ChargingSessionStatus.paymentFailed || sessionProvider.paymentError != null;

    final durationMins = session.endTime != null
        ? max(1, session.endTime!.difference(session.startTime).inMinutes)
        : 15;

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
          'CHARGING SESSION BILL',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // RECEIPT CARD
            GlassContainer(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CHARGEONE', style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.5)),
                          Text('EV Charging Receipt', style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isPaid ? AppColors.secondary : (isFailed ? AppColors.danger : Colors.amber)).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isPaid ? AppColors.secondary : (isFailed ? AppColors.danger : Colors.amber),
                          ),
                        ),
                        child: Text(
                          isPaid ? 'PAID' : (isFailed ? 'PAYMENT FAILED' : 'PAYMENT PENDING'),
                          style: GoogleFonts.outfit(
                            color: isPaid ? AppColors.secondary : (isFailed ? AppColors.danger : Colors.amber),
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 28),

                  // TOTAL COST HERO
                  Text('Final Amount Due', style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(
                    '₹${finalCost.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // SESSION METADATA
                  _buildReceiptRow('Charger Station', session.chargerName),
                  _buildReceiptRow('Charging Network', session.networkName),
                  _buildReceiptRow('Vehicle Profile', session.vehicleName),
                  _buildReceiptRow('Connector & Power', '${session.connectorType} (${session.chargerPowerKw.toInt()} kW)'),
                  _buildReceiptRow('Session ID', session.sessionId),
                  _buildReceiptRow('Duration', '$durationMins mins'),
                  const Divider(color: Colors.white10, height: 24),

                  // ENERGY BREAKDOWN
                  _buildReceiptRow('Initial SOC ➔ Final SOC', '${session.initialSocPercent.toInt()}% ➔ ${session.currentSocPercent.toInt()}%'),
                  _buildReceiptRow('Battery Energy Added', '${session.energyDeliveredKwh.toStringAsFixed(1)} kWh'),
                  _buildReceiptRow('Efficiency Loss (10%)', '${session.chargingLossKwh.toStringAsFixed(1)} kWh'),
                  _buildReceiptRow('Grid Energy Drawn', '${session.gridEnergyDrawnKwh.toStringAsFixed(1)} kWh'),
                  _buildReceiptRow('Tariff Rate', '₹${session.pricePerKwh.toStringAsFixed(1)} / kWh'),
                  const Divider(color: Colors.white10, height: 24),

                  // WALLET PAYMENT STATUS
                  _buildReceiptRow('Wallet Balance', '₹${walletBalance.toStringAsFixed(2)}'),
                  _buildReceiptRow(
                    isPaid ? 'Wallet Balance After' : 'Est. Balance After Payment',
                    '₹${(walletBalance - finalCost).toStringAsFixed(2)}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ERROR WARNING BANNER
            if (isFailed || isInsufficient) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_outlined, color: AppColors.danger, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        sessionProvider.paymentError ??
                            'Insufficient wallet balance (Short by ₹${(finalCost - walletBalance).toStringAsFixed(0)}). Add money to complete payment.',
                        style: GoogleFonts.outfit(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // BUTTON ACTIONS
            if (isPaid) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final tx = walletProvider.transactions.isNotEmpty
                        ? walletProvider.transactions.first
                        : null;
                    if (tx != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WalletTransactionDetailsScreen(transaction: tx),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.receipt, color: Colors.black, size: 20),
                  label: Text('VIEW WALLET TRANSACTION', style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () async {
                    await sessionProvider.clearCompletedSession();
                    if (context.mounted) {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('DONE', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ] else ...[
              if (isInsufficient) ...[
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddMoneyScreen(prefilledAmount: finalCost - walletBalance),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_circle_outline, color: Colors.black, size: 20),
                    label: Text('ADD MONEY TO WALLET', style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: sessionProvider.isProcessingPayment
                      ? null
                      : () async {
                          final userId = authProvider.user?.id ?? 'local_user';
                          final success = await sessionProvider.processSessionPayment(
                            walletProvider: walletProvider,
                            userId: userId,
                          );

                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Payment of ₹${finalCost.toStringAsFixed(0)} confirmed successfully!', style: GoogleFonts.outfit(color: Colors.white)),
                                backgroundColor: AppColors.secondary,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isInsufficient ? Colors.white.withOpacity(0.12) : AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: sessionProvider.isProcessingPayment
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                      : Text(
                          isInsufficient ? 'TRY AGAIN WITH WALLET' : 'CONFIRM WALLET PAYMENT',
                          style: GoogleFonts.outfit(
                            color: isInsufficient ? Colors.white70 : Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13)),
          Text(value, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
