import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Soft luminous backdrop that sits behind every screen.
class BrandAtmosphere extends StatelessWidget {
  final Widget child;

  const BrandAtmosphere({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppColors.pageGradient(
              isDark ? Brightness.dark : Brightness.light,
            ),
          ),
        ),
        Positioned(
          top: -90,
          right: -50,
          child: _GlowOrb(
            size: 280,
            color: isDark ? AppColors.skyBlue : AppColors.primaryBlue,
            opacity: isDark ? 0.18 : 0.14,
          ),
        ),
        Positioned(
          top: 220,
          left: -110,
          child: _GlowOrb(
            size: 240,
            color: AppColors.leafGreen,
            opacity: isDark ? 0.12 : 0.10,
          ),
        ),
        Positioned(
          bottom: 40,
          right: -80,
          child: _GlowOrb(
            size: 200,
            color: isDark ? AppColors.heart : AppColors.skyBlue,
            opacity: isDark ? 0.10 : 0.08,
          ),
        ),
        child,
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _GlowOrb({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
