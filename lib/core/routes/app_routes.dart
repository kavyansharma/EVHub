import 'package:flutter/material.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/signup_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/onboarding/vehicle_onboarding_screen.dart';
import '../../screens/main_navigation_screen.dart';
import '../../screens/admin/admin_dashboard_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot_password';
  static const String vehicleOnboarding = '/vehicle_onboarding';
  static const String home = '/home';
  static const String admin = '/admin';
  static const String partner = '/partner';
  static const String adminDashboard = '/admin_dashboard';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _buildFadeRoute(const SplashScreen());
      case onboarding:
        return _buildFadeRoute(const OnboardingScreen());
      case login:
        return _buildFadeRoute(const LoginScreen());
      case signup:
        return _buildFadeRoute(const SignupScreen());
      case forgotPassword:
        return _buildFadeRoute(const ForgotPasswordScreen());
      case vehicleOnboarding:
        return _buildFadeRoute(const VehicleOnboardingScreen());
      case home:
        return _buildFadeRoute(const MainNavigationScreen());
      case admin:
      case partner:
        return _buildFadeRoute(const MainNavigationScreen());
      case adminDashboard:
        return _buildFadeRoute(const AdminDashboardScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }

  static PageRouteBuilder _buildFadeRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 500),
    );
  }
}
