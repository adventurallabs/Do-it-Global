import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/ui.dart';
import 'api.dart';
import 'catalog.dart';
import 'scores.dart';

/// How a child's assessments have changed over time, for everyone who may see the child (admin, their
/// therapists, the family). See `scores.dart` for how answers are counted: no weights, just how many assessed
/// items are at the expected level, plus what changed item by item. Never shows clinical notes.
class AssessmentProgressCard extends StatefulWidget {
  final Child child;
  const AssessmentProgressCard({super.key, required this.child});

  @override
  State<AssessmentProgressCard> createState() => _AssessmentProgressCardState();
}

// The three levels on one hue, dark to light (a sequence, not categories); counts and a legend always go with it.
const _levelColors = {Level.expected: C.brand800, Level.developing: C.brand300, Level.notYet: Color(0xFFDCDFEE)};

class _AssessmentProgressCardState extends State<AssessmentProgressCard> {
  String _series = 'overall';
  int? _picked;
  bool _how = false, _allChanges = false;
  Object? _error;

  late final AppStore _store = context.read<AppStore>();

  @override
  void initState() {
    super.initState();
    _store.showingAssessments(widget.child.id, true);
    _load();
  }

  @override
  void dispose() {
    _store.showingAssessments(widget.child.id, false);
    super.dispose();
  }

