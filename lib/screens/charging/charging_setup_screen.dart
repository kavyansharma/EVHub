import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/smart_charging_calculator.dart';
import '../../core/widgets/glass_container.dart';
import '../../models/map_marker_model.dart';
import '../../models/vehicle_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/charging_session_provider.dart';
import '../../providers/garage_provider.dart';
import '../../providers/wallet_provider.dart';
import 'charging_session_screen.dart';

class ChargingSetupScreen extends StatefulWidget {
  final MapMarkerModel charger;

  const ChargingSetupScreen({
    super.key,
    required this.charger,
  });

  @override
  State<ChargingSetupScreen> createState() => _ChargingSetupScreenState();
}

class _ChargingSetupScreenState extends State<ChargingSetupScreen> {
  double _currentSoc = 20.0;
  double _targetSoc = 80.0;
  late String _selectedConnector;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _selectedConnector = widget.charger.connectors.isNotEmpty
        ? widget.charger.connectors.first
        : 'CCS2';
  }

  void _showSimulationConfirmationModal(
    BuildContext context,
    VehicleModel vehicle,
    SmartChargingResult calcResult,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.flash_on, color: AppColors.primary, size: 28),
            const SizedBox(width: 10),
            Text(
              'Start Charging Session',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This is a simulated charging session.',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'No money will be deducted from your wallet until charging is completed and you confirm payment.',
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Target SOC: ${_targetSoc.toInt()}% • Est. Cost: ₹${calcResult.estimatedCost.toInt()}',
                      style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: GoogleFonts.outfit(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              await _startSession(vehicle, calcResult);
            },
            child: Text(
              'START CHARGING',
              style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startSession(VehicleModel vehicle, SmartChargingResult calcResult) async {
    final sessionProvider = context.read<ChargingSessionProvider>();
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id ?? 'local_user';

    final chargerPowerKw = double.tryParse(
      widget.charger.power.replaceAll(RegExp(r'[^0-9.]'), ''),
    ) ?? 60.0;
    final pricePerKwh = SmartChargingCalculator.parsePrice(widget.charger.price);

    final session = await sessionProvider.startSession(
      userId: userId,
      chargerId: widget.charger.id,
      chargerName: widget.charger.title,
      networkName: widget.charger.network,
      chargerAddress: widget.charger.address ?? 'India EV Charger Station',
      vehicleId: vehicle.id,
      vehicleName: '${vehicle.manufacturer} ${vehicle.model}',
      connectorType: _selectedConnector,
      chargerPowerKw: chargerPowerKw,
      vehicleMaxPowerKw: vehicle.maxDcChargingSpeed,
      initialSocPercent: _currentSoc,
      targetSocPercent: _targetSoc,
      batteryCapacityKwh: vehicle.batteryCapacity,
      pricePerKwh: pricePerKwh > 0 ? pricePerKwh : 18.0,
    );

    if (!mounted) return;

    if (session != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChargingSessionScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sessionProvider.errorMessage ?? 'Unable to start charging session.',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final garageProvider = context.watch<GarageProvider>();
    final walletProvider = context.watch<WalletProvider>();
    final sessionProvider = context.watch<ChargingSessionProvider>();

    final vehicle = garageProvider.selectedVehicle ??
        (garageProvider.vehicles.isNotEmpty ? garageProvider.vehicles.first : null);

    final chargerPowerKw = double.tryParse(
      widget.charger.power.replaceAll(RegExp(r'[^0-9.]'), ''),
    ) ?? 60.0;
    final pricePerKwh = SmartChargingCalculator.parsePrice(widget.charger.price);

    final calcResult = SmartChargingCalculator.calculate(
      currentBatteryPct: _currentSoc,
      targetBatteryPct: _targetSoc,
      chargerPowerKw: chargerPowerKw,
      vehicleMaxPowerKw: vehicle?.maxDcChargingSpeed ?? 120.0,
      batteryCapacityKwh: vehicle?.batteryCapacity ?? 50.0,
      pricePerKwh: pricePerKwh > 0 ? pricePerKwh : 18.0,
      powerType: widget.charger.powerType,
    );

    final walletBalance = walletProvider.balance;
    final estRemainingBalance = walletBalance - calcResult.estimatedCost;

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
          'CHARGING SETUP',
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CHARGER SUMMARY CARD
            GlassContainer(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.ev_station, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.charger.title,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.charger.network} • ${widget.charger.power} • ${widget.charger.price}',
                          style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // EV VEHICLE CARD
            Text(
              'SELECTED EV PROFILE',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.directions_car, color: AppColors.secondary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle != null
                              ? '${vehicle.manufacturer} ${vehicle.model}'
                              : 'Tata Nexon EV (Default)',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Battery: ${vehicle?.batteryCapacity.toInt() ?? 50} kWh • Max DC: ${vehicle?.maxDcChargingSpeed.toInt() ?? 120} kW',
                          style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // SOC SLIDERS
            GlassContainer(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'BATTERY SOC SETTINGS',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_currentSoc.toInt()}% ➔ ${_targetSoc.toInt()}%',
                        style: GoogleFonts.outfit(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Current Battery SOC (${_currentSoc.toInt()}%)', style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12)),
                  Slider(
                    value: _currentSoc,
                    min: 10.0,
                    max: 95.0,
                    divisions: 17,
                    activeColor: AppColors.primary,
                    inactiveColor: Colors.white10,
                    onChanged: (val) {
                      setState(() {
                        _currentSoc = val;
                        if (_targetSoc <= _currentSoc) {
                          _targetSoc = math.min(100.0, _currentSoc + 10.0);
                        }
                        _validationError = null;
                      });
                    },
                  ),
                  Text('Target Battery SOC (${_targetSoc.toInt()}%)', style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12)),
                  Slider(
                    value: _targetSoc,
                    min: _currentSoc + 5.0,
                    max: 100.0,
                    divisions: 19,
                    activeColor: AppColors.secondary,
                    inactiveColor: Colors.white10,
                    onChanged: (val) {
                      setState(() {
                        _targetSoc = val;
                        _validationError = null;
                      });
                    },
                  ),
                  if (_validationError != null) ...[
                    const SizedBox(height: 4),
                    Text(_validationError!, style: GoogleFonts.outfit(color: AppColors.danger, fontSize: 12)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ESTIMATES BREAKDOWN
            GlassContainer(
              padding: const EdgeInsets.all(18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetric('ENERGY NEEDED', '${calcResult.grossEnergyFromGridKwh.toStringAsFixed(1)} kWh'),
                  Container(width: 1, height: 32, color: Colors.white10),
                  _buildMetric('EST. TIME', calcResult.formattedTime),
                  Container(width: 1, height: 32, color: Colors.white10),
                  _buildMetric('EST. COST', '₹${calcResult.estimatedCost.toInt()}'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // WALLET ESTIMATE PREVIEW
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('ChargeOne Wallet Balance', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                      Text('₹${walletBalance.toStringAsFixed(2)}', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Est. Remaining Balance', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                      Text('₹${estRemainingBalance.toStringAsFixed(2)}', style: GoogleFonts.outfit(color: estRemainingBalance < 0 ? AppColors.danger : AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'SIMULATION — NO MONEY DEDUCTED UNTIL SESSION IS COMPLETED',
                    style: GoogleFonts.spaceGrotesk(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // START BUTTON
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: sessionProvider.isLoading
                    ? null
                    : () {
                        if (vehicle == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Please select an EV profile first.', style: GoogleFonts.outfit(color: Colors.white))),
                          );
                          return;
                        }
                        _showSimulationConfirmationModal(context, vehicle, calcResult);
                      },
                icon: const Icon(Icons.flash_on, color: Colors.black, size: 22),
                label: Text(
                  'START SIMULATED CHARGING',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String title, String value) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 2),
        Text(title, style: GoogleFonts.spaceGrotesk(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
