import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../models/wallet_transaction_model.dart';
import '../../providers/wallet_provider.dart';
import '../wallet/add_money_screen.dart';
import '../wallet/wallet_settings_screen.dart';
import '../wallet/wallet_transaction_details_screen.dart';
import '../wallet/wallet_transaction_history_screen.dart';

class Wallet2Screen extends StatelessWidget {
  const Wallet2Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalletProvider>();
    final balance = provider.balance;
    final wallet = provider.wallet;
    final txList = provider.transactions;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'CHARGEONE WALLET',
          style: GoogleFonts.outfit(
            letterSpacing: 1.5,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalletSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SIMULATION MODE WARNING BANNER
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warning.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.warning, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Demo Wallet — Payments & top-ups are simulated.',
                          style: GoogleFonts.outfit(
                            color: AppColors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // HERO BALANCE CARD
                  _buildBalanceCard(context, provider, balance, wallet?.autoTopUpEnabled ?? false),
                  const SizedBox(height: 24),

                  // QUICK ACTIONS BAR
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionTile(
                          context,
                          title: 'Add Money',
                          subtitle: 'Top up wallet',
                          icon: Icons.add_circle_outline,
                          color: AppColors.primary,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AddMoneyScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionTile(
                          context,
                          title: 'Auto Top-Up',
                          subtitle: wallet?.autoTopUpEnabled == true ? 'ON' : 'OFF',
                          icon: Icons.autorenew,
                          color: AppColors.secondary,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const WalletSettingsScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // RECENT TRANSACTIONS HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RECENT TRANSACTIONS',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: Colors.white70,
                        ),
                      ),
                      if (txList.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const WalletTransactionHistoryScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'View All',
                            style: GoogleFonts.outfit(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // TRANSACTIONS LIST
                  _buildTransactionSection(context, txList),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, WalletProvider provider, double balance, bool autoTopUp) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppColors.walletGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.neonShadow(color: AppColors.accent, blurRadius: 20),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ChargeOne Universal Pay',
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: autoTopUp
                            ? AppColors.secondary.withOpacity(0.25)
                            : Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: autoTopUp ? AppColors.secondary : Colors.white24,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        autoTopUp ? 'AUTO TOP-UP ON' : 'SIMULATION READY',
                        style: GoogleFonts.outfit(
                          color: autoTopUp ? AppColors.secondary : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Available Balance',
                  style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${balance.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddMoneyScreen()),
                      );
                    },
                    icon: const Icon(Icons.add, color: Colors.black, size: 20),
                    label: Text(
                      '+ ADD MONEY',
                      style: GoogleFonts.outfit(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionSection(BuildContext context, List<WalletTransactionModel> txList) {
    if (txList.isEmpty) {
      return GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.history, color: Colors.white38, size: 36),
              const SizedBox(height: 8),
              Text(
                'No transactions recorded yet.',
                style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final recent = txList.take(5).toList();

    return Column(
      children: recent.map((tx) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WalletTransactionDetailsScreen(transaction: tx),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 16,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (tx.isCredit ? AppColors.secondary : AppColors.primary).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      tx.isCredit ? Icons.add_circle_outline : Icons.ev_station,
                      color: tx.isCredit ? AppColors.secondary : AppColors.primary,
                      size: 20,
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
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${tx.createdAt.day}/${tx.createdAt.month}/${tx.createdAt.year}',
                          style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    tx.formattedAmount,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: tx.isCredit ? AppColors.secondary : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