  @override
  void didUpdateWidget(AssessmentProgressCard old) {
    super.didUpdateWidget(old);
    if (old.child.id != widget.child.id) {
      _store.showingAssessments(old.child.id, false);
      _store.showingAssessments(widget.child.id, true);
      _series = 'overall';
      _picked = null;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      await context.read<AppStore>().loadAssessmentTimeline(widget.child.id);
      if (mounted && _error != null) setState(() => _error = null);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _show(String series) => setState(() {
        _series = series;
        _picked = null;
      });

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final pts = store.assessmentTimeline[widget.child.id];
    final first = widget.child.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle('Assessment progress', hint: pts == null || pts.isEmpty ? 'From the centre\'s OT assessments' : 'From ${plural(pts.length, 'completed assessment')}'),
      if (pts == null)
        AppCard(
          child: SizedBox(
            height: 70,
            child: Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Couldn\'t load. Try again')),
            ),
          ),
        )
      else if (pts.isEmpty)
        EmptyState(
          icon: Icons.stacked_line_chart_rounded,
          title: 'No completed assessment yet',
          hint: store.role == Role.parent
              ? 'After the centre assesses $first, the results appear here, and each later assessment shows what has changed.'
              : 'Complete an assessment and its results appear here. Every re-assessment adds a point and lists what changed, item by item.',
        )
      else
        _card(pts),
    ]);
  }

  Widget _card(List<AssessmentPoint> pts) {
    final latest = pts.last, before = pts.length > 1 ? pts[pts.length - 2] : null;
    final series = [
      'overall',
      for (final a in scoreAreas) if (pts.any((p) => p.areas.containsKey(a.key))) a.key,
      if (pts.any((p) => p.strength != null)) 'strength',
    ];
    if (!series.contains(_series)) _series = 'overall';
    final line = [for (final p in pts) if (p.value(_series) != null) (p: p, v: p.value(_series)!)];
    final grade = isGradeSeries(_series);
    final pick = line.isEmpty ? 0 : (_picked ?? line.length - 1).clamp(0, line.length - 1);
    final shown = line.isEmpty ? null : line[pick];
    final o = latest.overall, ob = before?.overall;
    final changes = before == null ? const <Change>[] : changesBetween(before, latest);
    final better = changes.where((c) => c.better).toList(), worse = changes.where((c) => !c.better).toList();

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Headline: the latest assessment as a plain count.
        Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 10, runSpacing: 4, children: [
          Text(o.percent == null ? '–' : '${o.percent!.round()}%', style: display(34).copyWith(fontFeatures: tnum)),
          Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('at the expected level', style: body(13, weight: FontWeight.w700))),
          if (o.percent != null && ob?.percent != null) Padding(padding: const EdgeInsets.only(bottom: 6), child: _Delta(o.percent! - ob!.percent!, unit: 'points', big: true)),
        ]),
        const SizedBox(height: 2),
        Text(
          '${o.expected} of ${plural(o.assessed, 'assessed item')} · ${kindShort(latest.kind)}, ${fmtDate(latest.date, 'd MMM yyyy')}${before == null ? '' : ' · compared with ${fmtDate(before.date, 'd MMM yyyy')}'}',
          style: body(12, color: C.muted, height: 1.35),
        ),
        const SizedBox(height: 14),

        // The line over time, one series at a time.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final s in series)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(seriesLabel(s)),
                  selected: _series == s,
                  showCheckmark: false,
                  labelStyle: body(12.5, weight: FontWeight.w700, color: _series == s ? Colors.white : C.ink),
                  selectedColor: C.brand700,
                  backgroundColor: Colors.white,
                  side: BorderSide(color: _series == s ? C.brand700 : C.line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (_) => _show(s),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        if (shown != null)
          Text.rich(TextSpan(children: [
            TextSpan(text: '${seriesLabel(_series)}  ', style: body(12.5, weight: FontWeight.w800)),
            TextSpan(text: _fmt(shown.v, grade), style: body(12.5, weight: FontWeight.w800, color: C.brand700).copyWith(fontFeatures: tnum)),
            TextSpan(text: '  ${_detail(shown.p, grade)}', style: body(12, color: C.muted)),
          ])),
        const SizedBox(height: 6),
        if (line.length >= 2)
          _TrendChart(
            values: [for (final x in line) (date: x.p.date, value: x.v)],
            max: grade ? 5 : 100,
            percent: !grade,
            selected: pick,
            onSelect: (i) => setState(() => _picked = i),
            label: '${seriesLabel(_series)} over ${plural(line.length, 'assessment')}: from ${_fmt(line.first.v, grade)} to ${_fmt(line.last.v, grade)}.',
          )
        else
          _Note(line.isEmpty ? '${seriesLabel(_series)} wasn\'t assessed yet.' : 'The line over time appears after the next assessment.'),

        // Latest assessment, area by area.
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),
        Text('Latest by area', style: body(13, weight: FontWeight.w800)),
        const SizedBox(height: 8),
        const _Legend(),
        const SizedBox(height: 6),
        for (final a in scoreAreas)
          if (latest.areas[a.key] case final c?)
            _AreaRow(
              label: a.label,
              count: c,
              delta: before?.areas[a.key]?.percent == null || c.percent == null ? null : c.percent! - before!.areas[a.key]!.percent!,
              selected: _series == a.key,
              onTap: () => _show(a.key),
            ),
        if (latest.strength != null)
          _GradeRow(
            value: latest.strength!,
            graded: latest.strengthGraded,
            delta: before?.strength == null ? null : latest.strength! - before!.strength!,
            selected: _series == 'strength',
            onTap: () => _show('strength'),
          ),

        // What changed, item by item.
        if (before != null) ...[
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Text('What changed since ${fmtDate(before.date, 'd MMM yyyy')}', style: body(13, weight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (changes.isEmpty)
            Text('Every item assessed both times stayed at the same level.', style: body(12.5, color: C.muted))
          else ...[
            for (final (title, list, up) in [('Improved', better, true), ('Needs attention', worse, false)])
              if (list.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Row(children: [
                    Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 18, color: up ? C.green : C.red),
                    const SizedBox(width: 6),
                    Text('$title · ${list.length}', style: body(12.5, weight: FontWeight.w800)),
                  ]),
                ),
                for (final c in _allChanges ? list : list.take(5)) _ChangeRow(c),
              ],
            if (!_allChanges && (better.length > 5 || worse.length > 5))
              Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => setState(() => _allChanges = true), child: Text('Show all ${changes.length} changes'))),
          ],
        ],

        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _how = !_how),
            icon: Icon(_how ? Icons.expand_less_rounded : Icons.info_outline_rounded, size: 18),
            label: Text(_how ? 'Hide how this is worked out' : 'How this is worked out'),
          ),
        ),
        if (_how) const _How(),
      ]),
    );
  }

  static String _fmt(double v, bool grade) => grade ? '${v.toStringAsFixed(1)}/5' : '${v.round()}%';

  static String _detail(AssessmentPoint p, bool grade) => [
        grade ? 'average of ${plural(p.strengthGraded, 'joint')} graded' : '',
        '${kindShort(p.kind)}, ${fmtDate(p.date, 'd MMM yyyy')}',
      ].where((s) => s.isNotEmpty).join(' · ');
}

