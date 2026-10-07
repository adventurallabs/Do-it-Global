import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../actions.dart';
import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/ui.dart';

// Building blocks shared by the therapist screens: attendance marking, session status and ratings.

/// My sessions in the week starting [monday], in time order. Empty when the login isn't linked to a therapist.
List<Session> mySessions(AppStore s, String monday) =>
    s.therapistId == null ? [] : (s.sessionsOfTherapist(s.therapistId!, monday)..sort((a, b) => '${a.date}${a.start}'.compareTo('${b.date}${b.start}')));

/// Attendance opens 15 minutes before the start; the database enforces the same rule.
bool canMark(Session s) => s.attendanceOpen;

/// Children whose attendance can still be set right now (after the end: only those never marked).
List<String> markable(Session s) => [for (final id in s.childIds) if (s.canMarkSeat(id)) id];

/// "9:15 AM" today, or "9:15 AM on Fri, 2 Oct" for another day.
String attendanceOpensLabel(Session s) {
  final t = fmtTime(fromMin((toMin(s.start) - 15).clamp(0, 24 * 60 - 1)));
  return s.date == todayISO() ? t : '$t on ${fmtDate(s.date, 'EEE, d MMM')}';
}

/// Children in [s] with no attendance yet.
List<String> unmarked(Session s) => [for (final id in s.childIds) if (s.seat(id)?.attendance == null) id];

/// "To mark" on Today and Week alike: unmarked children in sessions that are running or finished; later ones aren't overdue yet.
int toMarkCount(Iterable<Session> sessions) => sessions.where((s) => s.phase != 'upcoming').fold<int>(0, (a, s) => a + unmarked(s).length);

void openSession(BuildContext context, Session s) => context.push('/therapist/sessions/${s.id}');
void openChild(BuildContext context, String childId) => context.push('/therapist/children/$childId');

/// True once saved; on failure the error is shown and it returns false.
Future<bool> markSeats(BuildContext context, Session s, List<String> ids, String? status) async {
  HapticFeedback.lightImpact();
  try {
    await context.read<AppStore>().markAttendance(s, ids, status);
    return true;
  } catch (e) {
    if (context.mounted) toast(context, cleanError(e), error: true);
    return false;
  }
}

/// One child's mark from the toggle. Asks first when the mark is final (the session is over) or would drop the
/// child's rating, and offers Undo when a mark is cleared.
Future<void> setSeat(BuildContext context, Session s, String childId, String? v) async {
  final store = context.read<AppStore>();
  final seat = s.seat(childId);
  final first = store.child(childId)?.first ?? 'child';
  final before = seat?.attendance, rating = seat?.rating;
  if (s.phase == 'done' && v != null) {
    if (!await confirm(context, title: 'Mark $first ${v == 'late' ? 'late' : v}?', message: 'The session is over, so this can\'t be changed afterwards.', action: 'Save', danger: false)) return;
  } else if (rating != null && v != 'present' && v != 'late') {
    // The server drops the report of a child who didn't come.
    final ok = await confirm(context, title: v == null ? 'Clear $first\'s attendance?' : 'Mark $first absent?', message: 'This removes the $rating/10 report for this session.', action: v == null ? 'Clear' : 'Mark absent');
    if (!ok) return;
  }
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  // Undo only once the clear is saved: offering it for a clear that failed would "restore" a mark that never left.
  final saved = await markSeats(context, s, [childId], v);
  if (saved && v == null && before != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$first\'s attendance cleared'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            final now = store.sessionById(s.id) ?? s;
            try {
              await store.markAttendance(now, [childId], before);
              if (rating != null && (before == 'present' || before == 'late')) await store.rateSession(now, childId, rating);
            } catch (e) {
              messenger.showSnackBar(SnackBar(content: Text(cleanError(e)), backgroundColor: C.red));
            }
          },
        ),
      ));
  }
}

/// Marks every unmarked child present, except children whose parents sent an absence notice: they are marked absent.
/// Once the session is over these marks are final, so it asks first.
Future<void> markAllPresent(BuildContext context, Session s) async {
  final ids = unmarked(s);
  if (ids.isEmpty) return;
  final away = [for (final id in ids) if (s.seat(id)?.noticed ?? false) id];
  final here = [for (final id in ids) if (!away.contains(id)) id];
  final store = context.read<AppStore>();
  if (s.phase == 'done') {
    final what = [if (here.isNotEmpty) '${here.length} present', if (away.isNotEmpty) '${away.length} absent (parent notice)'].join(' and ');
    if (!await confirm(context, title: 'Mark $what?', message: 'The session is over, so this is final.', action: 'Save', danger: false)) return;
    if (!context.mounted) return;
  }
  HapticFeedback.mediumImpact();
  try {
    await Future.wait([
      if (here.isNotEmpty) store.markAttendance(s, here, 'present'),
      if (away.isNotEmpty) store.markAttendance(s, away, 'absent'),
    ]);
    if (context.mounted) {
      toast(context, away.isEmpty ? '${plural(here.length, 'child', 'children')} marked present' : '${here.length} present · ${away.length} absent (parent notice)');
    }
  } catch (e) {
    if (context.mounted) toast(context, cleanError(e), error: true);
  }
}

