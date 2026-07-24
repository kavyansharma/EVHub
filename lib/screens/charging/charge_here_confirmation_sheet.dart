import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/premium_button.dart';
import '../../core/utils/smart_charging_calculator.dart';
import '../../models/map_marker_model.dart';
import '../../models/vehicle_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/charging_session_provider.dart';
import '../../providers/garage_provider.dart';
import '../../providers/wallet_provider.dart';

class ChargeHereConfirmationSheet extends StatefulWidget {
  final MapMarkerModel charger;

  const ChargeHereConfirmationSheet({super.key, required this.charger});

  @override
  State<ChargeHereConfirmationSheet> createState() => _ChargeHereConfirmationSheetState();
}

class _ChargeHereConfirmationSheetState extends State<ChargeHereConfirmationSheet> {
  double _currentBatteryPct = 25.0;
  double _targetBatteryPct = 80.0;
  late String _selectedConnector;

  @override
  void initState() {
    super.initState();
    _selectedConnector = widget.charger.connectors.isNotEmpty
        ? widget.charger.connectors.first
        : 'CCS2';
  }

  @override
  Widget build(BuildContext context) {
    final garageProvider = context.watch<GarageProvider>();
    final walletProvider = context.watch<WalletProvider>();
    final authProvider = context.watch<AuthProvider>();
    final sessionProvider = context.watch<ChargingSessionProvider>();

    final VehicleModel? vehicle = garageProvider.selectedVehicle ??
        (garageProvider.vehicles.isNotEmpty ? garageProvider.vehicles.first : null);

    // Calculate smart charging estimates
    final double chargerPowerKw = double.tryParse(
      widget.charger.power.replaceAll(RegExp(r'[^0-9.]'), ''),
    ) ?? 60.0;
    final double pricePerKwh = SmartChargingCalculator.parsePrice(widget.charger.price);

    final calcResult = SmartChargingCalculator.calculate(
      currentBatteryPct: _currentBatteryPct,
      targetBatteryPct: _targetBatteryPct,
      chargerPowerKw: chargerPowerKw,
      vehicleMaxPowerKw: vehicle?.maxDcChargingSpeed ?? 120.0,
      batteryCapacityKwh: vehicle?.batteryCapacity ?? 50.0,
      pricePerKwh: pricePerKwh,
      powerType: widget.charger.powerType,
    );

    final double walletBalance = walletProvider.balance;
    final double estimatedCost = calcResult.estimatedCost;
    final bool isInsufficient = walletBalance < estimatedCost;
    final double remainingBalance = walletBalance - estimatedCost;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header Title & Demo Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CONFIRM CHARGING SESSION',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.science_outlined, color: AppColors.primary, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Simulation / Demo Session',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Charger Info Summary Card
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const HugeIcon(
                      icon: HugeIcons.strokeRoundedZap,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.charger.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.charger.network} • ${widget.charger.power} • ${widget.charger.price}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Vehicle Selection Integration
            const Text(
              'SELECTED EV PROFILE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            if (vehicle == null) ...[
              GlassContainer(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Complete your vehicle profile for accurate charging estimates.',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // Navigate to Garage / Profile
                      },
                      child: const Text('Update Vehicle', style: TextStyle(color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              GlassContainer(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.directions_car, color: AppColors.secondary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${vehicle.manufacturer} ${vehicle.model} (${vehicle.batteryCapacity.toInt()} kWh)',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Battery Range Sliders
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Battery: ${_currentBatteryPct.toInt()}% ➔ ${_targetBatteryPct.toInt()}%',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  '+${calcResult.estimatedRangeAddedKm.toInt()} km range',
                  style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _currentBatteryPct,
                    min: 5.0,
                    max: 90.0,
                    divisions: 17,
                    activeColor: AppColors.primary,
                    inactiveColor: Colors.white10,
                    onChanged: (val) {
                      setState(() {
                        _currentBatteryPct = val;
                        if (_targetBatteryPct <= _currentBatteryPct) {
                          _targetBatteryPct = math.min(100.0, _currentBatteryPct + 10.0);
                        }
                      });
                    },
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _targetBatteryPct,
                    min: _currentBatteryPct + 5.0,
                    max: 100.0,
                    divisions: 19,
                    activeColor: AppColors.secondary,
                    inactiveColor: Colors.white10,
                    onChanged: (val) {
                      setState(() {
                        _targetBatteryPct = val;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Smart Charging Breakdown Metrics
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildEstimateItem('Energy Needed', '${calcResult.grossEnergyFromGridKwh.toStringAsFixed(1)} kWh'),
                  Container(width: 1, height: 32, color: Colors.white10),
                  _buildEstimateItem('Estimated Time', calcResult.formattedTime),
                  Container(width: 1, height: 32, color: Colors.white10),
                  _buildEstimateItem('Est. Cost', '₹${calcResult.estimatedCost.toInt()}'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Wallet Balance Validation Section
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.account_balance_wallet_outlined, color: Colors.white70, size: 18),
                          SizedBox(width: 8),
                          Text('Universal Wallet Balance', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                      Text(
                        '₹${walletBalance.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isInsufficient ? 'Insufficient Balance' : 'Remaining After Session',
                        style: TextStyle(
                          color: isInsufficient ? AppColors.danger : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: isInsufficient ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      Text(
                        isInsufficient ? 'Short by ₹${(estimatedCost - walletBalance).toInt()}' : '₹${remainingBalance.toInt()}',
                        style: TextStyle(
                          color: isInsufficient ? AppColors.danger : AppColors.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Button
            if (isInsufficient) ...[
              PremiumButton(
                text: 'Add Money to Wallet',
                icon: Icons.add_circle_outline,
                onPressed: () {
                  // Trigger wallet top-up dialog
                  walletProvider.topUp(authProvider.user?.id ?? 'default_user', 500.0);
                },
              ),
            ] else ...[
              PremiumButton(
                text: 'Confirm & Start Charging',
                icon: Icons.flash_on,
                isLoading: sessionProvider.isLoading,
                onPressed: () async {
                  final userId = authProvider.user?.id ?? 'default_user';
                  await sessionProvider.startSession(
                    userId,
                    widget.charger.id,
                    _selectedConnector,
                  );
                  if (context.mounted) {
                    Navigator.pop(context); // Close sheet
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEstimateItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
