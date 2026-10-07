import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../util.dart';

//// Progress over time on a fixed 0–10 scale: one point per day (the average of that day's rated sessions),
/// joined by a 2px line. Faint bands behind it show what the numbers mean (needs support / developing /
/// doing well), so the chart reads without knowing the scale. Days are spaced by date, so gaps in time show
/// as gaps. Touch and drag to read any day; [onSelect] gets the day under the finger.
class RatingChart extends StatefulWidget {
  final List<DayRating> points;
  final Color color;
  final double height;

  /// Hides the axis labels and scrub tooltip; for small inline previews.
  final bool compact;

  /// The day currently picked elsewhere, highlighted on the line.
  final String? selectedDate;
  final ValueChanged<String>? onSelect;
  const RatingChart({super.key, required this.points, required this.color, this.height = 150, this.compact = false, this.selectedDate, this.onSelect});

  @override
  State<RatingChart> createState() => _RatingChartState();
}

class _RatingChartState extends State<RatingChart> {
  int? _active;

  @override
  void didUpdateWidget(RatingChart old) {
    super.didUpdateWidget(old);
    if (old.points != widget.points) _active = null;
  }

  static const _left = 24.0, _right = 30.0, _top = 12.0, _bottom = 22.0;

  static int _ms(String date) => DateTime.parse(date).millisecondsSinceEpoch;

  int _nearest(double dx, double width) {
    final pts = widget.points;
    if (pts.length < 2) return pts.length - 1;
    final t0 = _ms(pts.first.date), t1 = _ms(pts.last.date);
    final x = ((dx - _left) / (width - _left - _right)).clamp(0.0, 1.0) * (t1 - t0) + t0;
    var best = 0;
    for (var i = 1; i < pts.length; i++) {
      if ((_ms(pts[i].date) - x).abs() < (_ms(pts[best].date) - x).abs()) best = i;
    }
    return best;
  }

  void _scrub(Offset p, double w) {
    final i = _nearest(p.dx, w);
    if (i != _active) {
      HapticFeedback.selectionClick();
      setState(() => _active = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pts = widget.points;
    if (pts.isEmpty) {
      return SizedBox(height: widget.compact ? widget.height : 80, child: Center(child: Text('No reports in this period', style: body(12.5, color: C.muted))));
    }
    final selected = widget.selectedDate == null ? null : pts.lastIndexWhere((p) => p.date == widget.selectedDate);
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: LayoutBuilder(builder: (context, box) {
        final chart = CustomPaint(
          size: Size(box.maxWidth, widget.height),
          painter: _RatingPainter(points: pts, color: widget.color, active: _active, selected: selected == -1 ? null : selected, compact: widget.compact),
        );
        if (widget.compact) return chart;
        return Semantics(
          label: 'Progress chart, 0 to 10. Latest ${fmtRating(pts.last.value)} out of 10 on ${fmtDate(pts.last.date, 'd MMM')}.',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (d) => _scrub(d.localPosition, box.maxWidth),
            onHorizontalDragUpdate: (d) => _scrub(d.localPosition, box.maxWidth),
            onHorizontalDragEnd: (_) {
              if (_active != null) widget.onSelect?.call(pts[_active!].date);
              setState(() => _active = null);
            },
            onTapDown: (d) => _scrub(d.localPosition, box.maxWidth),
            onTapUp: (_) {
              if (_active != null) widget.onSelect?.call(pts[_active!].date);
              Future.delayed(const Duration(milliseconds: 1400), () {
                if (mounted) setState(() => _active = null);
              });
            },
            child: chart,
          ),
        );
      }),
    );
  }
}

