import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/glass_container.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import 'dashboard/dashboard_screen.dart';
import 'phase4/maps_screen.dart';
import 'phase4/route_planner_screen.dart';
import 'charging/live_charging_screen.dart';
import 'phase4/wallet_2_screen.dart';
import 'garage/garage_screen.dart';
import 'ai/ai_assistant_screen.dart';
import 'phase4/profile_screen.dart';
import 'admin/admin_dashboard_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 1; // Default to MapsScreen (index 1) for EV charging focus
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.user ?? UserModel.guest();
    final brandColor = const Color(0xFF10B981); // EVHub Emerald Green

    final List<Widget> screens = [
      const DashboardScreen(),     // 0. Dashboard
      const MapsScreen(),          // 1. Maps
      const RoutePlannerScreen(),  // 2. Trips
      const LiveChargingScreen(),  // 3. Charging / Sessions
      const Wallet2Screen(),        // 4. Wallet
      const GarageScreen(),         // 5. Garage
      const AIAssistantScreen(),   // 6. AI Assistant
      const ProfileScreen(),        // 7. Profile
    ];

    final List<Map<String, dynamic>> navItems = [
      {'title': 'Dashboard', 'icon': HugeIcons.strokeRoundedGrid02},
      {'title': 'Maps', 'icon': HugeIcons.strokeRoundedMapsLocation01},
      {'title': 'Trips', 'icon': HugeIcons.strokeRoundedRoute01},
      {'title': 'Charging', 'icon': HugeIcons.strokeRoundedFlash},
      {'title': 'Wallet', 'icon': HugeIcons.strokeRoundedWallet02},
      {'title': 'Garage', 'icon': HugeIcons.strokeRoundedCar02},
      {'title': 'AI Assistant', 'icon': HugeIcons.strokeRoundedAiChat01},
      {'title': 'Profile', 'icon': HugeIcons.strokeRoundedUser},
    ];

    if (currentUser.canManageChargers) {
      screens.add(const AdminDashboardScreen());
      navItems.add({
        'title': currentUser.isAdmin ? 'Admin Portal' : 'Partner Portal',
        'icon': currentUser.isAdmin ? HugeIcons.strokeRoundedSecurity : HugeIcons.strokeRoundedStore01,
      });
    }

    final safeIndex = _currentIndex >= screens.length ? 1 : _currentIndex;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Main Content Viewport
          Positioned.fill(
            child: Row(
              children: [
                if (!isMobile) _buildFloatingSidebar(brandColor, navItems, safeIndex),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: KeyedSubtree(
                      key: ValueKey<int>(safeIndex),
                      child: screens[safeIndex],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // FLOATING WHITE ROUNDED BOTTOM NAVIGATION BAR (Mobile / Responsive View)
          if (isMobile)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildBottomNavItem(
                        icon: HugeIcons.strokeRoundedMapsLocation01,
                        label: 'Map',
                        isSelected: safeIndex == 1,
                        onTap: () => setState(() => _currentIndex = 1),
                      ),
                      _buildBottomNavItem(
                        icon: HugeIcons.strokeRoundedRoute01,
                        label: 'Trip Planner',
                        isSelected: safeIndex == 2,
                        onTap: () => setState(() => _currentIndex = 2),
                      ),
                      _buildBottomNavItem(
                        icon: HugeIcons.strokeRoundedWallet02,
                        label: 'Wallet',
                        isSelected: safeIndex == 4,
                        onTap: () => setState(() => _currentIndex = 4),
                      ),
                      _buildBottomNavItem(
                        icon: HugeIcons.strokeRoundedFlash,
                        label: 'Sessions',
                        isSelected: safeIndex == 3,
                        onTap: () => setState(() => _currentIndex = 3),
                      ),
                      _buildBottomNavItem(
                        icon: HugeIcons.strokeRoundedUser,
                        label: 'Profile',
                        isSelected: safeIndex == 7,
                        onTap: () => setState(() => _currentIndex = 7),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNavItem({
    required List<List<dynamic>> icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final activeColor = const Color(0xFF10B981);
    final inactiveColor = const Color(0xFF94A3B8);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: icon,
            color: isSelected ? activeColor : inactiveColor,
            size: 22,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: isSelected ? activeColor : inactiveColor,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingSidebar(Color brandColor, List<Map<String, dynamic>> navItems, int activeIndex) {
    return SafeArea(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: _isExpanded ? 200 : 76,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: GlassContainer(
          padding: const EdgeInsets.all(8),
          borderRadius: 24.0,
          child: Column(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          boxShadow: AppColors.neonShadow(color: const Color(0xFF10B981), blurRadius: 10),
                        ),
                        child: const Icon(Icons.bolt, color: Colors.black, size: 20),
                      ),
                      if (_isExpanded) ...[
                        const SizedBox(width: 12),
                        const Text(
                          'EVHub',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(color: Colors.white10, height: 24, thickness: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: navItems.length,
                  itemBuilder: (context, index) {
                    final item = navItems[index];
                    final isSelected = activeIndex == index;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _currentIndex = index;
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: _isExpanded ? 16 : 0,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF10B981).withOpacity(0.2) : null,
                            borderRadius: BorderRadius.circular(16),
                            border: isSelected
                                ? Border.all(color: const Color(0xFF10B981), width: 1)
                                : Border.all(color: Colors.transparent, width: 1),
                          ),
                          child: Row(
                            mainAxisAlignment: _isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                            children: [
                              HugeIcon(
                                icon: item['icon'] as List<List<dynamic>>,
                                color: isSelected ? const Color(0xFF10B981) : AppColors.textSecondary,
                                size: 22.0,
                              ),
                              if (_isExpanded) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item['title'] as String,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : AppColors.textSecondary,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
