// ignore_for_file: unused_element
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/premium_button.dart';
import '../../models/location_search_result.dart';
import '../../models/vehicle_model.dart';
import '../../providers/maps_provider.dart';
import '../../services/maps_service.dart';
import '../../services/vehicle_service.dart';
import 'in_app_navigation_screen.dart';

// ─── Color palette ──────────────────────────────────────────────────────────
const Color _kGreen  = Color(0xFF10B981);
const Color _kOrange = Color(0xFFF59E0B);
const Color _kRed    = Color(0xFFEF4444);
const Color _kBlue   = Color(0xFF3B82F6);
const Color _kCard   = Color(0xFF141724);

class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController   = TextEditingController();
  final FocusNode _startFocusNode = FocusNode();
  final FocusNode _endFocusNode   = FocusNode();

  MapsService get _mapsService => context.read<MapsProvider>().mapsService;

  LocationSearchResult? _selectedOrigin;
  LocationSearchResult? _selectedDestination;

  List<LocationSearchResult> _startSuggestions = [];
  List<LocationSearchResult> _endSuggestions   = [];
  Timer? _debounceTimer;

  bool _isSearchingStart = false;
  bool _isSearchingEnd   = false;
  bool _isPlanningTrip   = false;
  bool _isGpsOrigin      = false;

  // Preset popular city routes
  static const List<Map<String, dynamic>> _quickRoutes = [
    {
      'label': 'Delhi → Jaipur',
      'origin': LocationSearchResult(
        displayName: 'New Delhi, Delhi',
        subtitle: 'Capital Region',
        latitude: 28.6139,
        longitude: 77.2090,
        source: LocationSearchResultSource.localFallback,
      ),
      'destination': LocationSearchResult(
        displayName: 'Jaipur, Rajasthan',
        subtitle: 'Pink City',
        latitude: 26.9124,
        longitude: 75.7873,
        source: LocationSearchResultSource.localFallback,
      ),
    },
    {
      'label': 'Mumbai → Pune',
      'origin': LocationSearchResult(
        displayName: 'Mumbai, Maharashtra',
        subtitle: 'Financial Capital',
        latitude: 19.0760,
        longitude: 72.8777,
        source: LocationSearchResultSource.localFallback,
      ),
      'destination': LocationSearchResult(
        displayName: 'Pune, Maharashtra',
        subtitle: 'Oxford of the East',
        latitude: 18.5204,
        longitude: 73.8567,
        source: LocationSearchResultSource.localFallback,
      ),
    },
    {
      'label': 'Bengaluru → Chennai',
      'origin': LocationSearchResult(
        displayName: 'Bengaluru, Karnataka',
        subtitle: 'Silicon Valley',
        latitude: 12.9716,
        longitude: 77.5946,
        source: LocationSearchResultSource.localFallback,
      ),
      'destination': LocationSearchResult(
        displayName: 'Chennai, Tamil Nadu',
        subtitle: 'Gateway to South',
        latitude: 13.0827,
        longitude: 80.2707,
        source: LocationSearchResultSource.localFallback,
      ),
    },
  ];

  @override
  void initState() {
    super.initState();
    _startFocusNode.addListener(() {
      if (!_startFocusNode.hasFocus) setState(() => _startSuggestions = []);
    });
    _endFocusNode.addListener(() {
      if (!_endFocusNode.hasFocus) setState(() => _endSuggestions = []);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MapsProvider>();
      if (provider.tripOrigin != null) {
        _selectedOrigin = provider.tripOrigin;
        _startController.text = provider.tripOrigin!.displayName;
      }
      if (provider.tripDestination != null) {
        _selectedDestination = provider.tripDestination;
        _endController.text = provider.tripDestination!.displayName;
      }
    });
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _startFocusNode.dispose();
    _endFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GPS & LOCATION HANDLING (Explicit User Trigger ONLY)
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _useCurrentLocation() async {
    setState(() => _isSearchingStart = true);
    try {
      final permission = await _mapsService.requestLocationPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _showSnackbar(
          'Location access is required to use your current location. You can also enter a starting location manually.',
          isError: true,
        );
        return;
      }

      final loc = await _mapsService.getCurrentLocation();
      final lat = loc['latitude']!;
      final lng = loc['longitude']!;
      final address = await _mapsService.getAddressFromCoordinates(lat, lng);

      final result = LocationSearchResult(
        displayName: address,
        subtitle: 'GPS Location',
        latitude: lat,
        longitude: lng,
        source: LocationSearchResultSource.googlePlaces,
      );

      setState(() {
        _selectedOrigin = result;
        _startController.text = address;
        _isGpsOrigin = true;
      });

      _showSnackbar('Current location set as starting point.');
    } catch (e) {
      _showSnackbar(
        'Location access is required to use your current location. You can also enter a starting location manually.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isSearchingStart = false);
    }
  }

  void _onQueryChanged(String query, bool isStart) {
    _debounceTimer?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        if (isStart) { _startSuggestions = []; _isSearchingStart = false; }
        else         { _endSuggestions   = []; _isSearchingEnd   = false; }
      });
      return;
    }

    setState(() {
      if (isStart) { _isSearchingStart = true; }
      else         { _isSearchingEnd   = true; }
    });

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      final cleanQuery = query.trim();
      final results = <LocationSearchResult>[];

      try {
        final rawPlaces = await _mapsService.getAutocompleteSuggestions(cleanQuery);
        for (final p in rawPlaces) {
          final desc = p['description'] as String? ?? cleanQuery;
          final lat  = (p['latitude']  as num?)?.toDouble() ?? 0.0;
          final lng  = (p['longitude'] as num?)?.toDouble() ?? 0.0;
          final pid  = p['place_id'] as String? ?? '';
          results.add(LocationSearchResult(
            displayName: desc,
            subtitle: p['subtitle'] as String? ?? 'Location search',
            latitude: lat,
            longitude: lng,
            placeId: pid,
            source: LocationSearchResultSource.googlePlaces,
          ));
        }
      } catch (e) {
        debugPrint('[RoutePlannerScreen] Autocomplete search error: $e');
      }

      const knownCities = [
        {'name': 'New Delhi, Delhi',       'lat': 28.6139, 'lng': 77.2090, 'sub': 'Capital Region'},
        {'name': 'Jaipur, Rajasthan',      'lat': 26.9124, 'lng': 75.7873, 'sub': 'Pink City'},
        {'name': 'Mumbai, Maharashtra',    'lat': 19.0760, 'lng': 72.8777, 'sub': 'Financial Capital'},
        {'name': 'Pune, Maharashtra',      'lat': 18.5204, 'lng': 73.8567, 'sub': 'Oxford of the East'},
        {'name': 'Bengaluru, Karnataka',   'lat': 12.9716, 'lng': 77.5946, 'sub': 'Silicon Valley'},
        {'name': 'Chennai, Tamil Nadu',    'lat': 13.0827, 'lng': 80.2707, 'sub': 'Gateway to South'},
        {'name': 'Hyderabad, Telangana',   'lat': 17.3850, 'lng': 78.4867, 'sub': 'Pearl City'},
      ];

      for (final city in knownCities) {
        final cName = city['name'] as String;
        if (cName.toLowerCase().contains(cleanQuery.toLowerCase()) &&
            !results.any((r) => r.displayName.toLowerCase() == cName.toLowerCase())) {
          results.add(LocationSearchResult(
            displayName: cName,
            subtitle: city['sub'] as String,
            latitude: city['lat'] as double,
            longitude: city['lng'] as double,
            source: LocationSearchResultSource.localFallback,
          ));
        }
      }

      if (mounted) {
        setState(() {
          if (isStart) { _startSuggestions = results; _isSearchingStart = false; }
          else         { _endSuggestions   = results; _isSearchingEnd   = false; }
        });
      }
    });
  }

  Future<void> _selectSuggestion(LocationSearchResult suggestion, bool isStart) async {
    setState(() {
      if (isStart) {
        _isSearchingStart = true;
        _startController.text = suggestion.displayName;
        _startSuggestions = [];
        _startFocusNode.unfocus();
        _isGpsOrigin = false;
      } else {
        _isSearchingEnd = true;
        _endController.text = suggestion.displayName;
        _endSuggestions = [];
        _endFocusNode.unfocus();
      }
    });

    LocationSearchResult resolved = suggestion;

    if (resolved.latitude == 0.0 || resolved.longitude == 0.0) {
      LatLng? coords;
      if (suggestion.placeId != null && suggestion.placeId!.isNotEmpty) {
        try {
          coords = await _mapsService.getPlaceCoordinates(suggestion.placeId!);
        } catch (_) {}
      }

      if (coords == null) {
        try {
          coords = await _mapsService.getCoordinatesFromAddress(suggestion.displayName);
        } catch (_) {}
      }

      if (coords != null) {
        resolved = LocationSearchResult(
          displayName: suggestion.displayName,
          subtitle: suggestion.subtitle,
          latitude: coords.latitude,
          longitude: coords.longitude,
          placeId: suggestion.placeId,
          source: suggestion.source,
        );
      } else {
        if (mounted) {
          setState(() {
            if (isStart) { _isSearchingStart = false; _startController.clear(); }
            else { _isSearchingEnd = false; _endController.clear(); }
          });
          _showSnackbar(
            isStart
                ? 'Could not find the starting location. Please try a more specific address.'
                : 'Could not find the destination. Please try a more specific location.',
            isError: true,
          );
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        if (isStart) {
          _selectedOrigin = resolved;
          _startController.text = resolved.displayName;
          _isSearchingStart = false;
        } else {
          _selectedDestination = resolved;
          _endController.text = resolved.displayName;
          _isSearchingEnd = false;
        }
      });
    }
  }

  void _swapLocations() {
    setState(() {
      final tmp = _selectedOrigin;
      _selectedOrigin = _selectedDestination;
      _selectedDestination = tmp;
      final tmpText = _startController.text;
      _startController.text = _endController.text;
      _endController.text = tmpText;
    });
  }

  void _applyQuickRoute(Map<String, dynamic> route) {
    setState(() {
      _selectedOrigin = route['origin'] as LocationSearchResult;
      _selectedDestination = route['destination'] as LocationSearchResult;
      _startController.text = _selectedOrigin!.displayName;
      _endController.text = _selectedDestination!.displayName;
      _startSuggestions = [];
      _endSuggestions = [];
      _isGpsOrigin = false;
    });
    _planTrip();
  }

  void _planTrip() async {
    if (_isPlanningTrip) return;
    final mp = context.read<MapsProvider>();
    if (mp.isLoadingRoute || mp.isLoading) return;

    setState(() => _isPlanningTrip = true);

    try {
      _startFocusNode.unfocus();
      _endFocusNode.unfocus();

      final startText = _startController.text.trim();
      final endText = _endController.text.trim();

      if (startText.isEmpty) {
        _showSnackbar('Please enter a starting location.', isError: true);
        return;
      }
      if (endText.isEmpty) {
        _showSnackbar('Could not find the destination. Please try a more specific location.', isError: true);
        return;
      }

      if (_selectedOrigin == null || (_selectedOrigin!.latitude == 0.0 && _selectedOrigin!.longitude == 0.0)) {
        try {
          final coords = await _mapsService.getCoordinatesFromAddress(startText);
          if (coords != null) {
            _selectedOrigin = LocationSearchResult(
              displayName: startText,
              subtitle: 'Address Location',
              latitude: coords.latitude,
              longitude: coords.longitude,
              source: LocationSearchResultSource.googlePlaces,
            );
          } else {
            _showSnackbar('Could not find the starting location. Please try a more specific address.', isError: true);
            return;
          }
        } catch (_) {
          _showSnackbar('Could not find the starting location. Please try a more specific address.', isError: true);
          return;
        }
      }

      if (_selectedDestination == null || (_selectedDestination!.latitude == 0.0 && _selectedDestination!.longitude == 0.0)) {
        try {
          final coords = await _mapsService.getCoordinatesFromAddress(endText);
          if (coords != null) {
            _selectedDestination = LocationSearchResult(
              displayName: endText,
              subtitle: 'Address Location',
              latitude: coords.latitude,
              longitude: coords.longitude,
              source: LocationSearchResultSource.googlePlaces,
            );
          } else {
            _showSnackbar('Could not find the destination. Please try a more specific location.', isError: true);
            return;
          }
        } catch (_) {
          _showSnackbar('Could not find the destination. Please try a more specific location.', isError: true);
          return;
        }
      }

      if (_selectedOrigin!.latitude == _selectedDestination!.latitude &&
          _selectedOrigin!.longitude == _selectedDestination!.longitude) {
        _showSnackbar('Start and destination must be different.', isError: true);
        return;
      }

      if (!mounted) return;
      await mp.planTrip(origin: _selectedOrigin!, destination: _selectedDestination!);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InAppNavigationScreen(
              origin: _selectedOrigin!,
              destination: _selectedDestination!,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPlanningTrip = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? Colors.amber : _kGreen, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: const Color(0xFF1A1D2E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UI BUILDERS
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MapsProvider>();

    final isCanPlan = _startController.text.trim().isNotEmpty &&
        _endController.text.trim().isNotEmpty &&
        !mp.isLoadingRoute &&
        !_isPlanningTrip;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Banner
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.route, color: _kGreen, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Smart EV Trip Planner',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Intelligent EV Route & Charger Planner',
                          style: GoogleFonts.outfit(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Locations Card (Start & Destination Input)
              GlassContainer(
                padding: const EdgeInsets.all(18),
                borderRadius: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Start Location Header with GPS Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.circle, color: _kGreen, size: 12),
                            const SizedBox(width: 8),
                            Text(
                              'Starting Location',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (_isGpsOrigin) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.gps_fixed, color: _kGreen, size: 14),
                            ],
                          ],
                        ),
                        TextButton.icon(
                          onPressed: _useCurrentLocation,
                          style: TextButton.styleFrom(
                            foregroundColor: _kGreen,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          icon: const Icon(Icons.my_location, size: 14),
                          label: Text(
                            '📍 Use Current Location',
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Start Input Field
                    TextField(
                      controller: _startController,
                      focusNode: _startFocusNode,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                      onChanged: (q) => _onQueryChanged(q, true),
                      decoration: InputDecoration(
                        hintText: 'Enter start address, city or landmark...',
                        hintStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        prefixIcon: _isSearchingStart
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: _kGreen),
                                ),
                              )
                            : const Icon(Icons.search, color: Colors.white54, size: 20),
                        suffixIcon: _startController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                                onPressed: () {
                                  _startController.clear();
                                  setState(() {
                                    _selectedOrigin = null;
                                    _startSuggestions = [];
                                    _isGpsOrigin = false;
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),

                    // Start Suggestions
                    if (_startSuggestions.isNotEmpty) _buildSuggestionList(_startSuggestions, true),

                    const SizedBox(height: 12),

                    // Divider & Swap Button
                    Row(
                      children: [
                        const Expanded(child: Divider(color: Colors.white10)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: InkWell(
                            onTap: _swapLocations,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.swap_vert, color: _kGreen, size: 20),
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: Colors.white10)),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Destination Header
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: _kRed, size: 14),
                        const SizedBox(width: 8),
                        Text(
                          'Destination Location',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Destination Input Field
                    TextField(
                      controller: _endController,
                      focusNode: _endFocusNode,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                      onChanged: (q) => _onQueryChanged(q, false),
                      decoration: InputDecoration(
                        hintText: 'Enter destination address, city or landmark...',
                        hintStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        prefixIcon: _isSearchingEnd
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: _kRed),
                                ),
                              )
                            : const Icon(Icons.place, color: Colors.white54, size: 20),
                        suffixIcon: _endController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                                onPressed: () {
                                  _endController.clear();
                                  setState(() {
                                    _selectedDestination = null;
                                    _endSuggestions = [];
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),

                    // Destination Suggestions
                    if (_endSuggestions.isNotEmpty) _buildSuggestionList(_endSuggestions, false),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Quick Popular Routes Chips
              Text(
                'POPULAR EV ROUTES',
                style: GoogleFonts.outfit(
                  color: Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickRoutes.map((route) {
                    final label = route['label'] as String;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(label, style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        avatar: const Icon(Icons.bolt, color: _kGreen, size: 14),
                        backgroundColor: Colors.white.withOpacity(0.06),
                        side: BorderSide(color: Colors.white.withOpacity(0.12)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        onPressed: () => _applyQuickRoute(route),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Vehicle & Battery Intelligence Section
              GlassContainer(
                padding: const EdgeInsets.all(18),
                borderRadius: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.electric_car, color: _kBlue, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'EV Vehicle & Battery Config',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Vehicle Selector
                    DropdownButtonFormField<VehicleModel>(
                      value: mp.selectedVehicle ?? VehicleService.indianEVEcosystem.first,
                      dropdownColor: _kCard,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Selected EV Model',
                        labelStyle: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: VehicleService.indianEVEcosystem.map((v) {
                        return DropdownMenuItem<VehicleModel>(
                          value: v,
                          child: Text(v.displayName),
                        );
                      }).toList(),
                      onChanged: (v) => mp.setSelectedVehicle(v),
                    ),
                    const SizedBox(height: 16),

                    // Battery Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Current Battery', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                        Text(
                          '${mp.currentBatteryPct.toInt()}%',
                          style: GoogleFonts.outfit(color: _kGreen, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    Slider(
                      value: mp.currentBatteryPct,
                      min: 5.0,
                      max: 100.0,
                      divisions: 19,
                      activeColor: _kGreen,
                      inactiveColor: Colors.white12,
                      onChanged: (val) => mp.setCurrentBatteryPct(val),
                    ),

                    // Safety Buffer Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Safety Buffer Reserve', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                        Text(
                          '${mp.safetyBufferPct.toInt()}%',
                          style: GoogleFonts.outfit(color: _kOrange, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    Slider(
                      value: mp.safetyBufferPct,
                      min: 5.0,
                      max: 30.0,
                      divisions: 5,
                      activeColor: _kOrange,
                      inactiveColor: Colors.white12,
                      onChanged: (val) => mp.setSafetyBufferPct(val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // PLAN TRIP BUTTON
              SizedBox(
                width: double.infinity,
                child: PremiumButton(
                  text: mp.isLoadingRoute || _isPlanningTrip ? 'CALCULATING ROUTE...' : 'PLAN TRIP',
                  icon: Icons.map,
                  onPressed: isCanPlan ? _planTrip : () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionList(List<LocationSearchResult> suggestions, bool isStart) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2235),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: suggestions.take(5).map((s) {
          return ListTile(
            dense: true,
            leading: Icon(
              isStart ? Icons.trip_origin : Icons.place,
              color: isStart ? _kGreen : _kRed,
              size: 18,
            ),
            title: Text(
              s.displayName,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              s.subtitle ?? 'Location',
              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11),
            ),
            onTap: () => _selectSuggestion(s, isStart),
          );
        }).toList(),
      ),
    );
  }
}
