import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'neo_widgets.dart';
import 'admin_look.dart';
import 'theme_controller.dart';

/// Premium analog clock — Level 3 hero object. Clean markers, refined hands.
class NeoAnalogClock extends StatelessWidget {
  final double size;
  final bool showSeconds;

  const NeoAnalogClock({
    super.key,
    this.size = 148,
    this.showSeconds = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: GoldRimSurface(
        depth: SoftDepth.two,
        shape: BoxShape.circle,
        texture: false,
        fill: true,
        rimWidth: 1.35,
        padding: EdgeInsets.all(size * 0.11),
        child: AdminRecessedDisk(
          child: _ClockHands(showSeconds: showSeconds),
        ),
      ),
    );
  }
}

class _ClockHands extends StatefulWidget {
  final bool showSeconds;

  const _ClockHands({required this.showSeconds});

  @override
  State<_ClockHands> createState() => _ClockHandsState();
}

class _ClockHandsState extends State<_ClockHands> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(
      Duration(seconds: widget.showSeconds ? 1 : 30),
      (_) {
        if (!mounted) return;
        setState(() => _now = DateTime.now());
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _PremiumClockPainter(time: _now, showSeconds: widget.showSeconds),
      ),
    );
  }
}

class _PremiumClockPainter extends CustomPainter {
  final DateTime time;
  final bool showSeconds;

  _PremiumClockPainter({required this.time, required this.showSeconds});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (var i = 0; i < 12; i++) {
      final angle = (i * 30 - 90) * math.pi / 180;
      final isCardinal = i % 3 == 0;
      final outer = Offset(
        center.dx + math.cos(angle) * (radius * 0.88),
        center.dy + math.sin(angle) * (radius * 0.88),
      );
      final inner = Offset(
        center.dx + math.cos(angle) * (radius * (isCardinal ? 0.74 : 0.80)),
        center.dy + math.sin(angle) * (radius * (isCardinal ? 0.74 : 0.80)),
      );
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = const Color(0xFF141414).withValues(alpha: isCardinal ? 0.78 : 0.26)
          ..strokeWidth = isCardinal ? 2.0 : 1.0
          ..strokeCap = StrokeCap.round,
      );
    }

    final hour = time.hour % 12;
    final minute = time.minute;
    final second = time.second;

    final hourAngle = ((hour + minute / 60) * 30 - 90) * math.pi / 180;
    final minuteAngle = ((minute + second / 60) * 6 - 90) * math.pi / 180;
    final secondAngle = (second * 6 - 90) * math.pi / 180;

    void hand(double angle, double len, double width, Color color, {bool shadow = true}) {
      final end = Offset(
        center.dx + math.cos(angle) * radius * len,
        center.dy + math.sin(angle) * radius * len,
      );
      if (shadow) {
        canvas.drawLine(
          center + const Offset(1.2, 1.6),
          end + const Offset(1.2, 1.6),
          Paint()
            ..color = const Color(0x22000000)
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.drawLine(
        center,
        end,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    hand(hourAngle, 0.46, 3.0, const Color(0xFF141414));
    hand(minuteAngle, 0.64, 2.0, const Color(0xFF141414));
    if (showSeconds) {
      hand(secondAngle, 0.72, 1.05, const Color(0xFFC9A24A), shadow: false);
    }

    canvas.drawCircle(center + const Offset(0.8, 1.2), 4.6, Paint()..color = const Color(0x22000000));
    canvas.drawCircle(center, 4.4, Paint()..color = const Color(0xFF141414));
    canvas.drawCircle(center, 1.8, Paint()..color = const Color(0xFFFAF6F0));
  }

  @override
  bool shouldRepaint(covariant _PremiumClockPainter oldDelegate) =>
      oldDelegate.time != time || oldDelegate.showSeconds != showSeconds;
}

/// Dashboard hero — Level 3. Greeting + name + crafted clock + date.
class NeoClockCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTrailingTap;
  final IconData? trailingIcon;
  final bool themeToggle;

  const NeoClockCard({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTrailingTap,
    this.trailingIcon,
    this.themeToggle = true,
  });

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final ink = AdminLook.inkOf(context);
    final mute = AdminLook.muteOf(context);
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final weekday = _weekdays[now.weekday - 1];
    final month = months[now.month - 1];

    Widget themeControl() {
      if (trailing != null) return trailing!;
      if (themeToggle) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeController,
          builder: (context, mode, _) {
            final dark = mode == ThemeMode.dark;
            return SoftIconButton(
              icon: dark ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded,
              size: 42,
              iconColor: AdminLook.gold,
              tooltip: dark ? 'Switch to day mode' : 'Switch to night mode',
              onTap: () => themeController.toggle(),
            );
          },
        );
      }
      if (trailingIcon != null) {
        return SoftIconButton(
          icon: trailingIcon!,
          size: 42,
          iconColor: AdminLook.gold,
          onTap: onTrailingTap,
        );
      }
      return const SizedBox.shrink();
    }

    return SoftSurface(
      depth: SoftDepth.three,
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      borderRadius: BorderRadius.circular(32),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 340;
          final clockSize = (constraints.maxWidth * (compact ? 0.42 : 0.34)).clamp(96.0, 148.0);

          final dateColumn = Column(
            crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Text(
                weekday.toUpperCase(),
                style: TextStyle(
                  color: mute,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: compact ? Alignment.center : Alignment.centerLeft,
                child: Text(
                  '${now.day}',
                  style: TextStyle(
                    color: ink,
                    fontSize: compact ? 44 : 52,
                    fontWeight: FontWeight.w800,
                    height: 0.95,
                    letterSpacing: -1.6,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: compact ? Alignment.center : Alignment.centerLeft,
                child: Text(
                  '$month ${now.year}',
                  style: TextStyle(
                    color: ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              themeControl(),
            ],
          );

          final greeting = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: mute,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                ),
              if (title != null) ...[
                const SizedBox(height: 4),
                Text(
                  title!,
                  style: TextStyle(
                    color: ink,
                    fontSize: compact ? 22 : 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    height: 1.15,
                  ),
                ),
              ],
            ],
          );

          if (compact) {
            return Column(
              children: [
                greeting,
                const SizedBox(height: 18),
                NeoAnalogClock(size: clockSize, showSeconds: false),
                const SizedBox(height: 16),
                dateColumn,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              greeting,
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  NeoAnalogClock(size: clockSize, showSeconds: false),
                  const SizedBox(width: 18),
                  Expanded(child: dateColumn),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
