import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/map_marker_model.dart';
import '../models/user_model.dart';
import '../services/csv_import_service.dart';
import '../services/file_download_helper.dart';

enum BulkImportStep { idle, parsing, previewReady, importing, complete }

class BulkImportProvider extends ChangeNotifier {
  final CsvImportService _importService = CsvImportService();

  BulkImportStep _step = BulkImportStep.idle;
  String? _fileName;
  Uint8List? _fileBytes;

  List<CsvRowValidationResult> _validationResults = [];
  String _importStrategy = 'Import New Only';

  bool _isProcessing = false;
  String? _errorMessage;

  int _importedCount = 0;
  int _skippedDuplicateCount = 0;
  int _progressCurrent = 0;
  int _progressTotal = 0;

  // Getters
  BulkImportStep get step => _step;
  String? get fileName => _fileName;
  List<CsvRowValidationResult> get validationResults => _validationResults;
  String get importStrategy => _importStrategy;
  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;

  int get totalRows => _validationResults.length;
  int get validRowsCount => _validationResults.where((r) => r.isValid && !r.isDuplicate).length;
  int get invalidRowsCount => _validationResults.where((r) => !r.isValid).length;
  int get duplicateRowsCount => _validationResults.where((r) => r.isValid && r.isDuplicate).length;

  int get importedCount => _importedCount;
  int get skippedDuplicateCount => _skippedDuplicateCount;
  int get progressCurrent => _progressCurrent;
  int get progressTotal => _progressTotal;

  List<MapMarkerModel> get chargersToImport => _validationResults
      .where((r) => r.isValid && !r.isDuplicate && r.parsedModel != null)
      .map((r) => r.parsedModel!)
      .toList();

  void setImportStrategy(String strategy) {
    _importStrategy = strategy;
    notifyListeners();
  }

  void reset() {
    _step = BulkImportStep.idle;
    _fileName = null;
    _fileBytes = null;
    _validationResults = [];
    _errorMessage = null;
    _isProcessing = false;
    _importedCount = 0;
    _skippedDuplicateCount = 0;
    _progressCurrent = 0;
    _progressTotal = 0;
    notifyListeners();
  }

  /// Select CSV file cross-platform using file_picker byte loading
  Future<void> pickAndProcessCsv({required List<MapMarkerModel> existingChargers}) async {
    _isProcessing = true;
    _errorMessage = null;
    _step = BulkImportStep.parsing;
    notifyListeners();

    try {
      final FilePickerResult? pickerResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (pickerResult == null || pickerResult.files.isEmpty) {
        _isProcessing = false;
        _step = BulkImportStep.idle;
        notifyListeners();
        return;
      }

      final PlatformFile file = pickerResult.files.first;
      _fileName = file.name;
      _fileBytes = file.bytes;

      if (_fileBytes == null || _fileBytes!.isEmpty) {
        throw Exception('Selected CSV file is empty or could not be read');
      }

      // Process CSV
      _validationResults = _importService.processCsv(
        bytes: _fileBytes!,
        existingFirestoreChargers: existingChargers,
      );

      _step = BulkImportStep.previewReady;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _step = BulkImportStep.idle;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Download CSV Template
  void downloadTemplate() {
    final templateText = CsvImportService.generateCsvTemplate();
    FileDownloadHelper.downloadCsv(
      csvContent: templateText,
      filename: 'evhub_chargers_template.csv',
    );
  }

  /// Download CSV Error Report
  void downloadErrorReport() {
    if (_validationResults.isEmpty) return;
    final reportText = CsvImportService.generateErrorReport(_validationResults);
    FileDownloadHelper.downloadCsv(
      csvContent: reportText,
      filename: 'evhub_import_error_report.csv',
    );
  }

  /// Execute Firestore Batch Write Import
  Future<bool> executeImport({required UserModel adminUser}) async {
    if (!adminUser.isAdmin) {
      _errorMessage = 'Only administrators can perform bulk charger imports.';
      notifyListeners();
      return false;
    }

    final toImport = chargersToImport;
    if (toImport.isEmpty) {
      _errorMessage = 'No valid new chargers available for import.';
      notifyListeners();
      return false;
    }

    _isProcessing = true;
    _step = BulkImportStep.importing;
    _progressCurrent = 0;
    _progressTotal = toImport.length;
    _skippedDuplicateCount = duplicateRowsCount;
    notifyListeners();

    try {
      final int count = await _importService.performBatchImport(
        chargersToImport: toImport,
        adminUid: adminUser.id,
        adminName: adminUser.name,
        onProgress: (processed, total) {
          _progressCurrent = processed;
          _progressTotal = total;
          notifyListeners();
        },
      );

      _importedCount = count;
      _step = BulkImportStep.complete;
      return true;
    } catch (e) {
      _errorMessage = 'Import failed: ${e.toString().replaceAll("Exception: ", "")}';
      _step = BulkImportStep.previewReady;
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }
}