typedef Status = ({String label, Tone tone, IconData? icon});

/// One short status for a session: live / next / later / upcoming, or once it has finished, what's left to mark.
Status sessionStatus(Session s, {bool next = false}) {
  final today = todayISO();
  if (s.date.compareTo(today) > 0) return (label: 'Upcoming', tone: Tone.neutral, icon: null);
  final phase = s.phase;
  if (phase == 'live') return (label: 'Live now', tone: Tone.green, icon: null);
  if (phase == 'upcoming') return next ? (label: 'Next', tone: Tone.blue, icon: null) : (label: 'Later', tone: Tone.neutral, icon: null);
  final left = unmarked(s).length;
  if (left > 0) return (label: 'Not completed · $left to mark', tone: Tone.amber, icon: Icons.edit_note_rounded);
  final reports = s.pendingReports.length;
  if (reports > 0) return (label: reports == 1 ? 'Report pending' : '$reports reports pending', tone: Tone.amber, icon: Icons.rate_review_outlined);
  final absent = s.seats.values.where((x) => x.attendance == 'absent').length;
  if (s.childIds.isEmpty) return (label: 'Completed', tone: Tone.neutral, icon: Icons.check_rounded);
  if (absent == 0) return (label: 'Completed · all present', tone: Tone.green, icon: Icons.check_rounded);
  return (label: 'Completed · $absent absent', tone: Tone.neutral, icon: Icons.check_rounded);
}

class StatusPill extends StatelessWidget {
  final Status status;
  final bool light;
  const StatusPill(this.status, {super.key, this.light = false});

  @override
  Widget build(BuildContext context) {
    final c = toneColors(status.tone);
    final fg = light ? Colors.white : c.fg;
    final live = status.label == 'Live now';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: light ? Colors.white.withValues(alpha: 0.14) : c.bg, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (status.icon != null)
          Padding(padding: const EdgeInsets.only(right: 4), child: Icon(status.icon, size: 13, color: fg))
        else
          Padding(padding: const EdgeInsets.only(right: 6), child: live ? _LiveDot(color: light ? const Color(0xFF6EE7B7) : c.fg) : Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle))),
        Flexible(child: Text(status.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11, weight: FontWeight.w700, color: fg, height: 1.1))),
      ]),
    );
  }
}

/// A dot with a soft halo for "live now".
class _LiveDot extends StatelessWidget {
  final Color color;
  const _LiveDot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 11,
        height: 11,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.25), shape: BoxShape.circle),
        child: Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      );
}

/// Present / Late / Absent in one row. Tapping the selected option clears it.
class AttendanceToggle extends StatelessWidget {
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;
  const AttendanceToggle({super.key, required this.value, required this.onChanged, this.enabled = true});

  static const options = [
    ('present', 'Present', Icons.check_rounded, C.green, C.greenBg),
    ('late', 'Late', Icons.schedule_rounded, C.amber, C.amberBg),
    ('absent', 'Absent', Icons.close_rounded, C.red, C.redBg),
  ];

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          height: 46,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: C.canvas, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
          child: Row(children: [
            for (final (v, label, icon, fg, bg) in options)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: value == v,
                  label: label,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: enabled ? () => onChanged(value == v ? null : v) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: value == v ? bg : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: value == v ? fg.withValues(alpha: 0.35) : Colors.transparent),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(icon, size: 15, color: value == v ? fg : C.muted),
                        const SizedBox(width: 4),
                        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, weight: value == v ? FontWeight.w800 : FontWeight.w600, color: value == v ? fg : C.muted))),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      );
}

/// The parent's absence notice ("Away · reason"), impossible to miss. Shown even after the child is marked.
class AbsenceNotice extends StatelessWidget {
  final String reason;
  const AbsenceNotice(this.reason, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: C.amberBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF2DFB4))),
        child: Row(children: [
          const Icon(Icons.event_busy_rounded, size: 15, color: C.amber),
          const SizedBox(width: 7),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: 'Away', style: body(12.5, weight: FontWeight.w800, color: C.amber)),
                if (reason.trim().isNotEmpty) TextSpan(text: ' · ${reason.trim()}', style: body(12.5, weight: FontWeight.w600, color: C.amber)),
              ]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      );
}

