import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../providers/wallet_provider.dart';
import '../../services/payment_gateway_abstraction.dart';

class AddMoneyScreen extends StatefulWidget {
  final double? prefilledAmount;

  const AddMoneyScreen({
    super.key,
    this.prefilledAmount,
  });

  @override
  State<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends State<AddMoneyScreen> {
  final TextEditingController _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final List<double> _quickAmounts = [100.0, 200.0, 500.0, 1000.0, 2000.0];
  double? _selectedQuickAmount;
  MockPaymentOutcome _simulatedOutcome = MockPaymentOutcome.success;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledAmount != null && widget.prefilledAmount! > 0) {
      _amountController.text = widget.prefilledAmount!.toStringAsFixed(0);
      if (_quickAmounts.contains(widget.prefilledAmount)) {
        _selectedQuickAmount = widget.prefilledAmount;
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onQuickAmountSelected(double amount) {
    setState(() {
      _selectedQuickAmount = amount;
      _amountController.text = amount.toStringAsFixed(0);
      _validationError = null;
    });
  }

  void _validateAndSubmit() async {
    final text = _amountController.text.trim();
    final amount = double.tryParse(text);

    if (amount == null || amount <= 0 || amount.isNaN) {
      setState(() {
        _validationError = 'Please enter a valid numeric amount.';
      });
      return;
    }

    if (amount < 10.0) {
      setState(() {
        _validationError = 'Minimum top-up amount is ₹10.';
      });
      return;
    }

    if (amount > 10000.0) {
      setState(() {
        _validationError = 'Maximum top-up amount per transaction is ₹10,000.';
      });
      return;
    }

    setState(() {
      _validationError = null;
    });

    final walletProvider = context.read<WalletProvider>();
    final success = await walletProvider.addMoney(
      amount: amount,
      paymentMethod: 'Mock Payment Gateway',
      simulatedOutcome: _simulatedOutcome,
    );

    if (!mounted) return;

    if (success) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.secondary, size: 28),
              const SizedBox(width: 10),
              Text(
                'Payment Successful',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '₹${amount.toStringAsFixed(0)} added to your ChargeOne Wallet!',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                'New Balance: ₹${walletProvider.balance.toStringAsFixed(2)}',
                style: GoogleFonts.outfit(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Simulation Mode — No real money charged.',
                  style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Return to previous screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('DONE', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            walletProvider.errorMessage ?? 'Payment failed or was cancelled.',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();

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
          'ADD MONEY TO WALLET',
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // DEMO SIMULATION BADGE
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Demo Payment Mode — Simulation Mode. No real money will be charged.',
                        style: GoogleFonts.outfit(
                          color: AppColors.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // AMOUNT INPUT CARD
              GlassContainer(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ENTER AMOUNT',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _validationError = null;
                          final parsed = double.tryParse(val);
                          _selectedQuickAmount = _quickAmounts.contains(parsed) ? parsed : null;
                        });
                      },
                      decoration: InputDecoration(
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 12, right: 8, top: 8),
                          child: Text(
                            '₹',
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        hintText: '0',
                        hintStyle: GoogleFonts.outfit(color: Colors.white24, fontSize: 32),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.04),
                      ),
                    ),
                    if (_validationError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _validationError!,
                        style: GoogleFonts.outfit(color: AppColors.danger, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // QUICK AMOUNT CHIPS
                    Text(
                      'QUICK SELECT',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _quickAmounts.map((amt) {
                        final isSelected = _selectedQuickAmount == amt;
                        return ChoiceChip(
                          label: Text(
                            '+₹${amt.toStringAsFixed(0)}',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.black : Colors.white,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: Colors.white.withOpacity(0.08),
                          onSelected: (sel) {
                            if (sel) _onQuickAmountSelected(amt);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // SIMULATION TESTING CONTROLS
              GlassContainer(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SIMULATED PAYMENT OUTCOME',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildOutcomeOption('Success', MockPaymentOutcome.success, Colors.greenAccent),
                        const SizedBox(width: 8),
                        _buildOutcomeOption('Failure', MockPaymentOutcome.failure, Colors.redAccent),
                        const SizedBox(width: 8),
                        _buildOutcomeOption('Cancel', MockPaymentOutcome.cancelled, Colors.orangeAccent),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // SUBMIT BUTTON
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: walletProvider.isProcessingPayment ? null : _validateAndSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: walletProvider.isProcessingPayment
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                        )
                      : Text(
                          'PROCESS MOCK PAYMENT',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutcomeOption(String title, MockPaymentOutcome outcome, Color color) {
    final isSelected = _simulatedOutcome == outcome;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _simulatedOutcome = outcome;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.white10,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: GoogleFonts.outfit(
                color: isSelected ? color : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
