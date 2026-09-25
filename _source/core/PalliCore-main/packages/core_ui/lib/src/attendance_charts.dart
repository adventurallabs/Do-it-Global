import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'neo_widgets.dart';

/// Charts for attendance, built on one rule: **colour is never the only thing
/// carrying the meaning.**
///
/// The app's own success green (#5E7A5A) and error red (#B8574A) sit ΔE 4.6
/// apart under protanopia — a red-green colourblind admin genuinely cannot
/// tell "present" from "absent" by hue. So every segment and every bar here
/// carries its own label and count, and the two states are additionally
/// separated by a diagonal hatch on "absent". The colour is a convenience for
/// readers who can use it, not the channel the chart depends on.

/// One state in a day's roll call.
enum AttendanceBand {
  present,
  absent,
  /// Nobody has called this child's roll. Not the same as absent, and the
  /// whole reason these charts exist.
  unmarked;

  String get label => switch (this) {
        AttendanceBand.present => 'Present',
        AttendanceBand.absent => 'Absent',
        AttendanceBand.unmarked => 'Not marked',
      };

  Color get color => switch (this) {
        AttendanceBand.present => AppColors.success,
        AttendanceBand.absent => AppColors.error,
        AttendanceBand.unmarked => const Color(0xFFB9B4AA),
      };

}

/// The second, non-chromatic channel. Kept out of [AttendanceBand] itself so
/// the enum's public surface does not leak a private type.
extension _BandTexture on AttendanceBand {
  _Texture get texture => switch (this) {
        AttendanceBand.present => _Texture.solid,
        AttendanceBand.absent => _Texture.diagonal,
        AttendanceBand.unmarked => _Texture.dotted,
      };
}

enum _Texture { solid, diagonal, dotted }

/// Part-to-whole for a single day: present / absent / not marked, as one bar.
///
/// A bar rather than a ring, because the reader's question is "how much of the
/// school is still unaccounted for", which is a length comparison.
class AttendanceCompositionBar extends StatelessWidget {
  final int present;
  final int absent;
  final int unmarked;

  /// Shown above the bar. Omitted when the caller has its own heading.
  final String? title;

  const AttendanceCompositionBar({
    super.key,
    required this.present,
    required this.absent,
    required this.unmarked,
    this.title,
  });

  int get _total => present + absent + unmarked;

  @override
  Widget build(BuildContext context) {
    final total = _total;
    final parts = <(AttendanceBand, int)>[
      (AttendanceBand.present, present),
      (AttendanceBand.absent, absent),
      (AttendanceBand.unmarked, unmarked),
    ].where((p) => p.$2 > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(title!,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: AppColors.onSurfaceMuted(context))),
          const SizedBox(height: 10),
        ],
        if (total == 0)
          Text('Nobody enrolled yet.',
              style: TextStyle(fontSize: 13, color: AppColors.onSurfaceMuted(context)))
        else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 22,
              child: Row(
                children: [
                  for (var i = 0; i < parts.length; i++) ...[
                    // A 2px surface gap between fills, so touching segments
                    // never read as one.
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(
                      flex: parts[i].$2,
                      child: CustomPaint(
                        painter: _BandPainter(parts[i].$1),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // The legend doubles as the value table — identity never rests on
          // the swatch alone.
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              for (final (band, value) in [
                (AttendanceBand.present, present),
                (AttendanceBand.absent, absent),
                (AttendanceBand.unmarked, unmarked),
              ])
                _LegendEntry(band: band, value: value, total: total),
            ],
          ),
        ],
      ],
    );
  }
}

class _LegendEntry extends StatelessWidget {
  final AttendanceBand band;
  final int value;
  final int total;

  const _LegendEntry({required this.band, required this.value, required this.total});

  @override
  Widget build(BuildContext context) {
    final share = total == 0 ? 0 : (value / total * 100).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CustomPaint(painter: _BandPainter(band, radius: 4)),
        ),
        const SizedBox(width: 7),
        Text.rich(
          TextSpan(children: [
            TextSpan(
              text: '$value ',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface(context)),
            ),
            TextSpan(
              text: '${band.label} · $share%',
              style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted(context)),
            ),
          ]),
        ),
      ],
    );
  }
}

/// One class's roll call. A class nobody has called is drawn as an empty track
/// with the words on it, never as a zero-length bar that reads like 0%.
class ClassAttendanceRow extends StatelessWidget {
  final String name;
  final int present;
  final int absent;
  final int unmarked;
  final VoidCallback? onTap;

  const ClassAttendanceRow({
    super.key,
    required this.name,
    required this.present,
    required this.absent,
    required this.unmarked,
    this.onTap,
  });

  bool get _called => present + absent > 0;

  @override
  Widget build(BuildContext context) {
    final total = present + absent + unmarked;
    final rate = _called ? present / (present + absent) * 100 : null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                if (rate == null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pending_actions_outlined,
                          size: 15, color: AppColors.warning),
                      const SizedBox(width: 5),
                      const Text('Not taken',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning)),
                    ],
                  )
                else
                  Text('${rate.toStringAsFixed(0)}%  ·  $present/${present + absent}',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface(context))),
              ],
            ),
            const SizedBox(height: 6),
            if (total == 0)
              const SizedBox.shrink()
            else
              _MiniComposition(present: present, absent: absent, unmarked: unmarked),
          ],
        ),
      ),
    );
  }
}

/// The same three bands as [AttendanceCompositionBar], at row height and
/// without its legend — the row's own text already names the numbers.
class _MiniComposition extends StatelessWidget {
  final int present;
  final int absent;
  final int unmarked;

