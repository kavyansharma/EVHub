import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _batteryController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  @override
  void initState() {
    super.initState();

    // Logo fade & scale animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    // Battery loading animation (charges from 0 to 100 repeatedly)
    _batteryController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _logoController.forward();
    _startSessionResolution();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _batteryController.dispose();
    super.dispose();
  }

  Future<void> _startSessionResolution() async {
    // Hold splash for 3.5 seconds to show smooth loading
    await Future.delayed(const Duration(milliseconds: 3500));
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // 1. Restore previous login session if any
    final bool sessionRestored = await authProvider.restoreSession();

    if (!mounted) return;

    if (sessionRestored) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else if (authProvider.isFirstLaunch) {
      Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppColors.darkBackground, const Color(0xFF0F1626)]
                : [AppColors.lightBackground, const Color(0xFFE3F2FD)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Decorative background glow dots (Premium look)
              if (isDark) ...[
                Positioned(
                  top: -100,
                  left: -100,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryPurple.withOpacity(0.15),
                          blurRadius: 100,
                          spreadRadius: 100,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: -100,
                  right: -100,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryCyan.withOpacity(0.15),
                          blurRadius: 100,
                          spreadRadius: 100,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              // Centered Brand Content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo Animation
                    AnimatedBuilder(
                      animation: _logoController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _logoScale.value,
                          child: Opacity(
                            opacity: _logoOpacity.value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? AppColors.darkSurface : Colors.white,
                          border: Border.all(
                            color: isDark ? AppColors.primaryCyan.withOpacity(0.3) : AppColors.primaryPurple.withOpacity(0.2),
                            width: 2,
                          ),
                          boxShadow: isDark
                              ? AppColors.neonShadow(color: AppColors.primaryCyan, blurRadius: 20)
                              : [
                                  BoxShadow(
                                    color: AppColors.primaryPurple.withOpacity(0.1),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  )
                                ],
                        ),
                        child: Icon(
                          Icons.electric_bolt_rounded,
                          size: 64,
                          color: isDark ? AppColors.primaryCyan : AppColors.primaryPurple,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // App Name with glow
                    Text(
                      'EVHub',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            shadows: isDark
                                ? [
                                    Shadow(
                                      color: AppColors.primaryCyan.withOpacity(0.5),
                                      blurRadius: 8,
                                    )
                                  ]
                                : null,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Intelligent EV Charging Network',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            letterSpacing: 1.2,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                    ),
                    const SizedBox(height: 80),
                    
                    // Battery Charging Custom Painter Animation
                    AnimatedBuilder(
                      animation: _batteryController,
                      builder: (context, child) {
                        return CustomPaint(
                          size: const Size(60, 30),
                          painter: BatteryProgressPainter(
                            progress: _batteryController.value,
                            color: isDark ? AppColors.primaryCyan : AppColors.primaryPurple,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Painter for drawing charging battery on Splash Screen
class BatteryProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  BatteryProgressPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paintOutline = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final paintFill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 1. Draw battery outline
    final batteryRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width - 6, size.height),
      const Radius.circular(6),
    );
    canvas.drawRRect(batteryRect, paintOutline);

    // 2. Draw battery tip (cap)
    final tipRect = Rect.fromLTWH(
      size.width - 4,
      size.height * 0.3,
      4,
      size.height * 0.4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(tipRect, const Radius.circular(2)),
      paintOutline..style = PaintingStyle.fill,
    );

    // 3. Draw battery fill levels (simulated charging steps)
    paintOutline.style = PaintingStyle.stroke;
    final int fillSegments = (progress * 5).floor() + 1; // 1 to 5 sections
    const double padding = 3.0;
    final double segmentWidth = (size.width - 12 - (4 * padding)) / 5;

    for (int i = 0; i < fillSegments; i++) {
      final rect = Rect.fromLTWH(
        padding + i * (segmentWidth + padding),
        padding,
        segmentWidth,
        size.height - (padding * 2),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paintFill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BatteryProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