/// A child's place in a session: name + ID, any absence notice, and the attendance toggle.
class SeatRow extends StatelessWidget {
  final Session session;
  final String childId;
  final bool showAge;
  const SeatRow(this.session, this.childId, {super.key, this.showAge = false});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final c = store.child(childId);
    final seat = session.seat(childId);
    final name = c?.name ?? 'Child';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: c == null ? null : () => openChild(context, c.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Avatar(name, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                NameWithId(name, c?.code ?? '—', style: body(14.5, weight: FontWeight.w700)),
                if (showAge && c != null) Text(ageLong(c.dob), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted)),
              ]),
            ),
            if (session.phase != 'upcoming' && (seat?.reportPending ?? false)) const StatusChip('Report pending', tone: Tone.amber),
          ]),
        ),
      ),
      if (seat?.noticed ?? false) ...[const SizedBox(height: 8), AbsenceNotice(seat!.absenceReason!)],
      const SizedBox(height: 8),
      AttendanceToggle(
        value: seat?.attendance,
        enabled: session.canMarkSeat(childId),
        onChanged: (v) => setSeat(context, session, childId, v),
      ),
    ]);
  }
}

/// Shown once per session (not per child) when it is over and its marks can no longer change.
class LockedNote extends StatelessWidget {
  const LockedNote({super.key});

  @override
  Widget build(BuildContext context) => Row(children: [
        const Icon(Icons.lock_outline_rounded, size: 13, color: C.muted),
        const SizedBox(width: 4),
        Expanded(child: Text('Locked: the session is over', style: body(11, color: C.muted))),
      ]);
}

/// Shown while attendance hasn't opened yet, so a greyed-out toggle has a reason.
class OpensNote extends StatelessWidget {
  final Session session;
  const OpensNote(this.session, {super.key});

  @override
  Widget build(BuildContext context) => Row(children: [
        const Icon(Icons.lock_clock_rounded, size: 14, color: C.blue),
        const SizedBox(width: 6),
        Expanded(child: Text('Attendance opens at ${attendanceOpensLabel(session)}', style: body(12, weight: FontWeight.w600, color: C.blue))),
      ]);
}

/// Under "Mark all present": why some children will be marked absent instead.
const noticeAbsentHint = 'Children with a parent\'s absence notice will be marked absent.';

/// Therapies I deliver.
bool deliversTherapy(AppStore store, String therapyId) => store.therapist(store.therapistId)?.therapyIds.contains(therapyId) ?? false;

/// White-on-brand stat used inside gradient heroes.
class HeroStat extends StatelessWidget {
  final String value, label;
  const HeroStat(this.value, this.label, {super.key});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, maxLines: 1, style: display(24, color: Colors.white).copyWith(fontFeatures: tnum)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11, weight: FontWeight.w600, color: C.brand200)),
        ]),
      );
}

Widget heroDivider() => Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.12));

/// Opens a session from a pending report, loading its week first if it isn't on screen yet.
Future<void> openReport(BuildContext context, PendingReport r) async {
  final store = context.read<AppStore>();
  try {
    await store.loadWeek(weekStart(r.date));
  } catch (e) {
    if (context.mounted) toast(context, cleanError(e), error: true);
    return;
  }
  if (context.mounted) context.push('/therapist/sessions/${r.sessionId}');
}

/// Attended sessions still waiting for my report (rating + a few words), oldest first, from any day.
class PendingReportsCard extends StatelessWidget {
  final List<PendingReport> reports;
  const PendingReportsCard(this.reports, {super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    // One row per session, listing the children it is waiting on.
    final bySession = <String, List<PendingReport>>{};
    for (final r in reports) {
      (bySession[r.sessionId] ??= []).add(r);
    }
    final rows = bySession.values.toList();
    return Container(
      decoration: BoxDecoration(color: C.amberBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF2DFB4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
          child: Row(children: [
            const Icon(Icons.rate_review_outlined, size: 20, color: C.amber),
            const SizedBox(width: 8),
            Expanded(child: Text('${plural(reports.length, 'session report')} pending', maxLines: 2, overflow: TextOverflow.ellipsis, style: body(13.5, weight: FontWeight.w700, color: C.amber))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(44, 0, 16, 6),
          child: Text('Rate how each child did (0–10) and write a few words. Parents see it in their child\'s progress.', style: body(12, color: C.amber, height: 1.35)),
        ),
        for (final group in rows.take(5))
          InkWell(
            onTap: () => openReport(context, group.first),
            child: Container(
              // A full 44px tap target.
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
              child: Row(children: [
                SizedBox(width: 56, child: Text(group.first.date == todayISO() ? 'Today' : fmtDate(group.first.date, 'EEE d'), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, weight: FontWeight.w800, color: C.ink))),
                Expanded(
                  child: Text(
                    '${group.first.sessionName} · ${group.map((r) => store.child(r.childId)?.first ?? 'Child').join(', ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(13, weight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Rate', style: body(12, weight: FontWeight.w800, color: C.amber)),
                const Icon(Icons.chevron_right_rounded, size: 18, color: C.amber),
              ]),
            ),
          ),
        if (rows.length > 5) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 4), child: Text('and ${rows.length - 5} more sessions', style: body(12, color: C.amber))),
        const SizedBox(height: 6),
      ]),
    );
  }
}
