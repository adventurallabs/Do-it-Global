import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/account.dart';
import '../../widgets/ui.dart';
import 'parts.dart';

export 'child_detail.dart' show TherapistChildDetail;
export 'session.dart' show TherapistSessionScreen;

// The therapist's day: what's on, who's here, and attendance in one tap.

// ---------------------------------------------------------------------------
// Today

class TherapistToday extends StatefulWidget {
  const TherapistToday({super.key});

  @override
  State<TherapistToday> createState() => _TherapistTodayState();
}

class _TherapistTodayState extends State<TherapistToday> {
  Timer? _tick;
  late String _today = todayISO();
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadAround();
    // Keeps live / next / done honest and rolls over at midnight.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final t = todayISO();
      if (t != _today) {
        _today = t;
        _loadAround();
      }
      setState(() {});
    });
  }

  /// This week plus its neighbours: last week can still have children to mark, and next week holds "next up" on a Sunday.
  /// Only a failure for this week shows; the neighbours just add to the page.
  Future<void> _loadAround() {
    final store = context.read<AppStore>();
    final m = weekStart(todayISO());
    return Future.wait<void>([
      for (final w in [m, addDays(m, -7), addDays(m, 7)])
        store.loadWeek(w).then((_) {
          if (!mounted) return;
          if (w == m && _error != null) setState(() => _error = null);
          store.touch();
        }, onError: (Object e) {
          if (w == m && mounted) setState(() => _error = e);
        }),
    ]);
  }

  void _retry() {
    setState(() => _error = null);
    _loadAround();
  }

  /// Pull-to-refresh: reloads what is loaded and fetches any of the weeks around today that is still missing.
  Future<void> _refresh() async {
    final store = context.read<AppStore>();
    setState(() => _error = null);
    await Future.wait([store.refresh(), _loadAround()]);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final today = todayISO();
    final m = weekStart(today);
    final week = mySessions(store, m);
    final sessions = week.where((s) => s.date == today).toList();
    final nextId = sessions.where((s) => s.phase == 'upcoming').firstOrNull?.id;
    final earlier = [...mySessions(store, addDays(m, -7)), ...week].where((s) => s.date.compareTo(today) < 0 && unmarked(s).isNotEmpty).toList();
    final later = [...week, ...mySessions(store, addDays(m, 7))].where((s) => s.date.compareTo(today) > 0).firstOrNull;

    return PageList(
      onRefresh: _refresh,
      children: [
        _Header(name: store.userName),
        _TodayHero(sessions: sessions),
        if (store.unreadMessages > 0) ...[
          const SizedBox(height: 12),
          AppCard(
            onTap: () => context.go('/therapist/messages'),
            border: C.brand300,
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(children: [
              const IconTile(Icons.mark_chat_unread_rounded, color: C.brand700, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('New from the centre', style: body(14, weight: FontWeight.w700, color: C.brand800)),
                  Text(
                    store.messages.lastWhere((m) => m.fromAdmin && m.readAt == null).body.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: body(12.5, color: C.muted, height: 1.35),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              StatusChip('${store.unreadMessages}', tone: Tone.blue, dot: false),
            ]),
          ),
        ],
        const SizedBox(height: 24),
        if (store.therapistId == null)
          const EmptyState(icon: Icons.link_off_rounded, title: 'Account not linked', hint: 'Ask the centre admin to link your login to your therapist profile. Then pull down to refresh.')
        else if (!store.weekLoaded(today))
          _error == null
              ? const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
              : EmptyState(icon: Icons.wifi_off_rounded, title: 'Couldn\'t load today', hint: cleanError(_error!), action: btn('Try again', onPressed: _retry))
        else ...[
          if (earlier.isNotEmpty) ...[_EarlierToMark(earlier), const SizedBox(height: 22)],
          if (store.pendingReports.isNotEmpty) ...[PendingReportsCard(store.pendingReports), const SizedBox(height: 22)],
          SectionTitle('Today\'s sessions', hint: sessions.isEmpty ? null : 'Tap a child\'s status to mark attendance'),
          if (sessions.isEmpty)
            EmptyState(
              icon: Icons.wb_sunny_outlined,
              title: 'No sessions today',
              hint: later == null ? 'Enjoy the quiet day.' : 'Next up: ${later.name}, ${relDay(later.date)} at ${fmtTime(later.start)}.',
            )
          else
            for (var i = 0; i < sessions.length; i++) _TimelineItem(session: sessions[i], next: sessions[i].id == nextId, first: i == 0, last: i == sessions.length - 1),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String name;
  const _Header({required this.name});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${greeting()},', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w600, color: C.muted)),
              Text(firstWord(name.isEmpty ? 'there' : name), maxLines: 1, overflow: TextOverflow.ellipsis, style: display(30)),
            ]),
          ),
          Semantics(
            button: true,
            label: 'Account',
            child: InkWell(customBorder: const CircleBorder(), onTap: () => showAccountSheet(context), child: Avatar(name.isEmpty ? '?' : name, size: 46)),
          ),
        ]),
      );
}

