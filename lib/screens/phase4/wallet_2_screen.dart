import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';

class Wallet2Screen extends StatelessWidget {
  const Wallet2Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalletProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('WALLET & PAYMENTS', style: TextStyle(letterSpacing: 2.0, fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.help_outline), onPressed: () {}),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.accent.withOpacity(0.08),
              AppColors.background,
            ],
            stops: const [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPremiumBalanceCard(provider, theme, context),
                      const SizedBox(height: 32),
                      
                      const Text(
                        'ADD MONEY INSTANTLY',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      _buildPaymentMethodsGrid(),
                      
                      const SizedBox(height: 32),
                      const Text(
                        'REWARDS & OFFERS',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      _buildRewardsList(),
                      
                      const SizedBox(height: 32),
                      const Text(
                        'TRANSACTION HISTORY',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      _buildTransactionList(),
                      
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildPremiumBalanceCard(WalletProvider provider, ThemeData theme, BuildContext context) {
    final balance = provider.wallet?.balance ?? 0.0;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppColors.walletGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.neonShadow(color: AppColors.accent, blurRadius: 25),
      ),
      child: Stack(
        children: [
          // Background accent bubbles
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
            padding: const EdgeInsets.all(28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'EVHub Universal Pay',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: const Text('ACTIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                    )
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Available Balance', style: TextStyle(color: Colors.white60, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  '₹${balance.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -1),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          final auth = context.read<AuthProvider>();
                          provider.topUp(auth.user?.id ?? 'default_user', 500.0);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Added ₹500.00 successfully!'), backgroundColor: AppColors.secondary),
                          );
                        },
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Text(
                              'Top Up +₹500',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Scanning charger QR code...')),
                          );
                        },
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code_scanner, color: Colors.white, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'Scan QR',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
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

  Widget _buildPaymentMethodsGrid() {
    final methods = [
      {'icon': HugeIcons.strokeRoundedPayment01, 'name': 'UPI'},
      {'icon': HugeIcons.strokeRoundedGoogle, 'name': 'GPay'},
      {'icon': HugeIcons.strokeRoundedSmartPhone02, 'name': 'PhonePe'},
      {'icon': HugeIcons.strokeRoundedCreditCard, 'name': 'Cards'},
      {'icon': HugeIcons.strokeRoundedBitcoinWallet, 'name': 'Paytm'},
      {'icon': HugeIcons.strokeRoundedBank, 'name': 'Net Banking'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemCount: methods.length,
      itemBuilder: (context, index) {
        return GlassContainer(
          padding: const EdgeInsets.all(8),
          borderRadius: 18,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: methods[index]['icon'] as List<List<dynamic>>,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                methods[index]['name'] as String,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRewardsList() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildRewardCard('Cashback', 'Earn up to ₹500 on next charge', HugeIcons.strokeRoundedDiscount, AppColors.secondary),
          _buildRewardCard('Referral', 'Invite friends, get ₹100 bonus', HugeIcons.strokeRoundedGroup, AppColors.primary),
          _buildRewardCard('Coupons', '3 Active SuperSaver coupons', HugeIcons.strokeRoundedTicket02, AppColors.warning),
        ],
      ),
    );
  }

  Widget _buildRewardCard(String title, String subtitle, List<List<dynamic>> icon, Color color) {
    return Container(
      width: 230,
      margin: const EdgeInsets.only(right: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.25), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: HugeIcon(icon: icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return Column(
      children: List.generate(4, (index) {
        final isCredit = index % 2 == 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 18,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isCredit ? AppColors.secondary : AppColors.danger).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: HugeIcon(
                    icon: isCredit ? HugeIcons.strokeRoundedAddCircle : HugeIcons.strokeRoundedFuelStation,
                    color: isCredit ? AppColors.secondary : AppColors.danger,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCredit ? 'Money Added (UPI Topup)' : 'Charging Session CP-04',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      const Text('Today, 2:30 PM', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                Text(
                  '${isCredit ? "+" : "-"}₹${isCredit ? 500 : 340}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isCredit ? AppColors.secondary : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

