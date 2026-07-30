import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/premium_button.dart';
import '../../models/location_search_result.dart';
import '../../models/map_marker_model.dart';
import '../../models/recommended_charging_stop.dart';
import '../../models/vehicle_model.dart';
import '../../providers/maps_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/maps_service.dart';
import '../../services/trip_energy_calculator.dart';
import '../../services/smart_trip_energy_cost_service.dart';
import '../../services/vehicle_service.dart';
import '../../models/smart_trip_cost_settings.dart';
import '../wallet/add_money_screen.dart';

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

  final MapsService _mapsService = MapsService();

  LocationSearchResult? _selectedOrigin;
  LocationSearchResult? _selectedDestination;

  List<LocationSearchResult> _startSuggestions = [];
  List<LocationSearchResult> _endSuggestions   = [];
  Timer? _debounceTimer;

  bool _isSearchingStart = false;
  bool _isSearchingEnd   = false;

  // Preset city routes for quick 1-tap trip selection
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
      if (isStart) {
        _isSearchingStart = true;
      } else {
        _isSearchingEnd = true;
      }
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

      // Add local city fallbacks if autocomplete produced few results
      const knownCities = [
        {'name': 'New Delhi, Delhi',       'lat': 28.6139, 'lng': 77.2090, 'sub': 'Capital Region'},
        {'name': 'Jaipur, Rajasthan',      'lat': 26.9124, 'lng': 75.7873, 'sub': 'Pink City'},
        {'name': 'Mumbai, Maharashtra',    'lat': 19.0760, 'lng': 72.8777, 'sub': 'Financial Capital'},
        {'name': 'Pune, Maharashtra',      'lat': 18.5204, 'lng': 73.8567, 'sub': 'Oxford of the East'},
        {'name': 'Bengaluru, Karnataka',   'lat': 12.9716, 'lng': 77.5946, 'sub': 'Silicon Valley'},
        {'name': 'Chennai, Tamil Nadu',    'lat': 13.0827, 'lng': 80.2707, 'sub': 'Gateway to South'},
        {'name': 'Hyderabad, Telangana',   'lat': 17.3850, 'lng': 78.4867, 'sub': 'Pearl City'},
        {'name': 'Ahmedabad, Gujarat',     'lat': 23.0225, 'lng': 72.5714, 'sub': 'Manchester of India'},
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
    LocationSearchResult resolved = suggestion;

    if (resolved.latitude == 0.0 || resolved.longitude == 0.0) {
      try {
        LatLng? coords;
        if (resolved.placeId != null && resolved.placeId!.isNotEmpty && resolved.placeId!.startsWith('ChI')) {
          coords = await _mapsService.getPlaceCoordinates(resolved.placeId!);
        }
        coords ??= await _mapsService.getCoordinatesFromAddress(resolved.displayName);
        if (coords != null) {
          resolved = LocationSearchResult(
            displayName: resolved.displayName,
            subtitle: resolved.subtitle,
            latitude: coords.latitude,
            longitude: coords.longitude,
            placeId: resolved.placeId,
            source: resolved.source,
          );
        }
      } catch (e) {
        debugPrint('[RoutePlannerScreen] Error resolving coordinates: $e');
      }
    }

    setState(() {
      if (isStart) {
        _selectedOrigin = resolved;
        _startController.text = resolved.displayName;
        _startSuggestions = [];
        _startFocusNode.unfocus();
      } else {
        _selectedDestination = resolved;
        _endController.text = resolved.displayName;
        _endSuggestions = [];
        _endFocusNode.unfocus();
      }
    });
  }

  void _swapLocations() {
    setState(() {
      final tmp  = _selectedOrigin;
      _selectedOrigin      = _selectedDestination;
      _selectedDestination = tmp;
      final tmpText = _startController.text;
      _startController.text = _endController.text;
      _endController.text   = tmpText;
    });
  }

  void _applyQuickRoute(Map<String, dynamic> route) {
    setState(() {
      _selectedOrigin      = route['origin']      as LocationSearchResult;
      _selectedDestination = route['destination'] as LocationSearchResult;
      _startController.text = _selectedOrigin!.displayName;
      _endController.text   = _selectedDestination!.displayName;
      _startSuggestions = [];
      _endSuggestions   = [];
    });
  }

  void _planTrip() async {
    _startFocusNode.unfocus();
    _endFocusNode.unfocus();

    if (_selectedOrigin == null || _startController.text.trim().isEmpty) {
      _showSnackbar('Please select a starting location.', isError: true);
      return;
    }
    if (_selectedDestination == null || _endController.text.trim().isEmpty) {
      _showSnackbar('Please select a destination.', isError: true);
      return;
    }
    if (_selectedOrigin!.latitude == _selectedDestination!.latitude &&
        _selectedOrigin!.longitude == _selectedDestination!.longitude) {
      _showSnackbar('Start and destination must be different.', isError: true);
      return;
    }

    final provider = context.read<MapsProvider>();
    await provider.planTrip(origin: _selectedOrigin!, destination: _selectedDestination!);
  }

  void _clearTrip() {
    setState(() {
      _selectedOrigin = null;
      _selectedDestination = null;
      _startController.clear();
      _endController.clear();
      _startSuggestions = [];
      _endSuggestions   = [];
    });
    context.read<MapsProvider>().clearTrip();
    _showSnackbar('Trip cleared successfully.');
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
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final theme      = Theme.of(context);
    final brandColor = theme.colorScheme.primary;
    final mp         = context.watch<MapsProvider>();

    final isRouteActive = mp.discoveryMode == 'route' && mp.routePoints.isNotEmpty;
    final chargersList  = mp.getFilteredMarkers();

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Smart EV Trip Planner',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            tooltip: 'Cost Settings',
            onPressed: () => _showCostSettingsSheet(context, mp),
          ),
          if (isRouteActive)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Clear Trip',
              onPressed: _clearTrip,
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [brandColor.withOpacity(0.15), AppColors.background],
            stops: const [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Quick Route Chips
                _buildQuickRouteChips(brandColor),
                const SizedBox(height: 16),

                // 2. Start / Destination Input
                _buildInputSection(brandColor, mp),
                const SizedBox(height: 20),

                // 3. EV + Battery Selection
                _buildVehicleAndBatterySection(brandColor, mp),
                const SizedBox(height: 20),

                // 4. Smart Trip Analysis card (replaces basic energy check)
                _buildSmartTripAnalysisCard(brandColor, mp),
                const SizedBox(height: 20),

                // 5. Route content
                if (mp.isLoadingRoute || mp.isLoading)
                  _buildLoadingCard(brandColor, 'Calculating route & finding corridor chargers...')
                else if (mp.isCalculatingSmartTrip)
                  _buildLoadingCard(brandColor, 'Calculating smart charging recommendations...')
                else if (isRouteActive) ...[
                  // 6. Trip Summary
                  _buildTripSummaryCard(brandColor, mp, chargersList),
                  const SizedBox(height: 20),

                  // 7. Recommended Charging Stops
                  _buildRecommendedStopsSection(brandColor, mp),

                  // 8. Smart Trip Timeline & Costs
                  if (mp.smartTripResult != null) ...[
                    const SizedBox(height: 20),
                    _buildCostSummaryCard(brandColor, mp),
                    const SizedBox(height: 20),
                    _buildWalletSimulationCard(brandColor, mp),
                    const SizedBox(height: 20),
                    _buildIceComparisonCard(brandColor, mp),
                    const SizedBox(height: 20),
                    _buildSmartTripTimeline(brandColor, mp),
                  ],

                  const SizedBox(height: 20),

                  // 9. Chargers Along Route
                  _buildRouteChargersHeader(brandColor, chargersList),
                  const SizedBox(height: 14),
                  if (chargersList.isEmpty)
                    _buildEmptyChargersCard()
                  else
                    _buildChargersTimeline(brandColor, mp, chargersList),
                ] else ...[
                  _buildEmptyGuideState(brandColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SECTION BUILDERS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildQuickRouteChips(Color brandColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Popular Routes',
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _quickRoutes.map((qr) {
              final label = qr['label'] as String;
              final isSelected =
                  _selectedOrigin?.displayName == (qr['origin'] as LocationSearchResult).displayName &&
                  _selectedDestination?.displayName == (qr['destination'] as LocationSearchResult).displayName;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
                  selected: isSelected,
                  selectedColor: brandColor.withOpacity(0.25),
                  backgroundColor: const Color(0xFF1A1D2E),
                  side: BorderSide(color: isSelected ? brandColor : Colors.white10),
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
                  onSelected: (_) => _applyQuickRoute(qr),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInputSection(Color brandColor, MapsProvider mp) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(children: [
        Row(children: [
          Column(children: [
            const Icon(Icons.my_location, color: _kGreen, size: 20),
            const SizedBox(height: 4),
            Container(height: 36, width: 2, color: Colors.white24),
            const SizedBox(height: 4),
            const Icon(Icons.location_on, color: _kRed, size: 20),
          ]),
          const SizedBox(width: 14),
          Expanded(child: Column(children: [
            TextField(
              controller: _startController,
              focusNode: _startFocusNode,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Start Location (e.g. Delhi)',
                hintStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                suffixIcon: _isSearchingStart
                    ? const Padding(padding: EdgeInsets.all(10.0),
                        child: SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
                    : null,
              ),
              onChanged: (val) => _onQueryChanged(val, true),
            ),
            const Divider(height: 24, color: Colors.white12),
            TextField(
              controller: _endController,
              focusNode: _endFocusNode,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Destination (e.g. Jaipur)',
                hintStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                suffixIcon: _isSearchingEnd
                    ? const Padding(padding: EdgeInsets.all(10.0),
                        child: SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
                    : null,
              ),
              onChanged: (val) => _onQueryChanged(val, false),
              onSubmitted: (_) => _planTrip(),
            ),
          ])),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle),
              child: const Icon(Icons.swap_vert, color: Colors.white70, size: 20),
            ),
            onPressed: _swapLocations,
          ),
        ]),

        // Autocomplete lists
        if (_startSuggestions.isNotEmpty)
          _buildSuggestionList(_startSuggestions, true),
        if (_endSuggestions.isNotEmpty)
          _buildSuggestionList(_endSuggestions, false),

        const SizedBox(height: 18),

        Row(children: [
          Expanded(child: PremiumButton(text: 'PLAN SMART TRIP', icon: Icons.electric_bolt, onPressed: _planTrip)),
          if (mp.discoveryMode == 'route') ...[
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: _clearTrip,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              child: const Text('Clear'),
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _buildSuggestionList(List<LocationSearchResult> items, bool isStart) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: items.length,
        itemBuilder: (_, idx) {
          final item = items[idx];
          return ListTile(
            dense: true,
            leading: Icon(isStart ? Icons.location_on_outlined : Icons.flag_outlined,
                color: isStart ? _kGreen : _kRed, size: 18),
            title: Text(item.displayName,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 13)),
            subtitle: Text(item.subtitle ?? 'Location',
                style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11)),
            onTap: () => _selectSuggestion(item, isStart),
          );
        },
      ),
    );
  }

  Widget _buildVehicleAndBatterySection(Color brandColor, MapsProvider mp) {
    final availableVehicles = VehicleService.indianEVEcosystem;
    final selectedVeh = mp.selectedVehicle ?? availableVehicles.first;

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.electric_car, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Text('YOUR EV & BATTERY',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.1)),
        ]),
        const SizedBox(height: 16),

        // Vehicle selector
        Text('Select Your EV',
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<VehicleModel>(
              value: availableVehicles.any((v) => v.id == selectedVeh.id) ? selectedVeh : availableVehicles.first,
              dropdownColor: const Color(0xFF1A1D2E),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
              items: availableVehicles.map((v) => DropdownMenuItem<VehicleModel>(
                value: v,
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Text('${v.manufacturer} ${v.model} ${v.variant}',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: brandColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                    child: Text('${v.usableBatteryCapacity.toStringAsFixed(1)} kWh',
                        style: GoogleFonts.outfit(color: brandColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ]),
              )).toList(),
              onChanged: (veh) {
                if (veh != null) mp.setSelectedVehicle(veh);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Selected vehicle specs row
        _buildVehicleSpecsRow(selectedVeh, brandColor),
        const SizedBox(height: 18),

        // Battery slider
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Current Battery',
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (mp.currentBatteryPct > 50 ? _kGreen : (mp.currentBatteryPct > 20 ? _kOrange : _kRed)).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('${mp.currentBatteryPct.toInt()}%',
                style: GoogleFonts.outfit(
                    color: mp.currentBatteryPct > 50 ? _kGreen : (mp.currentBatteryPct > 20 ? _kOrange : _kRed),
                    fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: mp.currentBatteryPct > 50 ? _kGreen : (mp.currentBatteryPct > 20 ? _kOrange : _kRed),
            inactiveTrackColor: Colors.white10,
            thumbColor: Colors.white,
            overlayColor: brandColor.withOpacity(0.2),
            trackHeight: 6,
          ),
          child: Slider(
            value: mp.currentBatteryPct,
            min: 0.0, max: 100.0, divisions: 100,
            label: '${mp.currentBatteryPct.toInt()}%',
            onChanged: (val) => mp.setCurrentBatteryPct(val),
          ),
        ),
        const SizedBox(height: 14),

        // Safety buffer
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Range Safety Buffer',
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          Row(children: [10.0, 15.0, 20.0].map((buf) {
            final isSel = mp.safetyBufferPct == buf;
            return Padding(
              padding: const EdgeInsets.only(left: 6.0),
              child: ChoiceChip(
                label: Text('${buf.toInt()}%', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
                selected: isSel,
                selectedColor: brandColor.withOpacity(0.3),
                backgroundColor: _kCard,
                side: BorderSide(color: isSel ? brandColor : Colors.white10),
                labelStyle: TextStyle(color: isSel ? Colors.white : Colors.white70),
                onSelected: (_) => mp.setSafetyBufferPct(buf),
              ),
            );
          }).toList()),
        ]),
        const SizedBox(height: 6),
        Text('This buffer accounts for real-world traffic, weather, AC, elevation, and driving style.',
            style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11)),
      ]),
    );
  }

  Widget _buildVehicleSpecsRow(VehicleModel veh, Color brandColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: brandColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: brandColor.withOpacity(0.15)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _buildSpecChip('${veh.realRange.toInt()} km', 'Real Range', Icons.alt_route, _kGreen),
        _buildSpecChip('${veh.usableBatteryCapacity.toStringAsFixed(1)} kWh', 'Usable', Icons.battery_full, _kBlue),
        _buildSpecChip('${veh.maxDcChargingSpeed.toInt()} kW', 'Max DC', Icons.bolt, _kOrange),
        _buildSpecChip(veh.connectorTypes.take(2).join(' / '), 'Connector', Icons.electrical_services, AppColors.primary),
      ]),
    );
  }

  Widget _buildSpecChip(String value, String label, IconData icon, Color color) {
    return Column(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(height: 4),
      Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
      Text(label, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 10)),
    ]);
  }

  // ─── SMART TRIP ANALYSIS CARD ───────────────────────────────────────────
  Widget _buildSmartTripAnalysisCard(Color brandColor, MapsProvider mp) {
    final analysis  = mp.tripEnergyAnalysis;
    final smartResult = mp.smartTripResult;

    // Determine status color/icon from smart result if available, else from basic analysis
    Color statusColor;
    IconData statusIcon;
    String statusTitle;
    String statusMessage;

    if (smartResult != null) {
      switch (smartResult.status) {
        case SmartTripStatus.tripPossible:
          statusColor   = _kGreen;
          statusIcon    = Icons.check_circle_outline;
          statusTitle   = 'TRIP POSSIBLE';
          statusMessage = 'Your EV has sufficient range for this trip with ${mp.safetyBufferPct.toInt()}% safety reserve. No charging required.';
          break;
        case SmartTripStatus.chargingRecommended:
          statusColor   = _kOrange;
          statusIcon    = Icons.bolt;
          statusTitle   = 'CHARGING RECOMMENDED';
          statusMessage = '${smartResult.recommendedStops.length} charging stop${smartResult.recommendedStops.length > 1 ? "s" : ""} recommended for a safe journey.';
          break;
        case SmartTripStatus.chargingRequired:
          statusColor   = _kRed;
          statusIcon    = Icons.warning_amber_outlined;
          statusTitle   = 'CHARGING REQUIRED';
          statusMessage = 'Charging is required to complete this trip. Plan stops along the route.';
          break;
      }
    } else if (analysis.status == ChargingRequirementStatus.rangeSufficient) {
      statusColor   = _kGreen;
      statusIcon    = Icons.check_circle_outline;
      statusTitle   = 'Range Check';
      statusMessage = analysis.statusMessage;
    } else if (analysis.status == ChargingRequirementStatus.chargingRequired) {
      statusColor   = _kOrange;
      statusIcon    = Icons.bolt;
      statusTitle   = analysis.statusTitle;
      statusMessage = analysis.statusMessage;
    } else {
      statusColor   = Colors.grey;
      statusIcon    = Icons.info_outline;
      statusTitle   = analysis.statusTitle;
      statusMessage = analysis.statusMessage;
    }

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Icon(Icons.battery_charging_full, color: statusColor, size: 22),
            const SizedBox(width: 10),
            Text('SMART TRIP ANALYSIS',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.1)),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Text(statusTitle,
                style: GoogleFonts.outfit(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 14),

        // Status Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withOpacity(0.25)),
          ),
          child: Row(children: [
            Icon(statusIcon, color: statusColor, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text(statusMessage,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
          ]),
        ),
        const SizedBox(height: 18),

        // Metrics grid (4 items)
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _buildMetricItem('Available', '${analysis.availableEnergyKwh.toStringAsFixed(1)} kWh', Icons.battery_saver, _kGreen),
          _buildMetricItem('Est. Range', '${analysis.estimatedRangeKm.toStringAsFixed(0)} km', Icons.alt_route, _kBlue),
          _buildMetricItem('Trip Energy', '${analysis.tripEnergyRequiredKwh.toStringAsFixed(1)} kWh', Icons.electric_bolt, _kOrange),
          if (smartResult != null)
            _buildMetricItem(
              'At Dest.',
              '${smartResult.estimatedBatteryAtDestinationPct.clamp(0.0, 100.0).toStringAsFixed(0)}%',
              Icons.flag,
              smartResult.estimatedBatteryAtDestinationPct >= 15 ? _kGreen : _kRed,
            )
          else
            _buildMetricItem('Buffer', '${mp.safetyBufferPct.toInt()}%', Icons.shield_outlined, AppColors.primary),
        ]),

        // If smart result available with stops needed, show extra insight
        if (smartResult != null && smartResult.chargingRequired) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, color: Colors.white54, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Estimated battery at destination (with ${smartResult.recommendedStops.length} stop${smartResult.recommendedStops.length > 1 ? "s" : ""}): '
                '${smartResult.estimatedBatteryAtDestinationPct.clamp(0, 100).toStringAsFixed(0)}%  •  '
                'Safety reserve: ${mp.safetyBufferPct.toInt()}%',
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11),
              )),
            ]),
          ),
        ],

        // Compatibility warning
        if (smartResult != null && !smartResult.compatibleChargerFound && smartResult.chargingRequired) ...[
          const SizedBox(height: 12),
          _buildCompatibilityWarning(mp),
        ],
      ]),
    );
  }

  Widget _buildCompatibilityWarning(MapsProvider mp) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kOrange.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.warning_amber_outlined, color: _kOrange, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(
            'No compatible charger found within the planned route corridor.',
            style: GoogleFonts.outfit(color: _kOrange, fontSize: 12, fontWeight: FontWeight.bold),
          )),
        ]),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => mp.setShowAllChargersWhenNoCompatible(!mp.showAllChargersWhenNoCompatible),
          child: Row(children: [
            Icon(mp.showAllChargersWhenNoCompatible ? Icons.check_box : Icons.check_box_outline_blank,
                color: _kBlue, size: 18),
            const SizedBox(width: 6),
            Text('Show all chargers (regardless of connector type)',
                style: GoogleFonts.outfit(color: _kBlue, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }

  // ─── RECOMMENDED CHARGING STOPS ─────────────────────────────────────────
  Widget _buildRecommendedStopsSection(Color brandColor, MapsProvider mp) {
    final stops = mp.recommendedStops;
    final result = mp.smartTripResult;
    if (result == null) return const SizedBox.shrink();
    if (!result.chargingRequired) return const SizedBox.shrink();
    if (stops.isEmpty) {
      return GlassContainer(
        padding: const EdgeInsets.all(20),
        borderRadius: 20,
        child: Row(children: [
          const Icon(Icons.info_outline, color: Colors.amber, size: 24),
          const SizedBox(width: 14),
          Expanded(child: Text(
            'No suitable charging stop could be identified along this route corridor. '
            'Consider searching for chargers at intermediate cities.',
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
          )),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Recommended Charging Stops',
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _kBlue.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBlue.withOpacity(0.3)),
          ),
          child: Text('${stops.length} Stop${stops.length > 1 ? "s" : ""}',
              style: GoogleFonts.outfit(color: _kBlue, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ]),
      const SizedBox(height: 12),

      ...stops.map((stop) => _buildRecommendedStopCard(stop, brandColor, mp)),
    ]);
  }

  Widget _buildRecommendedStopCard(RecommendedChargingStop stop, Color brandColor, MapsProvider mp) {
    final arrivalColor = stop.estimatedArrivalBatteryPct < 20 ? _kRed : (stop.estimatedArrivalBatteryPct < 40 ? _kOrange : _kGreen);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: 20,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // Stop number badge
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: _kBlue.withOpacity(0.2), shape: BoxShape.circle,
                  border: Border.all(color: _kBlue.withOpacity(0.5))),
              child: Center(child: Text('${stop.stopIndex}',
                  style: GoogleFonts.outfit(color: _kBlue, fontWeight: FontWeight.bold, fontSize: 14))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(stop.charger.title,
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${stop.charger.network} • ${stop.charger.power} (${stop.charger.powerType})',
                  style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12)),
            ])),
            if (!stop.isCompatible)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _kOrange.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Text('All', style: GoogleFonts.outfit(color: _kOrange, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
          ]),
          const SizedBox(height: 12),

          // Metrics row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _buildStopMetric('${stop.distanceFromStartKm.toStringAsFixed(0)} km', 'From Start', _kBlue),
                _buildStopMetric('${stop.distanceToDestinationKm.toStringAsFixed(0)} km', 'To Dest.', Colors.grey),
                _buildStopMetric('${stop.estimatedArrivalBatteryPct.toStringAsFixed(0)}%', 'Arrival', arrivalColor),
                _buildStopMetric('${stop.recommendedChargingTargetPct.toStringAsFixed(0)}%', 'Target', _kGreen),
              ]),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _buildStopMetric('+${stop.energyAddedToBatteryKwh.toStringAsFixed(1)} kWh', 'Added', _kGreen),
                _buildStopMetric('${stop.gridEnergyDrawnKwh.toStringAsFixed(1)} kWh', 'Grid Draw', _kOrange),
                _buildStopMetric('${stop.chargingLossKwh.toStringAsFixed(1)} kWh', 'Loss', _kRed),
                _buildStopMetric('₹${stop.estimatedChargingCost.toStringAsFixed(0)}', 'Est. Cost', _kBlue),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.receipt_long, color: Colors.white54, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Tariff: ${stop.pricePerKwh != null ? '₹${stop.pricePerKwh!.toStringAsFixed(1)}/kWh' : 'Unavailable'} (${stop.tariffSource})',
                  style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.access_time, color: Colors.white54, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Estimated charging time: ~${stop.estimatedChargingDurationMinutesInt} min',
                  style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11),
                ),
              ]),
            ]),
          ),

          // Battery charge progress bar
          const SizedBox(height: 10),
          _buildBatteryProgressBar(stop.estimatedArrivalBatteryPct, stop.recommendedChargingTargetPct),
          const SizedBox(height: 8),

          // Reason chip
          Row(children: [
            const Icon(Icons.info_outline, color: Colors.white38, size: 13),
            const SizedBox(width: 4),
            Expanded(child: Text(stop.reasonLabel,
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11))),
          ]),
        ]),
      ),
    );
  }

  Widget _buildBatteryProgressBar(double fromPct, double toPct) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final fromX = (fromPct / 100.0) * width;
      final toX   = (toPct   / 100.0) * width;

      return Container(
        height: 8,
        width: width,
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
        child: Stack(children: [
          // Full bar background
          Positioned.fill(child: Container(decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)))),
          // Existing charge
          Positioned(left: 0, top: 0, bottom: 0, width: fromX,
              child: Container(decoration: BoxDecoration(
                  color: fromPct < 20 ? _kRed : (fromPct < 40 ? _kOrange : _kGreen),
                  borderRadius: BorderRadius.circular(4)))),
          // Charge being added
          if (toX > fromX)
            Positioned(left: fromX, top: 0, bottom: 0, width: toX - fromX,
                child: Container(decoration: BoxDecoration(
                    color: _kGreen.withOpacity(0.5),
                    borderRadius: BorderRadius.only(topRight: Radius.circular(4), bottomRight: Radius.circular(4))))),
        ]),
      );
    });
  }

  Widget _buildStopMetric(String value, String label, Color color) {
    return Column(children: [
      Text(value, style: GoogleFonts.outfit(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
      Text(label, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 10)),
    ]);
  }

  // ─── SMART TRIP TIMELINE ─────────────────────────────────────────────────
  Widget _buildSmartTripTimeline(Color brandColor, MapsProvider mp) {
    final result   = mp.smartTripResult!;
    final stops    = result.recommendedStops;
    final originName = _selectedOrigin?.displayName.split(',').first ?? 'Start';
    final destName   = _selectedDestination?.displayName.split(',').first ?? 'Destination';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('TRIP PLAN',
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
      const SizedBox(height: 12),
      GlassContainer(
        padding: const EdgeInsets.all(20),
        borderRadius: 24,
        child: Column(children: [
          // Start node
          _buildTimelineNode(
            icon: Icons.my_location,
            iconColor: _kGreen,
            title: 'Start',
            subtitle: originName,
            detail: '0 km  •  ${mp.currentBatteryPct.toInt()}% battery',
            isFirst: true,
          ),

          // Charging stops
          ...stops.asMap().entries.map((entry) {
            final stop = entry.value;
            return _buildTimelineNode(
              icon: Icons.ev_station,
              iconColor: _kBlue,
              title: 'Charging Stop ${stop.stopIndex}',
              subtitle: stop.charger.title,
              detail: '${stop.distanceFromStartKm.toStringAsFixed(0)} km  •  '
                      'Arrival: ${stop.estimatedArrivalBatteryPct.toStringAsFixed(0)}%  →  '
                      'Target: ${stop.recommendedChargingTargetPct.toStringAsFixed(0)}%  •  '
                      '~${stop.estimatedChargingDurationMinutesInt} min charging',
            );
          }),

          // Destination node
          _buildTimelineNode(
            icon: Icons.flag,
            iconColor: _kRed,
            title: 'Destination',
            subtitle: destName,
            detail: '${result.tripDistanceKm.toStringAsFixed(0)} km  •  '
                    'Est. ${result.estimatedBatteryAtDestinationPct.clamp(0.0, 100.0).toStringAsFixed(0)}% battery',
            isLast: true,
          ),
        ]),
      ),
    ]);
  }

  Widget _buildTimelineNode({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String detail,
    bool isFirst = false,
    bool isLast  = false,
  }) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Left line + icon
        Column(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: iconColor.withOpacity(0.2), shape: BoxShape.circle,
                border: Border.all(color: iconColor.withOpacity(0.5))),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          if (!isLast)
            Expanded(child: Container(width: 2, color: Colors.white12, margin: const EdgeInsets.only(top: 4, bottom: 4))),
        ]),
        const SizedBox(width: 14),
        // Content
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11)),
              Text(subtitle, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(detail, style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ─── TRIP SUMMARY ────────────────────────────────────────────────────────
  Widget _buildTripSummaryCard(Color brandColor, MapsProvider mp, List<MapMarkerModel> chargersList) {
    final originName = _selectedOrigin?.displayName.split(',').first ?? 'Origin';
    final destName   = _selectedDestination?.displayName.split(',').first ?? 'Destination';
    final smartResult = mp.smartTripResult;

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            const Icon(Icons.route, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text('TRIP SUMMARY',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.1)),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: brandColor.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: Text('Route Active',
                style: GoogleFonts.outfit(color: brandColor, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 16),

        // Origin → Destination
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Start', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11)),
              Text(originName, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ])),
            const Icon(Icons.arrow_forward, color: AppColors.primary, size: 20),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Destination', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11)),
              Text(destName, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ])),
          ]),
        ),
        const SizedBox(height: 18),

        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _buildMetricItem('Distance', mp.routeDistance ?? '— km', Icons.straighten, _kBlue),
          _buildMetricItem('Drive Time', mp.routeDuration ?? '—', Icons.schedule, _kOrange),
          _buildMetricItem('Chargers', '${chargersList.length}', Icons.ev_station, _kGreen),
          _buildMetricItem('Rec. Stops', '${smartResult?.recommendedStops.length ?? 0}', Icons.pin_drop, _kBlue),
        ]),
      ]),
    );
  }

  Widget _buildRouteChargersHeader(Color brandColor, List<MapMarkerModel> chargersList) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('All Corridor Chargers (10 km)',
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _kGreen.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kGreen.withOpacity(0.3)),
        ),
        child: Text('${chargersList.length} Found',
            style: GoogleFonts.outfit(color: _kGreen, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    ]);
  }

  Widget _buildLoadingCard(Color brandColor, String message) {
    return GlassContainer(
      padding: const EdgeInsets.all(32),
      borderRadius: 24,
      child: Center(child: Column(children: [
        const CircularProgressIndicator(color: AppColors.primary),
        const SizedBox(height: 18),
        Text(message,
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center),
      ])),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon, Color color) {
    return Column(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 6),
      Text(value, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      Text(label, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11)),
    ]);
  }

  Widget _buildEmptyChargersCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      child: Row(children: [
        const Icon(Icons.info_outline, color: Colors.amber, size: 24),
        const SizedBox(width: 14),
        Expanded(child: Text(
          'No EV chargers found within 10 km of this route corridor.',
          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
        )),
      ]),
    );
  }

  Widget _buildChargersTimeline(Color brandColor, MapsProvider mp, List<MapMarkerModel> list) {
    final recommendedIds = mp.recommendedStops.map((s) => s.charger.id).toSet();

    return Column(
      children: list.take(15).toList().asMap().entries.map((entry) {
        final idx     = entry.key;
        final charger = entry.value;
        final isRecommended = recommendedIds.contains(charger.id);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: GlassContainer(
            padding: const EdgeInsets.all(14),
            borderRadius: 18,
            child: Row(children: [
              // Number badge — blue for recommended, green for others
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: (isRecommended ? _kBlue : _kGreen).withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: isRecommended ? Border.all(color: _kBlue.withOpacity(0.5), width: 2) : null,
                ),
                child: Center(child: isRecommended
                    ? const Icon(Icons.star, color: _kBlue, size: 16)
                    : Text('${idx + 1}',
                        style: GoogleFonts.outfit(color: _kGreen, fontWeight: FontWeight.bold, fontSize: 14))),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(charger.title,
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (isRecommended)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: _kBlue.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                      child: Text('REC', style: GoogleFonts.outfit(color: _kBlue, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                ]),
                const SizedBox(height: 4),
                Text('${charger.network} • ${charger.power} (${charger.powerType})',
                    style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  '${charger.connectors.join(", ")} • '
                  '${charger.distanceKm != null ? "${charger.distanceKm!.toStringAsFixed(1)} km from route" : "On route"}',
                  style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11),
                ),
              ])),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, color: AppColors.primary, size: 16),
                onPressed: () => mp.setSelectedMarker(charger),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyGuideState(Color brandColor) {
    return GlassContainer(
      padding: const EdgeInsets.all(28),
      borderRadius: 24,
      child: Center(child: Column(children: [
        Icon(Icons.electric_bolt, size: 64, color: brandColor.withOpacity(0.4)),
        const SizedBox(height: 16),
        Text('Smart EV Trip Planner',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 6),
        Text(
          'Enter Start & Destination, select your EV, set battery level — '
          'and get intelligent charging stop recommendations.',
          style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _buildGuideStep('1', 'Set Route', _kGreen),
          const SizedBox(width: 8),
          _buildGuideStep('2', 'Select EV', _kBlue),
          const SizedBox(width: 8),
          _buildGuideStep('3', 'Smart Plan', AppColors.primary),
        ]),
      ])),
    );
  }

  Widget _buildGuideStep(String num, String label, Color color) {
    return Column(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.4))),
        child: Center(child: Text(num, style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold, fontSize: 14))),
      ),
      const SizedBox(height: 4),
      Text(label, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 10)),
    ]);
  }

  // ─── Phase 4 Step 3 Cost & Energy Planners ──────────────────────────────
  Widget _buildCostSummaryCard(Color brandColor, MapsProvider mp) {
    final result = mp.smartTripResult;
    if (result == null) return const SizedBox.shrink();

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.receipt_long, color: _kOrange, size: 22),
          const SizedBox(width: 10),
          Text('SMART TRIP COST SUMMARY',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.1)),
        ]),
        const SizedBox(height: 16),
        
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _buildMetricItem('Distance', '${result.tripDistanceKm.toStringAsFixed(1)} km', Icons.route, Colors.white),
          _buildMetricItem('Energy Need', '${result.totalDrivingEnergyKwh.toStringAsFixed(1)} kWh', Icons.flash_on, _kOrange),
          _buildMetricItem('Batt. Added', '${result.totalEnergyAddedKwh.toStringAsFixed(1)} kWh', Icons.battery_charging_full, _kGreen),
          _buildMetricItem('Grid Drawn', '${result.totalGridEnergyKwh.toStringAsFixed(1)} kWh', Icons.electrical_services, _kBlue),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _buildMetricItem('Losses', '${result.totalChargingLossKwh.toStringAsFixed(1)} kWh', Icons.warning_amber_outlined, _kRed),
          _buildMetricItem('Total Cost', '₹${result.totalChargingCost.toStringAsFixed(2)}', Icons.currency_rupee, _kGreen),
          _buildMetricItem('Avg Cost', '₹${result.averageCostPerKm.toStringAsFixed(2)} / km', Icons.speed, _kBlue),
          _buildMetricItem('Per 100km', '₹${result.costPer100Km.toStringAsFixed(2)}', Icons.map, Colors.white),
        ]),
      ]),
    );
  }

  Widget _buildWalletSimulationCard(Color brandColor, MapsProvider mp) {
    final walletProvider = context.watch<WalletProvider>();
    final result = mp.smartTripResult;
    if (result == null) return const SizedBox.shrink();

    final walletBalance = walletProvider.balance;
    final estimatedCost = result.totalChargingCost;
    final remaining = walletBalance - estimatedCost;
    final isInsufficient = remaining < 0;

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.account_balance_wallet, color: _kBlue, size: 22),
          const SizedBox(width: 10),
          Text('WALLET SIMULATION',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.1)),
        ]),
        const SizedBox(height: 16),

        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Current Balance', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14)),
          Text('₹${walletBalance.toStringAsFixed(2)}', style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Estimated Trip Cost', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14)),
          Text('- ₹${estimatedCost.toStringAsFixed(2)}', style: GoogleFonts.outfit(color: _kRed, fontSize: 14, fontWeight: FontWeight.bold)),
        ]),
        const Divider(color: Colors.white10, height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Estimated Balance After Trip', style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          Text('₹${remaining.toStringAsFixed(2)}', style: GoogleFonts.outfit(color: isInsufficient ? _kRed : _kGreen, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),

        if (isInsufficient) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _kRed.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: _kRed.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.warning_amber_outlined, color: _kRed, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('Insufficient wallet balance for estimated trip charging cost.', style: GoogleFonts.outfit(color: _kRed, fontSize: 12))),
              PremiumButton(
                text: 'ADD MONEY',
                icon: Icons.add,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddMoneyScreen()),
                  );
                },
              ),
            ]),
          )
        ],
      ]),
    );
  }

  Widget _buildIceComparisonCard(Color brandColor, MapsProvider mp) {
    final result = mp.smartTripResult;
    if (result == null) return const SizedBox.shrink();

    final costService = const SmartTripEnergyCostService();
    final iceResult = costService.calculateIceComparison(
      tripDistanceKm: result.tripDistanceKm,
      totalEvCost: result.totalChargingCost,
      settings: mp.costSettings,
    );

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.local_gas_station, color: _kGreen, size: 22),
          const SizedBox(width: 10),
          Text('ESTIMATED SAVINGS',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.1)),
        ]),
        const SizedBox(height: 16),

        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('EV Charging Cost', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14)),
          Text('₹${result.totalChargingCost.toStringAsFixed(2)}', style: GoogleFonts.outfit(color: _kGreen, fontSize: 14, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Estimated ${mp.costSettings.iceComparisonFuelType} Cost', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14)),
          Text('₹${iceResult.fuelCost.toStringAsFixed(2)}', style: GoogleFonts.outfit(color: _kRed, fontSize: 14, fontWeight: FontWeight.bold)),
        ]),
        const Divider(color: Colors.white10, height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Estimated Savings', style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          Text('₹${iceResult.savings.toStringAsFixed(2)} (${iceResult.savingsPct.toStringAsFixed(0)}%)', style: GoogleFonts.outfit(color: _kGreen, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
      ]),
    );
  }

  void _showCostSettingsSheet(BuildContext context, MapsProvider mp) {
    final current = mp.costSettings;
    double defaultPrice = current.defaultChargingPricePerKwh;
    double petrolPrice = current.petrolPricePerLitre;
    double dieselPrice = current.dieselPricePerLitre;
    double petrolEff = current.petrolEfficiencyKml;
    double dieselEff = current.dieselEfficiencyKml;
    String fuelType = current.iceComparisonFuelType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setState) {
          return GlassContainer(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
            borderRadius: 24,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Cost & ICE Comparison Settings', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                _buildSettingSlider('Default Charging Tariff (₹/kWh)', defaultPrice, 0.0, 50.0, (v) => setState(() => defaultPrice = v)),
                const Divider(color: Colors.white10, height: 30),
                Text('ICE Comparison Settings', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(children: [
                  Text('Fuel Type:', style: GoogleFonts.outfit(color: Colors.white)),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                    dropdownColor: _kCard,
                    value: fuelType,
                    items: ['Petrol', 'Diesel'].map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: Colors.white)))).toList(),
                    onChanged: (v) => setState(() => fuelType = v!),
                  ),
                ]),
                const SizedBox(height: 10),
                _buildSettingSlider('Petrol Price (₹/L)', petrolPrice, 50.0, 150.0, (v) => setState(() => petrolPrice = v)),
                _buildSettingSlider('Diesel Price (₹/L)', dieselPrice, 50.0, 150.0, (v) => setState(() => dieselPrice = v)),
                _buildSettingSlider('Petrol Efficiency (km/L)', petrolEff, 5.0, 30.0, (v) => setState(() => petrolEff = v)),
                _buildSettingSlider('Diesel Efficiency (km/L)', dieselEff, 5.0, 30.0, (v) => setState(() => dieselEff = v)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: PremiumButton(
                    text: 'SAVE SETTINGS',
                    icon: Icons.save,
                    onPressed: () {
                      mp.updateCostSettings(SmartTripCostSettings(
                        defaultChargingPricePerKwh: defaultPrice,
                        petrolPricePerLitre: petrolPrice,
                        dieselPricePerLitre: dieselPrice,
                        petrolEfficiencyKml: petrolEff,
                        dieselEfficiencyKml: dieselEff,
                        iceComparisonFuelType: fuelType,
                      ));
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ]),
            ),
          );
        });
      },
    );
  }

  Widget _buildSettingSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: GoogleFonts.outfit(color: Colors.white, fontSize: 14)),
        Text(value.toStringAsFixed(1), style: GoogleFonts.outfit(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold)),
      ]),
      Slider(
        value: value,
        min: min,
        max: max,
        activeColor: AppColors.primary,
        inactiveColor: Colors.white10,
        onChanged: onChanged,
      ),
    ]);
  }
}