class _TodayHero extends StatelessWidget {
  final List<Session> sessions;
  const _TodayHero({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final live = sessions.where((s) => s.phase == 'live').firstOrNull;
    final next = sessions.where((s) => s.phase == 'upcoming').firstOrNull;
    final kids = {for (final s in sessions) ...s.childIds}.length;
    final seats = sessions.fold<int>(0, (a, s) => a + s.childIds.length);
    final marked = sessions.fold<int>(0, (a, s) => a + s.childIds.length - unmarked(s).length);
    final toMark = toMarkCount(sessions);
    final line = live != null
        ? 'Now · ${live.name} until ${fmtTime(live.end)}'
        : next != null
            ? 'Next · ${next.name} at ${fmtTime(next.start)}'
            : sessions.isEmpty
                ? 'No sessions today'
                : toMark > 0
                    ? 'All done · ${plural(toMark, 'child', 'children')} still to mark'
                    : 'All done for today. Lovely work.';
    final pill = live != null ? 'In session' : (sessions.isNotEmpty && next == null ? 'Day done' : 'Today');
    return HeroSurface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(fmtDate(todayISO(), 'EEEE, d MMMM'), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13, weight: FontWeight.w600, color: C.brand200))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: live != null ? const Color(0xFF6EE7B7) : C.brand300, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(pill, style: body(11, weight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Text(line, maxLines: 2, overflow: TextOverflow.ellipsis, style: display(20, color: Colors.white, height: 1.25)),
        const SizedBox(height: 18),
        Row(children: [
          HeroStat('${sessions.length}', sessions.length == 1 ? 'Session' : 'Sessions'),
          heroDivider(),
          HeroStat('$kids', kids == 1 ? 'Child' : 'Children'),
          heroDivider(),
          HeroStat('$toMark', 'To mark'),
        ]),
        if (seats > 0) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: marked / seats),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: Colors.white.withValues(alpha: 0.12), color: const Color(0xFF6EE7B7)),
            ),
          ),
          const SizedBox(height: 6),
          Text('$marked of $seats marked', style: body(11.5, weight: FontWeight.w600, color: C.brand200).copyWith(fontFeatures: tnum)),
        ],
      ]),
    );
  }
}

/// Gentle nudge for sessions on earlier days (this week or last) that still have children to mark.
class _EarlierToMark extends StatelessWidget {
  final List<Session> sessions;
  const _EarlierToMark(this.sessions);

  @override
  Widget build(BuildContext context) {
    final total = sessions.fold<int>(0, (a, s) => a + unmarked(s).length);
    return Container(
      decoration: BoxDecoration(color: C.amberBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF2DFB4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(children: [
            const Icon(Icons.edit_note_rounded, size: 20, color: C.amber),
            const SizedBox(width: 8),
            Expanded(child: Text('${plural(total, 'child', 'children')} still to mark from earlier days', maxLines: 2, overflow: TextOverflow.ellipsis, style: body(13.5, weight: FontWeight.w700, color: C.amber))),
          ]),
        ),
        for (final s in sessions.take(4))
          InkWell(
            onTap: () => openSession(context, s),
            child: Container(
              // A full 44px tap target.
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
              child: Row(children: [
                SizedBox(width: 56, child: Text(fmtDate(s.date, 'EEE d'), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, weight: FontWeight.w800, color: C.ink))),
                Expanded(child: Text('${s.name} · ${fmtTime(s.start)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13, weight: FontWeight.w600))),
                const SizedBox(width: 8),
                Text('${unmarked(s).length} to mark', style: body(12, weight: FontWeight.w700, color: C.amber)),
                const Icon(Icons.chevron_right_rounded, size: 18, color: C.amber),
              ]),
            ),
          ),
        if (sessions.length > 4) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 4), child: Text('and ${sessions.length - 4} more', style: body(12, color: C.amber))),
        const SizedBox(height: 6),
      ]),
    );
  }
}

