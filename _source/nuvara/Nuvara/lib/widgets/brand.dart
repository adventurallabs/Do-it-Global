import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

// The Nuvara mark and wordmark, drawn in code from the logo so they stay crisp at any size and can move.
// The mark is a friendly orange "u" standing on two feet with two sky-blue dots above it: the "ü" of nüvara.
// Geometry was traced from the brand artwork; tool/make_icons.py draws the same shapes for the launcher icons.

/// Outline of the orange "u", as x, y pairs. Centred on (0, 0); 1 unit = the whole mark's height.
const _u = <double>[0.4145,-0.2802, 0.4093,-0.2839, 0.4028,-0.2861, 0.397,-0.2865, 0.3878,-0.2855, 0.1374,-0.2423, 0.128,-0.2396, 0.1219,-0.2357, 0.1183,-0.2314, 0.1164,-0.2275, 0.1152,-0.223, 0.115,-0.2171, 0.1296,-0.1253, 0.1333,-0.0917, 0.1345,-0.0696, 0.1343,-0.0426, 0.1327,-0.0308, 0.1291,-0.0159, 0.1247,-0.0028, 0.1167,0.0125, 0.1081,0.0239, 0.0983,0.0332, 0.0873,0.041, 0.0723,0.0484, 0.0518,0.0549, 0.0368,0.0585, 0.0143,0.0611, -0.0016,0.0613, -0.0173,0.0598, -0.0316,0.0563, -0.0479,0.0494, -0.0606,0.0419, -0.0772,0.0278, -0.0869,0.0167, -0.0945,0.006, -0.1008,-0.0048, -0.1072,-0.0188, -0.1159,-0.0413, -0.1208,-0.0575, -0.1265,-0.0829, -0.1418,-0.1712, -0.1441,-0.1771, -0.1472,-0.1819, -0.1511,-0.1854, -0.156,-0.1881, -0.1635,-0.1897, -0.1723,-0.1888, -0.4237,-0.1456, -0.4351,-0.1423, -0.4428,-0.1369, -0.4461,-0.1328, -0.4484,-0.1279, -0.4493,-0.123, -0.4492,-0.1165, -0.4267,0.018, -0.4181,0.0558, -0.4096,0.0861, -0.3967,0.1232, -0.3842,0.1522, -0.3716,0.1776, -0.3565,0.203, -0.3373,0.2303, -0.325,0.2456, -0.3045,0.2671, -0.2849,0.2842, -0.2683,0.2969, -0.2319,0.3205, -0.228,0.3254, -0.2262,0.3313, -0.2237,0.3547, -0.2199,0.3795, -0.2202,0.385, -0.2222,0.3892, -0.2276,0.3932, -0.2387,0.3965, -0.3129,0.4132, -0.323,0.4172, -0.3335,0.4239, -0.3393,0.4296, -0.3449,0.4374, -0.3481,0.4449, -0.3496,0.4524, -0.3494,0.4606, -0.3474,0.4687, -0.343,0.4772, -0.3374,0.484, -0.3302,0.4895, -0.3208,0.4938, -0.312,0.4958, -0.2967,0.4975, -0.2543,0.4993, -0.2104,0.4993, -0.1804,0.4981, -0.1583,0.496, -0.1498,0.4944, -0.142,0.4902, -0.1341,0.4827, -0.1276,0.4733, -0.124,0.4641, -0.1227,0.4537, -0.1211,0.429, -0.1213,0.3687, -0.12,0.3635, -0.1166,0.3603, -0.113,0.3594, -0.1084,0.3595, -0.0804,0.3627, -0.0541,0.3642, -0.0182,0.3642, 0.0221,0.3617, 0.0694,0.3554, 0.1003,0.3496, 0.1322,0.3423, 0.17,0.3312, 0.1781,0.3298, 0.182,0.3307, 0.1853,0.3333, 0.1871,0.3365, 0.1881,0.3417, 0.1882,0.4472, 0.1893,0.4586, 0.192,0.4677, 0.1965,0.4775, 0.2017,0.4843, 0.2091,0.4903, 0.2143,0.493, 0.2211,0.4949, 0.2485,0.4978, 0.281,0.4993, 0.3354,0.4993, 0.3647,0.4978, 0.3849,0.4954, 0.3957,0.4912, 0.4047,0.4842, 0.4098,0.4778, 0.4134,0.4707, 0.4154,0.4635, 0.416,0.4544, 0.4149,0.4456, 0.412,0.4371, 0.4075,0.4296, 0.4018,0.4235, 0.3937,0.4176, 0.3839,0.4135, 0.3247,0.3996, 0.2989,0.3924, 0.2951,0.3902, 0.2924,0.3873, 0.2909,0.384, 0.2905,0.3795, 0.307,0.2733, 0.3095,0.2639, 0.3116,0.2603, 0.3152,0.2561, 0.3429,0.2317, 0.3604,0.214, 0.3839,0.186, 0.398,0.1649, 0.4075,0.1486, 0.4168,0.1297, 0.4225,0.1163, 0.4316,0.0893, 0.4376,0.0675, 0.4407,0.0532, 0.4454,0.0239, 0.4487,-0.0149, 0.4494,-0.0367, 0.4491,-0.0592, 0.4472,-0.0943, 0.4444,-0.124, 0.4402,-0.1546, 0.4228,-0.2598, 0.4193,-0.2728];