String kindShort(String kind) => labelOf(Answers.kind, kind) ?? 'Assessment';

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: C.canvas, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.timeline_rounded, size: 18, color: C.muted),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: body(12.5, color: C.muted, height: 1.35))),
        ]),
      );
}

/// "▲ 12 points": the arrow carries the direction, so colour is never the only cue.
class _Delta extends StatelessWidget {
  final double d;
  final String unit;
  final bool big, grade;
  const _Delta(this.d, {this.unit = '', this.big = false, this.grade = false});

  @override
  Widget build(BuildContext context) {
    final shown = grade ? (d * 10).round() / 10 : d.round().toDouble();
    final (icon, color) = shown > 0 ? (Icons.arrow_upward_rounded, C.green) : (shown < 0 ? (Icons.arrow_downward_rounded, C.red) : (Icons.drag_handle_rounded, C.muted));
    final n = grade ? shown.abs().toStringAsFixed(1) : shown.abs().round().toString();
    final text = shown == 0 ? 'same' : (unit.isEmpty ? n : '$n $unit');
    return Semantics(
      label: shown == 0 ? 'no change' : '${shown > 0 ? 'up' : 'down'} $n${unit.isEmpty ? '' : ' $unit'}',
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: big ? 16 : 13, color: color),
        const SizedBox(width: 1),
        Text(text, style: body(big ? 13 : 11.5, weight: FontWeight.w800).copyWith(fontFeatures: tnum)),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => Wrap(spacing: 14, runSpacing: 6, children: [
        for (final l in Level.values)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: _levelColors[l], borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 5),
            Text(levelLabels[l]!, style: body(11.5, weight: FontWeight.w600, color: C.muted)),
          ]),
      ]);
}

/// One area: a bar split into expected / developing / not yet, the count at the expected level and the change.
class _AreaRow extends StatelessWidget {
  final String label;
  final LevelCount count;
  final double? delta;
  final bool selected;
  final VoidCallback onTap;
  const _AreaRow({required this.label, required this.count, required this.delta, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = count;
    final parts = [for (final l in Level.values) (l, switch (l) { Level.expected => c.expected, Level.developing => c.developing, Level.notYet => c.notYet })];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Semantics(
        button: true,
        excludeSemantics: true,
        label: '$label: ${c.expected} of ${c.assessed} at the expected level, ${c.developing} developing, ${c.notYet} not yet'
            '${delta == null ? '' : ', ${delta!.round() == 0 ? 'no change' : '${delta! > 0 ? 'up' : 'down'} ${delta!.round().abs()} points'}'}',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(children: [
            SizedBox(
              width: 112,
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, weight: selected ? FontWeight.w800 : FontWeight.w600, color: selected ? C.brand800 : C.ink)),
            ),
            Expanded(
              child: SizedBox(
                height: 12,
                child: Row(children: [
                  for (final (i, (l, n)) in parts.indexed)
                    if (n > 0)
                      Expanded(
                        flex: n,
                        child: Container(
                          // A 2px gap between segments.
                          margin: EdgeInsets.only(right: i < 2 && parts.skip(i + 1).any((p) => p.$2 > 0) ? 2 : 0),
                          decoration: BoxDecoration(color: _levelColors[l], borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                ]),
              ),
            ),
            SizedBox(width: 44, child: Text('${c.expected}/${c.assessed}', textAlign: TextAlign.right, style: body(12, weight: FontWeight.w800).copyWith(fontFeatures: tnum))),
            SizedBox(width: 58, child: Align(alignment: Alignment.centerRight, child: delta == null ? Text('new', style: body(11, color: C.muted)) : FittedBox(fit: BoxFit.scaleDown, child: _Delta(delta!)))),
          ]),
        ),
      ),
    );
  }
}