  const _MiniComposition({
    required this.present,
    required this.absent,
    required this.unmarked,
  });

  @override
  Widget build(BuildContext context) {
    final parts = <(AttendanceBand, int)>[
      (AttendanceBand.present, present),
      (AttendanceBand.absent, absent),
      (AttendanceBand.unmarked, unmarked),
    ].where((p) => p.$2 > 0).toList();
    if (parts.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 12,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Row(
          children: [
            for (var i = 0; i < parts.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                flex: parts[i].$2,
                child: CustomPaint(
                  painter: _BandPainter(parts[i].$1),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Daily attendance over a run of school days.
///
/// One axis, one series. Days whose roll was only partly called are drawn
/// hollow — a 100% bar from two marked children is not the same fact as a
/// 100% bar from two hundred, and the chart has to show the difference.
class AttendanceTrendChart extends StatelessWidget {
  final List<AttendanceTrendPoint> points;
  const AttendanceTrendChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Text('No school days recorded yet.',
          style: TextStyle(fontSize: 13, color: AppColors.onSurfaceMuted(context)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 150,
          child: LayoutBuilder(
            builder: (context, constraints) => CustomPaint(
              size: Size(constraints.maxWidth, 150),
              painter: _TrendPainter(
                points: points,
                ink: AppColors.onSurface(context),
                muted: AppColors.onSurfaceMuted(context),
                grid: AppColors.divider,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 18,
          runSpacing: 6,
          children: [
            _TrendKey(filled: true, label: 'All classes marked'),
            _TrendKey(filled: false, label: 'Partly marked — read with care'),
          ],
        ),
      ],
    );
  }
}

class AttendanceTrendPoint {
  final DateTime date;

  /// Null when no roll was called at all that day — drawn as a gap, not a
  /// zero.
  final double? ratePercent;
  final bool fullyMarked;
  final int marked;
  final int expected;

  const AttendanceTrendPoint({
    required this.date,
    required this.ratePercent,
    required this.fullyMarked,
    required this.marked,
    required this.expected,
  });
}

class _TrendKey extends StatelessWidget {
  final bool filled;
  final String label;
  const _TrendKey({required this.filled, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: filled ? AppColors.accent : Colors.transparent,
            border: Border.all(color: AppColors.accent, width: 1.6),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 7),
        Text(label,
            style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceMuted(context))),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<AttendanceTrendPoint> points;
  final Color ink;
  final Color muted;
  final Color grid;

  _TrendPainter({
    required this.points,
    required this.ink,
    required this.muted,
    required this.grid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const labelBand = 18.0;
    final plotHeight = size.height - labelBand;
    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.6)
      ..strokeWidth = 1;

    // A recessive grid at 0 / 50 / 100, labelled once on the left.
    for (final v in [0, 50, 100]) {
      final y = plotHeight - plotHeight * (v / 100);
      canvas.drawLine(Offset(26, y), Offset(size.width, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
            text: '$v', style: TextStyle(fontSize: 9, color: muted)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(26 - tp.width - 5, y - tp.height / 2));
    }

    final left = 30.0;
    final slot = (size.width - left) / points.length;
    final barWidth = (slot * 0.56).clamp(4.0, 22.0);

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final cx = left + slot * i + slot / 2;
      final rate = p.ratePercent;
      if (rate == null) {
        // No roll called: a hollow tick on the baseline, not a zero bar.
        final dash = Paint()
          ..color = muted.withValues(alpha: 0.45)
          ..strokeWidth = 1.4;
        canvas.drawLine(
          Offset(cx, plotHeight - 3),
          Offset(cx, plotHeight + 3),
          dash,
        );
      } else {
        final h = (plotHeight * (rate / 100)).clamp(3.0, plotHeight);
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(cx - barWidth / 2, plotHeight - h, barWidth, h),
          // 4px rounded data-end, square against the baseline.
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        );
        if (p.fullyMarked) {
          canvas.drawRRect(rect, Paint()..color = AppColors.accent);
        } else {
          canvas.drawRRect(
            rect,
            Paint()
              ..color = AppColors.accent
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6,
          );
        }
      }

      // Selective labels: first, last, and nothing in between — a number on
      // every bar is noise.
      if (i == 0 || i == points.length - 1) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${p.date.day}/${p.date.month}',
            style: TextStyle(fontSize: 9.5, color: muted),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx - tp.width / 2, plotHeight + 5));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.points != points;
}

/// Fills a band with its colour *and* its texture.
class _BandPainter extends CustomPainter {
  final AttendanceBand band;
  final double radius;

  _BandPainter(this.band, {this.radius = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(rect, Paint()..color = band.color.withValues(alpha: 0.95));

    final mark = Paint()
      ..color = Colors.white.withValues(alpha: 0.42)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    switch (band.texture) {
      case _Texture.solid:
        break;
      case _Texture.diagonal:
        for (var x = -size.height; x < size.width; x += 5) {
          canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), mark);
        }
      case _Texture.dotted:
        final dot = Paint()..color = Colors.white.withValues(alpha: 0.55);
        for (var y = 3.0; y < size.height; y += 5) {
          for (var x = 3.0; x < size.width; x += 5) {
            canvas.drawCircle(Offset(x, y), 0.9, dot);
          }
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BandPainter old) => old.band != band;
}

/// A single number with its caveat under it — the right form when the answer
/// is one figure, not a shape.
class AttendanceStatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color? tint;
  final IconData icon;

  const AttendanceStatTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: tint ?? AppColors.onSurfaceMuted(context)),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: AppColors.onSurface(context),
              )),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11.5, height: 1.25, color: AppColors.onSurfaceMuted(context))),
        ],
      ),
    );
  }
}
