import '../models/map_marker_model.dart';

/// Abstract interface for bulk EV charger data sources.
/// Allows plugging in different APIs or file parsers (e.g. NREL, OpenChargeMap, CSV)
/// cleanly without rewriting the importer UI or provider workflow.
abstract class BulkChargerDataSource {
  /// Unique identifier for this data source (e.g. 'nrel_api', 'csv_file', 'open_charge_map')
  String get sourceId;

  /// Human-readable display name for this data source
  String get sourceName;

  /// Fetches raw data from the external source and maps it into EVHub [MapMarkerModel]s.
  /// Options can pass filters like API keys, state, city, limit, or file bytes.
  Future<List<MapMarkerModel>> fetchChargers({
    Map<String, dynamic>? options,
  });
}
