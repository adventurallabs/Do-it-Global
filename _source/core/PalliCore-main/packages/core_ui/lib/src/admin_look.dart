import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Cream + champagne chrome surfaces.
class AdminLook extends ThemeExtension<AdminLook> {
  final bool enabled;

  const AdminLook({this.enabled = false});

  static bool isActive(BuildContext context) =>
      Theme.of(context).extension<AdminLook>()?.enabled == true;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static const Color canvas = Color(0xFFF8F6F2);
  static const Color canvasDark = Color(0xFF1A1814);
  static const Color face = Color(0xFFFAF6F0);
  static const Color gold = Color(0xFFC9A24A);
  static const Color goldLite = Color(0xFFFFF4D4);
  static const Color ink = Color(0xFF141414);
  static const Color inkDark = Color(0xFFF6F1EA);
  static const Color mute = Color(0xFF8A8680);
  static const Color muteDark = Color(0xFFC9C2B6);

  /// Brushed-gold face for the primary call to action. Dark ink sits on it
  /// in both themes (white on gold fails contrast); the dark variant is a
  /// touch deeper so it doesn't glare against the near-black canvas.
  static const Color onGold = Color(0xFF1A1814);
  static const LinearGradient goldButton = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE2C275), Color(0xFFC9A24A), Color(0xFFB38D3A)],
  );
  static const LinearGradient goldButtonDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD6B366), Color(0xFFC09944), Color(0xFFA27F33)],
  );
  static LinearGradient goldButtonOf(BuildContext context) =>
      isDark(context) ? goldButtonDark : goldButton;

  static Color canvasOf(BuildContext context) => isDark(context) ? canvasDark : canvas;
  static Color inkOf(BuildContext context) => isDark(context) ? inkDark : ink;
  static Color muteOf(BuildContext context) => isDark(context) ? muteDark : mute;

  /// Frosted cream — slightly translucent so page rings read through.
  static const RadialGradient faceGradient = RadialGradient(
    center: Alignment(-0.42, -0.52),
    radius: 1.2,
    colors: [
      Color(0xF2FFFDFB),
      Color(0xE6FAF6F0),
      Color(0xD9F0EAE0),
    ],
  );

  static const RadialGradient faceGradientDark = RadialGradient(
    center: Alignment(-0.42, -0.52),
    radius: 1.2,
    colors: [
      Color(0xF22A261F),
      Color(0xE6221F1A),
      Color(0xD9181612),
    ],
  );

  static RadialGradient faceGradientOf(BuildContext context) =>
      isDark(context) ? faceGradientDark : faceGradient;

  static List<BoxShadow> shadowsFor(SoftDepth depth, {bool dark = false}) {
    if (dark) {
      switch (depth) {
        case SoftDepth.none:
          return const [];
        case SoftDepth.two:
          return const [
            BoxShadow(color: Color(0x59000000), offset: Offset(3, 8), blurRadius: 12),
            BoxShadow(color: Color(0x14FFFFFF), offset: Offset(-2, -3), blurRadius: 6),
          ];
        case SoftDepth.three:
          return const [
            BoxShadow(color: Color(0x73000000), offset: Offset(5, 14), blurRadius: 20),
            BoxShadow(color: Color(0x18FFFFFF), offset: Offset(-3, -5), blurRadius: 8),
          ];
        case SoftDepth.one:
          return const [
            BoxShadow(color: Color(0x66000000), offset: Offset(4, 10), blurRadius: 16),
            BoxShadow(color: Color(0x14FFFFFF), offset: Offset(-2, -3), blurRadius: 6),
          ];
      }
    }
    switch (depth) {
      case SoftDepth.none:
        return const [];
        case SoftDepth.two:
          return const [
            BoxShadow(color: Color(0x246B5840), offset: Offset(3, 8), blurRadius: 12),
            BoxShadow(color: Color(0xC2FFFFFF), offset: Offset(-2, -3), blurRadius: 6),
          ];
        case SoftDepth.three:
          return const [
            BoxShadow(color: Color(0x2A6B5840), offset: Offset(5, 14), blurRadius: 20),
            BoxShadow(color: Color(0xC8FFFFFF), offset: Offset(-3, -5), blurRadius: 10),
          ];
        case SoftDepth.one:
          return const [
            BoxShadow(color: Color(0x246B5840), offset: Offset(4, 10), blurRadius: 16),
            BoxShadow(color: Color(0xC2FFFFFF), offset: Offset(-3, -4), blurRadius: 8),
          ];
    }
  }

  static List<BoxShadow> shadowsOf(BuildContext context, SoftDepth depth) =>
      shadowsFor(depth, dark: isDark(context));

  @override
  AdminLook copyWith({bool? enabled}) => AdminLook(enabled: enabled ?? this.enabled);

  @override
  AdminLook lerp(ThemeExtension<AdminLook>? other, double t) {
    if (other is! AdminLook) return this;
    return t < 0.5 ? this : other;
  }
}