/// One session on today's timeline: rail dot, time, status, and every child with a one-tap attendance toggle.
class _TimelineItem extends StatelessWidget {
  final Session session;
  final bool next, first, last;
  const _TimelineItem({required this.session, required this.next, required this.first, required this.last});

  @override
  Widget build(BuildContext context) {
    final s = session;
    final status = sessionStatus(s, next: next);
    final live = s.phase == 'live';
    final done = s.phase == 'done';
    final left = unmarked(s);
    final dot = live ? C.green : (done ? C.brand300 : (next ? C.blue : C.line));
    return Stack(children: [
      // The rail: a hairline joining the sessions, with a dot at each.
      if (!(first && last)) Positioned(left: 6, top: first ? 22 : 0, bottom: last ? null : 0, height: last ? 22 : null, child: Container(width: 2, color: C.line)),
      Positioned(
        left: 0,
        top: 16,
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: live || next || done ? dot : Colors.white, shape: BoxShape.circle, border: Border.all(color: dot == C.line ? C.muted.withValues(alpha: 0.4) : Colors.white, width: 2.5), boxShadow: live ? [BoxShadow(color: C.green.withValues(alpha: 0.35), blurRadius: 8)] : null),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(left: 24, bottom: 14),
        child: AppCard(
          onTap: () => openSession(context, s),
          padding: EdgeInsets.zero,
          border: live ? C.brand400 : C.line,
          radius: 22,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(color: live ? C.brand800 : C.brand50, borderRadius: BorderRadius.circular(9)),
                    child: Text(fmtSpan(s.start, s.end), maxLines: 1, style: body(12, weight: FontWeight.w800, color: live ? Colors.white : C.brand800).copyWith(fontFeatures: tnum)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Align(alignment: Alignment.centerRight, child: StatusPill(status))),
                ]),
                const SizedBox(height: 9),
                Row(children: [
                  Expanded(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: display(19))),
                  const Icon(Icons.chevron_right_rounded, color: C.muted, size: 20),
                ]),
                Text('${minutesLabel(s.slot.minutes)} · ${plural(s.childIds.length, 'child', 'children')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, color: C.muted)),
              ]),
            ),
            if (s.childIds.isNotEmpty) const Divider(),
            for (var i = 0; i < s.childIds.length; i++) ...[
              if (i > 0) const Divider(indent: 14, endIndent: 14),
              Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 12), child: SeatRow(s, s.childIds[i])),
            ],
            if (s.childIds.isNotEmpty && !s.attendanceOpen) Padding(padding: const EdgeInsets.fromLTRB(14, 0, 12, 12), child: OpensNote(s)),
            if (done && s.markedCount > 0) const Padding(padding: EdgeInsets.fromLTRB(14, 0, 12, 12), child: LockedNote()),
            if (left.isNotEmpty && s.attendanceOpen) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  FilledButton(
                    onPressed: () => markAllPresent(context, s),
                    style: FilledButton.styleFrom(backgroundColor: C.brand50, foregroundColor: C.brand800),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.done_all_rounded, size: 18),
                      const SizedBox(width: 8),
                      Flexible(child: Text(left.length == s.childIds.length ? 'Mark all present' : 'Mark the rest present', maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                  if (left.any((id) => s.seat(id)?.noticed ?? false)) Padding(padding: const EdgeInsets.only(top: 8), child: Text(noticeAbsentHint, style: body(11.5, color: C.muted))),
                ]),
              ),
            ],
          ]),
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Week

class TherapistWeek extends StatefulWidget {
  const TherapistWeek({super.key});

  @override
  State<TherapistWeek> createState() => _TherapistWeekState();
}

