import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:evhub/core/theme/app_colors.dart';
import 'glass_border_painter.dart';

class GlassContainer extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final List<Color>? borderColors;
  final double borderWidth;
  final bool animateBorder;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.padding = const EdgeInsets.all(24.0),
    this.margin = EdgeInsets.zero,
    this.borderColors,
    this.borderWidth = 1.2,
    this.animateBorder = true,
  });

  @override
  State<GlassContainer> createState() => _GlassContainerState();
}

class _GlassContainerState extends State<GlassContainer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );
    if (widget.animateBorder) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant GlassContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateBorder != oldWidget.animateBorder) {
      if (widget.animateBorder) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultBorderColors = [
      AppColors.primary.withOpacity(0.4),
      AppColors.accent.withOpacity(0.1),
      AppColors.secondary.withOpacity(0.4),
      AppColors.primary.withOpacity(0.4),
    ];

    return Container(
      margin: widget.margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Stack(
            children: [
              // Card background
              Container(
                padding: widget.padding,
                decoration: BoxDecoration(
                  color: AppColors.card.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 24,
                      spreadRadius: -4,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: widget.child,
              ),
              // Glowing animated border overlay
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: GlassBorderPainter(
                          animationValue: widget.animateBorder ? _controller.value : 0.0,
                          borderRadius: widget.borderRadius,
                          borderColors: widget.borderColors ?? defaultBorderColors,
                          borderWidth: widget.borderWidth,
                        ),
                      );
                    },
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

