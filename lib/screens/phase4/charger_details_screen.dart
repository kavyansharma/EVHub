import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../models/map_marker_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/charger_source_badge.dart';
import '../../core/utils/smart_charging_calculator.dart';
import '../../services/places_service.dart';
import '../../providers/garage_provider.dart';
import '../charging/charge_here_confirmation_sheet.dart';

class ChargerDetailsScreen extends StatefulWidget {
  final MapMarkerModel marker;

  const ChargerDetailsScreen({super.key, required this.marker});

  @override
  State<ChargerDetailsScreen> createState() => _ChargerDetailsScreenState();
}

class _ChargerDetailsScreenState extends State<ChargerDetailsScreen> with SingleTickerProviderStateMixin {
  final PlacesService _placesService = PlacesService();
  List<PlaceModel> _places = [];
  bool _isLoadingPlaces = true;
  String _activeTab = 'all';
  late TabController _tabController;

  // Smart Charging Calculator State
  double _currentPct = 25.0;
  double _targetPct = 80.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadPlaces();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    final places = await _placesService.getNearbyPlaces(widget.marker.latitude, widget.marker.longitude);
    if (mounted) {
      setState(() {
        _places = places;
        _isLoadingPlaces = false;
      });
    }
  }

  String _getHeroImage(String network) {
    if (network.toLowerCase().contains('tata')) {
      return 'https://images.unsplash.com/photo-1563720223185-11003d516935?auto=format&fit=crop&w=800&q=80';
    }
    if (network.toLowerCase().contains('statiq')) {
      return 'https://images.unsplash.com/photo-1620891549027-942fdc95d3f5?auto=format&fit=crop&w=800&q=80';
    }
    if (network.toLowerCase().contains('jio')) {
      return 'https://images.unsplash.com/photo-1617783921319-7977eb780131?auto=format&fit=crop&w=800&q=80';
    }
    return 'https://images.unsplash.com/photo-1593941707882-a5bba14938cb?auto=format&fit=crop&w=800&q=80';
  }

  Color _getNetworkColor(String network) {
    if (network.toLowerCase().contains('tata')) return AppColors.brandTata;
    if (network.toLowerCase().contains('statiq')) return AppColors.primary;
    if (network.toLowerCase().contains('jio')) return AppColors.accentPurple;
    if (network.toLowerCase().contains('zeon')) return AppColors.secondary;
    return AppColors.accent;
  }

  void _showChargeHereModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChargeHereConfirmationSheet(charger: widget.marker),
    );
  }

  @override
  Widget build(BuildContext context) {
    final marker = widget.marker;
    final netColor = _getNetworkColor(marker.network);
    final garageProvider = context.watch<GarageProvider>();

    final vehicle = garageProvider.selectedVehicle ??
        (garageProvider.vehicles.isNotEmpty ? garageProvider.vehicles.first : null);

    final double chargerPowerKw = double.tryParse(marker.power.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 60.0;
    final double pricePerKwh = SmartChargingCalculator.parsePrice(marker.price);

    final calcResult = SmartChargingCalculator.calculate(
      currentBatteryPct: _currentPct,
      targetBatteryPct: _targetPct,
      chargerPowerKw: chargerPowerKw,
      vehicleMaxPowerKw: vehicle?.maxDcChargingSpeed ?? 120.0,
      batteryCapacityKwh: vehicle?.batteryCapacity ?? 50.0,
      pricePerKwh: pricePerKwh,
      powerType: marker.powerType,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Main scrollable details body
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Hero Image Panel
                Stack(
                  children: [
                    Container(
                      height: 380,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(_getHeroImage(marker.network)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black54,
                              Colors.transparent,
                              AppColors.background.withOpacity(0.9),
                              AppColors.background,
                            ],
                            stops: const [0.0, 0.4, 0.85, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 24,
                      left: 24,
                      right: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ChargerSourceBadge(
                                source: marker.source,
                                isVerified: marker.isVerified,
                                compact: false,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: netColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: netColor, width: 1),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(color: netColor, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      marker.network,
                                      style: TextStyle(color: netColor, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star, color: AppColors.warning, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${marker.rating}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            marker.title,
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: AppColors.textSecondary, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${marker.address ?? marker.description}${marker.distanceKm != null ? ' • ${marker.distanceKm!.toStringAsFixed(1)} km away' : ''}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Details Content Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick Specs Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard('POWER', marker.power, HugeIcons.strokeRoundedFlash, AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              'STALLS',
                              marker.source == 'google_places' ? 'Unknown' : '${marker.availableConnectorsCount}/${marker.connectorCount}',
                              HugeIcons.strokeRoundedFuelStation,
                              AppColors.secondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard('PRICE', marker.price ?? '₹21/kWh', HugeIcons.strokeRoundedLicense, Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Visual Connector Availability Section
                      const Text(
                        'CONNECTOR AVAILABILITY BREAKDOWN',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: marker.connectors.map((connector) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: _buildVisualConnectorCard(connector, marker),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 28),

                      // Live Station Availability & Relative Update Time
                      const Text(
                        'LIVE STATION INTELLIGENCE',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      GlassContainer(
                        padding: const EdgeInsets.all(16),
                        child: marker.source == 'google_places' || !marker.isVerified
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.info_outline, color: AppColors.textSecondary, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Live availability unavailable',
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildLiveStallStat('Status', marker.computedStatus.name.toUpperCase(), _getStatusColor(marker.computedStatus)),
                                  Container(width: 1, height: 40, color: Colors.white10),
                                  _buildLiveStallStat('Available', '${marker.availableConnectorsCount}/${marker.connectorCount}', AppColors.secondary),
                                  Container(width: 1, height: 40, color: Colors.white10),
                                  _buildLiveStallStat('Occupied', '${marker.occupiedConnectorsCount}', AppColors.warning),
                                  Container(width: 1, height: 40, color: Colors.white10),
                                  _buildLiveStallStat('Updated', marker.lastUpdated ?? '12 sec ago', Colors.white),
                                ],
                              ),
                      ),

                      const SizedBox(height: 28),

                      // Embedded Smart Charging Calculator
                      const Text(
                        'SMART CHARGING CALCULATOR',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      GlassContainer(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Battery Target: ${_currentPct.toInt()}% ➔ ${_targetPct.toInt()}%',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Efficiency: ${calcResult.efficiencyPercentage}%',
                                    style: const TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: _currentPct,
                                    min: 5.0,
                                    max: 90.0,
                                    divisions: 17,
                                    activeColor: AppColors.primary,
                                    onChanged: (val) {
                                      setState(() {
                                        _currentPct = val;
                                        if (_targetPct <= _currentPct) {
                                          _targetPct = math.min(100.0, _currentPct + 10.0);
                                        }
                                      });
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: _targetPct,
                                    min: _currentPct + 5.0,
                                    max: 100.0,
                                    divisions: 19,
                                    activeColor: AppColors.secondary,
                                    onChanged: (val) {
                                      setState(() {
                                        _targetPct = val;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildCalcMetric('Grid Energy', '${calcResult.grossEnergyFromGridKwh.toStringAsFixed(1)} kWh'),
                                Container(width: 1, height: 30, color: Colors.white10),
                                _buildCalcMetric('Est. Time', calcResult.formattedTime),
                                Container(width: 1, height: 30, color: Colors.white10),
                                _buildCalcMetric('Est. Cost', '₹${calcResult.estimatedCost.toInt()}'),
                                Container(width: 1, height: 30, color: Colors.white10),
                                _buildCalcMetric('Range Added', '+${calcResult.estimatedRangeAddedKm.toInt()} km'),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Center(
                              child: Text(
                                '* Estimates based on standard charging curves.',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Nearby Places / Amenities
                      const Text(
                        'NEARBY AMENITIES (PLACES)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      _buildAmenitiesSection(),

                      const SizedBox(height: 28),

                      // Reviews List
                      const Text(
                        'COMMUNITY REVIEWS',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      _buildReviewsList(),

                      const SizedBox(height: 140), // Spacing for floating buttons
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Header Glass Overlay Buttons
          Positioned(
            top: 24,
            left: 20,
            right: 20,
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildFloatingTopBtn(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      _buildFloatingTopBtn(
                        icon: Icons.favorite_border,
                        onTap: () {},
                      ),
                      const SizedBox(width: 12),
                      _buildFloatingTopBtn(
                        icon: Icons.share_outlined,
                        onTap: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Floating Action Panel at the bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 36, top: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [AppColors.background, AppColors.background.withOpacity(0.0)],
                  stops: const [0.6, 1.0],
                ),
              ),
              child: Row(
                children: [
                  // Navigate Circle Button
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Starting GPS navigation layout...')),
                      );
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedRoute01,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Main Action Button ("Charge Here" for EVHub Verified, "View Details" for Google Places)
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (marker.source == 'evhub_verified' && marker.isVerified) {
                          _showChargeHereModal(context);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Live availability unavailable for Google Places chargers.')),
                          );
                        }
                      },
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: marker.source == 'evhub_verified' && marker.isVerified
                              ? AppColors.chargingGradient
                              : const LinearGradient(colors: [Color(0xFF374151), Color(0xFF1F2937)]),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: marker.source == 'evhub_verified' && marker.isVerified
                              ? AppColors.neonShadow(color: AppColors.primary, blurRadius: 15)
                              : [],
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                marker.source == 'evhub_verified' && marker.isVerified ? Icons.flash_on : Icons.info_outline,
                                color: marker.source == 'evhub_verified' && marker.isVerified ? Colors.black : Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                marker.source == 'evhub_verified' && marker.isVerified ? 'Charge Here' : 'View Details',
                                style: TextStyle(
                                  color: marker.source == 'evhub_verified' && marker.isVerified ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(MarkerStatus status) {
    switch (status) {
      case MarkerStatus.available:
        return const Color(0xFF00FF9C);
      case MarkerStatus.busy:
        return const Color(0xFFFFC247);
      case MarkerStatus.offline:
        return const Color(0xFFFF4D67);
      case MarkerStatus.unknown:
        return const Color(0xFF8F9CAE);
    }
  }

  Widget _buildVisualConnectorCard(String connector, MapMarkerModel marker) {
    final bool isUnknown = marker.source == 'google_places' || !marker.isVerified;
    final int avail = isUnknown ? 0 : marker.availableConnectorsCount;
    final int total = marker.connectorCount > 0 ? marker.connectorCount : 2;

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isUnknown ? Colors.grey : AppColors.secondary).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedPlug01,
              color: isUnknown ? Colors.grey : AppColors.secondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$connector (${marker.powerType})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 6),
                // Visual Dots Row
                Row(
                  children: List.generate(total, (idx) {
                    final isAvail = !isUnknown && idx < avail;
                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isUnknown
                            ? Colors.grey
                            : (isAvail ? AppColors.secondary : AppColors.warning),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          Text(
            isUnknown ? 'Not Available' : '$avail / $total Available',
            style: TextStyle(
              color: isUnknown ? AppColors.textSecondary : (avail > 0 ? AppColors.secondary : AppColors.warning),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalcMetric(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
      ],
    );
  }

  Widget _buildFloatingTopBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, List<List<dynamic>> icon, Color color) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      borderRadius: 20,
      child: Column(
        children: [
          HugeIcon(icon: icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLiveStallStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildAmenitiesSection() {
    if (_isLoadingPlaces) {
      return const SizedBox(
        height: 130,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_places.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text('No amenities found nearby.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            _buildAmenityTab('all', 'All'),
            _buildAmenityTab('cafe', 'Cafes'),
            _buildAmenityTab('restaurant', 'Food'),
            _buildAmenityTab('hotel', 'Hotels'),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 170,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _places.length,
            itemBuilder: (context, index) {
              final place = _places[index];
              if (_activeTab != 'all' && place.type != _activeTab) {
                return const SizedBox.shrink();
              }

              IconData icon;
              if (place.type == 'restaurant') {
                icon = Icons.restaurant;
              } else if (place.type == 'cafe') {
                icon = Icons.local_cafe;
              } else if (place.type == 'shopping_mall') {
                icon = Icons.shopping_bag;
              } else if (place.type == 'washroom') {
                icon = Icons.wc;
              } else if (place.type == 'atm') {
                icon = Icons.local_atm;
              } else if (place.type == 'hospital') {
                icon = Icons.local_hospital;
              } else {
                icon = Icons.hotel;
              }

              return Container(
                width: 180,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    image: NetworkImage(place.imageUrl),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken),
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                        child: Icon(icon, color: Colors.white, size: 14),
                      ),
                      const Spacer(),
                      Text(
                        place.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${place.distance.toInt()}m', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                          Row(
                            children: [
                              const Icon(Icons.star, color: AppColors.warning, size: 11),
                              const SizedBox(width: 2),
                              Text(
                                place.rating.toStringAsFixed(1),
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Routing to ${place.name}...')),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                          ),
                          child: const Center(
                            child: Text(
                              'Navigate',
                              style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAmenityTab(String tab, String label) {
    final isSelected = _activeTab == tab;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = tab;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildReviewsList() {
    final reviews = [
      {'name': 'Karan Sharma', 'rating': 5.0, 'comment': 'Extremely fast 120kW charging! Highly recommended station.'},
      {'name': 'Ananya Sen', 'rating': 4.0, 'comment': 'Clean location with washrooms and a Starbucks nearby.'},
    ];

    return Column(
      children: reviews.map((r) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(r['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                    Row(
                      children: List.generate(5, (idx) {
                        return Icon(
                          Icons.star,
                          size: 12,
                          color: idx < (r['rating'] as double) ? AppColors.warning : Colors.white10,
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  r['comment'] as String,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

