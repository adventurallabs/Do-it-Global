import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/charts.dart' show RatingPill;
import '../../widgets/ui.dart';
import '../admin/requests.dart' show RequestCard;
import 'kit.dart';

class ParentSchedule extends StatefulWidget {
  const ParentSchedule({super.key});

  @override
  State<ParentSchedule> createState() => _ParentScheduleState();
}

class _ParentScheduleState extends State<ParentSchedule> {
  String monday = weekStart(todayISO());
  final failed = <String>{};

  @override
  void initState() {
    super.initState();
    // Opened for a particular week (the tab is built on first visit, after Home asked for it).
    monday = scheduleWeek.value ?? monday;
    scheduleWeek.value = null;
    scheduleWeek.addListener(_jump);
    _load(monday);
  }

  @override
  void dispose() {
    scheduleWeek.removeListener(_jump);
    super.dispose();
  }

  /// Another tab asked for a particular week while this one was alive.
  void _jump() {
    final m = scheduleWeek.value;
    if (m == null) return;
    scheduleWeek.value = null;
    if (m != monday) _go(m);
  }

  Future<void> _load(String m, {bool force = false}) async {
    final store = context.read<AppStore>();
    if (!force && store.weekSlots(m) != null) return;
    try {
      await store.loadWeek(m, force: force);
      failed.remove(m);
    } catch (_) {
      failed.add(m);
    }
    if (mounted) store.touch();
  }

  void _go(String m) {
    setState(() => monday = m);
    _load(m);
  }

  @override
  Widget build(BuildContext context) => ChildScope(
    builder: (context, store, kid) {
      final loaded = store.weekSlots(monday) != null;
      final sessions = kid == null ? <Session>[] : sessionsOf(store, kid.id, monday);
      final visits = [for (final s in sessions) visitOf(s, kid!.id)];
      final attended = visits.where((v) => v == Visit.present || v == Visit.late).length;
      final away = visits.where((v) => v == Visit.away).length;
      final days = <String, List<Session>>{};
      for (final s in sessions) {
        (days[s.date] ??= []).add(s);
      }
      // Weeks the Schedule badge counts (this and next) that have sessions to confirm but aren't on screen.
      final thisWeek = weekStart(todayISO());
      final elsewhere = kid == null
          ? <({String monday, int n})>[]
          : [
              for (final m in [thisWeek, addDays(thisWeek, 7)])
                if (m != monday) (monday: m, n: store.awaitingConfirmation(kid.id, m).length),
            ].where((e) => e.n > 0).toList();
      int count(bool later) => elsewhere.where((e) => later ? e.monday.compareTo(monday) > 0 : e.monday.compareTo(monday) < 0).fold<int>(0, (a, e) => a + e.n);
      return PageList(
        onRefresh: () async {
          await Future.wait([store.refresh(), _load(monday, force: true)]);
        },
        children: [
          TabHeader('Schedule', subtitle: kid == null ? null : "${kid.first}'s sessions, week by week"),
          const ChildSwitcher(),
          // The Schedule badge counts every child; point to the others who have sessions waiting.
          if (kid != null)
            for (final c in family(store))
              if (c.id != kid.id && toConfirmSoon(store, c.id) > 0) _OtherChildToConfirm(kid: c, count: toConfirmSoon(store, c.id)),
          if (kid != null)
            for (final r in store.requests.where((r) => r.childId == kid.id && (r.pending || DateTime.now().difference(r.resolvedAt ?? r.createdAt).inDays < 7)))
              Padding(padding: const EdgeInsets.only(bottom: 10), child: RequestCard(r, admin: false)),
          WeekPager(monday: monday, onChanged: _go, earlier: count(false), later: count(true)),
          const SizedBox(height: 14),
          for (final e in elsewhere) _ConfirmElsewhere(monday: e.monday, shown: monday, count: e.n, onOpen: () => _go(e.monday)),
          if (kid != null && loaded) ConfirmWeekCard(kid: kid, monday: monday),
          if (kid == null)
            const EmptyState(icon: Icons.child_care_rounded, title: noChildTitle, hint: noChildHint)
          else if (!loaded)
            failed.contains(monday)
                ? EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: "Couldn't load this week",
                    hint: 'Please check your connection and try again.',
                    action: btn('Try again', icon: Icons.refresh_rounded, kind: 'soft', onPressed: () {
                      // Back to the spinner while it loads again.
                      setState(() => failed.remove(monday));
                      _load(monday, force: true);
                    }),
                  )
                : const Spinner()
          else if (sessions.isEmpty)
            EmptyState(
              icon: Icons.event_available_outlined,
              title: 'No sessions this week',
              hint: monday.compareTo(weekStart(todayISO())) > 0 ? "The centre hasn't planned this week yet. Check back soon." : 'Nothing was scheduled for ${kid.first} this week.',
            )
          else ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                StatusChip(plural(sessions.length, 'session'), dot: false),
                if (attended > 0) StatusChip('$attended attended', tone: Tone.green),
                if (away > 0) StatusChip('$away away', tone: Tone.amber),
              ],
            ),
            const SizedBox(height: 8),
            for (final e in days.entries) ...[
              _DayHeading(e.key),
              for (final s in e.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ScheduleTile(session: s, kid: kid),
                ),
            ],
          ],
        ],
      );
    },
  );
}

