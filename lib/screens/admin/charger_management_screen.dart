import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/charger_source_badge.dart';
import '../../models/map_marker_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_charger_provider.dart';
import 'add_charger_screen.dart';
import 'charger_review_screen.dart';

class ChargerManagementScreen extends StatefulWidget {
  final String? initialSearchQuery;
  final String? initialStatusFilter;
  final String? initialNetworkFilter;

  const ChargerManagementScreen({
    super.key,
    this.initialSearchQuery,
    this.initialStatusFilter,
    this.initialNetworkFilter,
  });

  @override
  State<ChargerManagementScreen> createState() => _ChargerManagementScreenState();
}

class _ChargerManagementScreenState extends State<ChargerManagementScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = context.read<AuthProvider>().user ?? UserModel.guest();
      final adminProvider = context.read<AdminChargerProvider>();
      adminProvider.loadChargers(currentUser: currentUser);
      adminProvider.startRealtimeUpdates(currentUser: currentUser);

      if (widget.initialSearchQuery != null && widget.initialSearchQuery!.isNotEmpty) {
        _searchController.text = widget.initialSearchQuery!;
        adminProvider.setSearchQuery(widget.initialSearchQuery!);
      }
      if (widget.initialStatusFilter != null) {
        adminProvider.setStatusFilter(widget.initialStatusFilter!);
      }
      if (widget.initialNetworkFilter != null) {
        adminProvider.setNetworkFilter(widget.initialNetworkFilter!);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().user ?? UserModel.guest();
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
        title: Text(
          currentUser.isAdmin ? 'Admin Charger Portal' : 'Partner Chargers',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: () => adminProvider.loadChargers(currentUser: currentUser),
            tooltip: 'Refresh list',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_charger_fab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add, color: Colors.black),
        label: Text(
          currentUser.isAdmin ? 'Add New Charger' : 'Submit New Charger',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AddChargerScreen(),
            ),
          );
        },
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search & Filter Header Row
            GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 20,
              child: Column(
                children: [
                  // Search TextField
                  Row(
                    children: [
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedSearch01,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Search by station name, network or address...',
                            hintStyle: TextStyle(color: AppColors.textSecondary),
                            border: InputBorder.none,
                          ),
                          onChanged: (query) => adminProvider.setSearchQuery(query),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            adminProvider.setSearchQuery('');
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Filter Chips Scrollable Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Verification Status Filter
                        _buildFilterDropdown(
                          label: 'Status:',
                          value: adminProvider.selectedVerifiedFilter,
                          items: const ['All', 'Approved', 'Pending', 'Rejected'],
                          onChanged: (val) {
                            if (val != null) adminProvider.setVerifiedFilter(val);
                          },
                        ),
                        const SizedBox(width: 10),

                        // Network Filter
                        _buildFilterDropdown(
                          label: 'Network:',
                          value: adminProvider.selectedNetworkFilter,
                          items: const ['All', 'Tata Power', 'Jio-bp Pulse', 'Statiq', 'Shell Recharge', 'Zeon', 'ChargeZone', 'Independent'],
                          onChanged: (val) {
                            if (val != null) adminProvider.setNetworkFilter(val);
                          },
                        ),
                        const SizedBox(width: 10),

                        // Operating Status Filter
                        _buildFilterDropdown(
                          label: 'Availability:',
                          value: adminProvider.selectedStatusFilter,
                          items: const ['All', 'Available', 'Busy', 'Offline'],
                          onChanged: (val) {
                            if (val != null) adminProvider.setStatusFilter(val);
                          },
                        ),
                        const SizedBox(width: 10),

                        // Sort Filter
                        _buildFilterDropdown(
                          label: 'Sort:',
                          value: adminProvider.selectedSortBy,
                          items: const ['Newest', 'Name', 'Availability'],
                          onChanged: (val) {
                            if (val != null) adminProvider.setSortBy(val);
                          },
                        ),
                        const SizedBox(width: 10),

                        // Reset Filters Button
                        TextButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            adminProvider.resetFilters();
                          },
                          icon: const Icon(Icons.filter_alt_off, size: 16, color: AppColors.danger),
                          label: const Text('Reset', style: TextStyle(color: AppColors.danger, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Charger List Header Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${adminProvider.chargers.length} of ${adminProvider.allChargers.length} chargers',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                if (adminProvider.pendingChargersCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warning),
                    ),
                    child: Text(
                      '⏳ ${adminProvider.pendingChargersCount} Pending Review',
                      style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Main List View
            Expanded(
              child: adminProvider.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : adminProvider.chargers.isEmpty
                      ? _buildEmptyState(currentUser)
                      : ListView.builder(
                          itemCount: adminProvider.chargers.length,
                          itemBuilder: (context, index) {
                            final charger = adminProvider.chargers[index];
                            return _buildChargerCard(charger, currentUser);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(width: 6),
          DropdownButton<String>(
            value: items.contains(value) ? value : items.first,
            dropdownColor: AppColors.card,
            underline: const SizedBox(),
            isDense: true,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            items: items.map((item) {
              return DropdownMenuItem(value: item, child: Text(item));
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildChargerCard(MapMarkerModel charger, UserModel currentUser) {
    final bool canEdit = currentUser.isAdmin || (currentUser.isPartner && charger.ownerId == currentUser.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Source badge & Verification Chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ChargerSourceBadge(
                  source: charger.source,
                  isVerified: charger.isVerified,
                  compact: true,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _getVerificationColor(charger.verificationStatus).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _getVerificationColor(charger.verificationStatus)),
                  ),
                  child: Text(
                    charger.verificationStatus.toUpperCase(),
                    style: TextStyle(
                      color: _getVerificationColor(charger.verificationStatus),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Station Name & Network
            Text(
              charger.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  charger.network,
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(width: 8),
                const Text('•', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    charger.address ?? charger.description,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Power, Availability & Connectors Info
            Row(
              children: [
                _buildInfoBadge(HugeIcons.strokeRoundedFlash, charger.power, AppColors.primary),
                const SizedBox(width: 8),
                _buildInfoBadge(HugeIcons.strokeRoundedPlug01, '${charger.availableStalls} Plugs', AppColors.secondary),
                const SizedBox(width: 8),
                _buildInfoBadge(HugeIcons.strokeRoundedMoney01, charger.price ?? '₹21/kWh', AppColors.warning),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 8),

            // Bottom Actions Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (charger.lastUpdated != null)
                  Text(
                    'Updated ${charger.lastUpdated}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  )
                else
                  const SizedBox(),

                Row(
                  children: [
                    // View / Review
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, color: AppColors.primary, size: 20),
                      tooltip: 'View Details',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChargerReviewScreen(charger: charger),
                          ),
                        );
                      },
                    ),

                    // Edit
                    if (canEdit)
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                        tooltip: 'Edit Charger',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AddChargerScreen(initialCharger: charger),
                            ),
                          );
                        },
                      ),

                    // Delete
                    if (currentUser.isAdmin)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                        tooltip: 'Delete Charger',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: AppColors.card,
                              title: const Text('Delete Charger?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Are you sure you want to permanently delete this charger?',
                                    style: TextStyle(color: Colors.white, fontSize: 13),
                                  ),
                                  const SizedBox(height: 12),
                                  Text('Station: ${charger.title}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('Network: ${charger.network}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                  Text('Address: ${charger.address ?? charger.description}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                ],
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete Charger', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true && mounted) {
                            if (!context.mounted) return;
                            context.read<AdminChargerProvider>().deleteCharger(charger.id, currentUser);
                          }
                        },
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBadge(List<List<dynamic>> icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(UserModel currentUser) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const HugeIcon(icon: HugeIcons.strokeRoundedFlash, color: AppColors.textSecondary, size: 48),
          const SizedBox(height: 16),
          const Text(
            'No Chargers Found',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            currentUser.isPartner
                ? 'You have not registered any chargers yet.'
                : 'No chargers match the selected search and filter criteria.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getVerificationColor(String status) {
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
