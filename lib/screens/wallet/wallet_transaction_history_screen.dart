import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../models/wallet_transaction_model.dart';
import '../../providers/wallet_provider.dart';
import 'wallet_transaction_details_screen.dart';

class WalletTransactionHistoryScreen extends StatelessWidget {
  const WalletTransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final txList = walletProvider.transactions;

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
          'TRANSACTION HISTORY',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: txList.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long_outlined, color: Colors.white38, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'No Transactions Yet',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Top up your wallet to see transaction ledger activity.',
                    style: GoogleFonts.outfit(color: Colors.white60, fontSize: 14),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20.0),
              itemCount: txList.length,
              itemBuilder: (context, index) {
                final tx = txList[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WalletTransactionDetailsScreen(transaction: tx),
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
                              color: _getStatusColor(tx).withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getTxIcon(tx),
                              color: _getStatusColor(tx),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.description.isNotEmpty ? tx.description : tx.typeDisplayName,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (tx.networkName != null) ...[
                                      Text(
                                        tx.networkName!,
                                        style: GoogleFonts.outfit(color: AppColors.primary, fontSize: 12),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Text(
                                      '${tx.createdAt.day}/${tx.createdAt.month}/${tx.createdAt.year}',
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
                                tx.formattedAmount,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: tx.isCredit ? AppColors.secondary : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tx.status.name.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(tx),
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

  Color _getStatusColor(WalletTransactionModel tx) {
    if (tx.status == WalletTransactionStatus.failed) return AppColors.danger;
    if (tx.status == WalletTransactionStatus.reversed) return Colors.orangeAccent;
    if (tx.isCredit) return AppColors.secondary;
    return AppColors.primary;
  }

  IconData _getTxIcon(WalletTransactionModel tx) {
    if (tx.type == WalletTransactionType.topUp) return Icons.add_circle_outline;
    if (tx.type == WalletTransactionType.refund) return Icons.replay;
    if (tx.type == WalletTransactionType.cashback) return Icons.card_giftcard;
    return Icons.ev_station;
  }
}
