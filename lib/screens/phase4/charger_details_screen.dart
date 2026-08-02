import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../models/map_marker_model.dart';
import '../../providers/maps_provider.dart';
import '../../services/charging_time_estimator_service.dart';
import '../../services/smart_charger_ranking_service.dart';
import '../../services/smart_trip_energy_cost_service.dart';
import '../garage/garage_screen.dart';
import '../charging/charging_setup_screen.dart';
import '../../services/navigation_launcher_service.dart';




/// Screen / Bottom sheet displaying comprehensive Smart Charger Details
/// including network, availability, power, connectors, pricing, EV compatibility,
/// smart charging estimates, favorites toggle, and navigation action.
class ChargerDetailsScreen extends StatelessWidget {
  final MapMarkerModel marker;

  const ChargerDetailsScreen({
    super.key,
    required this.marker,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<MapsProvider>(
      builder: (context, mapsProvider, child) {
        final isFav = mapsProvider.isFavorite(marker.id);
        final selectedVehicle = mapsProvider.selectedVehicle;
        final isRouteMode = mapsProvider.discoveryMode == 'route';

        // Pricing hierarchy via SmartTripEnergyCostService
        final costService = const SmartTripEnergyCostService();
        final tariffResult = costService.determineTariff(marker, mapsProvider.costSettings);
        final tariffPrice = tariffResult.price;
        final priceDisplay = (tariffPrice != null && tariffPrice > 0)
            ? '₹${tariffPrice.toStringAsFixed(1).replaceAll('.0', '')}/kWh'
            : 'Price unavailable';

        // EV Compatibility via SmartChargerRankingService
        final compStatus = SmartChargerRankingService.checkCompatibility(
          charger: marker,
          vehicleConnectors: selectedVehicle?.connectorTypes,
        );

        // Power parsing
        final powerKw = ChargingTimeEstimatorService.parsePowerKW(marker.power);
        final speedCategory = _getSpeedCategory(powerKw, marker.power);

        // Charging estimates if vehicle selected
        final timeEstimator = const ChargingTimeEstimatorService();
        final currentSoc = mapsProvider.currentBatteryPct;
        const targetSoc = 80.0;
        final vehicleCapacity = selectedVehicle?.batteryCapacity ?? 40.0;
        final maxDcKw = selectedVehicle?.maxDcChargingSpeed ?? 50.0;

        final estimateResult = selectedVehicle != null && currentSoc < targetSoc
            ? timeEstimator.estimate(
                fromBatteryPct: currentSoc,
                toBatteryPct: targetSoc,
                batteryCapacityKWh: vehicleCapacity,
                chargerPowerKW: powerKw > 0 ? powerKw : 60.0,
                vehicleMaxChargingKW: maxDcKw,
              )
            : null;

        final gridEnergy = estimateResult != null
            ? costService.calculateGridEnergyDrawn(
                estimateResult.energyDeliveredKWh,
                powerKw > 0 ? powerKw : 60.0,
              )
            : 0.0;

        final chargingCost = (estimateResult != null && tariffPrice != null && tariffPrice > 0)
            ? costService.calculateChargingCost(gridEnergy, tariffPrice)
            : null;

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
              'Charger Details',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  isFav ? Icons.star : Icons.star_border,
                  color: isFav ? AppColors.warning : Colors.white70,
                  size: 26,
                ),
                onPressed: () async {
                  await mapsProvider.toggleFavorite(marker.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isFav ? 'Removed from Favorites' : 'Saved to Favorites!',
                          style: GoogleFonts.outfit(color: Colors.white),
                        ),
                        duration: const Duration(seconds: 2),
                        backgroundColor: AppColors.card,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER CARD
                GlassContainer(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: AppColors.chargingGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Icon(Icons.ev_station, color: Colors.black, size: 28),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  marker.title,
                                  style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      marker.network,
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (marker.isVerified || marker.source == 'evhub_verified') ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.verified, color: AppColors.primary, size: 12),
                                            const SizedBox(width: 4),
                                            Text(
                                              '✓ EVHub Verified',
                                              style: GoogleFonts.outfit(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white10, height: 1),
                      const SizedBox(height: 16),

                      // AVAILABILITY BADGE & STATUS
                      Row(
                        children: [
                          _buildStatusBadge(marker.status),
                          const Spacer(),
                          if (marker.availableStalls.isNotEmpty) ...[
                            const Icon(Icons.power, color: Colors.white60, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Stalls: ${marker.availableStalls}',
                              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // LOCATION & DISTANCE
                GlassContainer(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'LOCATION',
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        marker.description.trim().isNotEmpty
                            ? marker.description
                            : 'Location coordinates available',
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (marker.distanceKm != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.near_me, color: AppColors.secondary, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${marker.distanceKm!.toStringAsFixed(1)} km away',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          if (isRouteMode)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.alt_route, color: AppColors.secondary, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    marker.distanceKm != null
                                        ? '${marker.distanceKm!.toStringAsFixed(1)} km from route'
                                        : 'Approx. distance from route',
                                    style: GoogleFonts.outfit(
                                      color: AppColors.secondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // CHARGING SPEED & CONNECTORS & PRICING
                Row(
                  children: [
                    // Speed Card
                    Expanded(
                      child: GlassContainer(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.bolt, color: AppColors.warning, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'SPEED',
                                  style: GoogleFonts.spaceGrotesk(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              speedCategory,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              powerKw > 0 ? '${powerKw.toStringAsFixed(0)} kW' : 'Power unavailable',
                              style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Price Card
                    Expanded(
                      child: GlassContainer(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.currency_rupee, color: AppColors.primary, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'TARIFF',
                                  style: GoogleFonts.spaceGrotesk(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              priceDisplay,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tariffResult.source,
                              style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // CONNECTORS SECTION
                GlassContainer(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.electrical_services, color: AppColors.secondary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'AVAILABLE CONNECTORS',
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      marker.connectors.isNotEmpty
                          ? Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: marker.connectors.map((c) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.charging_station, color: AppColors.secondary, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        c,
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            )
                          : Text(
                              'Connector information unavailable',
                              style: GoogleFonts.outfit(color: Colors.white60, fontSize: 14),
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // EV COMPATIBILITY SECTION
                GlassContainer(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.directions_car, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'EV COMPATIBILITY',
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (selectedVehicle != null) ...[
                        Row(
                          children: [
                            Text(
                              '${selectedVehicle.manufacturer} ${selectedVehicle.model}',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const Spacer(),
                            _buildCompatibilityBadge(compStatus),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Supported connectors: ${selectedVehicle.connectorTypes.join(", ")}',
                          style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13),
                        ),
                      ] else ...[
                        Text(
                          'Select your EV to check charger compatibility and charging time estimates.',
                          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const GarageScreen()),
                              );
                            },
                            icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                            label: Text(
                              'SELECT MY EV',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ESTIMATED CHARGING PERFORMANCE
                if (selectedVehicle != null) ...[
                  GlassContainer(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.analytics_outlined, color: AppColors.warning, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'SMART CHARGING ESTIMATE',
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'ESTIMATED',
                                style: GoogleFonts.outfit(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildEstimateItem(
                              'Current SOC',
                              '${currentSoc.toStringAsFixed(0)}%',
                              Icons.battery_3_bar,
                            ),
                            _buildEstimateItem(
                              'Target SOC',
                              '${targetSoc.toStringAsFixed(0)}%',
                              Icons.battery_charging_full,
                            ),
                            _buildEstimateItem(
                              'Energy Added',
                              estimateResult != null
                                  ? '${estimateResult.energyDeliveredKWh.toStringAsFixed(1)} kWh'
                                  : '-- kWh',
                              Icons.bolt,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(color: Colors.white10, height: 1),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.timer_outlined, color: AppColors.secondary, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'Est. Time:',
                                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  estimateResult != null
                                      ? '~${estimateResult.estimatedMinutes} min'
                                      : 'Unavailable',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.payments_outlined, color: AppColors.primary, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'Est. Cost:',
                                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  chargingCost != null && chargingCost > 0
                                      ? '₹${chargingCost.toStringAsFixed(0)}'
                                      : 'Unavailable',
                                  style: GoogleFonts.outfit(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // START SIMULATED CHARGING ACTION
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (selectedVehicle == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Select your EV before starting charging.',
                              style: GoogleFonts.outfit(color: Colors.white),
                            ),
                            action: SnackBarAction(
                              label: 'SELECT VEHICLE',
                              textColor: AppColors.primary,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const GarageScreen()),
                                );
                              },
                            ),
                            backgroundColor: AppColors.card,
                          ),
                        );
                        return;
                      }

                      if (marker.status == MarkerStatus.offline) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'This charger is OFFLINE. Charging cannot be initiated.',
                              style: GoogleFonts.outfit(color: Colors.white),
                            ),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChargingSetupScreen(charger: marker),
                        ),
                      );
                    },
                    icon: const Icon(Icons.flash_on, color: Colors.black, size: 22),
                    label: Text(
                      'START CHARGING',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // PRIMARY NAVIGATION ACTION
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      const NavigationLauncherService().openGoogleMapsNavigation(
                        marker.latitude,
                        marker.longitude,
                        destinationName: marker.name,
                        destinationId: marker.id,
                        screenName: 'ChargerDetailsScreen',
                      );
                    },

                    icon: const Icon(Icons.navigation_outlined, color: Colors.white, size: 22),
                    label: Text(
                      'NAVIGATE TO CHARGER',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // FAVORITE SECONDARY ACTION
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await mapsProvider.toggleFavorite(marker.id);
                    },
                    icon: Icon(
                      isFav ? Icons.star : Icons.star_border,
                      color: isFav ? AppColors.warning : Colors.white,
                      size: 20,
                    ),
                    label: Text(
                      isFav ? 'SAVED TO FAVORITES' : 'ADD TO FAVORITES',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(MarkerStatus status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case MarkerStatus.available:
        bg = Colors.green.withOpacity(0.2);
        fg = Colors.greenAccent;
        label = 'AVAILABLE';
        break;
      case MarkerStatus.busy:
        bg = Colors.orange.withOpacity(0.2);
        fg = Colors.orangeAccent;
        label = 'BUSY';
        break;
      case MarkerStatus.offline:
        bg = Colors.red.withOpacity(0.2);
        fg = Colors.redAccent;
        label = 'OFFLINE';
        break;
      case MarkerStatus.unknown:
        bg = Colors.grey.withOpacity(0.2);
        fg = Colors.white70;
        label = 'UNKNOWN';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: fg,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status == MarkerStatus.unknown ? 'Availability unknown' : label,
            style: GoogleFonts.outfit(
              color: fg,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompatibilityBadge(EVCompatibilityStatus status) {
    Color fg;
    String label;

    switch (status) {
      case EVCompatibilityStatus.compatible:
        fg = Colors.greenAccent;
        label = '✓ COMPATIBLE';
        break;
      case EVCompatibilityStatus.partiallyCompatible:
        fg = Colors.amberAccent;
        label = '⚠ PARTIALLY COMPATIBLE';
        break;
      case EVCompatibilityStatus.incompatible:
        fg = Colors.redAccent;
        label = '✕ NOT COMPATIBLE';
        break;
      case EVCompatibilityStatus.noVehicleSelected:
        fg = Colors.white70;
        label = 'Select your EV';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fg.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildEstimateItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white60, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          title,
          style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.5), fontSize: 11),
        ),
      ],
    );
  }

  String _getSpeedCategory(double powerKw, String? rawPower) {
    if (powerKw >= 100) return 'Ultra Fast';
    if (powerKw >= 30) return 'DC Fast';
    if (powerKw > 0) return 'AC Charging';
    if (rawPower != null && rawPower.toLowerCase().contains('fast')) return 'Fast Charging';
    return 'AC / DC Charging';
  }
}
