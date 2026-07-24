import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/premium_button.dart';
import '../../services/maps_service.dart';

class LocationPickerResult {
  final double latitude;
  final double longitude;
  final String address;

  const LocationPickerResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}

class LocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialAddress;

  const LocationPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialAddress,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapsService _mapsService = MapsService();
  GoogleMapController? _mapController;

  late LatLng _selectedLocation;
  String _selectedAddress = 'Fetching address...';
  bool _isGeocoding = false;

  // Search Autocomplete state
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _suggestions = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    final double lat = widget.initialLat ?? 28.6304; // New Delhi default
    final double lng = widget.initialLng ?? 77.2177;
    _selectedLocation = LatLng(lat, lng);

    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _selectedAddress = widget.initialAddress!;
    } else {
      _updateAddressForLocation(_selectedLocation);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _updateAddressForLocation(LatLng location) async {
    setState(() {
      _isGeocoding = true;
    });

    try {
      final address = await _mapsService.getAddressFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (mounted) {
        setState(() {
          _selectedAddress = address;
          _isGeocoding = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _selectedAddress = 'Lat: ${location.latitude.toStringAsFixed(4)}, Lng: ${location.longitude.toStringAsFixed(4)}';
          _isGeocoding = false;
        });
      }
    }
  }

  Future<void> _moveToCurrentLocation() async {
    try {
      final locMap = await _mapsService.getCurrentLocation();
      final latLng = LatLng(locMap['latitude']!, locMap['longitude']!);

      setState(() {
        _selectedLocation = latLng;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 16.0),
      );

      _updateAddressForLocation(latLng);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get current location: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _onSearchQueryChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      setState(() {
        _isSearching = true;
      });

      final results = await _mapsService.getAutocompleteSuggestions(
        query,
        currentLat: _selectedLocation.latitude,
        currentLng: _selectedLocation.longitude,
      );

      if (mounted) {
        setState(() {
          _suggestions = results;
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _selectSuggestion(Map<String, dynamic> suggestion) async {
    final placeId = suggestion['place_id'] as String?;
    final desc = suggestion['description'] as String?;
    if (placeId == null) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = [];
      _searchController.text = desc ?? '';
    });

    final coords = await _mapsService.getPlaceCoordinates(placeId);
    if (coords != null) {
      setState(() {
        _selectedLocation = coords;
        _selectedAddress = desc ?? 'Selected Location';
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(coords, 16.0),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Select Location on Map',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          // 1. Google Map View
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLocation,
              zoom: 15.0,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: (position) {
              _selectedLocation = position.target;
            },
            onCameraIdle: () {
              _updateAddressForLocation(_selectedLocation);
            },
            markers: {
              Marker(
                markerId: const MarkerId('selected_pin'),
                position: _selectedLocation,
                draggable: true,
                onDragEnd: (newPos) {
                  setState(() {
                    _selectedLocation = newPos;
                  });
                  _updateAddressForLocation(newPos);
                },
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // 2. Center Pin Marker Overlay
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: AppColors.neonShadow(color: AppColors.primary, blurRadius: 16),
                    ),
                    child: const Icon(Icons.location_on, color: Colors.black, size: 28),
                  ),
                  Container(
                    width: 4,
                    height: 12,
                    color: AppColors.primary,
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Top Autocomplete Search Bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                GlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  borderRadius: 20,
                  child: Row(
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
                          onChanged: _onSearchQueryChanged,
                          decoration: const InputDecoration(
                            hintText: 'Search city, landmark or place...',
                            hintStyle: TextStyle(color: AppColors.textSecondary),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      if (_isSearching)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      else if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _suggestions = [];
                            });
                          },
                        ),
                    ],
                  ),
                ),

                // Suggestions dropdown list
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                      boxShadow: AppColors.softShadow(),
                    ),
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _suggestions.length,
                      separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (context, index) {
                        final item = _suggestions[index];
                        return ListTile(
                          dense: true,
                          leading: const HugeIcon(
                            icon: HugeIcons.strokeRoundedLocation01,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          title: Text(
                            item['description'] ?? '',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                          onTap: () => _selectSuggestion(item),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // 4. Current Location Button
          Positioned(
            right: 16,
            bottom: 180,
            child: FloatingActionButton(
              heroTag: 'location_picker_gps',
              backgroundColor: AppColors.card,
              onPressed: _moveToCurrentLocation,
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedGps01,
                color: AppColors.primary,
                size: 24,
              ),
            ),
          ),

          // 5. Bottom Card with Selected Address & Confirm Button
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: GlassContainer(
              padding: const EdgeInsets.all(20),
              borderRadius: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const HugeIcon(
                          icon: HugeIcons.strokeRoundedMapsLocation01,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selected Location',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _isGeocoding
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                  )
                                : Text(
                                    _selectedAddress,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Chip(
                        backgroundColor: Colors.white.withOpacity(0.08),
                        label: Text(
                          'Lat: ${_selectedLocation.latitude.toStringAsFixed(5)}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        backgroundColor: Colors.white.withOpacity(0.08),
                        label: Text(
                          'Lng: ${_selectedLocation.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PremiumButton(
                    text: 'Confirm Location',
                    icon: Icons.check_circle_outline,
                    onPressed: () {
                      Navigator.of(context).pop(
                        LocationPickerResult(
                          latitude: _selectedLocation.latitude,
                          longitude: _selectedLocation.longitude,
                          address: _selectedAddress,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
