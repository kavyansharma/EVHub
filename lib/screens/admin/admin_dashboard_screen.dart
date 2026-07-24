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
import '../../providers/charger_data_dashboard_provider.dart';
import 'charger_management_screen.dart';
import 'add_charger_screen.dart';
import 'bulk_charger_import_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedRecentTab = 0; // 0: Recently Added, 1: Recently Updated

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = context.read<AuthProvider>().user ?? UserModel.guest();
      final dashboardProvider = context.read<ChargerDataDashboardProvider>();
      final adminChargerProvider = context.read<AdminChargerProvider>();

      if (currentUser.isAdmin) {
        dashboardProvider.refreshDashboard(currentUser: currentUser);
        adminChargerProvider.loadChargers(currentUser: currentUser);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().user ?? UserModel.guest();
    final dbProvider = context.watch<ChargerDataDashboardProvider>();

    if (!currentUser.isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Admin Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.danger),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.gpp_bad_rounded, color: AppColors.danger, size: 48),
                SizedBox(height: 16),
                Text('Access Denied', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(
                  'The Charger Data Operations Dashboard is restricted to authorized EVHub Administrators.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final summary = dbProvider;
    final dq = dbProvider.dataQualityHealth;
    final avail = dbProvider.availabilityHealth;
    final stale = dbProvider.staleDataStats;
    final location = dbProvider.locationCoverage;
    final alerts = dbProvider.dataQualityAlerts;

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
          'Charger Data Operations Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: dbProvider.isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Refresh Dashboard Data',
            onPressed: dbProvider.isLoading ? null : () => dbProvider.refreshDashboard(currentUser: currentUser),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: dbProvider.isLoading && dbProvider.chargers.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => dbProvider.refreshDashboard(currentUser: currentUser),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Admin Banner Header
                    _buildAdminBanner(currentUser),
                    const SizedBox(height: 20),

                    // Quick Actions Navigation Bar
                    _buildQuickActionsBar(context, currentUser),
                    const SizedBox(height: 24),

                    // SECTION 1: Summary Cards Grid (8 Cards)
                    _buildSectionHeader('1. Charger Database Summary Metrics', HugeIcons.strokeRoundedAnalytics01),
                    const SizedBox(height: 12),
                    _buildSummaryMetricsGrid(summary),
                    const SizedBox(height: 24),

                    // SECTION 2: Data Quality Health & Score
                    _buildSectionHeader('2. Data Quality Health & Field Audit', HugeIcons.strokeRoundedSecurity),
                    const SizedBox(height: 12),
                    _buildDataQualityHealthCard(dq),
                    const SizedBox(height: 24),

                    // SECTION 3: Actionable Data Quality Alerts
                    if (alerts.isNotEmpty) ...[
                      _buildSectionHeader('3. Actionable Data Quality Alerts', HugeIcons.strokeRoundedAlert02),
                      const SizedBox(height: 12),
                      _buildDataQualityAlertsList(context, alerts),
                      const SizedBox(height: 24),
                    ],

                    // SECTION 4: Source & Network Distribution
                    _buildSectionHeader('4. Charger Source & Network Distribution', HugeIcons.strokeRoundedFlash),
                    const SizedBox(height: 12),
                    _buildSourceAndNetworkSection(summary),
                    const SizedBox(height: 24),

                    // SECTION 5: Geographic Location Coverage
                    _buildSectionHeader('5. Geographic Location Coverage', HugeIcons.strokeRoundedMapsLocation01),
                    const SizedBox(height: 12),
                    _buildLocationCoverageSection(location),
                    const SizedBox(height: 24),

                    // SECTION 6: Availability & Connector Health
                    _buildSectionHeader('6. Availability & Connector Health', HugeIcons.strokeRoundedPlug01),
                    const SizedBox(height: 12),
                    _buildAvailabilityHealthCard(avail),
                    const SizedBox(height: 24),

                    // SECTION 7: Stale Data Detection & Analysis
                    _buildSectionHeader('7. Stale Data Analysis', HugeIcons.strokeRoundedClock01),
                    const SizedBox(height: 12),
                    _buildStaleDataCard(dbProvider, stale),
                    const SizedBox(height: 24),

                    // SECTION 8: Recent Activity
                    _buildSectionHeader('8. Recent Database Activity', HugeIcons.strokeRoundedAnalytics01),
                    const SizedBox(height: 12),
                    _buildRecentActivitySection(dbProvider),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAdminBanner(UserModel user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const HugeIcon(icon: HugeIcons.strokeRoundedSecurity, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Logged in as Admin: ${user.name}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Real-time Firestore /chargers collection data operations & analysis',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsBar(BuildContext context, UserModel user) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildActionButton(
              icon: HugeIcons.strokeRoundedFolder01,
              title: 'Manage Chargers',
              color: AppColors.secondary,
              width: isMobile ? (constraints.maxWidth - 12) / 2 : 180,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChargerManagementScreen())),
            ),
            _buildActionButton(
              icon: HugeIcons.strokeRoundedAddCircle,
              title: '+ Add Charger',
              color: AppColors.primary,
              width: isMobile ? (constraints.maxWidth - 12) / 2 : 180,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddChargerScreen())),
            ),
            _buildActionButton(
              icon: HugeIcons.strokeRoundedFileDownload,
              title: 'Bulk Import',
              color: const Color(0xFF64B5F6),
              width: isMobile ? (constraints.maxWidth - 12) / 2 : 180,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BulkChargerImportScreen())),
            ),
            _buildActionButton(
              icon: HugeIcons.strokeRoundedAlert02,
              title: 'Quality Issues',
              color: AppColors.warning,
              width: isMobile ? (constraints.maxWidth - 12) / 2 : 180,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChargerManagementScreen(initialSearchQuery: '')),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButton({
    required List<List<dynamic>> icon,
    required String title,
    required Color color,
    required double width,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(icon: icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // SECTION 1: SUMMARY METRICS GRID (8 CARDS)
  // =========================================================================
  Widget _buildSummaryMetricsGrid(ChargerDataDashboardProvider summary) {
    final List<Map<String, dynamic>> items = [
      {'title': 'Total EVHub Verified', 'value': '${summary.totalVerifiedChargers}', 'icon': HugeIcons.strokeRoundedCheckmarkBadge01, 'color': AppColors.secondary, 'sub': 'Firestore database'},
      {'title': 'Total Active Chargers', 'value': '${summary.totalActiveChargers}', 'icon': HugeIcons.strokeRoundedFlash, 'color': AppColors.primary, 'sub': 'Available + Busy'},
      {'title': 'Available Chargers', 'value': '${summary.availableChargers}', 'icon': HugeIcons.strokeRoundedZap, 'color': AppColors.secondary, 'sub': 'Ready for charging'},
      {'title': 'Busy Chargers', 'value': '${summary.busyChargers}', 'icon': HugeIcons.strokeRoundedClock01, 'color': AppColors.warning, 'sub': 'Currently occupied'},
      {'title': 'Offline Chargers', 'value': '${summary.offlineChargers}', 'icon': HugeIcons.strokeRoundedCancel01, 'color': AppColors.danger, 'sub': 'In maintenance'},
      {'title': 'Unknown Status', 'value': '${summary.unknownAvailabilityChargers}', 'icon': HugeIcons.strokeRoundedHelpCircle, 'color': Colors.grey, 'sub': 'Needs verification'},
      {'title': 'Added (Last 7 Days)', 'value': '${summary.chargersAddedLast7Days}', 'icon': HugeIcons.strokeRoundedCalendarAdd01, 'color': const Color(0xFF81C784), 'sub': 'Recent additions'},
      {'title': 'Updated (Last 7 Days)', 'value': '${summary.chargersUpdatedLast7Days}', 'icon': HugeIcons.strokeRoundedRefresh, 'color': const Color(0xFF64B5F6), 'sub': 'Recent edits'},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 550 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: crossAxisCount == 1 ? 2.8 : 1.8,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      HugeIcon(icon: item['icon'] as List<List<dynamic>>, color: item['color'] as Color, size: 22),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (item['color'] as Color).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item['sub'] as String,
                          style: TextStyle(color: item['color'] as Color, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['value'] as String,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    item['title'] as String,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // SECTION 2: DATA QUALITY HEALTH CARD
  // =========================================================================
  Widget _buildDataQualityHealthCard(DataQualityHealth dq) {
    Color scoreColor = AppColors.secondary;
    if (dq.score < 50.0) {
      scoreColor = AppColors.danger;
    } else if (dq.score < 75.0) {
      scoreColor = AppColors.warning;
    } else if (dq.score < 90.0) {
      scoreColor = const Color(0xFF64B5F6);
    }

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Database Quality Score', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text('Evaluated across 8 required fields per charger', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: scoreColor),
                ),
                child: Row(
                  children: [
                    Text(
                      '${dq.score.toStringAsFixed(1)}%',
                      style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${dq.ratingTier})',
                      style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          LinearProgressIndicator(
            value: (dq.score / 100.0).clamp(0.0, 1.0),
            backgroundColor: Colors.white10,
            color: scoreColor,
            minHeight: 10,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 20),

          const Text('Missing Field Audit Summary:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildAuditChip('Missing City', dq.missingCity, AppColors.warning),
              _buildAuditChip('Missing State', dq.missingState, AppColors.warning),
              _buildAuditChip('Missing Country', dq.missingCountry, AppColors.warning),
              _buildAuditChip('Missing GeoPoint', dq.missingGeoPoint, AppColors.danger),
              _buildAuditChip('Missing Connectors', dq.missingConnectorTypes, AppColors.danger),
              _buildAuditChip('Missing Power', dq.missingPower, AppColors.warning),
              _buildAuditChip('Missing Phone', dq.missingPhone, Colors.grey),
              _buildAuditChip('Missing Website', dq.missingWebsite, Colors.grey),
              _buildAuditChip('Missing Image', dq.missingImage, Colors.grey),
              _buildAuditChip('Missing Amenities', dq.missingAmenities, Colors.grey),
              _buildAuditChip('Missing Timestamps', dq.missingLastUpdated, AppColors.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuditChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: count > 0 ? color.withOpacity(0.12) : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: count > 0 ? color.withOpacity(0.4) : Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: count > 0 ? color : Colors.white24,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(color: count > 0 ? Colors.black : Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SECTION 3: ACTIONABLE DATA QUALITY ALERTS
  // =========================================================================
  Widget _buildDataQualityAlertsList(BuildContext context, List<DataQualityAlert> alerts) {
    return Column(
      children: alerts.map((alert) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChargerManagementScreen(
                    initialSearchQuery: alert.filterKey == 'missing_city' ? 'Unknown City' : '',
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 16,
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: alert.alertColor, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      alert.message,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textSecondary, size: 14),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // =========================================================================
  // SECTION 4: CHARGER SOURCE & NETWORK DISTRIBUTION
  // =========================================================================
  Widget _buildSourceAndNetworkSection(ChargerDataDashboardProvider summary) {
    final networks = summary.networkBreakdown;

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Charger Source Breakdown', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              const Text('Persistent vs External', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const ChargerSourceBadge(source: 'evhub_verified', isVerified: true),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${summary.evhubVerifiedCount} chargers', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('${summary.evhubVerifiedPercentage.toStringAsFixed(1)}% of total', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const ChargerSourceBadge(source: 'google_places', isVerified: false),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${summary.googlePlacesCount} chargers', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          const Text('Live API Discoveries', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          const Text('Network Distribution (Sorted Descending):', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: networks.length > 8 ? 8 : networks.length,
            separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final net = networks[idx];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(net.networkName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('${net.count} chargers (${net.percentage.toStringAsFixed(1)}%)', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: (net.percentage / 100.0).clamp(0.0, 1.0),
                    backgroundColor: Colors.white10,
                    color: AppColors.primary,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SECTION 5: GEOGRAPHIC LOCATION COVERAGE
  // =========================================================================
  Widget _buildLocationCoverageSection(LocationCoverage location) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCoverageMetric('Countries', '${location.totalCountries}', HugeIcons.strokeRoundedGlobal),
              _buildCoverageMetric('States', '${location.totalStates}', HugeIcons.strokeRoundedMapsLocation01),
              _buildCoverageMetric('Cities', '${location.totalCities}', HugeIcons.strokeRoundedBuilding01),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Top 5 Cities', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    ...location.topCities.take(5).map((c) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                              Text('${c.count} (${c.percentage.toStringAsFixed(0)}%)', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Top 5 States', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    ...location.topStates.take(5).map((s) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                              Text('${s.count} (${s.percentage.toStringAsFixed(0)}%)', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoverageMetric(String label, String value, List<List<dynamic>> icon) {
    return Column(
      children: [
        HugeIcon(icon: icon, color: AppColors.primary, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }

  // =========================================================================
  // SECTION 6: AVAILABILITY & CONNECTOR HEALTH
  // =========================================================================
  Widget _buildAvailabilityHealthCard(AvailabilityHealth avail) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Overall Connector Availability', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              Text(
                '${avail.connectorAvailabilityPercentage.toStringAsFixed(1)}% Available',
                style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),

          LinearProgressIndicator(
            value: (avail.connectorAvailabilityPercentage / 100.0).clamp(0.0, 1.0),
            backgroundColor: Colors.white10,
            color: AppColors.secondary,
            minHeight: 10,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total Connectors', '${avail.totalConnectors}', Colors.white),
              _buildStatItem('Available Plugs', '${avail.availableConnectors}', AppColors.secondary),
              _buildStatItem('Occupied Plugs', '${avail.occupiedConnectors}', AppColors.warning),
              _buildStatItem('Offline Stations', '${avail.offlineCount}', AppColors.danger),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SECTION 7: STALE DATA ANALYSIS
  // =========================================================================
  Widget _buildStaleDataCard(ChargerDataDashboardProvider dbProvider, StaleDataStats stale) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Stale Data Monitor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('Chargers not updated in >${stale.thresholdDays} days', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
              DropdownButton<int>(
                value: dbProvider.staleThresholdDays,
                dropdownColor: AppColors.card,
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 14, child: Text('14 Days Threshold')),
                  DropdownMenuItem(value: 30, child: Text('30 Days Threshold')),
                  DropdownMenuItem(value: 60, child: Text('60 Days Threshold')),
                  DropdownMenuItem(value: 90, child: Text('90 Days Threshold')),
                ],
                onChanged: (val) {
                  if (val != null) dbProvider.setStaleThresholdDays(val);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Fresh (<${stale.thresholdDays}d)', '${stale.freshCount}', AppColors.secondary),
              _buildStatItem('Stale (>${stale.thresholdDays}d)', '${stale.staleCount}', AppColors.warning),
              _buildStatItem('Never Updated', '${stale.neverUpdatedCount}', AppColors.danger),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SECTION 8: RECENT ACTIVITY
  // =========================================================================
  Widget _buildRecentActivitySection(ChargerDataDashboardProvider summary) {
    final recentList = _selectedRecentTab == 0
        ? summary.recentlyAddedChargers
        : summary.recentlyUpdatedChargers;

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChoiceChip(
                label: const Text('Recently Added (10)'),
                selected: _selectedRecentTab == 0,
                selectedColor: AppColors.primary,
                backgroundColor: Colors.white10,
                labelStyle: TextStyle(color: _selectedRecentTab == 0 ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                onSelected: (val) => setState(() => _selectedRecentTab = 0),
              ),
              const SizedBox(width: 10),
              ChoiceChip(
                label: const Text('Recently Updated (10)'),
                selected: _selectedRecentTab == 1,
                selectedColor: AppColors.secondary,
                backgroundColor: Colors.white10,
                labelStyle: TextStyle(color: _selectedRecentTab == 1 ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                onSelected: (val) => setState(() => _selectedRecentTab = 1),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentList.length,
            separatorBuilder: (ctx, idx) => const Divider(color: Colors.white10, height: 1),
            itemBuilder: (ctx, idx) {
              final c = recentList[idx];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const HugeIcon(icon: HugeIcons.strokeRoundedZap, color: AppColors.primary, size: 20),
                title: Text(c.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('${c.network} • ${c.city ?? c.address ?? "No City"}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.status == MarkerStatus.available ? AppColors.secondary.withOpacity(0.15) : AppColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    c.status.name.toUpperCase(),
                    style: TextStyle(color: c.status == MarkerStatus.available ? AppColors.secondary : AppColors.warning, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, List<List<dynamic>> icon) {
    return Row(
      children: [
        HugeIcon(icon: icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
      ],
    );
  }
}