/// "2 sessions next week need your confirmation · View": the Schedule badge counts this week and next,
/// so when the screen shows a different week this points to where the badge comes from.
class _ConfirmElsewhere extends StatelessWidget {
  /// The week with sessions waiting, and the week on screen (which decides "go to" or "go back to").
  final String monday, shown;
  final int count;
  final VoidCallback onOpen;
  const _ConfirmElsewhere({required this.monday, required this.shown, required this.count, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final thisWeek = weekStart(todayISO());
    final which = monday == thisWeek ? 'this week' : (monday == addDays(thisWeek, 7) ? 'next week' : 'the week of ${fmtDate(monday, 'd MMM')}');
    final ahead = monday.compareTo(shown) > 0;
    // "Next week" read from a later page would sound like a week further on, so going back names the date.
    final target = monday == thisWeek ? 'this week' : 'the week of ${fmtDate(monday, 'd MMM')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        onTap: onOpen,
        color: C.amberBg,
        border: C.amber.withValues(alpha: 0.45),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(children: [
          const IconTile(Icons.fact_check_rounded, color: C.amber, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${plural(count, 'session')} $which ${count == 1 ? 'needs' : 'need'} your confirmation', style: body(14, weight: FontWeight.w700)),
              Text(ahead ? 'Tap to go to $which' : 'Tap to go back to $target', style: body(12.5, color: C.amber, weight: FontWeight.w600)),
            ]),
          ),
          Icon(ahead ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded, color: C.amber),
        ]),
      ),
    );
  }
}

/// "Anaya has 2 sessions to confirm · Show": another child on this login has sessions waiting this week or next.
class _OtherChildToConfirm extends StatelessWidget {
  final Child kid;
  final int count;
  const _OtherChildToConfirm({required this.kid, required this.count});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: AppCard(
      onTap: () => selectedChildId.value = kid.id,
      color: C.amberBg,
      border: C.amber.withValues(alpha: 0.45),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      child: Row(children: [
        Avatar(kid.name, size: 30),
        const SizedBox(width: 10),
        Expanded(child: Text('${kid.first} has ${plural(count, 'session')} to confirm', style: body(13.5, weight: FontWeight.w700))),
        TextButton(
          onPressed: () => selectedChildId.value = kid.id,
          style: TextButton.styleFrom(foregroundColor: C.amber, minimumSize: const Size(0, 40)),
          child: const Text('Show'),
        ),
      ]),
    ),
  );
}

class _DayHeading extends StatelessWidget {
  final String date;
  const _DayHeading(this.date);

  @override
  Widget build(BuildContext context) {
    final today = date == todayISO();
    final rel = relDay(date);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 0, 10),
      child: Row(
        children: [
          Flexible(
            child: Text(
              fmtDate(date, 'EEEE'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: display(18, color: today ? C.brand700 : C.ink),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              fmtDate(date, 'd MMM'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: body(13, weight: FontWeight.w600, color: C.muted),
            ),
          ),
          if (rel == 'Today' || rel == 'Tomorrow') ...[const SizedBox(width: 8), StatusChip(rel, tone: today ? Tone.green : Tone.blue, dot: false)],
        ],
      ),
    );
  }
}

/// One session for one child: time, what and who, how it went (or the "Can't make it?" action).
class ScheduleTile extends StatelessWidget {
  final Session session;
  final Child kid;
  const ScheduleTile({super.key, required this.session, required this.kid});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final s = session;
    final v = visitOf(s, kid.id);
    final note = s.seat(kid.id)?.note.trim() ?? '';
    final therapist = store.therapistName(s.therapistId);
    final dim = v == Visit.away || v == Visit.absent;
    final waiting = s.unconfirmed(kid.id) && store.requestCovering(kid.id, s) == null;
    return AppCard(
      padding: const EdgeInsets.all(14),
      border: v == Visit.live ? C.brand400 : (waiting ? C.amber.withValues(alpha: 0.5) : C.line),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 62,
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(color: v == Visit.live ? C.brand800 : (dim ? C.sand : C.brand50), borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                fit(
                  Text(
                    fmtTimeShort(s.start),
                    style: display(18, color: v == Visit.live ? Colors.white : C.brand900).copyWith(fontFeatures: tnum),
                  ),
                  alignment: Alignment.center,
                ),
                fit(
                  Text(
                    fmtTime(s.start).split(' ').last,
                    style: body(10.5, weight: FontWeight.w700, color: v == Visit.live ? C.brand100 : C.muted),
                  ),
                  alignment: Alignment.center,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: body(15.5, weight: FontWeight.w700, color: dim ? C.ink.withValues(alpha: 0.7) : C.ink),
                ),
                Text(
                  fmtSpan(s.start, s.end),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: body(12.5, weight: FontWeight.w600, color: C.brand700).copyWith(fontFeatures: tnum),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Avatar(therapist, size: 20),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        therapist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: body(12.5, weight: FontWeight.w600, color: C.muted),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        '  ·  ${minutesLabel(s.slot.minutes)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: body(12.5, color: C.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SlotActions(session: s, kid: kid),
                if (s.seat(kid.id)?.rating != null) ...[const SizedBox(height: 8), RatingPill(s.seat(kid.id)!.rating!)],
                if (s.phase != 'upcoming' && (s.seat(kid.id)?.reportPending ?? false)) ...[
                  const SizedBox(height: 8),
                  const Align(alignment: Alignment.centerLeft, child: StatusChip('Report pending', tone: Tone.amber)),
                ],
                if (note.isNotEmpty) ...[const SizedBox(height: 10), NoteQuote(note)],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