/// Concentric canvas behind every screen.
class AdminBackdrop extends StatelessWidget {
  final Widget child;
  const AdminBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = AdminLook.isDark(context);
    return ColoredBox(
      color: AdminLook.canvasOf(context),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _PageRingsPainter(dark: dark),
                isComplex: true,
                willChange: false,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _PageRingsPainter extends CustomPainter {
  final bool dark;
  const _PageRingsPainter({this.dark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.18);
    final fill = Paint()
      ..shader = RadialGradient(
        colors: dark
            ? const [Color(0x001A1814), Color(0x22C9A24A)]
            : const [Color(0x00FDFBF7), Color(0x14C4B49A)],
      ).createShader(Rect.fromCircle(center: center, radius: size.width));
    canvas.drawCircle(center, size.width, fill);

    final stroke = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0;
    for (var i = 1; i <= 6; i++) {
      stroke.color = dark
          ? Color.fromRGBO(201, 162, 74, 0.05 + i * 0.012)
          : Color.fromRGBO(176, 160, 136, 0.06 + i * 0.015);
      canvas.drawCircle(center, i * size.shortestSide * 0.2, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _PageRingsPainter oldDelegate) => oldDelegate.dark != dark;
}

class _CardRingsPainter extends CustomPainter {
  const _CardRingsPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.9, size.height * 1.05);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05;
    for (var i = 1; i <= 4; i++) {
      stroke.color = Color.fromRGBO(180, 160, 120, 0.05 + i * 0.016);
      canvas.drawCircle(center, i * math.max(size.width, size.height) * 0.28, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Polished metallic stroke — champagne highlight on top/left, bronze on bottom/right.
class _GoldHairlinePainter extends CustomPainter {
  final BorderRadius borderRadius;
  final BoxShape shape;
  final double width;
  final double flow;

  const _GoldHairlinePainter({
    required this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.width = 1.35,
    this.flow = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = rect.deflate(width / 2);
    final rrect = shape == BoxShape.circle
        ? RRect.fromRectAndRadius(inset, Radius.circular(inset.shortestSide / 2))
        : borderRadius.toRRect(inset);

    final rotation = flow * math.pi; // half circuit around the rim
    final shader = SweepGradient(
      startAngle: -math.pi * 0.92,
      endAngle: math.pi * 1.08,
      transform: GradientRotation(rotation),
      colors: const [
        Color(0xFFFFF9E8),
        Color(0xFFF0D078),
        Color(0xFFC9A24A),
        Color(0xFF8F6524),
        Color(0xFFB8892E),
        Color(0xFFE8C56A),
        Color(0xFFFFF9E8),
      ],
      stops: const [0.0, 0.12, 0.28, 0.48, 0.68, 0.86, 1.0],
    ).createShader(rect);

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round
        ..shader = shader,
    );

    final inner = rect.deflate(width + 0.55);
    final innerRRect = shape == BoxShape.circle
        ? RRect.fromRectAndRadius(inner, Radius.circular(inner.shortestSide / 2))
        : borderRadius.toRRect(inner);
    canvas.drawRRect(
      innerRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..shader = SweepGradient(
          startAngle: -math.pi * 0.92,
          endAngle: math.pi * 1.08,
          transform: GradientRotation(rotation),
          colors: const [
            Color(0xCCFFFFFF),
            Color(0x66FFF6D6),
            Color(0x22FFFFFF),
            Color(0x33C9A24A),
            Color(0x88FFFFFF),
          ],
          stops: const [0.0, 0.22, 0.5, 0.78, 1.0],
        ).createShader(rect),
    );

    if (flow > 0 && flow < 1) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width + 1.4
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            transform: GradientRotation(-math.pi * 0.5 + rotation),
            colors: const [
              Color(0x00FFF6D0),
              Color(0x00FFF6D0),
              Color(0xFFFFF9E8),
              Color(0xFFFFE08A),
              Color(0x00C9A24A),
              Color(0x00C9A24A),
            ],
            stops: const [0.0, 0.38, 0.48, 0.56, 0.68, 1.0],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GoldHairlinePainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.shape != shape ||
      oldDelegate.width != width ||
      oldDelegate.flow != flow;
}

/// Raised glass bevel — soft white catch on top/left, warm shade on bottom/right.
class _RaisedBevelPainter extends CustomPainter {
  final BorderRadius borderRadius;
  final BoxShape shape;

  const _RaisedBevelPainter({
    required this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  RRect _rrect(Size size) {
    final rect = Offset.zero & size;
    if (shape == BoxShape.circle) {
      return RRect.fromRectAndRadius(rect, Radius.circular(size.shortestSide / 2));
    }
    return borderRadius.toRRect(rect);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      _rrect(size).deflate(1.1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xA3FFFFFF), Color(0x22FFFFFF), Color(0x2E8A7A62)],
          stops: [0.0, 0.46, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _RaisedBevelPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius || oldDelegate.shape != shape;
}

class _InnerLipPainter extends CustomPainter {
  final BorderRadius borderRadius;
  final BoxShape shape;

  const _InnerLipPainter({
    required this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = shape == BoxShape.circle
        ? RRect.fromRectAndRadius(rect, Radius.circular(size.shortestSide / 2))
        : borderRadius.toRRect(rect);
    canvas.drawRRect(
      rrect.deflate(0.8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x558A7A62), Color(0x11FFFFFF), Color(0x88FFFFFF)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Champagne-rimmed floating surface — metallic gold frame, raised bevel, frosted face.
class GoldRimSurface extends StatefulWidget {
  final Widget child;
  final SoftDepth depth;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double rimWidth;
  final VoidCallback? onTap;
  final bool texture;
  final bool fill;
  final bool frost;
  final bool expand;
  final Color? faceColor;
  /// Paints the face with this instead of [faceColor] / the cream default.
  final Gradient? faceGradient;

  const GoldRimSurface({
    super.key,
    required this.child,
    this.depth = SoftDepth.one,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.padding,
    this.margin,
    this.rimWidth = 1.35,
    this.onTap,
    this.texture = true,
    this.fill = false,
    this.frost = false,
    this.expand = false,
    this.faceColor,
    this.faceGradient,
  });

  @override
  State<GoldRimSurface> createState() => _GoldRimSurfaceState();
}

class _GoldRimSurfaceState extends State<GoldRimSurface> with SingleTickerProviderStateMixin {
  AnimationController? _flow;

  @override
  void dispose() {
    _flow?.dispose();
    super.dispose();
  }

  void _playFlow() {
    _flow ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..addListener(() {
        if (mounted) setState(() {});
      });
    _flow!.forward(from: 0).whenComplete(() {
      if (mounted) _flow?.reset();
    });
  }

  void _handleTap() {
    _playFlow();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(32);
    final clipRadius = widget.shape == BoxShape.circle ? BorderRadius.circular(999) : radius;
    final stretch = widget.fill || widget.expand;
    final flow = _flow?.value ?? 0.0;
    final animating = _flow?.isAnimating == true;

    Widget content = Padding(padding: widget.padding ?? EdgeInsets.zero, child: widget.child);
    if (stretch) {
      content = SizedBox(
        width: double.infinity,
        height: widget.fill ? double.infinity : null,
        child: content,
      );
    }

    Widget face = Stack(
      fit: widget.fill ? StackFit.expand : StackFit.loose,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: widget.shape,
              borderRadius: widget.shape == BoxShape.circle ? null : radius,
              color: widget.faceGradient == null ? widget.faceColor : null,
              gradient: widget.faceGradient ??
                  (widget.faceColor == null ? AdminLook.faceGradientOf(context) : null),
            ),
          ),
        ),
        content,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _SurfaceChromePainter(
                borderRadius: radius,
                shape: widget.shape,
                rimWidth: widget.rimWidth,
                texture: widget.texture,
                flow: flow,
              ),
              isComplex: true,
              willChange: animating,
            ),
          ),
        ),
      ],
    );

    if (widget.frost) {
      face = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: face,
      );
    }

    final body = Container(
      margin: widget.margin,
      width: stretch ? double.infinity : null,
      height: widget.fill ? double.infinity : null,
      decoration: BoxDecoration(
        shape: widget.shape,
        borderRadius: widget.shape == BoxShape.circle ? null : radius,
        boxShadow: AdminLook.shadowsOf(context, widget.depth),
      ),
      child: ClipRRect(
        borderRadius: clipRadius,
        child: face,
      ),
    );
    final wrapped = widget.onTap == null
        ? body
        : GestureDetector(onTap: _handleTap, behavior: HitTestBehavior.opaque, child: body);
    return RepaintBoundary(child: wrapped);
  }
}

class _SurfaceChromePainter extends CustomPainter {
  final BorderRadius borderRadius;
  final BoxShape shape;
  final double rimWidth;
  final bool texture;
  final double flow;

  const _SurfaceChromePainter({
    required this.borderRadius,
    required this.shape,
    required this.rimWidth,
    required this.texture,
    this.flow = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (texture) {
      const _CardRingsPainter().paint(canvas, size);
    }
    _RaisedBevelPainter(borderRadius: borderRadius, shape: shape).paint(canvas, size);
    _GoldHairlinePainter(borderRadius: borderRadius, shape: shape, width: rimWidth, flow: flow)
        .paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _SurfaceChromePainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.shape != shape ||
      oldDelegate.rimWidth != rimWidth ||
      oldDelegate.texture != texture ||
      oldDelegate.flow != flow;
}

class AdminRecessedDisk extends StatelessWidget {
  final Widget child;
  const AdminRecessedDisk({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(-0.15, -0.2),
                radius: 0.95,
                colors: [Color(0xFFFFFDFB), Color(0xFFEDE6DA)],
              ),
            ),
          ),
          const IgnorePointer(
            child: CustomPaint(
              painter: _InnerLipPainter(
                borderRadius: BorderRadius.all(Radius.circular(99)),
                shape: BoxShape.circle,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Recessed square well for category icons — stamped into the card, gold hairline.
class AdminIconWell extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const AdminIconWell({
    super.key,
    required this.icon,
    this.color = AdminLook.gold,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    final dark = AdminLook.isDark(context);
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? const [Color(0xFF1E1B16), Color(0xFF2A261F)]
                      : const [Color(0xFFE8E0D4), Color(0xFFFBF7F1)],
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: _InnerLipPainter(borderRadius: radius))),
            ),
            Center(child: Icon(icon, color: color, size: size * 0.46)),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _GoldHairlinePainter(borderRadius: radius, width: 0.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recessed circular control (logout).
class AdminInsetButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final Color? iconColor;

  const AdminInsetButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.size = 42,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AdminLook.isDark(context);
    final child = SizedBox(
      width: size,
      height: size,
      child: GoldRimSurface(
        depth: SoftDepth.none,
        shape: BoxShape.circle,
        texture: false,
        fill: true,
        rimWidth: 1.05,
        onTap: onTap,
        faceColor: dark ? const Color(0xFF2A261F) : null,
        child: Center(
          child: Icon(icon, size: size * 0.42, color: iconColor ?? AdminLook.inkOf(context)),
        ),
      ),
    );
    if (tooltip == null) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}
