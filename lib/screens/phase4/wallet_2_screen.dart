import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../models/wallet_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';

class Wallet2Screen extends StatelessWidget {
  const Wallet2Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalletProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Universal Wallet 2.0')),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBalanceCard(provider.wallet, isDark),
                  const SizedBox(height: 24),
                  _buildWalletTypeCard(provider.wallet, isDark),
                  const SizedBox(height: 24),
                  const Text('Recent Invoices', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildInvoiceList(),
                ],
              ),
            ),
    );
  }

  Widget _buildBalanceCard(WalletModel? wallet, bool isDark) {
    final balance = wallet?.balance ?? 0.0;
    
    return GlassContainer(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Text('Available Balance', style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 12),
          Text(
            '₹${balance.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.primaryCyan),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(Icons.add, 'Top Up', AppColors.primaryCyan, Colors.black),
              _buildActionButton(Icons.send, 'Transfer', AppColors.primaryPurple, Colors.white),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color bgColor, Color textColor) {
    return ElevatedButton.icon(
      onPressed: () {},
      icon: Icon(icon, color: textColor),
      label: Text(label, style: TextStyle(color: textColor)),
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  Widget _buildWalletTypeCard(WalletModel? wallet, bool isDark) {
    if (wallet == null) return const SizedBox();

    IconData icon;
    String title;
    String subtitle;
    
    switch (wallet.walletType) {
      case WalletType.corporate:
        icon = Icons.business;
        title = 'Corporate Fleet Wallet';
        subtitle = 'Managed by ${wallet.corporateId ?? "Company"} • GST: ${wallet.gstNumber ?? "N/A"}';
        break;
      case WalletType.family:
        icon = Icons.family_restroom;
        title = 'Family Shared Wallet';
        subtitle = 'Shared across 3 vehicles';
        break;
      case WalletType.personal:
        icon = Icons.person;
        title = 'Personal Wallet';
        subtitle = wallet.autoTopUpEnabled ? 'Auto Top-Up Enabled' : 'Auto Top-Up Disabled';
        break;
    }

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, size: 40, color: AppColors.primaryPurple),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInvoiceList() {
    // Simulated invoice list
    return Column(
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invoice #INV-2026${index}9$index', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Text('Tata Power EZ Charge', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                const Text('-₹450', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                const SizedBox(width: 16),
                const Icon(Icons.download, color: AppColors.primaryCyan),
              ],
            ),
          ),
        );
      }),
    );
  }
}
