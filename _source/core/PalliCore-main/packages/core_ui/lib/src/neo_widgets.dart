import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'admin_look.dart';

class _InnerShadowPainter extends CustomPainter {
  final BorderRadius borderRadius;
  final BoxShape shape;
  final double distance;
  final double blur;

  const _InnerShadowPainter({
    required this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.distance = 6,
    this.blur = 10,
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
      _rrect(size).deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x66A8A398), Color(0x00FFFFFF), Color(0x99FFFFFF)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _InnerShadowPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.shape != shape ||
      oldDelegate.distance != distance ||
      oldDelegate.blur != blur;
}

/// Recessed clay well — opposite of a floating card.
class NeoWell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final double? width;
  final double? height;

  const NeoWell({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(18);
    final dark = AdminLook.isDark(context);
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: dark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF14120F), Color(0xFF1E1B16), Color(0xFF2A261F)],
                stops: [0.0, 0.42, 1.0],
              )
            : AppColors.insetGradient,
        borderRadius: shape == BoxShape.circle ? null : radius,
        shape: shape,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _InnerShadowPainter(
                  borderRadius: radius,
                  shape: shape,
                  distance: shape == BoxShape.circle ? 8 : 6,
                  blur: shape == BoxShape.circle ? 12 : 10,
                ),
              ),
            ),
          ),
          Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ],
      ),
    );
  }
}

/// Soft surface with explicit depth level. Default is Level 1.
class SoftSurface extends StatelessWidget {
  final Widget child;
  final SoftDepth depth;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final Color? color;
  final bool fill;

  const SoftSurface({
    super.key,
    required this.child,
    this.depth = SoftDepth.one,
    this.padding,
    this.margin,
    this.borderRadius,
    this.onTap,
    this.color,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(30);
    return GoldRimSurface(
      depth: depth,
      margin: margin,
      padding: padding,
      borderRadius: radius,
      onTap: onTap,
      fill: fill,
      rimWidth: switch (depth) {
        SoftDepth.three => 1.55,
        SoftDepth.two => 1.3,
        SoftDepth.one => 1.4,
        SoftDepth.none => 1.1,
      },
      child: child,
    );
  }
}

/// Soft inset field well — Level 0 recessed wash, not a floating pillow.
class SoftField extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SoftField({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    return NeoWell(
      padding: padding,
      borderRadius: BorderRadius.circular(28),
      child: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: InputDecorationTheme(
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding: const EdgeInsets.fromLTRB(8, 14, 14, 14),
            labelStyle: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12, fontWeight: FontWeight.w500),
            floatingLabelStyle: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12, fontWeight: FontWeight.w500),
            hintStyle: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 15, fontWeight: FontWeight.w500),
            prefixIconColor: AppColors.onSurfaceHint(context),
            suffixIconColor: AppColors.onSurfaceHint(context),
            isDense: false,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Tactile circular action — Level 2.
class SoftIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? iconColor;
  final double size;
  final bool elevated;

  const SoftIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.iconColor,
    this.size = 42,
    this.elevated = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!elevated) {
      final inset = AdminInsetButton(
        icon: icon,
        onTap: onTap,
        size: size,
        iconColor: iconColor ?? AdminLook.inkOf(context),
      );
      if (tooltip == null) return inset;
      return Tooltip(message: tooltip!, child: inset);
    }
    final child = SizedBox(
      width: size,
      height: size,
      child: GoldRimSurface(
        depth: SoftDepth.two,
        shape: BoxShape.circle,
        texture: false,
        fill: true,
        onTap: onTap,
        child: Center(
          child: Icon(
            icon,
            size: size * 0.42,
            color: iconColor ?? AdminLook.gold,
          ),
        ),
      ),
    );
    if (tooltip == null) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}

