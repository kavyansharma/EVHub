import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glowing_button.dart';
import '../../components/station_card.dart';
import '../../components/wallet_card.dart';
import '../../data/mock_data.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;

  // Find Chargers state
  String _chargerSearchQuery = '';
  String _selectedFilter = 'All'; // 'All', 'Ultra Fast', 'Tesla Compatible'

  // Trip Planner state
  final _originController = TextEditingController(text: 'San Francisco');
  final _destController = TextEditingController(text: 'Los Angeles');
  bool _tripCalculated = false;

  // AI Assistant state
  final List<ChatMessage> _aiMessages = [
    ChatMessage(
      text: 'Hello! I am your EVHub AI Assistant. Ask me anything about nearby stations, billing, or trip optimization!',
      isUser: false,
      timestamp: DateTime.now(),
    ),
  ];
  final _aiChatController = TextEditingController();
  final _aiScrollController = ScrollController();

  @override
  void dispose() {
    _originController.dispose();
    _destController.dispose();
    _aiChatController.dispose();
    _aiScrollController.dispose();
    super.dispose();
  }

  void _sendAiMessage() {
    final query = _aiChatController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _aiMessages.add(ChatMessage(
        text: query,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _aiChatController.clear();
    });

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_aiScrollController.hasClients) {
        _aiScrollController.animateTo(
          _aiScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // Simulate AI thinking and reply
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      final reply = MockData.getAiResponse(query);
      setState(() {
        _aiMessages.add(ChatMessage(
          text: reply,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      // Scroll to bottom again
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_aiScrollController.hasClients) {
          _aiScrollController.animateTo(
            _aiScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.electric_bolt_rounded,
              color: isDark ? AppColors.primaryCyan : AppColors.primaryPurple,
            ),
            const SizedBox(width: 8),
            const Text(
              'EVHub',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.themeMode == ThemeMode.dark
                  ? Icons.dark_mode_rounded
                  : themeProvider.themeMode == ThemeMode.light
                      ? Icons.light_mode_rounded
                      : Icons.settings_brightness_rounded,
            ),
            onPressed: () {
              if (themeProvider.themeMode == ThemeMode.system) {
                themeProvider.setThemeMode(ThemeMode.light);
              } else if (themeProvider.themeMode == ThemeMode.light) {
                themeProvider.setThemeMode(ThemeMode.dark);
              } else {
                themeProvider.setThemeMode(ThemeMode.system);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background blobs
          if (isDark) ...[
            Positioned(
              top: -80,
              left: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryCyan.withOpacity(0.05),
                      blurRadius: 90,
                      spreadRadius: 90,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              right: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPurple.withOpacity(0.05),
                      blurRadius: 90,
                      spreadRadius: 90,
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          SafeArea(
            child: IndexedStack(
              index: _currentTab,
              children: [
                _buildDashboardTab(),
                _buildChargersTab(),
                _buildTripPlannerTab(),
                _buildAiAssistantTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppColors.glassBorder(Theme.of(context).brightness),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (index) => setState(() => _currentTab = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
          selectedItemColor: isDark ? AppColors.primaryCyan : AppColors.primaryPurple,
          unselectedItemColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.ev_station_rounded),
              label: 'Chargers',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_rounded),
              label: 'Planner',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assistant_rounded),
              label: 'Assistant',
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: DASHBOARD
  // ==========================================
  Widget _buildDashboardTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Welcome Card
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                child: Icon(
                  user?.isGuest == true ? Icons.account_circle_outlined : Icons.person_rounded,
                  size: 32,
                  color: isDark ? AppColors.primaryCyan : AppColors.primaryPurple,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${user?.name ?? 'Guest Driver'}!',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      user?.email ?? 'guest_session@evhub.com',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Universal Wallet Section
          Text(
            'Universal Wallet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          WalletCard(
            balance: user?.walletBalance ?? 0.0,
            onAddFunds: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Simulated funding request initiated! Balance updated by +\$50.00'),
                  backgroundColor: AppColors.accentGreen,
                ),
              );
            },
            onHistory: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) {
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Transaction History',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildTransactionItem('EVHub Supercharger Alpha', '-\$14.25', 'Today, 10:14 AM', true),
                        _buildTransactionItem('Wallet Top-up', '+\$50.00', 'Yesterday, 6:00 PM', false),
                        _buildTransactionItem('Greenway Rapid Charging', '-\$8.80', 'Oct 12, 2:45 PM', true),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 28),

          // Quick actions Grid
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.6,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildQuickAction(
                icon: Icons.electric_car_rounded,
                title: 'Start Charge',
                subtitle: 'Scan QR code',
                color: AppColors.primaryCyan,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Simulating Scan QR charger interface...')),
                  );
                },
              ),
              _buildQuickAction(
                icon: Icons.map_rounded,
                title: 'Smart Routes',
                subtitle: 'Calculate trip stops',
                color: AppColors.primaryPurple,
                onTap: () => setState(() => _currentTab = 2),
              ),
              _buildQuickAction(
                icon: Icons.assistant_rounded,
                title: 'AI Helper',
                subtitle: 'Optimize battery',
                color: AppColors.accentGreen,
                onTap: () => setState(() => _currentTab = 3),
              ),
              _buildQuickAction(
                icon: Icons.settings_rounded,
                title: 'Account Settings',
                subtitle: 'Configure app details',
                color: AppColors.accentAmber,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Simulated settings screen')),
                  );
                },
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          // Logout Button
          ElevatedButton(
            onPressed: () async {
              await authProvider.logout();
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Log Out Session'),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(String title, String amount, String date, bool isExpense) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isExpense ? AppColors.dangerRed.withOpacity(0.12) : AppColors.accentGreen.withOpacity(0.12),
        child: Icon(
          isExpense ? Icons.bolt_rounded : Icons.add_circle_outline_rounded,
          color: isExpense ? AppColors.dangerRed : AppColors.accentGreen,
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: Text(date, style: const TextStyle(fontSize: 12)),
      trailing: Text(
        amount,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isExpense ? AppColors.dangerRed : AppColors.accentGreen,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      borderRadius: 16,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: FIND CHARGERS
  // ==========================================
  Widget _buildChargersTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter list
    final filteredStations = MockData.stations.where((st) {
      // Filter by search query
      final matchesSearch = st.name.toLowerCase().contains(_chargerSearchQuery.toLowerCase()) ||
          st.location.toLowerCase().contains(_chargerSearchQuery.toLowerCase());
      
      // Filter by type
      if (!matchesSearch) return false;
      if (_selectedFilter == 'Ultra Fast') {
        return st.power >= 150.0;
      } else if (_selectedFilter == 'Tesla Compatible') {
        return st.isTeslaCompatible;
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // Search Bar
          TextField(
            onChanged: (val) => setState(() => _chargerSearchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search charging stations...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _chargerSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () => setState(() {
                        _chargerSearchQuery = '';
                      }),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),

          // Filters Row
          Row(
            children: ['All', 'Ultra Fast', 'Tesla Compatible'].map((filter) {
              final isSelected = _selectedFilter == filter;
              final accentColor = isDark ? AppColors.primaryCyan : AppColors.primaryPurple;
              return Container(
                margin: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    filter,
                    style: TextStyle(
                      color: isSelected ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white : Colors.black),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: accentColor,
                  backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected ? Colors.transparent : AppColors.glassBorder(Theme.of(context).brightness),
                    ),
                  ),
                  onSelected: (val) {
                    if (val) {
                      setState(() => _selectedFilter = filter);
                    }
                  },
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Station List
          Expanded(
            child: filteredStations.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.ev_station_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No charging stations match your criteria'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredStations.length,
                    itemBuilder: (context, index) {
                      final st = filteredStations[index];
                      return StationCard(
                        station: st,
                        onTap: () => _showStationDetails(st),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showStationDetails(ChargingStation st) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    st.name,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    st.location,
                    style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                  const SizedBox(height: 20),
                  
                  // Specification details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDetailSpecBox('Max Power', AppFormatters.formatPower(st.power), Icons.flash_on_rounded),
                      _buildDetailSpecBox('Plug Count', '${st.totalStalls} plugs', Icons.power_rounded),
                      _buildDetailSpecBox('Cost', '${AppFormatters.formatCurrency(st.pricePerKWh)}/kWh', Icons.attach_money_rounded),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  const Text('Available Plugs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  ...st.plugs.map((plug) => ListTile(
                        leading: const Icon(Icons.settings_input_hdmi_rounded),
                        title: Text(plug),
                        subtitle: const Text('Available now'),
                        trailing: Text(
                          AppFormatters.formatCurrency(st.pricePerKWh),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        contentPadding: EdgeInsets.zero,
                      )),
                  
                  const SizedBox(height: 32),
                  GlowingButton(
                    text: 'Navigate to Station',
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Starting navigation to ${st.name}...')),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailSpecBox(String label, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: isDark ? AppColors.primaryCyan : AppColors.primaryPurple),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: TRIP PLANNER
  // ==========================================
  Widget _buildTripPlannerTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Route inputs
          GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.alt_route_rounded, color: AppColors.accentAmber),
                    SizedBox(width: 8),
                    Text(
                      'AI Intelligent Route Planner',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _originController,
                  decoration: const InputDecoration(
                    labelText: 'Departure City',
                    prefixIcon: Icon(Icons.my_location_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _destController,
                  decoration: const InputDecoration(
                    labelText: 'Destination City',
                    prefixIcon: Icon(Icons.flag_rounded),
                  ),
                ),
                const SizedBox(height: 20),
                GlowingButton(
                  text: 'Calculate Optimized Stops',
                  onPressed: () {
                    setState(() {
                      _tripCalculated = true;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Output Roadmap
          if (_tripCalculated) ...[
            Text(
              'Trip Roadmap & Charging Stops',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: MockData.tripStops.length,
              itemBuilder: (context, index) {
                final stop = MockData.tripStops[index];
                final isLast = index == MockData.tripStops.length - 1;
                
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline dots and lines
                    Column(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index == 0
                                ? AppColors.primaryPurple
                                : isLast
                                    ? AppColors.primaryCyan
                                    : AppColors.accentGreen,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            index == 0
                                ? Icons.navigation_rounded
                                : isLast
                                    ? Icons.place_rounded
                                    : Icons.bolt_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 3,
                            height: 70,
                            color: isDark ? Colors.white24 : Colors.black12,
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),

                    // Roadmap details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stop.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            index == 0
                                ? 'Full Battery (100%) • Starting Point'
                                : isLast
                                    ? 'Estimated Arrival at ${AppFormatters.formatPercentage(stop.estimatedBatteryPercent)} battery'
                                    : 'Arrive at ${AppFormatters.formatPercentage(stop.estimatedBatteryPercent)} battery • Charge for ${stop.chargeTimeMinutes.toStringAsFixed(0)} mins',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          if (stop.distanceFromStart > 0)
                            Text(
                              'Distance: ${AppFormatters.formatDistance(stop.distanceFromStart)} from origin',
                              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                            ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: AI ASSISTANT
  // ==========================================
  Widget _buildAiAssistantTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // AI greeting info
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            borderRadius: 16,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryCyan.withOpacity(0.12),
                  child: const Icon(Icons.smart_toy_rounded, color: AppColors.primaryCyan),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EVHub AI Smart Concierge',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'Powered by EVHub Cloud Core AI',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Chat messages list
        Expanded(
          child: ListView.builder(
            controller: _aiScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _aiMessages.length,
            itemBuilder: (context, index) {
              final msg = _aiMessages[index];
              return Align(
                alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(msg.isUser ? 16 : 0),
                      bottomRight: Radius.circular(msg.isUser ? 0 : 16),
                    ),
                    color: msg.isUser
                        ? (isDark ? AppColors.primaryCyan : AppColors.primaryPurple)
                        : (isDark ? AppColors.darkSurfaceCard : Colors.white),
                    border: msg.isUser
                        ? null
                        : Border.all(color: AppColors.glassBorder(Theme.of(context).brightness)),
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      color: msg.isUser
                          ? (isDark ? Colors.black : Colors.white)
                          : (isDark ? Colors.white : Colors.black87),
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Input bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.glassBorder(Theme.of(context).brightness)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _aiChatController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendAiMessage(),
                  decoration: const InputDecoration(
                    hintText: 'Type your message...',
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.send_rounded,
                  color: isDark ? AppColors.primaryCyan : AppColors.primaryPurple,
                ),
                onPressed: _sendAiMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
