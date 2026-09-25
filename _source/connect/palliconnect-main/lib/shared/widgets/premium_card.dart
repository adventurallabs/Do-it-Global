import 'package:flutter/material.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';

class PremiumCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool luminous;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.luminous = false,
  });

  @override
  State<PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends State<PremiumCard> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.978).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null) _scaleController.forward();
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap != null) _scaleController.reverse();
  }

  void _onTapCancel() {
    if (widget.onTap != null) _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(AppSpacing.radiusLg);
    final fill = widget.color ??
        (isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.78)
            : Colors.white.withValues(alpha: 0.78));

    final card = AnimatedBuilder(
      animation: _scale,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: child,
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.luminous
                ? [
                    AppColors.skyBlue.withValues(alpha: isDark ? 0.55 : 0.85),
                    AppColors.primaryBlue.withValues(alpha: 0.9),
                    AppColors.leafGreen.withValues(alpha: 0.7),
                  ]
                : [
                    Colors.white.withValues(alpha: isDark ? 0.22 : 0.95),
                    AppColors.skyBlue.withValues(alpha: isDark ? 0.18 : 0.28),
                    AppColors.leafGreen.withValues(alpha: isDark ? 0.10 : 0.16),
                  ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.22 : 0.10),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: AppColors.leafGreen.withValues(alpha: isDark ? 0.08 : 0.05),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(1.15),
          child: Material(
            color: fill,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg - 1),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: widget.padding ?? const EdgeInsets.all(AppSpacing.md),
              child: widget.child,
            ),
          ),
        ),
      ),
    );

    if (widget.onTap == null) return card;
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: card,
    );
  }
}
