import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/map_marker_model.dart';
import '../../providers/maps_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/charger_source_badge.dart';
import '../../services/smart_charger_ranking_service.dart';
import '../../services/charging_time_estimator_service.dart';
import '../../services/navigation_launcher_service.dart';
import '../../screens/phase4/charger_details_screen.dart';

/// Synchronous Charger Details Bottom Sheet.
/// Immediately renders complete charger details from the in-memory [charger] object
/// without blocking async calls, loaders, or dark empty states.
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
    final lat = charger.latitude;
    final lng = charger.longitude;
    final name = charger.name;
    final id = charger.id;

    final isLatValid = !lat.isNaN && lat != 0.0 && lat >= -90.0 && lat <= 90.0;
    final isLngValid = !lng.isNaN && lng != 0.0 && lng >= -180.0 && lng <= 180.0;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final address = charger.displayAddress.trim();

    if (!charger.hasValidCoordinates || !isLatValid || !isLngValid) {
      debugPrint('[EVHUB_NAV_ERROR] Invalid navigation coordinates for charger: lat=$lat, lng=$lng');
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            "Navigation unavailable: this charger does not have a valid location.",
            style: GoogleFonts.outfit(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF1A1D2E),
          behavior: SnackBarBehavior.floating,
          action: address.isNotEmpty
              ? SnackBarAction(
                  label: 'OPEN ADDRESS IN GOOGLE MAPS',
                  textColor: const Color(0xFF3B82F6),
                  onPressed: () async {
                    final query = Uri.encodeComponent(address);
                    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
                    try {
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
                      }
                    } catch (e) {
                      debugPrint('[EVHUB_NAV_ERROR] External address search error: $e');
                    }
                  },
                )
              : null,
        ),
      );
      return;
    }

    // Safely capture root navigator before popping bottom sheet
    final navigator = Navigator.of(context, rootNavigator: true);

    // Synchronously launch Google Maps directly from user gesture callback
    NavigationLauncherService().launchNavigation(
      lat,
      lng,
      destinationName: name,
      destinationId: id,
    ).then((success) {
      if (!success) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Google Maps was blocked by your browser. Please allow pop-ups for EVHub and tap NAVIGATE again.',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF1A1D2E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    // Close bottom sheet
    navigator.pop();
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

                  // LOCATION & DISTANCE ROW
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
                        if (charger.distanceKm != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.near_me, color: Color(0xFF3B82F6), size: 14),
                              const SizedBox(width: 6),
                              Text(
                                '${charger.distanceKm!.toStringAsFixed(1)} km away',
                                style: GoogleFonts.outfit(color: const Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
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
                      _buildCompatibilityBadge(compStatus),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ACTION BUTTONS: NAVIGATE TO CHARGER + START & FULL DETAILS
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: SizedBox(
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: () => _onNavigatePressed(context),
                            icon: const Icon(Icons.navigation_outlined, color: Color(0xFF3B82F6), size: 18),
                            label: Text(
                              'NAVIGATE',
                              style: GoogleFonts.outfit(color: const Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ChargerDetailsScreen(marker: charger)),
                              );
                            },
                            icon: const Icon(Icons.bolt, color: Colors.black, size: 20),
                            label: Text(
                              'START CHARGING',
                              style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Navigation Status: Ready',
                      style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10),
                    ),
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
        label = 'Availability unknown';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
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
        label = '✓ Compatible';
        break;
      case EVCompatibilityStatus.partiallyCompatible:
        fg = Colors.amberAccent;
        label = '⚠ Partial';
        break;
      case EVCompatibilityStatus.incompatible:
        fg = Colors.redAccent;
        label = '✕ Incompatible';
        break;
      case EVCompatibilityStatus.noVehicleSelected:
        fg = Colors.white60;
        label = 'Select your EV';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fg.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}
