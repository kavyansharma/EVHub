import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  // Animation controller for illustration micro-animations
  late AnimationController _vectorController;

  @override
  void initState() {
    super.initState();
    _vectorController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _vectorController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _completeOnboarding() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.completeOnboarding();
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<OnboardingData> pages = [
      OnboardingData(
        title: 'Find Chargers',
        description: 'Locate ultra-fast charging stations near you in real-time. Filter by plug types, speeds, and live occupancy.',
        painter: RadarIllustrationPainter(
          animationValue: _vectorController,
          color: isDark ? AppColors.primaryCyan : AppColors.primaryPurple,
        ),
      ),
      OnboardingData(
        title: 'Universal Wallet',
        description: 'Pay securely across multiple operators without needing separate cards. Tap-and-charge with single-wallet convenience.',
        painter: WalletIllustrationPainter(
          animationValue: _vectorController,
          color: isDark ? AppColors.primaryPurple : AppColors.primaryCyan,
        ),
      ),
      OnboardingData(
        title: 'Smart Trip Planner',
        description: 'Map out road trips with automatic charging stops planned based on your car\'s battery capacity, elevation, and charger speed.',
        painter: RouteIllustrationPainter(
          animationValue: _vectorController,
          color: isDark ? AppColors.accentGreen : AppColors.primaryCyan,
        ),
      ),
      OnboardingData(
        title: 'AI Assistant',
        description: 'Ask our smart concierge to recommend top-rated chargers, predict queues, or optimize your charging curves.',
        painter: AssistantIllustrationPainter(
          animationValue: _vectorController,
          color: isDark ? AppColors.primaryCyan : AppColors.primaryPurple,
        ),
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          // Background subtle gradients
          if (isDark) ...[
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPurple.withOpacity(0.08),
                      blurRadius: 80,
                      spreadRadius: 80,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryCyan.withOpacity(0.08),
                      blurRadius: 80,
                      spreadRadius: 80,
                    ),
                  ],
                ),
              ),
            ),
          ],

          SafeArea(
            child: Column(
              children: [
                // Top Header (Skip Button)
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextButton(
                      onPressed: _completeOnboarding,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ),
                ),

                // Main Page View (Illustrations and Text)
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: pages.length,
                    itemBuilder: (context, index) {
                      final item = pages[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Custom Painter Animated Illustration
                            Container(
                              height: 240,
                              width: 240,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? AppColors.darkSurface : Colors.white,
                                border: Border.all(
                                  color: AppColors.glassBorder(Theme.of(context).brightness),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isDark ? Colors.black : Colors.grey).withOpacity(0.05),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  )
                                ],
                              ),
                              child: AnimatedBuilder(
                                animation: _vectorController,
                                builder: (context, child) {
                                  return CustomPaint(
                                    painter: item.painter,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 48),

                            // Text Title
                            Text(
                              item.title,
                              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 28,
                                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),

                            // Description
                            Text(
                              item.description,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    height: 1.5,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Footer Section (Indicators and CTA Buttons)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Page Indicators (Animated Dots)
                      Row(
                        children: List.generate(
                          pages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 8),
                            height: 8,
                            width: _currentIndex == index ? 24 : 8,
                            decoration: BoxDecoration(
                              color: _currentIndex == index
                                  ? (isDark ? AppColors.primaryCyan : AppColors.primaryPurple)
                                  : (isDark ? Colors.white24 : Colors.black12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),

                      // Next/Get Started Action Button
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _currentIndex == pages.length - 1
                            ? SizedBox(
                                width: 140,
                                height: 50,
                                child: ElevatedButton(
                                  key: const ValueKey('get_started'),
                                  onPressed: _completeOnboarding,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? AppColors.primaryCyan : AppColors.primaryPurple,
                                    foregroundColor: isDark ? Colors.black : Colors.white,
                                    minimumSize: Size.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text('Get Started'),
                                ),
                              )
                            : SizedBox(
                                width: 90,
                                height: 50,
                                child: ElevatedButton(
                                  key: const ValueKey('next'),
                                  onPressed: () {
                                    _pageController.nextPage(
                                      duration: const Duration(milliseconds: 350),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                                    foregroundColor: isDark ? Colors.white : AppColors.lightTextPrimary,
                                    minimumSize: Size.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(
                                        color: AppColors.glassBorder(Theme.of(context).brightness),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: const Icon(Icons.arrow_forward_rounded),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Onboarding Page DTO
class OnboardingData {
  final String title;
  final String description;
  final CustomPainter painter;

  OnboardingData({
    required this.title,
    required this.description,
    required this.painter,
  });
}

// --- Custom Painters for Premium Illustrations ---

// 1. Radar illustration (Find Chargers)
class RadarIllustrationPainter extends CustomPainter {
  final Animation<double> animationValue;
  final Color color;

  RadarIllustrationPainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paintRing = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw concentric radar rings
    canvas.drawCircle(center, size.width * 0.4, paintRing);
    canvas.drawCircle(center, size.width * 0.28, paintRing);
    canvas.drawCircle(center, size.width * 0.16, paintRing);

    // Draw sweeping radar line
    final angle = animationValue.value * 2 * math.pi;
    final sweepPaint = Paint()
      ..color = color.withOpacity(0.4)
      ..strokeWidth = 2.5;
    final sweepEnd = Offset(
      center.dx + size.width * 0.4 * math.cos(angle),
      center.dy + size.height * 0.4 * math.sin(angle),
    );
    canvas.drawLine(center, sweepEnd, sweepPaint);

    // Draw simulated charger pins blinking
    final pinPaint = Paint()..style = PaintingStyle.fill;
    final points = [
      Offset(center.dx - 40, center.dy - 30),
      Offset(center.dx + 50, center.dy - 40),
      Offset(center.dx + 30, center.dy + 45),
      Offset(center.dx - 45, center.dy + 25),
    ];

    for (int i = 0; i < points.length; i++) {
      final pinOffset = points[i];
      // Blinking effect based on sine wave offset
      final opacity = 0.3 + 0.7 * math.sin(animationValue.value * 2 * math.pi + i).abs();
      
      pinPaint.color = color.withOpacity(opacity);
      canvas.drawCircle(pinOffset, 6, pinPaint);
      canvas.drawCircle(pinOffset, 12, Paint()
        ..color = color.withOpacity(opacity * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1);
    }

    // Center locator dot
    canvas.drawCircle(center, 7, pinPaint..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 2. Wallet illustration (Universal Wallet)
class WalletIllustrationPainter extends CustomPainter {
  final Animation<double> animationValue;
  final Color color;

  WalletIllustrationPainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final t = animationValue.value;
    
    // Smooth hover/float offset using sine
    final yOffset = 10 * math.sin(t * 2 * math.pi);

    final cardRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + yOffset),
      width: size.width * 0.6,
      height: size.height * 0.35,
    );

    final cardRRect = RRect.fromRectAndRadius(cardRect, const Radius.circular(12));

    // Outer glow
    final glowPaint = Paint()
      ..color = color.withOpacity(0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRRect(cardRRect, glowPaint);

    // Card fill
    final cardPaint = Paint()
      ..shader = LinearGradient(
        colors: [color, color.withOpacity(0.5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(cardRect);
    canvas.drawRRect(cardRRect, cardPaint);

    // Chip decoration on card
    final chipRect = Rect.fromLTWH(
      cardRect.left + 15,
      cardRect.top + 15 + yOffset,
      20,
      15,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(chipRect, const Radius.circular(3)),
      Paint()..color = Colors.white.withOpacity(0.6),
    );

    // Dynamic wave ripples from payment card
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < 3; i++) {
      final rippleProgress = (t + i / 3.0) % 1.0;
      final radius = size.width * 0.3 * rippleProgress + 30;
      final opacity = 1.0 - rippleProgress;
      ringPaint.color = color.withOpacity(opacity * 0.4);
      canvas.drawCircle(center, radius, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 3. Route illustration (Smart Trip Planner)
class RouteIllustrationPainter extends CustomPainter {
  final Animation<double> animationValue;
  final Color color;

  RouteIllustrationPainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paintPath = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.15, size.height * 0.75);
    path.cubicTo(
      size.width * 0.25, size.height * 0.3,
      size.width * 0.6, size.height * 0.2,
      size.width * 0.85, size.height * 0.6,
    );

    // Draw main static route path
    canvas.drawPath(path, paintPath);

    // Animated traveler dot along the path
    final pathMetrics = path.computeMetrics().toList();
    if (pathMetrics.isNotEmpty) {
      final metric = pathMetrics.first;
      final distance = metric.length * (animationValue.value % 1.0);
      final tangent = metric.getTangentForOffset(distance);
      if (tangent != null) {
        final position = tangent.position;
        // Glow indicator
        canvas.drawCircle(position, 12, Paint()..color = color.withOpacity(0.25));
        canvas.drawCircle(position, 6, Paint()..color = color);
      }

      // Draw charger node stops along the route path
      final stopOffsets = [
        metric.getTangentForOffset(metric.length * 0.25)?.position,
        metric.getTangentForOffset(metric.length * 0.65)?.position,
      ];

      for (var offset in stopOffsets) {
        if (offset != null) {
          canvas.drawCircle(offset, 8, Paint()..color = AppColors.accentGreen);
          canvas.drawCircle(offset, 4, Paint()..color = Colors.white);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 4. Assistant Wave illustration (AI Assistant)
class AssistantIllustrationPainter extends CustomPainter {
  final Animation<double> animationValue;
  final Color color;

  AssistantIllustrationPainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paintWave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final int waveCount = 5;
    final double maxAmplitude = 25.0;

    for (int i = 0; i < waveCount; i++) {
      final double progress = i / (waveCount - 1);
      final double amp = maxAmplitude * math.sin(animationValue.value * 2 * math.pi + progress * math.pi);
      
      final wavePath = Path();
      wavePath.moveTo(size.width * 0.2, center.dy);

      for (double x = size.width * 0.2; x <= size.width * 0.8; x++) {
        // Sine wave calculations
        final double xNorm = (x - size.width * 0.2) / (size.width * 0.6);
        final double y = center.dy + amp * math.sin(xNorm * 3 * math.pi + animationValue.value * 2 * math.pi) * (1.0 - math.pow(2 * xNorm - 1.0, 2));
        wavePath.lineTo(x, y);
      }

      paintWave.color = color.withOpacity((1.0 - progress * 0.7) * 0.5);
      canvas.drawPath(wavePath, paintWave);
    }

    // AI Core circle in center
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withOpacity(0.2), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: 24));
    canvas.drawCircle(center, 24, corePaint);
    canvas.drawCircle(center, 8, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