/// "7" for whole numbers, "6.5" otherwise.
String fmtRating(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

class _RatingPainter extends CustomPainter {
  final List<DayRating> points;
  final Color color;
  final int? active, selected;
  final bool compact;
  _RatingPainter({required this.points, required this.color, required this.active, required this.selected, required this.compact});

  @override
  void paint(Canvas canvas, Size size) {
    final l = compact ? 2.0 : _RatingChartState._left, r = compact ? 6.0 : _RatingChartState._right;
    final t = compact ? 6.0 : _RatingChartState._top, b = compact ? 6.0 : _RatingChartState._bottom;
    final w = size.width - l - r, h = size.height - t - b;
    final t0 = _RatingChartState._ms(points.first.date).toDouble();
    final span = (_RatingChartState._ms(points.last.date) - t0).toDouble();
    double y(double v) => t + h - v / 10 * h;
    Offset at(int i) => Offset(
          points.length == 1 || span == 0 ? l + w / 2 : l + (_RatingChartState._ms(points[i].date) - t0) / span * w,
          y(points[i].value),
        );

    // What the numbers mean, as faint bands: 0–4 needs support, 4–7 developing, 7–10 doing well.
    if (!compact) {
      for (final (lo, hi, c) in [(0.0, 4.0, C.red), (4.0, 7.0, C.amber), (7.0, 10.0, C.green)]) {
        canvas.drawRect(Rect.fromLTRB(l, y(hi), l + w, y(lo)), Paint()..color = c.withValues(alpha: 0.045));
      }
    }
    // Recessive grid: 0, 5, 10.
    final grid = Paint()
      ..color = C.line
      ..strokeWidth = 1;
    for (final v in compact ? const [0.0] : const [0.0, 5.0, 10.0]) {
      canvas.drawLine(Offset(l, y(v)), Offset(l + w, y(v)), grid);
      if (!compact) _text(canvas, v.toStringAsFixed(0), Offset(l - 6, y(v)), body(10, weight: FontWeight.w600, color: C.muted), align: 1);
    }

    if (points.length > 1) {
      final path = Path()..moveTo(at(0).dx, at(0).dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(at(i).dx, at(i).dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
    // A dot per day, so single days and gaps stay visible.
    if (!compact && points.length <= 60) {
      for (var i = 0; i < points.length - 1; i++) {
        canvas.drawCircle(at(i), 2.6, Paint()..color = color);
      }
    }

    // The day picked elsewhere.
    if (selected != null && !compact) {
      final p = at(selected!);
      canvas.drawLine(Offset(p.dx, t), Offset(p.dx, t + h), Paint()
        ..color = color.withValues(alpha: 0.35)
        ..strokeWidth = 1.5);
      canvas.drawCircle(p, 6.5, Paint()..color = Colors.white);
      canvas.drawCircle(p, 5, Paint()..color = color);
    }

    // Latest day: ringed, with its value labelled beside it.
    final end = at(points.length - 1);
    canvas.drawCircle(end, compact ? 4 : 5, Paint()..color = Colors.white);
    canvas.drawCircle(end, compact ? 3 : 4, Paint()..color = color);
    if (!compact) {
      _text(canvas, fmtRating(points.last.value), end + const Offset(9, 0), body(12, weight: FontWeight.w800, color: C.ink), align: -1);
      String fmt(String d) => fmtDate(d, 'd MMM');
      _text(canvas, fmt(points.first.date), Offset(l, size.height - 8), body(10, weight: FontWeight.w600, color: C.muted), align: -1);
      if (points.length > 1) _text(canvas, fmt(points.last.date), Offset(l + w, size.height - 8), body(10, weight: FontWeight.w600, color: C.muted), align: 1);
    }

    // Scrub crosshair + tooltip.
    if (active != null && active! < points.length && !compact) {
      final p = at(active!);
      final d = points[active!];
      canvas.drawLine(Offset(p.dx, t), Offset(p.dx, t + h), Paint()
        ..color = C.ink.withValues(alpha: 0.25)
        ..strokeWidth = 1);
      canvas.drawCircle(p, 6, Paint()..color = Colors.white);
      canvas.drawCircle(p, 4.5, Paint()..color = color);
      final label = '${fmtRating(d.value)}/10  ·  ${fmtDate(d.date, 'EEE, d MMM')}${d.count > 1 ? '  ·  avg of ${d.count}' : ''}';
      final tp = TextPainter(text: TextSpan(text: label, style: body(11.5, weight: FontWeight.w700, color: Colors.white)), textDirection: TextDirection.ltr)..layout();
      final bw = tp.width + 16, bh = tp.height + 10;
      final bx = (p.dx - bw / 2).clamp(0.0, size.width - bw);
      final by = (p.dy - bh - 10).clamp(0.0, size.height - bh);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw, bh), const Radius.circular(8)), Paint()..color = C.brand900);
      tp.paint(canvas, Offset(bx + 8, by + 5));
    }
  }

  /// [align]: -1 left-aligned at x, 0 centred, 1 right-aligned at x; vertically centred on y.
  void _text(Canvas c, String s, Offset o, TextStyle st, {int align = 0}) {
    final tp = TextPainter(text: TextSpan(text: s, style: st), textDirection: TextDirection.ltr)..layout();
    final dx = align < 0 ? o.dx : (align > 0 ? o.dx - tp.width : o.dx - tp.width / 2);
    tp.paint(c, Offset(dx, o.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_RatingPainter old) => old.points != points || old.color != color || old.active != active || old.selected != selected || old.compact != compact;
}

// "▲ 1.3 recently" / "▼ 0.7 recently" / "Steady": the last three ratings against the three before.
/// Text and an arrow, never colour alone.
class TrendBadge extends StatelessWidget {
  final double? change;
  const TrendBadge(this.change, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = change;
    if (c == null) return const SizedBox.shrink();
    final flat = c.abs() < 0.25, up = c > 0;
    final fg = flat ? C.muted : (up ? C.green : C.amber);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: flat ? C.sand : (up ? C.greenBg : C.amberBg), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(flat ? Icons.trending_flat_rounded : (up ? Icons.trending_up_rounded : Icons.trending_down_rounded), size: 14, color: fg),
        const SizedBox(width: 4),
        Text(flat ? 'Steady' : '${up ? '+' : '−'}${c.abs().toStringAsFixed(1)} lately', style: body(11, weight: FontWeight.w700, color: fg)),
      ]),
    );
  }
}

/// A rating as a compact "7/10" pill in the rating's colour band.
class RatingPill extends StatelessWidget {
  final int rating;
  final bool large;
  const RatingPill(this.rating, {super.key, this.large = false});

  static Color colorOf(num r) => r >= 7 ? C.green : (r >= 4 ? C.amber : C.red);

  @override
  Widget build(BuildContext context) {
    final c = colorOf(rating);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 10 : 8, vertical: large ? 5 : 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99)),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '$rating', style: body(large ? 15 : 12.5, weight: FontWeight.w800, color: c)),
          TextSpan(text: '/10', style: body(large ? 11.5 : 10.5, weight: FontWeight.w700, color: c.withValues(alpha: 0.7))),
        ]),
        style: const TextStyle(fontFeatures: tnum),
      ),
    );
  }
}
