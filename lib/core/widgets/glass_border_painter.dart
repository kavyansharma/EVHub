import 'package:flutter/material.dart';
import 'dart:math' as math;

class GlassBorderPainter extends CustomPainter {
  final double animationValue;
  final double borderRadius;
  final List<Color> borderColors;
  final double borderWidth;

  GlassBorderPainter({
    required this.animationValue,
    required this.borderRadius,
    required this.borderColors,
    this.borderWidth = 1.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    // Use a SweepGradient to create a rotating neon border glow
    paint.shader = SweepGradient(
      colors: borderColors,
      stops: const [0.0, 0.3, 0.7, 1.0],
      transform: GradientRotation(animationValue * 2 * math.pi),
    ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant GlassBorderPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.borderColors != borderColors ||
        oldDelegate.borderWidth != borderWidth;
  }
}
