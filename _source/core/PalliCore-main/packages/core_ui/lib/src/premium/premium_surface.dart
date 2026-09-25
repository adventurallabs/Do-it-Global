import 'package:flutter/material.dart';
import 'decorative_arcs.dart';
import 'premium_border.dart';
import 'premium_colors.dart';
import 'premium_constants.dart';
import 'premium_shadows.dart';

enum PremiumSurfaceType { card, pill, circle }

enum PremiumFinish { raised, recessed }

/// Layered admin material. One widget, any shape.
///
/// 1. Soft outer shadow
/// 2. Gold gradient outer edge
/// 3. Thin inner white highlight
/// 4. Warm surface gradient
/// 5. Optional decorative arcs
/// 6. Content
class PremiumSurface extends StatelessWidget {
  final Widget child;
  final PremiumSurfaceType type;
  final BorderRadius? borderRadius;
  final bool showGoldBorder;
  final bool showArcs;
  final bool showInnerHighlight;
  final PremiumFinish finish;
  final PremiumElevation elevation;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  const PremiumSurface({
    super.key,
    required this.child,
    this.type = PremiumSurfaceType.card,
    this.borderRadius,
    this.showGoldBorder = true,
    this.showArcs = false,
    this.showInnerHighlight = true,
    this.finish = PremiumFinish.raised,
    this.elevation = PremiumElevation.card,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
  });

  const PremiumSurface.card({
    super.key,
    required this.child,
    this.showArcs = true,
    this.padding,
    this.margin,
    this.onTap,
    this.elevation = PremiumElevation.card,
  })  : type = PremiumSurfaceType.card,
        borderRadius = null,
        showGoldBorder = true,
        showInnerHighlight = true,
        finish = PremiumFinish.raised,
        width = null,
        height = null;

  const PremiumSurface.circle({
    super.key,
    required this.child,
    this.width = PremiumConstants.circleButton,
    this.height = PremiumConstants.circleButton,
    this.padding,
    this.margin,
    this.onTap,
    this.elevation = PremiumElevation.control,
    this.finish = PremiumFinish.raised,
  })  : type = PremiumSurfaceType.circle,
        borderRadius = null,
        showGoldBorder = true,
        showInnerHighlight = true,
        showArcs = false;

  const PremiumSurface.pill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.margin,
    this.onTap,
    this.elevation = PremiumElevation.control,
  })  : type = PremiumSurfaceType.pill,
        borderRadius = null,
        showGoldBorder = true,
        showInnerHighlight = true,
        showArcs = false,
        finish = PremiumFinish.raised,
        width = null,
        height = null;

  BoxShape get _shape => type == PremiumSurfaceType.circle ? BoxShape.circle : BoxShape.rectangle;

  BorderRadius get _radius {
    if (borderRadius != null) return borderRadius!;
    switch (type) {
      case PremiumSurfaceType.circle:
        return BorderRadius.circular(999);
      case PremiumSurfaceType.pill:
        return BorderRadius.circular(PremiumConstants.pillRadius);
      case PremiumSurfaceType.card:
        return BorderRadius.circular(PremiumConstants.cardRadius);
    }
  }

  BorderRadius _inset(BorderRadius radius, double d) {
    Radius shrink(Radius r) => Radius.circular((r.x - d).clamp(0, 999));
    return BorderRadius.only(
      topLeft: shrink(radius.topLeft),
      topRight: shrink(radius.topRight),
      bottomLeft: shrink(radius.bottomLeft),
      bottomRight: shrink(radius.bottomRight),
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = _radius;
    final shape = _shape;
    final gold = showGoldBorder ? PremiumConstants.goldEdge : 0.0;
    final bevel = showInnerHighlight ? PremiumConstants.innerHighlight : 0.0;

    Widget clipInner(Widget child) {
      if (shape == BoxShape.circle) return ClipOval(child: child);
      return ClipRRect(borderRadius: _inset(radius, gold + bevel), child: child);
    }

    Widget surface = clipInner(
      Stack(
        fit: (width != null || height != null) ? StackFit.expand : StackFit.loose,
        children: [
          const Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(gradient: PremiumColors.surface)),
          ),
          if (finish == PremiumFinish.recessed)
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE8E1D6), Color(0xFFFBF8F3)],
                  ),
                ),
              ),
            ),
          if (showArcs) const Positioned.fill(child: DecorativeArcs()),
          Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ],
      ),
    );

    surface = PremiumInnerHighlight(
      radius: _inset(radius, gold),
      shape: shape,
      enabled: showInnerHighlight,
      child: surface,
    );

    surface = PremiumBorder(
      radius: radius,
      shape: shape,
      enabled: showGoldBorder,
      child: surface,
    );

    surface = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: shape == BoxShape.circle ? null : radius,
        shape: shape,
        boxShadow: finish == PremiumFinish.recessed ? const [] : PremiumShadows.of(elevation),
      ),
      child: surface,
    );

    if (onTap == null) return surface;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: surface);
  }
}
