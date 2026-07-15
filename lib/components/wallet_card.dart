import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';

class WalletCard extends StatelessWidget {
  final double balance;
  final VoidCallback onAddFunds;
  final VoidCallback onHistory;

  const WalletCard({
    super.key,
    required this.balance,
    required this.onAddFunds,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.primaryPurple,
                  const Color(0xFF5D00E2),
                  AppColors.primaryCyan.withOpacity(0.8),
                ]
              : [
                  AppColors.primaryPurple,
                  const Color(0xFF7E00EA),
                  const Color(0xFFC06CFF),
                ],
        ),
        boxShadow: isDark
            ? AppColors.neonShadow(color: AppColors.primaryPurple, blurRadius: 20)
            : [
                BoxShadow(
                  color: AppColors.primaryPurple.withOpacity(0.25),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Stack(
        children: [
          // Background abstract shapes/circuits
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.electric_bolt_rounded,
              size: 150,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          Positioned(
            left: 20,
            top: 20,
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 24,
              color: Colors.white.withOpacity(0.15),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                // Label
                Text(
                  'UNIVERSAL EV WALLET',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                // Balance
                Text(
                  AppFormatters.formatCurrency(balance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                
                // Actions Row
                Row(
                  children: [
                    // Add Funds Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onAddFunds,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryPurple,
                          elevation: 0,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle_outline_rounded, size: 18),
                            SizedBox(width: 6),
                            Text('Add Funds'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // History Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onHistory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.18),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_rounded, size: 18),
                            SizedBox(width: 6),
                            Text('History'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