/// The two dots: centre x, centre y, radius (same units).
const _dots = [(-0.3358, -0.3322, 0.1154), (-0.0437, -0.3885, 0.1151)];

/// Where the "u" stands: the bottom of its feet.
const _ground = 0.4993;

/// Width of the whole mark divided by its height.
const markAspect = 0.90;

Path _uPath(double scale, Offset centre) {
  final p = Path()..moveTo(centre.dx + _u[0] * scale, centre.dy + _u[1] * scale);
  for (var i = 2; i < _u.length; i += 2) {
    p.lineTo(centre.dx + _u[i] * scale, centre.dy + _u[i + 1] * scale);
  }
  return p..close();
}

/// Paints the mark. The animation inputs default to "at rest".
class NuvaraMarkPainter extends CustomPainter {
  /// One colour for everything (monochrome mark), or null for the brand colours.
  final Color? mono;
  final Color body, dot;

  /// 0 → 1: the "u" grows up from the ground with a little overshoot.
  final double rise;

  /// -1 … 1: squash (negative) or stretch (positive) of the "u" about its feet.
  final double squash;

  /// 0 → 1 for each dot: falls in from above and settles. 1 = in place.
  final double leftDot, rightDot;

  /// Extra vertical offset of the dots (in mark heights), for idle bobbing.
  final double bob;

  /// Soft shadow under the feet.
  final bool shadow;

  const NuvaraMarkPainter({
    this.mono,
    this.body = C.clay500,
    this.dot = C.sky,
    this.rise = 1,
    this.squash = 0,
    this.leftDot = 1,
    this.rightDot = 1,
    this.bob = 0,
    this.shadow = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.height, size.width / markAspect);
    final centre = size.center(Offset.zero);
    final feet = centre.dy + _ground * scale;

    if (shadow && rise > 0) {
      final w = scale * 0.62 * (1 + 0.15 * -squash);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(centre.dx, feet + scale * 0.015), width: w, height: scale * 0.05),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18 * rise.clamp(0, 1))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, scale * 0.02),
      );
    }

    if (rise > 0) {
      canvas.save();
      // Grow and squash about the point between the feet, so it always stands on the ground.
      final sy = rise * (1 + 0.16 * squash);
      final sx = (0.6 + 0.4 * rise.clamp(0, 1)) * (1 - 0.10 * squash);
      canvas.translate(centre.dx, feet);
      canvas.scale(sx, sy);
      canvas.translate(-centre.dx, -feet);
      canvas.drawPath(_uPath(scale, centre), Paint()..color = mono ?? body);
      canvas.restore();
    }

    for (final (i, (x, y, r)) in _dots.indexed) {
      final t = i == 0 ? leftDot : rightDot;
      if (t <= 0) continue;
      final fall = (1 - t) * 0.55; // drops from above
      final c = Offset(centre.dx + x * scale, centre.dy + (y - fall + bob * (i == 0 ? 1 : -0.7)) * scale);
      canvas.drawCircle(c, r * scale * (0.7 + 0.3 * t.clamp(0, 1)), Paint()..color = (mono ?? dot).withValues(alpha: t.clamp(0, 1)));
    }
  }

  @override
  bool shouldRepaint(NuvaraMarkPainter o) =>
      o.rise != rise || o.squash != squash || o.leftDot != leftDot || o.rightDot != rightDot || o.bob != bob || o.mono != mono || o.body != body || o.dot != dot || o.shadow != shadow;
}

