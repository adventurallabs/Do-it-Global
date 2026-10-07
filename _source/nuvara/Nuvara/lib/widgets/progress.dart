import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import 'charts.dart';
import 'ui.dart';

// A child's progress, shared by the admin, therapist and parent screens. After every session the child
// attended, its therapist gives a report: a 0–10 rating and a few words. From those:
//   * Overall progress: the level lately, how it is changing, and one chart across every therapy.
//   * By therapy: the same per therapy.
//   * Day by day: every session of a chosen day, with the therapist's words, and any report still pending.

enum ProgressRange {
  month('1 month', 31),
  quarter('3 months', 92),
  all('All', null);

  final String label;
  final int? days;
  const ProgressRange(this.label, this.days);

  /// The first day shown, or null for everything.
  String? get from => days == null ? null : addDays(todayISO(), -days!);
}

/// The headline numbers for a child (or one therapy) over a period.
class ProgressSummary {
  /// Rated sessions in the period, oldest first.
  final List<ProgressPoint> rated;

  /// Sessions the child attended in the period that still have no report.
  final int pending;

  /// Average of the latest five ratings: where the child is now.
  final double? level;

  /// Latest five against the five before them; null without enough reports.
  final double? change;

  const ProgressSummary(this.rated, this.pending, this.level, this.change);

  int get reported => rated.length;
  int get attended => reported + pending;

  static ProgressSummary of(
    List<ProgressPoint> points, {
    String? therapyId,
    String? from,
  }) {
    final inRange = [
      for (final p in points)
        if ((therapyId == null || p.therapyId == therapyId) &&
            (from == null || p.date.compareTo(from) >= 0))
          p,
    ];
    final rated = inRange.where((p) => p.rating != null).toList();
    final pending = inRange.where((p) => p.pending).length;
    double avg(Iterable<ProgressPoint> x) =>
        x.fold(0.0, (a, p) => a + p.rating!) / x.length;
    const n = 5;
    final recent = rated.length > n ? rated.sublist(rated.length - n) : rated;
    final before = rated.length > n
        ? rated.sublist(
            (rated.length - 2 * n).clamp(0, rated.length - n),
            rated.length - n,
          )
        : <ProgressPoint>[];
    return ProgressSummary(
      rated,
      pending,
      recent.isEmpty ? null : avg(recent),
      recent.length >= 3 && before.length >= 3
          ? avg(recent) - avg(before)
          : null,
    );
  }
}

class ProgressPanel extends StatefulWidget {
  final Child child;
  const ProgressPanel(this.child, {super.key});

  @override
  State<ProgressPanel> createState() => _ProgressPanelState();
}

