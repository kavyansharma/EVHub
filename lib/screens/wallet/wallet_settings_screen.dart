import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../providers/wallet_provider.dart';

class WalletSettingsScreen extends StatefulWidget {
  const WalletSettingsScreen({super.key});

  @override
  State<WalletSettingsScreen> createState() => _WalletSettingsScreenState();
}

class _WalletSettingsScreenState extends State<WalletSettingsScreen> {
  late bool _autoTopUpEnabled;
  late double _threshold;
  late double _amount;

  final List<double> _thresholdOptions = [100.0, 200.0, 500.0, 1000.0];
  final List<double> _amountOptions = [200.0, 500.0, 1000.0, 2000.0];

  @override
  void initState() {
    super.initState();
    final provider = context.read<WalletProvider>();
    final wallet = provider.wallet;
    _autoTopUpEnabled = wallet?.autoTopUpEnabled ?? false;
    _threshold = wallet?.autoTopUpThreshold ?? 200.0;
    _amount = wallet?.autoTopUpAmount ?? 500.0;
  }

  void _saveSettings() async {
    final provider = context.read<WalletProvider>();
    await provider.updateAutoTopUpSettings(
      enabled: _autoTopUpEnabled,
      threshold: _threshold,
      amount: _amount,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Wallet settings updated successfully!',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        backgroundColor: AppColors.secondary,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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
          'WALLET SETTINGS',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AUTO TOP-UP CARD
            GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.autorenew, color: AppColors.secondary, size: 24),
                          const SizedBox(width: 10),
                          Text(
                            'Auto Top-Up',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _autoTopUpEnabled,
                        activeColor: AppColors.secondary,
                        onChanged: (val) {
                          setState(() {
                            _autoTopUpEnabled = val;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Automatically add funds when balance drops below threshold.',
                    style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  if (_autoTopUpEnabled) ...[
                    const Divider(color: Colors.white10, height: 24),
                    Text(
                      'TRIGGER THRESHOLD',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _thresholdOptions.map((opt) {
                        final isSel = _threshold == opt;
                        return ChoiceChip(
                          label: Text('Below ₹${opt.toStringAsFixed(0)}'),
                          selected: isSel,
                          selectedColor: AppColors.secondary,
                          labelStyle: GoogleFonts.outfit(
                            color: isSel ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          backgroundColor: Colors.white.withOpacity(0.08),
                          onSelected: (sel) {
                            if (sel) setState(() => _threshold = opt);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'AUTOMATIC TOP-UP AMOUNT',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _amountOptions.map((opt) {
                        final isSel = _amount == opt;
                        return ChoiceChip(
                          label: Text('Add ₹${opt.toStringAsFixed(0)}'),
                          selected: isSel,
                          selectedColor: AppColors.primary,
                          labelStyle: GoogleFonts.outfit(
                            color: isSel ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          backgroundColor: Colors.white.withOpacity(0.08),
                          onSelected: (sel) {
                            if (sel) setState(() => _amount = opt);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // DISCLAIMER CARD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white60, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Auto Top-Up is currently simulated. No real payment will be charged.',
                      style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // SAVE BUTTON
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'SAVE SETTINGS',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
