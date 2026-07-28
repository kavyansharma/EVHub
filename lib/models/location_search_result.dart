import 'package:google_maps_flutter/google_maps_flutter.dart';

enum LocationSearchResultSource { googlePlaces, localFallback }

class LocationSearchResult {
  final String displayName;
  final String? subtitle;
  final double latitude;
  final double longitude;
  final String? placeId;
  final LocationSearchResultSource source;

  const LocationSearchResult({
    required this.displayName,
    this.subtitle,
    required this.latitude,
    required this.longitude,
    this.placeId,
    required this.source,
  });

  LatLng get coordinates => LatLng(latitude, longitude);

  Map<String, dynamic> toSuggestionMap() {
    return {
      'description': displayName,
      'subtitle': subtitle ?? (source == LocationSearchResultSource.localFallback ? 'City search' : 'Location search'),
      'place_id': placeId ?? '',
      'type': 'location',
      'latitude': latitude,
      'longitude': longitude,
      'source': source == LocationSearchResultSource.googlePlaces ? 'google_places' : 'local_fallback',
    };
  }
}
