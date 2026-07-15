import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../providers/theme_provider.dart';
import 'dashboard/dashboard_screen.dart';
import 'phase4/maps_screen.dart';
import 'charging/live_charging_screen.dart';
import 'garage/garage_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(), // Home Dashboard
    const MapsScreen(), // Replaced in Batch 2
    const LiveChargingScreen(), // Replaced in Batch 4
    const GarageScreen(), // Replaced in Batch 3
    const Center(child: Text('Profile')),
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final brandColor = themeProvider.currentBrandColor;

    return Scaffold(
      body: _screens[_currentIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Action for Start Charging
          setState(() {
            _currentIndex = 2; // Jump to Charge Tab
          });
        },
        backgroundColor: brandColor,
        elevation: 8,
        shape: const CircleBorder(),
        child: const Icon(Icons.bolt, size: 32, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BottomAppBar(
            color: AppColors.card,
            shape: const CircularNotchedRectangle(),
            notchMargin: 10,
            child: SizedBox(
              height: 65,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.home_rounded, 'Home', brandColor),
                  _buildNavItem(1, Icons.map_rounded, 'Map', brandColor),
                  const SizedBox(width: 48), // Space for FAB
                  _buildNavItem(3, Icons.directions_car_rounded, 'Garage', brandColor),
                  _buildNavItem(4, Icons.person_rounded, 'Profile', brandColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, Color activeColor) {
    final isActive = _currentIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive ? activeColor.withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isActive ? activeColor : AppColors.textSecondary,
              size: isActive ? 28 : 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : AppColors.textSecondary,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          )
        ],
      ),
    );
  }
}
