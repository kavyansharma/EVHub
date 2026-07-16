import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../models/map_marker_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../services/places_service.dart';
import '../../providers/charging_session_provider.dart';
import '../../providers/auth_provider.dart';
import '../charging/live_charging_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final marker = widget.marker;
    final netColor = _getNetworkColor(marker.network);
    final sessionProvider = context.watch<ChargingSessionProvider>();

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
                                  marker.description,
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
                            child: _buildMetricCard('STALLS', marker.availableStalls, HugeIcons.strokeRoundedFuelStation, AppColors.secondary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard('PRICE', '₹21/kWh', HugeIcons.strokeRoundedLicense, Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Connector Grid
                      const Text(
                        'CONNECTOR SPECIFICATIONS',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      _buildConnectorRow('CCS2 Dual (DC Fast)', '120 kW SuperSpeed', '₹21.00 / kWh', true),
                      const SizedBox(height: 12),
                      _buildConnectorRow('Type 2 AC', '22 kW SmartCharge', '₹15.00 / kWh', true),
                      const SizedBox(height: 12),
                      _buildConnectorRow('CHAdeMO Fast', '50 kW FastCharge', '₹18.00 / kWh', false),
                      
                      const SizedBox(height: 28),

                      // Queue details
                      const Text(
                        'LIVE STATION AVAILABILITY',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      GlassContainer(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildLiveStallStat('Occupied', '1', Colors.grey),
                            Container(width: 1, height: 40, color: Colors.white10),
                            _buildLiveStallStat('Available', '3', AppColors.secondary),
                            Container(width: 1, height: 40, color: Colors.white10),
                            _buildLiveStallStat('Active Queue', '0 min', AppColors.primary),
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
                      // Trigger navigation UI or toast
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
                  // Book Slot
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Slot booked at ${marker.title}!'),
                            backgroundColor: AppColors.secondary,
                          ),
                        );
                      },
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Center(
                          child: Text(
                            'Book Slot',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Start Charging
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () {
                        final auth = context.read<AuthProvider>();
                        sessionProvider.startSession(
                          auth.user?.id ?? 'default_user',
                          marker.id,
                          'ccs2_1',
                        );
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LiveChargingScreen()),
                        );
                      },
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: AppColors.chargingGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppColors.neonShadow(color: AppColors.primary, blurRadius: 15),
                        ),
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.flash_on, color: Colors.black, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Charge Now',
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
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
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildConnectorRow(String type, String power, String price, bool isAvailable) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isAvailable ? AppColors.secondary : Colors.grey).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedPlug01,
              color: isAvailable ? AppColors.secondary : Colors.grey,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text('$power • $price', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (isAvailable ? AppColors.secondary : AppColors.danger).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (isAvailable ? AppColors.secondary : AppColors.danger).withOpacity(0.3),
              ),
            ),
            child: Text(
              isAvailable ? 'AVAILABLE' : 'IN USE',
              style: TextStyle(
                color: isAvailable ? AppColors.secondary : AppColors.danger,
                fontWeight: 'AVAILABLE'.contains('AVAIL') ? FontWeight.bold : FontWeight.normal,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStallStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
        // Tab indicator filters
        Row(
          children: [
            _buildAmenityTab('all', 'All'),
            _buildAmenityTab('cafe', 'Cafes'),
            _buildAmenityTab('restaurant', 'Food'),
            _buildAmenityTab('hotel', 'Hotels'),
          ],
        ),
        const SizedBox(height: 12),
        // Filtered places slider
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
                      // Navigate Button
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

