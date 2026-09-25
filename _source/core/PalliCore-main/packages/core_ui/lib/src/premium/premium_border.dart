import 'package:flutter/material.dart';
import 'premium_colors.dart';
import 'premium_constants.dart';

/// Gradient gold shell. Not a solid [Border.all] — lighting lives in the fill
/// of this outer layer, then the inner surface is inset by [width].
class PremiumBorder extends StatelessWidget {
  final Widget child;
  final BorderRadius radius;
  final BoxShape shape;
  final double width;
  final bool enabled;

  const PremiumBorder({
    super.key,
    required this.child,
    required this.radius,
    this.shape = BoxShape.rectangle,
    this.width = PremiumConstants.goldEdge,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Container(
      decoration: BoxDecoration(
        borderRadius: shape == BoxShape.circle ? null : radius,
        shape: shape,
        gradient: PremiumColors.goldEdge,
      ),
      padding: EdgeInsets.all(width),
      child: child,
    );
  }
}

/// Thin inner bevel: white on the lit edge, soft shade opposite.
class PremiumInnerHighlight extends StatelessWidget {
  final Widget child;
  final BorderRadius radius;
  final BoxShape shape;
  final double width;
  final bool enabled;

  const PremiumInnerHighlight({
    super.key,
    required this.child,
    required this.radius,
    this.shape = BoxShape.rectangle,
    this.width = PremiumConstants.innerHighlight,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Container(
      decoration: BoxDecoration(
        borderRadius: shape == BoxShape.circle ? null : radius,
        shape: shape,
        gradient: PremiumColors.innerHighlight,
      ),
      padding: EdgeInsets.all(width),
      child: child,
    );
  }
}