class _GradeRow extends StatelessWidget {
  final double value;
  final int graded;
  final double? delta;
  final bool selected;
  final VoidCallback onTap;
  const _GradeRow({required this.value, required this.graded, required this.delta, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Semantics(
          button: true,
          excludeSemantics: true,
          label: 'Muscle strength: average grade ${value.toStringAsFixed(1)} out of 5 over ${plural(graded, 'joint')}',
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(children: [
              SizedBox(width: 112, child: Text('Muscle strength', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, weight: selected ? FontWeight.w800 : FontWeight.w600, color: selected ? C.brand800 : C.ink))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 12,
                    child: Stack(children: [
                      Container(color: _levelColors[Level.notYet]),
                      FractionallySizedBox(widthFactor: (value / 5).clamp(0.02, 1.0), child: Container(decoration: BoxDecoration(color: C.brand600, borderRadius: BorderRadius.circular(4)))),
                    ]),
                  ),
                ),
              ),
              SizedBox(width: 44, child: Text('${value.toStringAsFixed(1)}/5', textAlign: TextAlign.right, style: body(12, weight: FontWeight.w800).copyWith(fontFeatures: tnum))),
              SizedBox(width: 58, child: Align(alignment: Alignment.centerRight, child: delta == null ? Text('new', style: body(11, color: C.muted)) : FittedBox(fit: BoxFit.scaleDown, child: _Delta(delta!, grade: true)))),
            ]),
          ),
        ),
      );
}

class _ChangeRow extends StatelessWidget {
  final Change c;
  const _ChangeRow(this.c);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 24, bottom: 6),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: c.label, style: body(13, weight: FontWeight.w700)),
          TextSpan(text: '  ${c.from} → ${c.to}', style: body(12.5, color: C.ink.withValues(alpha: 0.75))),
          TextSpan(text: '  · ${c.area}', style: body(11.5, color: C.muted)),
        ])),
      );
}

/// The counting rules, made from the same mapping the scores use, so the explanation can't drift from them.
class _How extends StatelessWidget {
  const _How();

  @override
  Widget build(BuildContext context) {
    String answers(ScoreArea a, Level l) {
      final names = [for (final e in a.levels.entries) if (e.value == l) labelOf(a.options, e.key) ?? e.key];
      if (a.key == 'behaviour' && l != Level.expected) names.add(l == Level.developing ? 'Present (mild)' : 'Present (moderate / severe or no severity)');
      if (a.key == 'behaviour') names.remove('Present');
      return names.toSet().join(', ');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'Each answer is counted as at the expected level, developing, or not yet, using the form\'s own answers below. "Not assessed" and "Not applicable" are left out. '
          'An area\'s percentage is how many of its assessed items are at the expected level; Overall counts every assessed item together. '
          'Muscle strength is the average grade on the usual 0–5 scale. Nothing is weighted, and the list of changes shows exactly which items moved.',
          style: body(12.5, color: C.muted, height: 1.45),
        ),
        const SizedBox(height: 8),
        for (final a in scoreAreas)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '${a.label}: ', style: body(12, weight: FontWeight.w800)),
              for (final l in Level.values)
                if (answers(a, l).isNotEmpty) TextSpan(text: '${levelLabels[l]} — ${answers(a, l)}. ', style: body(12, color: C.muted)),
            ])),
          ),
      ]),
    );
  }
}

/// One series on a fixed scale (0–100% or 0–5), points spaced by date. Tap or drag to read a point.
class _TrendChart extends StatelessWidget {
  final List<({String date, double value})> values;
  final double max;
  final bool percent;
  final int selected;
  final ValueChanged<int> onSelect;
  final String label;
  const _TrendChart({required this.values, required this.max, required this.percent, required this.selected, required this.onSelect, required this.label});

  static const l = 34.0, r = 16.0, t = 18.0, b = 22.0, height = 170.0;

