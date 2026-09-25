import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

class AppMotion {
  // ── Durations ───────────────────────────────────────────────────
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration splash = Duration(milliseconds: 2400);
  static const Duration stagger = Duration(milliseconds: 80);

  // ── Standard easing ─────────────────────────────────────────────
  static const Curve standard = Curves.easeInOutCubic;
  static const Curve decelerate = Curves.easeOutCubic;
  static const Curve accelerate = Curves.easeInCubic;

  // ── Spring curves ───────────────────────────────────────────────
  static const Curve spring = _SpringCurve(mass: 1, stiffness: 300, damping: 22);
  static const Curve springBouncy = _SpringCurve(mass: 1, stiffness: 350, damping: 18);
  static const Curve springGentle = _SpringCurve(mass: 1, stiffness: 200, damping: 26);
}

class _SpringCurve extends Curve {
  final double mass;
  final double stiffness;
  final double damping;

  const _SpringCurve({
    required this.mass,
    required this.stiffness,
    required this.damping,
  });

  @override
  double transformInternal(double t) {
    final sim = SpringSimulation(
      SpringDescription(mass: mass, stiffness: stiffness, damping: damping),
      0.0,
      1.0,
      0.0,
    );
    return sim.x(t);
  }
}
