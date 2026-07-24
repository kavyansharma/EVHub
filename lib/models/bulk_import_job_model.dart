/// Represents an administrative EV charger bulk import / incremental sync job.
/// Persisted in memory and in Firestore `/import_jobs/{jobId}` for audit history.
class BulkImportJobModel {
  final String jobId;
  final String startedAt;
  final String? completedAt;
  final String status; // 'in_progress', 'completed', 'failed', 'cancelled'
  final String source; // 'open_charge_map', 'nrel', 'csv'
  final bool isDryRun;
  final bool isSyncMode;
  final int requestedCount;
  final int processedCount;
  final int createdCount;
  final int updatedCount;
  final int skippedCount;
  final int errorCount;
  final int staleCount;
  final int lastProcessedPage;
  final String createdBy;
  final String? errorMessage;

  const BulkImportJobModel({
    required this.jobId,
    required this.startedAt,
    this.completedAt,
    required this.status,
    required this.source,
    this.isDryRun = false,
    this.isSyncMode = true,
    this.requestedCount = 0,
    this.processedCount = 0,
    this.createdCount = 0,
    this.updatedCount = 0,
    this.skippedCount = 0,
    this.errorCount = 0,
    this.staleCount = 0,
    this.lastProcessedPage = 1,
    required this.createdBy,
    this.errorMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'jobId': jobId,
      'startedAt': startedAt,
      'completedAt': completedAt,
      'status': status,
      'source': source,
      'isDryRun': isDryRun,
      'isSyncMode': isSyncMode,
      'requestedCount': requestedCount,
      'processedCount': processedCount,
      'createdCount': createdCount,
      'updatedCount': updatedCount,
      'skippedCount': skippedCount,
      'errorCount': errorCount,
      'staleCount': staleCount,
      'lastProcessedPage': lastProcessedPage,
      'createdBy': createdBy,
      'errorMessage': errorMessage,
    };
  }

  factory BulkImportJobModel.fromMap(Map<String, dynamic> map, String id) {
    return BulkImportJobModel(
      jobId: map['jobId'] as String? ?? id,
      startedAt: map['startedAt'] as String? ?? DateTime.now().toIso8601String(),
      completedAt: map['completedAt'] as String?,
      status: map['status'] as String? ?? 'completed',
      source: map['source'] as String? ?? 'open_charge_map',
      isDryRun: map['isDryRun'] as bool? ?? false,
      isSyncMode: map['isSyncMode'] as bool? ?? true,
      requestedCount: (map['requestedCount'] as num?)?.toInt() ?? 0,
      processedCount: (map['processedCount'] as num?)?.toInt() ?? 0,
      createdCount: (map['createdCount'] as num?)?.toInt() ?? 0,
      updatedCount: (map['updatedCount'] as num?)?.toInt() ?? 0,
      skippedCount: (map['skippedCount'] as num?)?.toInt() ?? 0,
      errorCount: (map['errorCount'] as num?)?.toInt() ?? 0,
      staleCount: (map['staleCount'] as num?)?.toInt() ?? 0,
      lastProcessedPage: (map['lastProcessedPage'] as num?)?.toInt() ?? 1,
      createdBy: map['createdBy'] as String? ?? 'admin',
      errorMessage: map['errorMessage'] as String?,
    );
  }

  BulkImportJobModel copyWith({
    String? jobId,
    String? startedAt,
    String? completedAt,
    String? status,
    String? source,
    bool? isDryRun,
    bool? isSyncMode,
    int? requestedCount,
    int? processedCount,
    int? createdCount,
    int? updatedCount,
    int? skippedCount,
    int? errorCount,
    int? staleCount,
    int? lastProcessedPage,
    String? createdBy,
    String? errorMessage,
  }) {
    return BulkImportJobModel(
      jobId: jobId ?? this.jobId,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      status: status ?? this.status,
      source: source ?? this.source,
      isDryRun: isDryRun ?? this.isDryRun,
      isSyncMode: isSyncMode ?? this.isSyncMode,
      requestedCount: requestedCount ?? this.requestedCount,
      processedCount: processedCount ?? this.processedCount,
      createdCount: createdCount ?? this.createdCount,
      updatedCount: updatedCount ?? this.updatedCount,
      skippedCount: skippedCount ?? this.skippedCount,
      errorCount: errorCount ?? this.errorCount,
      staleCount: staleCount ?? this.staleCount,
      lastProcessedPage: lastProcessedPage ?? this.lastProcessedPage,
      createdBy: createdBy ?? this.createdBy,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
