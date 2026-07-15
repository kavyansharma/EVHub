import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GlowingButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? glowColor;
  final Color? buttonColor;
  final Color? textColor;
  final IconData? icon;

  const GlowingButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.glowColor,
    this.buttonColor,
    this.textColor,
    this.icon,
  });

  @override
  State<GlowingButton> createState() => _GlowingButtonState();
}

class _GlowingButtonState extends State<GlowingButton> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryGlow = widget.glowColor ??
        (isDark ? AppColors.primaryCyan : AppColors.primaryPurple);
    final buttonBg = widget.buttonColor ??
        (isDark ? AppColors.primaryCyan : AppColors.primaryPurple);
    final textCol = widget.textColor ?? (isDark ? Colors.black : Colors.white);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onPressed();
        },
        onTapCancel: () => _controller.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: buttonBg,
              boxShadow: _isHovered
                  ? AppColors.neonShadow(color: primaryGlow, blurRadius: 20)
                  : AppColors.neonShadow(color: primaryGlow.withOpacity(0.5), blurRadius: 10),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: textCol),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.text,
                    style: TextStyle(
                      color: textCol,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