class _TherapistWeekState extends State<TherapistWeek> {
  String monday = weekStart(todayISO());
  Object? error;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Live / next / to-mark follow the clock, as on Today.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    final store = context.read<AppStore>();
    final m = monday;
    setState(() => error = null);
    try {
      await store.loadWeek(m, force: force);
      store.touch();
    } catch (e) {
      if (mounted && m == monday) setState(() => error = e);
    }
  }

  void _go(int weeks) {
    setState(() => monday = weeks == 0 ? weekStart(todayISO()) : addDays(monday, 7 * weeks));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final loaded = store.weekSlots(monday) != null;
    final sessions = mySessions(store, monday);
    final thisWeek = monday == weekStart(todayISO());
    final days = <String, List<Session>>{};
    for (final s in sessions) {
      (days[s.date] ??= []).add(s);
    }
    final today = todayISO();
    final nextId = sessions.where((s) => s.date == today && s.phase == 'upcoming').firstOrNull?.id;

    return PageList(
      onRefresh: () => _load(force: true),
      children: [
        TabHeader('My week', actions: [if (!thisWeek) TextButton(onPressed: () => _go(0), child: const Text('This week'))]),
        _WeekBar(monday: monday, onPrev: () => _go(-1), onNext: () => _go(1)),
        const SizedBox(height: 12),
        if (store.therapistId == null)
          const EmptyState(icon: Icons.link_off_rounded, title: 'Account not linked', hint: 'Ask the centre admin to link your login to your therapist profile.')
        else if (!loaded)
          error == null
              ? const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
              : EmptyState(icon: Icons.wifi_off_rounded, title: 'Couldn\'t load this week', hint: cleanError(error!), action: btn('Try again', onPressed: _load))
        else ...[
          _WeekTotals(sessions),
          const SizedBox(height: 18),
          if (sessions.isEmpty)
            const EmptyState(icon: Icons.event_available_outlined, title: 'No sessions this week', hint: 'Sessions the admin plans for you will show up here.')
          else
            for (final e in days.entries) _DayGroup(date: e.key, sessions: e.value, nextId: nextId),
        ],
      ],
    );
  }
}

class _WeekBar extends StatelessWidget {
  final String monday;
  final VoidCallback onPrev, onNext;
  const _WeekBar({required this.monday, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final thisWeek = monday == weekStart(todayISO());
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line), boxShadow: softShadow),
      child: Row(children: [
        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left_rounded), tooltip: 'Previous week'),
        Expanded(
          child: Column(children: [
            Text(thisWeek ? 'This week' : (monday == addDays(weekStart(todayISO()), 7) ? 'Next week' : 'Week of ${fmtDate(monday, 'd MMM')}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14.5, weight: FontWeight.w700)),
            Text(weekLabel(monday), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted)),
          ]),
        ),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right_rounded), tooltip: 'Next week'),
      ]),
    );
  }
}

class _WeekTotals extends StatelessWidget {
  final List<Session> sessions;
  const _WeekTotals(this.sessions);

  @override
  Widget build(BuildContext context) {
    final kids = {for (final s in sessions) ...s.childIds}.length;
    final minutes = sessions.fold<int>(0, (a, s) => a + s.slot.minutes);
    final toMark = toMarkCount(sessions);
    final hours = minutes / 60;
    return HeroSurface(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Row(children: [
        HeroStat('${sessions.length}', 'Sessions'),
        heroDivider(),
        HeroStat('$kids', kids == 1 ? 'Child' : 'Children'),
        heroDivider(),
        HeroStat(hours == hours.roundToDouble() ? '${hours.round()}h' : '${hours.toStringAsFixed(1)}h', 'Hours'),
        heroDivider(),
        HeroStat('$toMark', 'To mark'),
      ]),
    );
  }
}

class _DayGroup extends StatelessWidget {
  final String date;
  final List<Session> sessions;
  final String? nextId;
  const _DayGroup({required this.date, required this.sessions, this.nextId});

