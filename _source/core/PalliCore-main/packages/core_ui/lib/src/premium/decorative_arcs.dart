import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'premium_colors.dart';

/// Concentric watermark arcs. Origin sits outside the surface so the
/// pattern is clipped by the parent — it is not drawn as a card-sized circle.
class DecorativeArcs extends StatelessWidget {
  const DecorativeArcs({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: CustomPaint(painter: _ArcsPainter(), child: SizedBox.expand()),
    );
  }
}

class _ArcsPainter extends CustomPainter {
  const _ArcsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width * 0.92, size.height * 1.08);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05;
    final span = math.max(size.width, size.height);
    for (var i = 1; i <= 8; i++) {
      paint.color = PremiumColors.arc.withValues(alpha: 0.07 + i * 0.015);
      canvas.drawCircle(origin, i * span * 0.18, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
