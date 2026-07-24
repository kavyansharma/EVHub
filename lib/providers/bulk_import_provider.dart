import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/map_marker_model.dart';
import '../models/user_model.dart';
import '../services/bulk_data_source.dart';
import '../services/csv_import_service.dart';
import '../services/file_download_helper.dart';
import '../services/nrel_charger_data_source.dart';
import '../services/open_charge_map_charger_data_source.dart';

enum BulkImportStep { idle, parsing, previewReady, importing, complete }

enum ImportSourceMode { openChargeMapIndia, nrelApi, csvFile }

class BulkImportProvider extends ChangeNotifier {
  final CsvImportService _importService = CsvImportService();
  final BulkChargerDataSource _nrelDataSource;
  final BulkChargerDataSource _ocmDataSource;

  BulkImportProvider({
    BulkChargerDataSource? nrelDataSource,
    BulkChargerDataSource? ocmDataSource,
  })  : _nrelDataSource = nrelDataSource ?? NrelChargerDataSource(),
        _ocmDataSource = ocmDataSource ?? OpenChargeMapChargerDataSource();

  BulkImportStep _step = BulkImportStep.idle;
  ImportSourceMode _sourceMode = ImportSourceMode.openChargeMapIndia;

  // Open Charge Map Options
  int _ocmLimit = 250;
  String _customOcmApiKey = '';

  // NREL API Options
  String _selectedState = 'ALL';
  int _apiLimit = 100;
  String _customApiKey = '';

  // CSV State
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

  int _totalApiRecords = 0;
  int _nonIndiaRejectedCount = 0;
  int _invalidCoordCount = 0;

  // Getters
  BulkImportStep get step => _step;
  ImportSourceMode get sourceMode => _sourceMode;
  int get ocmLimit => _ocmLimit;
  String get customOcmApiKey => _customOcmApiKey;
  String get selectedState => _selectedState;
  int get apiLimit => _apiLimit;
  String get customApiKey => _customApiKey;
  String? get fileName => _fileName;
  List<CsvRowValidationResult> get validationResults => _validationResults;
  String get importStrategy => _importStrategy;
  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;

  int get totalApiRecords => _totalApiRecords;
  int get nonIndiaRejectedCount => _nonIndiaRejectedCount;
  int get invalidCoordCount => _invalidCoordCount;

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

  void setSourceMode(ImportSourceMode mode) {
    _sourceMode = mode;
    notifyListeners();
  }

  void setOcmLimit(int limit) {
    _ocmLimit = limit;
    notifyListeners();
  }

  void setCustomOcmApiKey(String key) {
    _customOcmApiKey = key;
    notifyListeners();
  }

  void setSelectedState(String state) {
    _selectedState = state;
    notifyListeners();
  }

  void setApiLimit(int limit) {
    _apiLimit = limit;
    notifyListeners();
  }

  void setCustomApiKey(String key) {
    _customApiKey = key;
    notifyListeners();
  }

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
    _totalApiRecords = 0;
    _nonIndiaRejectedCount = 0;
    _invalidCoordCount = 0;
    notifyListeners();
  }

  /// Fetches Indian EV charging stations from Open Charge Map API and performs deduplication.
  Future<void> fetchFromOpenChargeMapApi({
    required List<MapMarkerModel> existingChargers,
    BulkChargerDataSource? customDataSource,
  }) async {
    _isProcessing = true;
    _errorMessage = null;
    _step = BulkImportStep.parsing;
    _progressCurrent = 0;
    _progressTotal = _ocmLimit;
    _totalApiRecords = 0;
    _nonIndiaRejectedCount = 0;
    _invalidCoordCount = 0;
    notifyListeners();

    try {
      final dataSource = customDataSource ?? _ocmDataSource;
      List<MapMarkerModel> fetched = [];

      if (dataSource is OpenChargeMapChargerDataSource) {
        final statsResult = await dataSource.fetchChargersWithStats(options: {
          'apiKey': _customOcmApiKey.isNotEmpty ? _customOcmApiKey : null,
          'limit': _ocmLimit,
          'onProgress': (count, page) {
            _progressCurrent = count;
            notifyListeners();
          },
        });
        fetched = statsResult.validChargers;
        _totalApiRecords = statsResult.totalApiRecords;
        _nonIndiaRejectedCount = statsResult.nonIndiaRejectedCount;
        _invalidCoordCount = statsResult.invalidCoordCount;
      } else {
        fetched = await dataSource.fetchChargers(options: {
          'apiKey': _customOcmApiKey.isNotEmpty ? _customOcmApiKey : null,
          'limit': _ocmLimit,
          'onProgress': (count, page) {
            _progressCurrent = count;
            notifyListeners();
          },
        });
        _totalApiRecords = fetched.length;
      }

      if (fetched.isEmpty) {
        throw Exception('No valid EV chargers were returned from Open Charge Map for India.');
      }

      _validationResults = _importService.processFetchedChargers(
        fetchedChargers: fetched,
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

  /// Fetches EV charging station records from the U.S. NREL API and runs deduplication.
  Future<void> fetchFromNrelApi({
    required List<MapMarkerModel> existingChargers,
    BulkChargerDataSource? customDataSource,
  }) async {
    _isProcessing = true;
    _errorMessage = null;
    _step = BulkImportStep.parsing;
    notifyListeners();

    try {
      final dataSource = customDataSource ?? _nrelDataSource;
      final fetched = await dataSource.fetchChargers(options: {
        'apiKey': _customApiKey.isNotEmpty ? _customApiKey : null,
        'state': _selectedState,
        'limit': _apiLimit,
      });

      if (fetched.isEmpty) {
        throw Exception('No EV chargers were returned from NREL API for the selected filters.');
      }

      _validationResults = _importService.processFetchedChargers(
        fetchedChargers: fetched,
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