class _ProgressPanelState extends State<ProgressPanel> {
  String? day;
  ProgressRange range = ProgressRange.quarter;
  Object? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProgressPanel old) {
    super.didUpdateWidget(old);
    if (old.child.id != widget.child.id) {
      day = null;
      _load();
    }
  }

  Future<void> _load({bool force = false}) async {
    final store = context.read<AppStore>();
    setState(() => error = null);
    try {
      await store.loadProgress(widget.child.id, force: force);
      store.touch();
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final kid = widget.child;
    final points = store.progressOf(kid.id);
    if (points == null) {
      return error == null
          ? const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            )
          : EmptyState(
              icon: Icons.cloud_off_rounded,
              title: "Couldn't load progress",
              hint: cleanError(error!),
              action: btn(
                'Try again',
                icon: Icons.refresh_rounded,
                onPressed: () => _load(force: true),
              ),
            );
    }
    final days = {for (final p in points) p.date}.toList()..sort();
    final pendingDays = {
      for (final p in points)
        if (p.pending) p.date,
    };
    final shownDay = day != null && days.contains(day) ? day : days.lastOrNull;
    // Therapies in the child's plan first, then any they had sessions in before.
    final therapyIds = [
      ...kid.therapyIds,
      ...{for (final p in points) p.therapyId}
          .where((id) => !kid.therapyIds.contains(id)),
    ];
    final from = range.from;
    void pick(String d) => setState(() => day = d);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Segmented<ProgressRange>(
          value: range,
          expand: true,
          options: [for (final r in ProgressRange.values) seg(r, r.label)],
          onChanged: (r) => setState(() => range = r),
        ),
        const SizedBox(height: 12),
        _Overview(
          child: kid,
          summary: ProgressSummary.of(points, from: from),
          days: store.dailyRatings(kid.id, from: from),
          selectedDay: shownDay,
          onSelect: pick,
        ),
        const SizedBox(height: 22),
        // The sections below are built over the next frames, so this panel never stalls a scroll.
        if (therapyIds.isNotEmpty)
          Deferred(
            height: 200.0 * therapyIds.length,
            builder: (_) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle('By therapy'),
                for (final id in therapyIds)
                  if (store.therapy(id) case final t?)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TherapyProgress(
                        therapy: t,
                        summary: ProgressSummary.of(
                          points,
                          therapyId: t.id,
                          from: from,
                        ),
                        days: store.dailyRatings(
                          kid.id,
                          therapyId: t.id,
                          from: from,
                        ),
                        selectedDay: shownDay,
                        onSelect: pick,
                      ),
                    ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        Deferred(
          frames: 2,
          height: 320,
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(
                'Day by day',
                hint: days.isEmpty
                    ? null
                    : 'Every session and what the therapist wrote',
                action: days.isEmpty
                    ? null
                    : TextButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.parse(shownDay!),
                            firstDate: DateTime.parse(days.first),
                            lastDate: DateTime.parse(days.last),
                            selectableDayPredicate: (d) =>
                                days.contains(iso(d)),
                            helpText: 'Days with sessions',
                          );
                          if (picked != null) pick(iso(picked));
                        },
                        icon: const Icon(
                          Icons.calendar_month_rounded,
                          size: 18,
                        ),
                        label: const Text('Pick a day'),
                      ),
              ),
              if (shownDay == null)
                EmptyState(
                  icon: Icons.edit_note_rounded,
                  title: 'No sessions yet',
                  hint:
                      "After each session ${kid.first} attends, the therapist rates how it went (0–10) and writes a few words. Every report appears here.",
                )
              else ...[
                _DayStrip(
                  days: days,
                  pending: pendingDays,
                  selected: shownDay,
                  onPick: pick,
                ),
                const SizedBox(height: 10),
                DayProgress(
                  points: points.where((p) => p.date == shownDay).toList(),
                  date: shownDay,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Every therapy together: the level lately in numbers and words, the change, reports given and pending,
/// and one point per day on the chart.
class _Overview extends StatelessWidget {
  final Child child;
  final ProgressSummary summary;
  final List<DayRating> days;
  final String? selectedDay;
  final ValueChanged<String> onSelect;
  const _Overview({
    required this.child,
    required this.summary,
    required this.days,
    required this.selectedDay,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final level = s.level;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Overall progress', style: body(15, weight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Stat(
                  label: 'Level lately',
                  value: level == null ? '–' : fmtRating(level),
                  unit: level == null ? null : '/10',
                  color: level == null ? C.muted : RatingPill.colorOf(level),
                  footer: level == null
                      ? Text(
                          'No reports yet',
                          style: body(11.5, color: C.muted),
                        )
                      : StatusChip(
                          ratingBand(level),
                          tone: _tone(level),
                          dot: false,
                        ),
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Change',
                  value: s.change == null
                      ? '–'
                      : '${s.change! >= 0 ? '+' : '−'}${s.change!.abs().toStringAsFixed(1)}',
                  color: s.change == null || s.change!.abs() < 0.25
                      ? C.ink
                      : (s.change! > 0 ? C.green : C.amber),
                  footer: s.change == null
                      ? Text(
                          'Needs 6+ reports',
                          style: body(11.5, color: C.muted),
                        )
                      : TrendBadge(s.change),
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Reports',
                  value: '${s.reported}',
                  unit: s.attended == 0 ? null : '/${s.attended}',
                  color: C.ink,
                  footer: s.pending > 0
                      ? StatusChip(
                          '${s.pending} pending',
                          tone: Tone.amber,
                          dot: false,
                        )
                      : Text(
                          s.attended == 0 ? 'No sessions' : 'All in',
                          style: body(11.5, color: C.muted),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          RatingChart(
            points: days,
            color: C.brand600,
            height: 170,
            selectedDate: selectedDay,
            onSelect: onSelect,
          ),
          const SizedBox(height: 8),
          Text(
            'Each point is one day: the average rating of ${child.first}\'s sessions that day, all therapies. '
            'Shaded: 7–10 doing well · 4–6 developing · 0–3 needs support. "Level lately" is the average of the last 5 reports.',
            style: body(11.5, color: C.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

Tone _tone(double v) => v >= 7 ? Tone.green : (v >= 4 ? Tone.amber : Tone.red);

class _Stat extends StatelessWidget {
  final String label, value;
  final String? unit;
  final Color color;
  final Widget footer;
  const _Stat({
    required this.label,
    required this.value,
    this.unit,
    required this.color,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: body(11.5, weight: FontWeight.w700, color: C.muted),
      ),
      const SizedBox(height: 2),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: display(26, color: color).copyWith(fontFeatures: tnum),
              ),
              if (unit != null)
                TextSpan(
                  text: unit,
                  style: body(12, weight: FontWeight.w600, color: C.muted),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: footer,
      ),
    ],
  );
}

class _TherapyProgress extends StatelessWidget {
  final Therapy therapy;
  final ProgressSummary summary;
  final List<DayRating> days;
  final String? selectedDay;
  final ValueChanged<String> onSelect;
  const _TherapyProgress({
    required this.therapy,
    required this.summary,
    required this.days,
    required this.selectedDay,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final t = therapy;
    final s = summary;
    final last = s.rated.lastOrNull;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: t.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            t.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: body(14.5, weight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.reported == 0
                          ? (s.pending > 0
                                ? 'No reports yet'
                                : 'No sessions in this period')
                          : '${plural(s.reported, 'report')} · level lately ${fmtRating(s.level!)} (${ratingBand(s.level!).toLowerCase()})',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: body(12, color: C.muted),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (s.change != null) TrendBadge(s.change),
                        if (s.pending > 0)
                          StatusChip(
                            '${s.pending} report${s.pending == 1 ? '' : 's'} pending',
                            tone: Tone.amber,
                            dot: false,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (last != null) ...[
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Latest',
                      style: body(
                        10.5,
                        weight: FontWeight.w700,
                        color: C.muted,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${last.rating}',
                            style: display(
                              28,
                              color: t.color,
                            ).copyWith(fontFeatures: tnum),
                          ),
                          TextSpan(
                            text: '/10',
                            style: body(11.5, color: C.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          if (days.isNotEmpty) ...[
            const SizedBox(height: 10),
            RatingChart(
              points: days,
              color: t.color,
              height: 130,
              selectedDate: selectedDay,
              onSelect: onSelect,
            ),
          ],
        ],
      ),
    );
  }
}

/// Recent days with sessions as chips, newest last; the picked one is filled. A dot marks a day with a
/// report still pending.
class _DayStrip extends StatelessWidget {
  final List<String> days;
  final Set<String> pending;
  final String selected;
  final ValueChanged<String> onPick;
  const _DayStrip({
    required this.days,
    required this.pending,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final recent = days.length > 14 ? days.sublist(days.length - 14) : days;
    final shown = recent.contains(selected)
        ? recent
        : [selected, ...recent.skip(1)];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        children: [
          for (final d in shown)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onTap: () => onPick(d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 52,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: d == selected ? C.brand800 : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: d == selected ? C.brand800 : C.line,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        fmtDate(d, 'EEE'),
                        style: body(
                          10.5,
                          weight: FontWeight.w700,
                          color: d == selected ? C.brand200 : C.muted,
                        ),
                      ),
                      Text(
                        fmtDate(d, 'd'),
                        style: display(
                          17,
                          color: d == selected ? Colors.white : C.ink,
                        ),
                      ),
                      Text(
                        fmtDate(d, 'MMM'),
                        style: body(
                          9.5,
                          weight: FontWeight.w600,
                          color: d == selected ? C.brand200 : C.muted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: pending.contains(d)
                              ? C.amber
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Every session of one day: therapy, time, therapist, rating (or "report pending" / "absent") and the
/// therapist's description.
class DayProgress extends StatelessWidget {
  final List<ProgressPoint> points;
  final String date;
  const DayProgress({super.key, required this.points, required this.date});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              fmtDate(date, 'EEEE, d MMMM yyyy'),
              style: body(14, weight: FontWeight.w800, color: C.brand800),
            ),
          ),
          for (var i = 0; i < points.length; i++) ...[
            if (i > 0) const Divider(indent: 16, endIndent: 16),
            ProgressRow(
              points[i],
              therapyName: store.therapyName(points[i].therapyId),
              therapistName: store.therapistName(points[i].therapistId),
              color: store.therapy(points[i].therapyId)?.color ?? C.brand600,
            ),
          ],
        ],
      ),
    );
  }
}

/// One session: what, when, who, the rating and the description, or why there is no rating.
class ProgressRow extends StatelessWidget {
  final ProgressPoint point;
  final String therapyName, therapistName;
  final Color color;
  const ProgressRow(
    this.point, {
    super.key,
    required this.therapyName,
    required this.therapistName,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = point;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 34,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      therapyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: body(14, weight: FontWeight.w700),
                    ),
                    Text(
                      '${fmtSpan(p.start, p.end)} · ${p.sessionName} · $therapistName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: body(12, color: C.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (p.rating != null)
                RatingPill(p.rating!, large: true)
              else if (p.pending)
                const StatusChip('Report pending', tone: Tone.amber)
              else
                StatusChip(
                  p.attendance == 'absent' ? 'Absent' : 'Not rated',
                  dot: false,
                ),
            ],
          ),
          if (p.note.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
              decoration: BoxDecoration(
                color: C.brand50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(p.note.trim(), style: body(13.5, height: 1.45)),
            ),
          ] else if (p.pending) ...[
            const SizedBox(height: 8),
            Text(
              '$therapistName hasn\'t written the report for this session yet.',
              style: body(12, color: C.amber),
            ),
          ],
        ],
      ),
    );
  }
}