/// The mark at rest. [size] is its height.
class NuvaraMark extends StatelessWidget {
  final double size;
  final Color? mono;
  const NuvaraMark({super.key, this.size = 40, this.mono});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Nuvara',
        image: true,
        child: SizedBox(width: size * markAspect, height: size, child: CustomPaint(painter: NuvaraMarkPainter(mono: mono))),
      );
}

/// The mark, alive: the dots bob gently and the "u" breathes. For loading states and empty screens.
class LivingMark extends StatefulWidget {
  final double size;
  const LivingMark({super.key, this.size = 56});

  @override
  State<LivingMark> createState() => _LivingMarkState();
}

class _LivingMarkState extends State<LivingMark> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.size * markAspect,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            final t = _c.value * 2 * math.pi;
            return CustomPaint(painter: NuvaraMarkPainter(squash: 0.25 * math.sin(t * 2), bob: -0.035 * (1 - math.cos(t)).abs()));
          },
        ),
      );
}

/// "nüvara." as in the logo: "n", the mark, "v" over "ara" and a sky-blue full stop. [height] is the cap
/// height of one line; the whole wordmark is about 2.1 × that tall.
class NuvaraWordmark extends StatelessWidget {
  final double height;

  /// White letters, for dark backgrounds.
  final bool light;

  /// "nüvara." on one line instead of two, for headers.
  final bool inline;
  const NuvaraWordmark({super.key, this.height = 40, this.light = false, this.inline = false});

  @override
  Widget build(BuildContext context) {
    final ink = light ? Colors.white : C.brand900;
    final style = GoogleFonts.archivo(fontSize: height * 1.38, fontWeight: FontWeight.w900, color: ink, height: 1, letterSpacing: -height * 0.06);
    // Text boxes end below the baseline (descender room), so the mark's feet and the full stop are lifted
    // to sit on the letters' baseline.
    final mark = Padding(
      padding: EdgeInsets.only(left: height * 0.02, right: height * 0.02, bottom: height * 0.24),
      child: NuvaraMark(size: height * 1.42),
    );
    final dot = Padding(
      padding: EdgeInsets.only(left: height * 0.06, bottom: height * 0.30),
      child: Container(width: height * 0.26, height: height * 0.26, decoration: const BoxDecoration(color: C.sky, shape: BoxShape.circle)),
    );
    Widget line(List<Widget> parts) => Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: parts);
    final word = Semantics(
      label: 'Nuvara',
      excludeSemantics: true,
      child: inline
          ? line([Text('n', style: style), mark, Text('vara', style: style), dot])
          : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
              line([Text('n', style: style), mark, Text('v', style: style), SizedBox(width: height * 0.32)]),
              SizedBox(height: height * 0.08),
              line([Text('ara', style: style), dot]),
            ]),
    );
    return word;
  }
}

/// The mark as SVG (for PDF receipts), in a 0.9 × 1 view box.
String nuvaraMarkSvg({String body = '#EA501E', String dot = '#36A9E0'}) {
  String n(double v) => v.toStringAsFixed(4);
  final d = StringBuffer('M${n(_u[0] + 0.45)} ${n(_u[1] + 0.5)}');
  for (var i = 2; i < _u.length; i += 2) {
    d.write('L${n(_u[i] + 0.45)} ${n(_u[i + 1] + 0.5)}');
  }
  d.write('Z');
  final dots = [for (final (x, y, r) in _dots) '<circle cx="${n(x + 0.45)}" cy="${n(y + 0.5)}" r="${n(r)}" fill="$dot"/>'].join();
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -0.01 0.9 1.02"><path d="$d" fill="$body"/>$dots</svg>';
}
