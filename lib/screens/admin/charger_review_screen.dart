import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/premium_button.dart';
import '../../core/widgets/charger_source_badge.dart';
import '../../models/map_marker_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_charger_provider.dart';
import 'add_charger_screen.dart';

class ChargerReviewScreen extends StatelessWidget {
  final MapMarkerModel charger;

  const ChargerReviewScreen({super.key, required this.charger});

  @override
  Widget build(BuildContext context) {
    final adminUser = context.watch<AuthProvider>().user ?? UserModel.guest();
    final adminProvider = context.watch<AdminChargerProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Charger Verification Review',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            _buildStatusBanner(),
            const SizedBox(height: 20),

            // Charger Main Info Glass Card
            GlassContainer(
              padding: const EdgeInsets.all(20),
              borderRadius: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ChargerSourceBadge(
                        source: charger.source,
                        isVerified: charger.isVerified,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(charger.verificationStatus).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _getStatusColor(charger.verificationStatus)),
                        ),
                        child: Text(
                          charger.verificationStatus.toUpperCase(),
                          style: TextStyle(
                            color: _getStatusColor(charger.verificationStatus),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text(
                    charger.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    charger.address ?? charger.description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 12),

                  // Metrics Grid
                  Row(
                    children: [
                      _buildMetricTile(
                        icon: HugeIcons.strokeRoundedFlash,
                        title: 'Power',
                        value: charger.power,
                        color: AppColors.primary,
                      ),
                      _buildMetricTile(
                        icon: HugeIcons.strokeRoundedZap,
                        title: 'Type',
                        value: charger.powerType,
                        color: AppColors.secondary,
                      ),
                      _buildMetricTile(
                        icon: HugeIcons.strokeRoundedMoney01,
                        title: 'Tariff',
                        value: charger.price ?? '₹21/kWh',
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Map Location Preview Card
            GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      HugeIcon(icon: HugeIcons.strokeRoundedMapsLocation01, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Location Preview',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 180,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(charger.latitude, charger.longitude),
                          zoom: 15.0,
                        ),
                        markers: {
                          Marker(
                            markerId: MarkerId(charger.id),
                            position: LatLng(charger.latitude, charger.longitude),
                            infoWindow: InfoWindow(title: charger.title),
                          ),
                        },
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Chip(
                        backgroundColor: Colors.white.withOpacity(0.06),
                        label: Text('Lat: ${charger.latitude.toStringAsFixed(6)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        backgroundColor: Colors.white.withOpacity(0.06),
                        label: Text('Lng: ${charger.longitude.toStringAsFixed(6)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Connector & Operating Details
            GlassContainer(
              padding: const EdgeInsets.all(20),
              borderRadius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Supported Connectors', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: charger.connectors.map((c) {
                      return Chip(
                        backgroundColor: AppColors.primary.withOpacity(0.12),
                        avatar: const HugeIcon(icon: HugeIcons.strokeRoundedPlug01, color: AppColors.primary, size: 16),
                        label: Text(c, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 12),

                  _buildDetailRow('Total Connectors:', '${charger.connectorCount} Plugs'),
                  _buildDetailRow('Available Plugs:', charger.availableStalls),
                  _buildDetailRow('Opening Hours:', charger.openingHours ?? '24 Hours'),
                  _buildDetailRow('Network Owner:', charger.network),
                  if (charger.createdBy != null) _buildDetailRow('Submitted By:', charger.createdBy!),
                  if (charger.ownerId != null) _buildDetailRow('Partner UID:', charger.ownerId!),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Admin Actions Row
            if (adminUser.isAdmin) ...[
              Row(
                children: [
                  Expanded(
                    child: PremiumButton(
                      text: 'Approve & Verify',
                      icon: Icons.check_circle,
                      isLoading: adminProvider.isLoading,
                      onPressed: () async {
                        final success = await adminProvider.approveCharger(charger.id, adminUser);
                        if (success && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      onPressed: () async {
                        final success = await adminProvider.rejectCharger(charger.id, adminUser);
                        if (success && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      icon: const Icon(Icons.cancel, color: AppColors.danger),
                      label: const Text(
                        'Reject',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AddChargerScreen(initialCharger: charger),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit Charger Info'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: BorderSide(color: AppColors.danger.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppColors.card,
                            title: const Text('Delete Charger?', style: TextStyle(color: Colors.white)),
                            content: Text('Are you sure you want to permanently delete "${charger.title}"?', style: const TextStyle(color: AppColors.textSecondary)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
                            ],
                          ),
                        );

                        if (confirm == true && context.mounted) {
                          final success = await adminProvider.deleteCharger(charger.id, adminUser);
                          if (success && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        }
                      },
                      icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                      label: const Text('Delete Charger'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    Color bg;
    Color border;
    IconData icon;
    String text;

    switch (charger.verificationStatus.toLowerCase()) {
      case 'approved':
        bg = AppColors.secondary.withOpacity(0.12);
        border = AppColors.secondary;
        icon = Icons.verified;
        text = 'This charger is APPROVED and visible on public maps as EVHub Verified.';
        break;
      case 'rejected':
        bg = AppColors.danger.withOpacity(0.12);
        border = AppColors.danger;
        icon = Icons.error_outline;
        text = 'This charger has been REJECTED. It is not visible to public drivers.';
        break;
      case 'pending':
      default:
        bg = AppColors.warning.withOpacity(0.12);
        border = AppColors.warning;
        icon = Icons.hourglass_empty;
        text = 'This partner submission is PENDING Admin approval.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: border, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: border, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required List<List<dynamic>> icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            HugeIcon(icon: icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppColors.secondary;
      case 'rejected':
        return AppColors.danger;
      case 'pending':
      default:
        return AppColors.warning;
    }
  }
}