/// Segmented control — recessed track, gold-rim selected pill.
class SoftSegmentedControl extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  const SoftSegmentedControl({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor = AdminLook.inkOf(context);
    final idleColor = AdminLook.muteOf(context);
    if (labels.isEmpty) return const SizedBox.shrink();
    final selected = index.clamp(0, labels.length - 1);
    return NeoWell(
      padding: const EdgeInsets.all(5),
      borderRadius: BorderRadius.circular(999),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / labels.length;
          return Stack(
            children: [
              // One pill that glides to the chosen segment, instead of the
              // highlight jumping from one to the next.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                left: selected * w,
                top: 0,
                bottom: 0,
                width: w,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GoldRimSurface(
                    depth: SoftDepth.two,
                    borderRadius: BorderRadius.circular(999),
                    rimWidth: 1.15,
                    texture: false,
                    expand: true,
                    padding: EdgeInsets.zero,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == selected,
                        child: GestureDetector(
                          onTap: () {
                            if (i == selected) return;
                            HapticFeedback.selectionClick();
                            onChanged(i);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: i == selected ? FontWeight.w600 : FontWeight.w500,
                                color: i == selected ? selectedColor : idleColor,
                              ),
                              child: Text(
                                labels[i],
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class SoftPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const SoftPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.9,
                    color: AdminLook.inkOf(context),
                    height: 1.1,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: AdminLook.muteOf(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ...actions.map(
            (w) => Padding(
              padding: const EdgeInsets.only(left: 10),
              child: w,
            ),
          ),
        ],
      ),
    );
  }
}

class SoftPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  /// Brand-gold face instead of the default ink one.
  final bool gold;

  const SoftPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.gold = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final dark = AdminLook.isDark(context);
    // A disabled gold button gets its own opaque muted face — fading the
    // whole button lets the dark canvas bleed through and the ink label sinks.
    final goldOff = gold && !enabled;
    final fg = goldOff
        ? (dark ? AdminLook.inkDark.withValues(alpha: 0.8) : AdminLook.onGold.withValues(alpha: 0.6))
        : gold
            ? AdminLook.onGold
            : (dark ? AdminLook.canvasDark : Colors.white);
    Widget button = GoldRimSurface(
      depth: SoftDepth.two,
      texture: false,
      expand: true,
      faceColor: dark ? AdminLook.inkDark : AdminLook.ink,
      faceGradient: goldOff
          ? LinearGradient(
              colors: dark
                  ? const [Color(0xFF6A5A38), Color(0xFF584A2E)]
                  : const [Color(0xFFEBDCB4), Color(0xFFDDCA98)],
            )
          : gold
              ? AdminLook.goldButtonOf(context)
              : null,
      borderRadius: BorderRadius.circular(999),
      onTap: onPressed,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
          ],
          // Flexible + ellipsis: long labels / large system font sizes must
          // shrink, never overflow the pill.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontWeight: gold ? FontWeight.w700 : FontWeight.w600,
                fontSize: 15,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
    if (!enabled) {
      button = goldOff
          ? IgnorePointer(child: button)
          : Opacity(opacity: 0.45, child: IgnorePointer(child: button));
    }
    return button;
  }
}

// ---------- Backward-compatible aliases for existing call sites ----------

class NeoSurface extends SoftSurface {
  const NeoSurface({
    super.key,
    required super.child,
    SoftDepth? depth,
    bool soft = false,
    bool tight = false,
    bool pressed = false,
    super.padding,
    super.margin,
    super.borderRadius,
    super.onTap,
  }) : super(
          depth: depth ??
              (tight
                  ? SoftDepth.two
                  : soft
                      ? SoftDepth.one
                      : SoftDepth.one),
        );
}

class NeoInset extends SoftField {
  const NeoInset({
    super.key,
    required super.child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    BorderRadius? borderRadius,
    double? width,
    double? height,
    BoxShape shape = BoxShape.rectangle,
  }) : super(padding: padding ?? const EdgeInsets.symmetric(horizontal: 4, vertical: 2));
}

class NeoCircleButton extends SoftIconButton {
  const NeoCircleButton({
    super.key,
    required super.icon,
    super.onTap,
    super.tooltip,
    super.iconColor,
    super.size = 42,
    bool inset = false,
  }) : super(elevated: !inset);
}

class NeoDateBadge extends StatelessWidget {
  final String label;
  const NeoDateBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return GoldRimSurface(
      depth: SoftDepth.two,
      texture: false,
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Text(
        label,
        style: TextStyle(
          color: AdminLook.inkOf(context),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class NeoFieldShell extends SoftField {
  const NeoFieldShell({super.key, required super.child, super.padding});
}

class NeoSegmentedControl extends SoftSegmentedControl {
  const NeoSegmentedControl({
    super.key,
    required super.labels,
    required super.index,
    required super.onChanged,
  });
}

class NeoPrimaryButton extends SoftPrimaryButton {
  const NeoPrimaryButton({
    super.key,
    required super.label,
    super.onPressed,
    super.icon,
  });
}

class NeoPageHeader extends SoftPageHeader {
  const NeoPageHeader({
    super.key,
    required super.title,
    super.subtitle,
    super.actions,
  });
}
