import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/premium_button.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_charger_provider.dart';
import '../../providers/bulk_import_provider.dart';
import '../../services/csv_import_service.dart';

class BulkChargerImportScreen extends StatefulWidget {
  const BulkChargerImportScreen({super.key});

  @override
  State<BulkChargerImportScreen> createState() => _BulkChargerImportScreenState();
}

class _BulkChargerImportScreenState extends State<BulkChargerImportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = context.read<AuthProvider>().user ?? UserModel.guest();
      final adminProvider = context.read<AdminChargerProvider>();
      if (adminProvider.allChargers.isEmpty) {
        adminProvider.loadChargers(currentUser: currentUser);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().user ?? UserModel.guest();
    final adminProvider = context.watch<AdminChargerProvider>();
    final bulkProvider = context.watch<BulkImportProvider>();

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
          title: const Text('Bulk Charger Import', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  'Bulk Charger Import is restricted to authorized EVHub Administrators only.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

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
          'Bulk Charger Import',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (bulkProvider.step != BulkImportStep.idle)
            TextButton.icon(
              onPressed: () => bulkProvider.reset(),
              icon: const Icon(Icons.restart_alt_rounded, color: AppColors.warning, size: 18),
              label: const Text('Reset', style: TextStyle(color: AppColors.warning, fontSize: 13)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Admin Badge Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  HugeIcon(icon: HugeIcons.strokeRoundedSecurity, color: AppColors.primary, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'EVHub Admin Portal — Non-Destructive Safe Importer',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Error Banner if any
            if (bulkProvider.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.danger),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        bulkProvider.errorMessage!,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Source Selector: Open Charge Map India (Default) vs NREL API vs CSV Upload
            _buildSourceSelector(bulkProvider),
            const SizedBox(height: 20),

            // Step 1: Import Source Section
            if (bulkProvider.sourceMode == ImportSourceMode.openChargeMapIndia)
              _buildOcmIndiaSection(bulkProvider, adminProvider)
            else if (bulkProvider.sourceMode == ImportSourceMode.nrelApi)
              _buildNrelApiSection(bulkProvider, adminProvider)
            else
              _buildUploadSection(bulkProvider, adminProvider, currentUser),
            const SizedBox(height: 24),

            // Preview & Validation Results Section
            if (bulkProvider.step == BulkImportStep.previewReady || bulkProvider.step == BulkImportStep.importing) ...[
              _buildValidationMetricsSummary(bulkProvider),
              const SizedBox(height: 20),
              _buildDataSafetyCard(bulkProvider),
              const SizedBox(height: 20),
              _buildPreviewTable(bulkProvider),
              const SizedBox(height: 24),
              if (bulkProvider.step == BulkImportStep.importing)
                _buildProgressCard(bulkProvider)
              else
                _buildImportActions(bulkProvider, currentUser, adminProvider),
              const SizedBox(height: 24),
            ],

            // Step Completion Summary
            if (bulkProvider.step == BulkImportStep.complete) ...[
              _buildCompletionSummary(bulkProvider),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSourceSelector(BulkImportProvider bulkProvider) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => bulkProvider.setSourceMode(ImportSourceMode.openChargeMapIndia),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: bulkProvider.sourceMode == ImportSourceMode.openChargeMapIndia ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🇮🇳', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      'OCM — India',
                      style: TextStyle(
                        color: bulkProvider.sourceMode == ImportSourceMode.openChargeMapIndia ? Colors.black : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => bulkProvider.setSourceMode(ImportSourceMode.nrelApi),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: bulkProvider.sourceMode == ImportSourceMode.nrelApi ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🇺🇸', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      'NREL API',
                      style: TextStyle(
                        color: bulkProvider.sourceMode == ImportSourceMode.nrelApi ? Colors.black : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => bulkProvider.setSourceMode(ImportSourceMode.csvFile),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: bulkProvider.sourceMode == ImportSourceMode.csvFile ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.upload_file_rounded,
                      size: 16,
                      color: bulkProvider.sourceMode == ImportSourceMode.csvFile ? Colors.black : Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'CSV File',
                      style: TextStyle(
                        color: bulkProvider.sourceMode == ImportSourceMode.csvFile ? Colors.black : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOcmIndiaSection(BulkImportProvider bulkProvider, AdminChargerProvider adminProvider) {
    const limitList = [50, 100, 250, 500, 1000, 5000];

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text('🇮🇳', style: TextStyle(fontSize: 22)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Import India Chargers from Open Charge Map',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Fetch official public EV charging stations in India directly from Open Charge Map API (countrycode=IN). Automatically filters out non-India locations and invalid coordinates.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Filters Row
          Row(
            children: [
              // Fixed Country Filter
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Target Country', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: const [
                          Text('🇮🇳', style: TextStyle(fontSize: 16)),
                          SizedBox(width: 8),
                          Text('India (IN)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Maximum Results Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Max Results', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: bulkProvider.ocmLimit,
                          dropdownColor: AppColors.card,
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          items: limitList.map((lim) {
                            return DropdownMenuItem<int>(
                              value: lim,
                              child: Text('$lim Chargers'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) bulkProvider.setOcmLimit(val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Custom OCM API Key (Optional)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Open Charge Map API Key (Development / Demo Only)',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              const Text(
                'Production environment proxies API calls via Firebase Cloud Functions using Secrets Manager.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
              ),
              const SizedBox(height: 6),
              TextField(
                onChanged: (val) => bulkProvider.setCustomOcmApiKey(val),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Paste dev OCM API Key here...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Fetch Action Button
          SizedBox(
            width: double.infinity,
            child: PremiumButton(
              text: bulkProvider.isProcessing && bulkProvider.step == BulkImportStep.parsing
                  ? 'Fetching & Validating India Chargers (${bulkProvider.progressCurrent})...'
                  : 'Fetch India Chargers & Preview',
              icon: Icons.travel_explore_rounded,
              isLoading: bulkProvider.isProcessing && bulkProvider.step == BulkImportStep.parsing,
              onPressed: () {
                if (!bulkProvider.isProcessing) {
                  bulkProvider.fetchFromOpenChargeMapApi(existingChargers: adminProvider.allChargers);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNrelApiSection(BulkImportProvider bulkProvider, AdminChargerProvider adminProvider) {
    const statesList = ['ALL', 'CA', 'NY', 'TX', 'FL', 'WA', 'IL', 'MA', 'NC', 'CO', 'GA', 'PA', 'OH'];
    const limitList = [50, 100, 250, 500];

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.cloud_download_rounded, color: AppColors.primary, size: 22),
              SizedBox(width: 10),
              Text(
                'Import from NREL Alternative Fuel Stations API',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Fetch official public EV station data directly from the U.S. Department of Energy NREL API.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Filters Row
          Row(
            children: [
              // State Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('U.S. State Filter', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: bulkProvider.selectedState,
                          dropdownColor: AppColors.card,
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          items: statesList.map((st) {
                            return DropdownMenuItem<String>(
                              value: st,
                              child: Text(st == 'ALL' ? 'All U.S. States' : st),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) bulkProvider.setSelectedState(val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Limit Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Station Limit', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: bulkProvider.apiLimit,
                          dropdownColor: AppColors.card,
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          items: limitList.map((lim) {
                            return DropdownMenuItem<int>(
                              value: lim,
                              child: Text('$lim Stations'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) bulkProvider.setApiLimit(val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Custom API Key (Optional)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('NREL API Key (Optional — Defaults to DEMO_KEY)', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                onChanged: (val) => bulkProvider.setCustomApiKey(val),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Paste custom NREL API Key here...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Fetch Action Button
          SizedBox(
            width: double.infinity,
            child: PremiumButton(
              text: bulkProvider.isProcessing && bulkProvider.step == BulkImportStep.parsing
                  ? 'Fetching & Validating NREL Data...'
                  : 'Fetch Data & Preview Chargers',
              icon: Icons.travel_explore_rounded,
              isLoading: bulkProvider.isProcessing && bulkProvider.step == BulkImportStep.parsing,
              onPressed: () {
                if (!bulkProvider.isProcessing) {
                  bulkProvider.fetchFromNrelApi(existingChargers: adminProvider.allChargers);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadSection(BulkImportProvider bulkProvider, AdminChargerProvider adminProvider, UserModel user) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '1. Select CSV File',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              OutlinedButton.icon(
                onPressed: () => bulkProvider.downloadTemplate(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const HugeIcon(icon: HugeIcons.strokeRoundedFileDownload, color: AppColors.primary, size: 16),
                label: const Text('Download CSV Template', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          InkWell(
            onTap: bulkProvider.isProcessing
                ? null
                : () => bulkProvider.pickAndProcessCsv(existingChargers: adminProvider.allChargers),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.4),
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: Center(
                child: Column(
                  children: [
                    if (bulkProvider.isProcessing && bulkProvider.step == BulkImportStep.parsing) ...[
                      const CircularProgressIndicator(color: AppColors.primary),
                      const SizedBox(height: 16),
                      const Text('Parsing & Validating CSV File...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const HugeIcon(icon: HugeIcons.strokeRoundedUpload01, color: AppColors.primary, size: 32),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        bulkProvider.fileName ?? 'Click to Choose CSV File from Device',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Supports headers: name, network, address, latitude, longitude, totalConnectors, availableConnectors, power, etc.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationMetricsSummary(BulkImportProvider bulkProvider) {
    final int totalRecords = bulkProvider.totalApiRecords > 0
        ? bulkProvider.totalApiRecords
        : bulkProvider.totalRows;
    final int totalRejected = bulkProvider.nonIndiaRejectedCount +
        bulkProvider.invalidCoordCount +
        bulkProvider.invalidRowsCount;

    return Column(
      children: [
        Row(
          children: [
            _buildMetricCard('Total Fetched', '$totalRecords', HugeIcons.strokeRoundedDocumentCode, AppColors.primary),
            const SizedBox(width: 12),
            _buildMetricCard('Valid India', '${bulkProvider.validRowsCount}', HugeIcons.strokeRoundedCheckmarkCircle01, AppColors.secondary),
            const SizedBox(width: 12),
            _buildMetricCard('Duplicates', '${bulkProvider.duplicateRowsCount}', HugeIcons.strokeRoundedAlert02, AppColors.warning),
            const SizedBox(width: 12),
            _buildMetricCard('Rejected/Invalid', '$totalRejected', HugeIcons.strokeRoundedCancel01, AppColors.danger),
          ],
        ),
        if (bulkProvider.nonIndiaRejectedCount > 0 || bulkProvider.invalidCoordCount > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rejection Breakdown: ${bulkProvider.nonIndiaRejectedCount} Non-India records • ${bulkProvider.invalidCoordCount} Invalid Coordinates',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, List<List<dynamic>> icon, Color color) {
    return Expanded(
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HugeIcon(icon: icon, color: color, size: 20),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSafetyCard(BulkImportProvider bulkProvider) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_outlined, color: AppColors.secondary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Data Safety & Deduplication Protection',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'You are about to import ${bulkProvider.validRowsCount} new EVHub Verified chargers into Firestore. '
                  '${bulkProvider.duplicateRowsCount} duplicate chargers within 100m will be safely skipped. '
                  'Existing Firestore chargers will NOT be overwritten.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTable(BulkImportProvider bulkProvider) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CSV Row Preview & Validation Inspection',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (bulkProvider.invalidRowsCount > 0)
                OutlinedButton.icon(
                  onPressed: () => bulkProvider.downloadErrorReport(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.download, size: 14),
                  label: const Text('Download Error Report', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            constraints: const BoxConstraints(maxHeight: 320),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: ListView.separated(
              itemCount: bulkProvider.validationResults.length,
              separatorBuilder: (ctx, idx) => const Divider(color: Colors.white10, height: 1),
              itemBuilder: (ctx, index) {
                final item = bulkProvider.validationResults[index];
                return ExpansionTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 12,
                    backgroundColor: item.isValid
                        ? (item.isDuplicate ? AppColors.warning.withOpacity(0.2) : AppColors.secondary.withOpacity(0.2))
                        : AppColors.danger.withOpacity(0.2),
                    child: Text(
                      '${item.rowNumber}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: item.isValid
                            ? (item.isDuplicate ? AppColors.warning : AppColors.secondary)
                            : AppColors.danger,
                      ),
                    ),
                  ),
                  title: Text(
                    item.rawValues['name'] ?? 'Unknown Station',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: Text(
                    '${item.rawValues['network']} • ${item.rawValues['city']} (${item.rawValues['latitude']}, ${item.rawValues['longitude']})',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getStatusBgColor(item),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _getStatusBorderColor(item)),
                    ),
                    child: Text(
                      item.statusLabel,
                      style: TextStyle(color: _getStatusBorderColor(item), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.white.withOpacity(0.02),
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!item.isValid) ...[
                            const Text('Validation Errors:', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            ...item.errors.map((e) => Text('• $e', style: const TextStyle(color: Colors.white70, fontSize: 11))),
                          ],
                          if (item.isDuplicate && item.existingDuplicateCharger != null) ...[
                            const Text('Duplicate Comparison:', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('Existing Match: "${item.existingDuplicateCharger!.title}" (${item.existingDuplicateCharger!.network})', style: const TextStyle(color: Colors.white, fontSize: 11)),
                            Text('Distance Gap: ${item.duplicateDistanceMeters?.toStringAsFixed(1)} meters', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportActions(BulkImportProvider bulkProvider, UserModel user, AdminChargerProvider adminProvider) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => bulkProvider.reset(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Cancel Import'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: PremiumButton(
              text: 'Import ${bulkProvider.validRowsCount} New Chargers',
              icon: Icons.upload_file_rounded,
              isLoading: bulkProvider.isProcessing,
              onPressed: bulkProvider.validRowsCount == 0
                  ? () {}
                  : () async {
                      final bool confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: AppColors.card,
                              title: const Text('Confirm Bulk Import', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              content: Text(
                                'You are about to add ${bulkProvider.validRowsCount} new EVHub Verified chargers to Firestore. '
                                '${bulkProvider.duplicateRowsCount} duplicates will be skipped. Proceed?',
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Confirm & Import', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ) ??
                          false;

                      if (confirm && mounted) {
                        final success = await bulkProvider.executeImport(adminUser: user);
                        if (success && mounted) {
                          adminProvider.loadChargers(currentUser: user);
                        }
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(BulkImportProvider bulkProvider) {
    final double pct = bulkProvider.progressTotal > 0
        ? (bulkProvider.progressCurrent / bulkProvider.progressTotal).clamp(0.0, 1.0)
        : 0.0;

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Importing Chargers to Firestore...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${(pct * 100).toStringAsFixed(0)}%', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.white10,
            color: AppColors.primary,
            minHeight: 10,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 12),
          Text(
            'Progress: ${bulkProvider.progressCurrent} / ${bulkProvider.progressTotal} chargers written in batch chunks.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionSummary(BulkImportProvider bulkProvider) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.black, size: 36),
          ),
          const SizedBox(height: 16),
          const Text('Bulk Import Complete!', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('New chargers are immediately live on the EVHub map as ⭐ EVHub Verified.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total CSV Rows', '${bulkProvider.totalRows}', Colors.white),
              _buildStatItem('Successfully Imported', '${bulkProvider.importedCount}', AppColors.secondary),
              _buildStatItem('Skipped Duplicates', '${bulkProvider.skippedDuplicateCount}', AppColors.warning),
              _buildStatItem('Failed Rows', '${bulkProvider.invalidRowsCount}', AppColors.danger),
            ],
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              if (bulkProvider.invalidRowsCount > 0)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => bulkProvider.downloadErrorReport(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download Error Report', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              if (bulkProvider.invalidRowsCount > 0) const SizedBox(width: 16),
              Expanded(
                child: PremiumButton(
                  text: 'Done & Return to Dashboard',
                  icon: Icons.check_circle_outline,
                  onPressed: () {
                    bulkProvider.reset();
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }

  Color _getStatusBgColor(CsvRowValidationResult item) {
    if (!item.isValid) return AppColors.danger.withOpacity(0.15);
    if (item.isDuplicate) return AppColors.warning.withOpacity(0.15);
    return AppColors.secondary.withOpacity(0.15);
  }

  Color _getStatusBorderColor(CsvRowValidationResult item) {
    if (!item.isValid) return AppColors.danger;
    if (item.isDuplicate) return AppColors.warning;
    return AppColors.secondary;
  }
}
