import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/map_marker_model.dart';
import '../../providers/maps_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/charger_source_badge.dart';
import '../../services/smart_charger_ranking_service.dart';
import '../../services/charging_time_estimator_service.dart';
import '../../services/navigation_launcher_service.dart';
import '../../screens/phase4/charger_details_screen.dart';

/// Synchronous Charger Details Bottom Sheet.
/// Immediately renders complete charger details from the in-memory [charger] object.
class ChargerMarkerDetailsSheet extends StatelessWidget {
  final MapMarkerModel charger;

  const ChargerMarkerDetailsSheet({
    super.key,
    required this.charger,
  });

  Color _getNetworkColor(String network) {
    final net = network.toLowerCase();
    if (net.contains('tata')) return AppColors.brandTata;
    if (net.contains('statiq')) return AppColors.primary;
    if (net.contains('jio')) return AppColors.accentPurple;
    if (net.contains('zeon')) return AppColors.secondary;
    return const Color(0xFF10B981);
  }

  void _onNavigatePressed(BuildContext context) {
    const NavigationLauncherService().openGoogleMapsNavigation(
      charger.latitude,
      charger.longitude,
      destinationName: charger.name,
      destinationId: charger.id,
      screenName: 'ChargerMarkerDetailsSheet',
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('SHEET BUILD');
    debugPrint('id: ${charger.id}');
    debugPrint('name: ${charger.name}');
    debugPrint('network: ${charger.networkName}');
    debugPrint('latitude: ${charger.latitude}');
    debugPrint('longitude: ${charger.longitude}');
    debugPrint('status: ${charger.status}');
    debugPrint('power: ${charger.power}');
    debugPrint('connectors: ${charger.connectors}');
    debugPrint('address: ${charger.address}');
    debugPrint('price: ${charger.price}');

    final netColor = _getNetworkColor(charger.networkName);

    return Consumer<MapsProvider>(
      builder: (context, mapsProvider, _) {
        final isFav = mapsProvider.isFavorite(charger.id);
        final selectedVehicle = mapsProvider.selectedVehicle;

        // Pricing & Tariff
        final priceDisplay = (charger.price != null && charger.price!.trim().isNotEmpty)
            ? charger.price!
            : charger.pricePerKwh;

        // EV Compatibility
        final compStatus = SmartChargerRankingService.checkCompatibility(
          charger: charger,
          vehicleConnectors: selectedVehicle?.connectorTypes,
        );

        // Power kW
        final powerKw = ChargingTimeEstimatorService.parsePowerKW(charger.power);

        return SafeArea(
          bottom: true,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1A1D2E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, -4))
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top drag indicator handle bar
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // HEADER ROW: Icon, Title, Network, Verified, Favorite, Close
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: netColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: netColor.withOpacity(0.4), width: 1.5),
                        ),
                        child: Center(
                          child: Icon(Icons.ev_station, color: netColor, size: 26),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              charger.name,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.white,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Text(
                                  charger.networkName,
                                  style: GoogleFonts.outfit(
                                    color: netColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                if (charger.isVerified || charger.source == 'evhub_verified') ...[
                                  const SizedBox(width: 8),
                                  const ChargerSourceBadge(source: 'evhub_verified'),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isFav ? Icons.star : Icons.star_border,
                          color: isFav ? const Color(0xFFF59E0B) : Colors.white60,
                          size: 24,
                        ),
                        onPressed: () => mapsProvider.toggleFavorite(charger.id),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 22),
                        onPressed: () {
                          mapsProvider.setSelectedMarker(null);
                          Navigator.of(context).maybePop();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // STATUS BADGE & POWER & CONNECTORS ROW
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildStatusBadge(charger.status),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt, color: Color(0xFFF59E0B), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              powerKw > 0 ? '${powerKw.toStringAsFixed(0)} kW' : charger.displayPower,
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                        ),
                        child: Text(
                          charger.displayConnectors,
                          style: GoogleFonts.outfit(color: const Color(0xFF3B82F6), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // LOCATION & DISTANCE DETAILS ROW (Distance from route & Distance to destination)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, color: Color(0xFF10B981), size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                charger.displayAddress,
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                                Text(
                                  'Distance: ${charger.distanceKm != null ? "${charger.distanceKm!.toStringAsFixed(1)} km" : "On Route"}',
                                  style: GoogleFonts.outfit(color: const Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // TARIFF & EV COMPATIBILITY ROW
                  Row(
                    children: [
                      const Icon(Icons.currency_rupee, color: Color(0xFF10B981), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Tariff: ',
                        style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12),
                      ),
                      Text(
                        priceDisplay,
                        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const Spacer(),
                      _buildCompatibilityBadge(compStatus.name),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ACTION BUTTONS: VIEW DETAILS & NAVIGATE
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ChargerDetailsScreen(marker: charger)),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.info_outline, color: Colors.white, size: 18),
                          label: Text(
                            'VIEW DETAILS',
                            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _onNavigatePressed(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.navigation, color: Colors.white, size: 18),
                          label: Text(
                            'NAVIGATE',
                            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
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
    );
  }

  Widget _buildStatusBadge(MarkerStatus status) {
    Color bg;
    Color fg;
    String text;

    switch (status) {
      case MarkerStatus.available:
        bg = const Color(0xFF10B981).withOpacity(0.15);
        fg = const Color(0xFF10B981);
        text = 'AVAILABLE';
        break;
      case MarkerStatus.busy:
        bg = const Color(0xFFF59E0B).withOpacity(0.15);
        fg = const Color(0xFFF59E0B);
        text = 'BUSY';
        break;
      case MarkerStatus.offline:
        bg = Colors.red.withOpacity(0.15);
        fg = Colors.redAccent;
        text = 'OFFLINE';
        break;
      case MarkerStatus.unknown:
        bg = Colors.white.withOpacity(0.1);
        fg = Colors.white70;
        text = 'STATUS UNKNOWN';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(color: fg, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildCompatibilityBadge(String compStatus) {
    Color color;
    IconData icon;

    if (compStatus == 'Compatible') {
      color = const Color(0xFF10B981);
      icon = Icons.check_circle;
    } else if (compStatus == 'Incompatible') {
      color = Colors.redAccent;
      icon = Icons.cancel;
    } else {
      color = const Color(0xFFF59E0B);
      icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            compStatus,
            style: GoogleFonts.outfit(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