  List<double> _xs(double w) {
    final ts = [for (final v in values) DateTime.parse(v.date).millisecondsSinceEpoch.toDouble()];
    final span = ts.last - ts.first;
    return [for (var i = 0; i < ts.length; i++) l + (span == 0 ? i / (ts.length - 1) : (ts[i] - ts.first) / span) * (w - l - r)];
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final xs = _xs(w);
        void pick(Offset p) {
          var best = 0;
          for (var i = 1; i < xs.length; i++) {
            if ((xs[i] - p.dx).abs() < (xs[best] - p.dx).abs()) best = i;
          }
          if (best != selected) {
            HapticFeedback.selectionClick();
            onSelect(best);
          }
        }

        return Semantics(
          label: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => pick(d.localPosition),
            onHorizontalDragUpdate: (d) => pick(d.localPosition),
            child: RepaintBoundary(child: CustomPaint(size: Size(w, height), painter: _TrendPainter(values: values, xs: xs, selected: selected, max: max, percent: percent))),
          ),
        );
      });
}

class _TrendPainter extends CustomPainter {
  final List<({String date, double value})> values;
  final List<double> xs;
  final int selected;
  final double max;
  final bool percent;
  _TrendPainter({required this.values, required this.xs, required this.selected, required this.max, required this.percent});

  static const _l = _TrendChart.l, _t = _TrendChart.t, _b = _TrendChart.b, _r = _TrendChart.r;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height - _t - _b;
    double y(double v) => _t + h * (1 - v / max);
    void text(String s, Offset at, {TextAlign align = TextAlign.left, Color color = C.muted, double fontSize = 10.5, FontWeight weight = FontWeight.w600}) {
      final tp = TextPainter(text: TextSpan(text: s, style: body(fontSize, weight: weight, color: color)), textDirection: TextDirection.ltr)..layout();
      final dx = align == TextAlign.right ? at.dx - tp.width : (align == TextAlign.center ? at.dx - tp.width / 2 : at.dx);
      tp.paint(canvas, Offset(dx.clamp(0, size.width - tp.width), at.dy - tp.height / 2));
    }

    // Recessive grid: bottom, middle and top labelled, quarters faint.
    final grid = Paint()..strokeWidth = 1;
    for (var q = 0; q <= 4; q++) {
      final v = max * q / 4;
      canvas.drawLine(Offset(_l, y(v)), Offset(size.width - _r, y(v)), grid..color = q.isEven ? C.line : C.line.withValues(alpha: 0.5));
      if (q.isEven) text(percent ? '${v.round()}%' : v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1), Offset(_l - 6, y(v)), align: TextAlign.right);
    }
    text(fmtDate(values.first.date, 'MMM yy'), Offset(xs.first, size.height - 8));
    text(fmtDate(values.last.date, 'MMM yy'), Offset(xs.last, size.height - 8), align: TextAlign.right);
    canvas.drawLine(Offset(xs[selected], _t), Offset(xs[selected], _t + h), Paint()
      ..color = C.brand200
      ..strokeWidth = 1);

    final line = Path()..moveTo(xs.first, y(values.first.value));
    for (var i = 1; i < values.length; i++) {
      line.lineTo(xs[i], y(values[i].value));
    }
    final area = Path.from(line)
      ..lineTo(xs.last, _t + h)
      ..lineTo(xs.first, _t + h)
      ..close();
    canvas.drawPath(area, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.brand600.withValues(alpha: 0.14), C.brand600.withValues(alpha: 0)]).createShader(Rect.fromLTWH(0, _t, size.width, h)));
    canvas.drawPath(line, Paint()
      ..color = C.brand600
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round);
    for (var i = 0; i < values.length; i++) {
      final c = Offset(xs[i], y(values[i].value));
      final rad = i == selected ? 6.0 : 4.5;
      canvas.drawCircle(c, rad + 2, Paint()..color = Colors.white);
      canvas.drawCircle(c, rad, Paint()..color = i == selected ? C.brand800 : C.brand600);
    }
    final s = Offset(xs[selected], y(values[selected].value));
    final v = values[selected].value;
    text(percent ? '${v.round()}%' : v.toStringAsFixed(1), Offset(s.dx, s.dy - 15), align: TextAlign.center, color: C.ink, fontSize: 12, weight: FontWeight.w800);
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.values != values || old.selected != selected || old.max != max || old.xs.length != xs.length || (xs.isNotEmpty && old.xs.last != xs.last);
}