  @override
  Widget build(BuildContext context) {
    final today = date == todayISO();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(children: [
            Flexible(child: Text(fmtDate(date, 'EEEE, d MMM'), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w800, color: today ? C.brand700 : C.ink))),
            if (today) ...[const SizedBox(width: 8), const StatusChip('Today', tone: Tone.green, dot: false)],
            const Spacer(),
            Text(plural(sessions.length, 'session'), style: body(12, color: C.muted)),
          ]),
        ),
        for (var i = 0; i < sessions.length; i++)
          GroupedRow(index: i, count: sessions.length, indent: 76, child: _WeekRow(sessions[i], next: sessions[i].id == nextId)),
      ]),
    );
  }
}

class _WeekRow extends StatelessWidget {
  final Session session;
  final bool next;
  const _WeekRow(this.session, {this.next = false});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final s = session;
    final kids = [for (final id in s.childIds) store.child(id)].whereType<Child>().toList();
    final live = s.phase == 'live';
    final noticed = s.seats.values.where((x) => x.noticed).length;
    return InkWell(
      onTap: () => openSession(context, s),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(children: [
          SizedBox(
            width: 52,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fmtTimeShort(s.start), maxLines: 1, style: display(17, color: live ? C.green : C.brand900).copyWith(fontFeatures: tnum)),
              Text(fmtTime(s.end), maxLines: 1, overflow: TextOverflow.fade, softWrap: false, style: body(10.5, weight: FontWeight.w600, color: C.muted).copyWith(fontFeatures: tnum)),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14.5, weight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                kids.isEmpty ? 'No children' : kids.map((c) => '${c.first} ${c.code}').join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: body(12, weight: FontWeight.w600, color: C.muted),
              ),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                StatusPill(sessionStatus(s, next: next)),
                if (noticed > 0) StatusChip('$noticed away', tone: Tone.amber),
              ]),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: C.muted, size: 20),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Children

class TherapistChildren extends StatefulWidget {
  const TherapistChildren({super.key});

  @override
  State<TherapistChildren> createState() => _TherapistChildrenState();
}

class _TherapistChildrenState extends State<TherapistChildren> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final all = [...store.children]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final list = all.where((c) => c.matches(q)).toList();
    // Next week too: on a Sunday (the centre runs every day) the next session is usually there.
    final m = weekStart(todayISO());
    final week = [...mySessions(store, m), ...mySessions(store, addDays(m, 7))];
    final now = '${todayISO()} ${nowHM()}';
    Session? nextWith(String id) => week.where((s) => s.childIds.contains(id) && '${s.date} ${s.end}'.compareTo(now) > 0).firstOrNull;

    return PageList(
      onRefresh: store.refresh,
      itemCount: list.length,
      itemBuilder: (context, i) {
        final c = list[i];
        return Padding(padding: const EdgeInsets.only(bottom: 10), child: _ChildCard(c, next: nextWith(c.id)));
      },
      children: [
        TabHeader('My children', subtitle: all.isEmpty ? null : plural(all.length, 'child', 'children')),
        SearchField(hint: 'Search by name or ID (C007)', onChanged: (v) => setState(() => q = v)),
        const SizedBox(height: 14),
        if (all.isEmpty)
          const EmptyState(icon: Icons.child_care_rounded, title: 'No children yet', hint: 'Children appear here once they are in your sessions.')
        else if (list.isEmpty)
          EmptyState(icon: Icons.search_off_rounded, title: 'No match for "$q"', hint: 'Try part of the name, or an ID like C004.'),
      ],
    );
  }
}

class _ChildCard extends StatelessWidget {
  final Child child;
  final Session? next;
  const _ChildCard(this.child, {this.next});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final c = child;
    final n = next;
    return AppCard(
      onTap: () => openChild(context, c.id),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Avatar(c.name, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              NameWithId(c.name, c.code, style: body(15, weight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                n == null ? ageLong(c.dob) : '${ageOf(c.dob)} · Next ${n.date == todayISO() ? 'today' : n.date == addDays(todayISO(), 1) ? 'tomorrow' : fmtDate(n.date, 'EEE, d MMM')} ${fmtTime(n.start)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: body(12.5, color: C.muted),
              ),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: C.muted),
        ]),
        if (c.therapies.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final ct in c.therapies)
              if (store.therapy(ct.therapyId) case final t?) TherapyTag(t),
          ]),
        ],
      ]),
    );
  }
}
