import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/glass_container.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
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
  int _currentIndex = 0;
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.user ?? UserModel.guest();
    final brandColor = themeProvider.currentBrandColor;

    // Dynamically construct nav items based on user role
    final List<Widget> screens = [
      const DashboardScreen(),     // 0. Dashboard
      const MapsScreen(),          // 1. Maps
      const RoutePlannerScreen(),  // 2. Trips
      const LiveChargingScreen(),  // 3. Charging
      const Wallet2Screen(),        // 4. Wallet
      const GarageScreen(),         // 5. Garage
      const AIAssistantScreen(),   // 6. AI Assistant
      const ProfileScreen(),        // 7. Settings / Profile
    ];

    final List<Map<String, dynamic>> navItems = [
      {'title': 'Dashboard', 'icon': HugeIcons.strokeRoundedGrid02},
      {'title': 'Maps', 'icon': HugeIcons.strokeRoundedMapsLocation01},
      {'title': 'Trips', 'icon': HugeIcons.strokeRoundedRoute01},
      {'title': 'Charging', 'icon': HugeIcons.strokeRoundedFlash},
      {'title': 'Wallet', 'icon': HugeIcons.strokeRoundedWallet02},
      {'title': 'Garage', 'icon': HugeIcons.strokeRoundedCar02},
      {'title': 'AI Assistant', 'icon': HugeIcons.strokeRoundedAiChat01},
      {'title': 'Settings', 'icon': HugeIcons.strokeRoundedSettings01},
    ];

    if (currentUser.canManageChargers) {
      screens.add(const AdminDashboardScreen());
      navItems.add({
        'title': currentUser.isAdmin ? 'Admin Portal' : 'Partner Portal',
        'icon': currentUser.isAdmin ? HugeIcons.strokeRoundedSecurity : HugeIcons.strokeRoundedStore01,
      });
    }

    final safeIndex = _currentIndex >= screens.length ? 0 : _currentIndex;

    return Scaffold(
      body: Row(
        children: [
          // Custom Expandable Left Floating Navigation Rail
          _buildFloatingSidebar(brandColor, navItems, safeIndex),
          
          // Main screen viewport
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.02, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey<int>(safeIndex),
                child: screens[safeIndex],
              ),
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
              // Header logo / Toggle button
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
                          gradient: AppColors.chargingGradient,
                          shape: BoxShape.circle,
                          boxShadow: AppColors.neonShadow(color: AppColors.primary, blurRadius: 10),
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
              
              // Navigation Items List
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
                            gradient: isSelected
                                ? LinearGradient(
                                    colors: [
                                      brandColor.withOpacity(0.35),
                                      brandColor.withOpacity(0.05),
                                    ],
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(16),
                            border: isSelected
                                ? Border.all(color: brandColor.withOpacity(0.4), width: 1)
                                : Border.all(color: Colors.transparent, width: 1),
                          ),
                          child: Row(
                            mainAxisAlignment: _isExpanded
                                ? MainAxisAlignment.start
                                : MainAxisAlignment.center,
                            children: [
                              HugeIcon(
                                icon: item['icon'] as List<List<dynamic>>,
                                color: isSelected ? brandColor : AppColors.textSecondary,
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

              // Expand / Collapse Chevron Button at bottom
              const Divider(color: Colors.white10, height: 24, thickness: 1),
              InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  width: double.infinity,
                  child: Center(
                    child: HugeIcon(
                      icon: _isExpanded
                          ? HugeIcons.strokeRoundedArrowLeft01
                          : HugeIcons.strokeRoundedArrowRight01,
                      color: AppColors.textSecondary,
                      size: 20.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

