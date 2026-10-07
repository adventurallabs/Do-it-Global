import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../assessment/progress_chart.dart';
import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/charts.dart' show fmtRating;
import '../../widgets/progress.dart';
import '../../widgets/ui.dart';
import 'kit.dart';

/// How the child is doing: after every session the therapist rates it 0–10 and describes it. Overall
/// progress and progress per therapy as charts, and any day in detail.
class ParentProgress extends StatelessWidget {
  const ParentProgress({super.key});

  @override
  Widget build(BuildContext context) => ChildScope(
        builder: (context, store, kid) => PageList(
          onRefresh: () async {
            await store.refresh();
            if (kid != null) await store.loadProgress(kid.id, force: true).catchError((_) {});
            store.touch();
          },
          children: [
            TabHeader('Progress', subtitle: kid == null ? null : 'How ${kid.first} is growing'),
            const ChildSwitcher(),
            if (kid == null)
              const EmptyState(icon: Icons.insights_rounded, title: noChildTitle, hint: noChildHint)
            else ...[
              _ProgressHero(kid: kid, store: store),
              const SizedBox(height: 22),
              AssessmentProgressCard(child: kid),
              const SizedBox(height: 22),
              ProgressPanel(kid),
            ],
          ],
        ),
      );
}

class _ProgressHero extends StatelessWidget {
  final Child kid;
  final AppStore store;
  const _ProgressHero({required this.kid, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = ProgressSummary.of(store.progressOf(kid.id) ?? const <ProgressPoint>[]);
    final level = s.level;
    final change = s.change;
    final title = level == null
        ? "${kid.first}'s journey"
        : change != null && change >= 0.25
            ? '${kid.first} is moving forward'
            : '${kid.first} is ${ratingBand(level).toLowerCase()}';
    final line = level == null
        ? 'After each session the therapist rates how it went (0–10) and writes a few words. Reports appear here.'
        : [
            'Average of the last ${s.reported < 5 ? s.reported : 5} session reports.',
            if (change != null) change.abs() < 0.25 ? 'Steady lately.' : (change > 0 ? 'Up ${change.toStringAsFixed(1)} on the reports before.' : 'Down ${change.abs().toStringAsFixed(1)} on the reports before.'),
            if (s.pending > 0) '${plural(s.pending, 'report')} still to come from the therapist.',
          ].join(' ');
    return HeroPanel(
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            heroOverline('Progress lately'),
            const SizedBox(height: 6),
            Text(title, style: display(22, color: Colors.white, height: 1.2)),
            const SizedBox(height: 6),
            Text(line, style: body(13, color: C.brand100, height: 1.4)),
          ]),
        ),
        if (level != null) ...[
          const SizedBox(width: 14),
          Container(
            width: 78,
            height: 78,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08), border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.5)),
            padding: const EdgeInsets.all(8),
            // Shrinks with large text rather than spilling out of the circle.
            child: fit(
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(fmtRating(level), style: display(26, color: Colors.white).copyWith(fontFeatures: tnum)),
                Text('out of 10', style: body(10, weight: FontWeight.w700, color: C.brand200)),
              ]),
              alignment: Alignment.center,
            ),
          ),
        ],
      ]),
    );
  }
}

/// Today's rated sessions for the home screen; nothing at all on a day without sessions.
class TodayProgress extends StatelessWidget {
  final Child kid;
  final List<Session> sessions;
  const TodayProgress({super.key, required this.kid, required this.sessions});

  @override
  Widget build(BuildContext context) {
    // No sessions today: Home's Today card already says so.
    if (sessions.isEmpty) return const SizedBox.shrink();
    final store = context.read<AppStore>();
    final done = [
      for (final s in sessions)
        if (s.seat(kid.id) case final seat? when seat.rating != null || seat.note.trim().isNotEmpty || (s.phase != 'upcoming' && seat.reportPending)) (s: s, seat: seat),
    ];
    final waiting = done.where((d) => d.seat.reportPending).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle("Today's progress", hint: done.isEmpty ? null : (waiting > 0 ? '${plural(waiting, 'report')} still to come' : 'From ${kid.first}\'s therapists')),
      if (done.isEmpty)
        AppCard(
          child: Row(children: [
            const IconTile(Icons.insights_rounded, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'The therapist\'s report appears here after each session.',
                style: body(13.5, weight: FontWeight.w600),
              ),
            ),
          ]),
        )
      else
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (var i = 0; i < done.length; i++) ...[
              if (i > 0) const Divider(indent: 16, endIndent: 16),
              ProgressRow(
                ProgressPoint({
                  'session_id': done[i].s.id,
                  'day': done[i].s.date,
                  'start_time': done[i].s.start,
                  'end_time': done[i].s.end,
                  'session_name': done[i].s.name,
                  'therapy_id': done[i].s.therapyId,
                  'therapist_id': done[i].s.therapistId,
                  'attendance': done[i].seat.attendance,
                  'rating': done[i].seat.rating,
                  'note': done[i].seat.note,
                }),
                therapyName: store.therapyName(done[i].s.therapyId),
                therapistName: store.therapistName(done[i].s.therapistId),
                color: store.therapy(done[i].s.therapyId)?.color ?? C.brand600,
              ),
            ],
          ]),
        ),
    ]);
  }
}

