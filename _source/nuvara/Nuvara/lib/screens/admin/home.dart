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
import 'requests.dart' show preferredLabel;
import 'sessions.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  Timer? _tick;
  late String _today = todayISO();

  @override
  void initState() {
    super.initState();
    _loadTomorrow();
    // Keeps "Now" badges honest and rolls over at midnight.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final t = todayISO();
      if (t != _today) {
        final before = _today;
        final newWeek = weekStart(t) != weekStart(before);
        _today = t;
        final store = context.read<AppStore>();
        // A new week closes last week's bills; a new day may be in a week not loaded yet.
        // On failure (e.g. offline at midnight) the next tick quietly tries again.
        (newWeek ? store.refresh() : store.loadWeek(weekStart(t)).then((_) => store.touch())).catchError((_) {
          if (_today == t) _today = before;
        });
        _loadTomorrow();
      }
      setState(() {});
    });
  }

  /// On Sundays tomorrow is in next week, which isn't loaded at sign-in; its absence notices matter today.
  void _loadTomorrow() {
    final store = context.read<AppStore>();
    final m = weekStart(addDays(todayISO(), 1));
    if (store.weekSlots(m) != null) return;
    store.loadWeek(m).then((_) => store.touch(), onError: (_) {});
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
    final slots = store.slotsOn(today);
    final sessions = [for (final s in slots) ...s.sessions];
    final kids = {for (final s in sessions) ...s.childIds}.length;
    final staff = {for (final s in sessions) s.therapistId}.length;
    final owing = store.owing;
    final monday = weekStart(today);
    final thisWeek = store.feeWeeks.where((w) => w.monday == monday).toList();
    final billed = thisWeek.fold(0.0, (a, w) => a + w.amount), paid = thisWeek.fold(0.0, (a, w) => a + (w.paid > w.amount ? w.amount : w.paid));
    final attention = _attention(context, store, today, sessions);
    final started = [for (final s in slots) if (slotStarted(s)) ...s.sessions];

    return PageList(
      onRefresh: store.refresh,
      children: [
        _Header(name: store.userName),
        _TodayHero(slots: slots, sessions: sessions.length, kids: kids, staff: staff, roll: rollOf(started, store), away: rollOf(sessions, store).away),
        if (store.actionableRequests.isNotEmpty) ...[
          const SizedBox(height: 22),
          _RequestsAlert(requests: store.actionableRequests),
        ],
        if (attention.isNotEmpty) ...[
          const SizedBox(height: 22),
          _AttentionCard(items: attention),
        ],
        const SizedBox(height: 22),
        GridView(
          // Two per row on phones, more on tablets and wider.
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 240, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 118),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _NavCard(icon: Icons.favorite_rounded, color: const Color(0xFFB8486A), title: 'Our therapies', value: plural(store.therapies.length, 'therapy', 'therapies'), to: '/admin/therapies', push: true),
            _NavCard(icon: Icons.calendar_view_week_rounded, color: C.brand600, title: 'Timetables', value: '${plural(store.weekIndex[weekStart(today)]?.slots ?? 0, 'slot')} this week', to: '/admin/timetable'),
            _NavCard(icon: Icons.child_care_rounded, color: const Color(0xFFC2622D), title: 'Children', value: '${store.activeChildren.length} enrolled', to: '/admin/children'),
            _NavCard(icon: Icons.badge_rounded, color: const Color(0xFF3D64A8), title: 'Therapists', value: '${store.activeTherapists.length} on staff', to: '/admin/therapists', push: true),
            _NavCard(icon: Icons.event_repeat_rounded, color: C.violet, title: 'Slot requests', value: store.actionableRequests.isEmpty ? 'None waiting' : '${store.actionableRequests.length} waiting', to: '/admin/requests', push: true),
            _NavCard(icon: Icons.qr_code_2_rounded, color: const Color(0xFF2B8A9A), title: 'Payments', value: _paymentsValue(store), to: _paymentsToCheck(store) == 0 ? '/admin/fees/upi' : '/admin/fees/verify', push: true),
          ],
        ),
        const SizedBox(height: 10),
        _FeesCard(billed: billed, paid: paid, outstanding: owing.fold(0.0, (a, o) => a + o.due), owing: owing.length),
        const SizedBox(height: 26),
        SectionTitle(
          'Today\'s schedule',
          hint: slots.isEmpty ? fmtDate(today, 'EEEE, d MMMM') : '${fmtDate(today, 'EEEE')} · ${plural(slots.length, 'time slot')}',
          action: TextButton(onPressed: () => context.push('/admin/timetable/${weekStart(today)}?view=day'), child: const Text('Open week')),
        ),
        if (!store.weekLoaded(today))
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (slots.isEmpty && (store.weekSlots(monday) ?? const []).isNotEmpty)
          // The week is planned, just not today (e.g. a Sunday off).
          EmptyState(
            icon: Icons.wb_sunny_outlined,
            title: 'No sessions today',
            hint: 'This week\'s timetable has no time slots on ${fmtDate(today, 'EEEE')}.',
            action: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
              btn('Add a slot today', icon: Icons.add_rounded, kind: 'filled', onPressed: () => showSlotForm(context, monday: monday, date: today)),
              btn('Open week', icon: Icons.calendar_view_week_rounded, onPressed: () => context.push('/admin/timetable/$monday')),
            ]),
          )
        else if (slots.isEmpty)
          EmptyState(
            icon: Icons.wb_sunny_outlined,
            title: 'Nothing scheduled today',
            hint: 'Create this week\'s timetable to see today\'s time slots here.',
            action: btn('Plan this week', icon: Icons.edit_calendar_rounded, kind: 'filled', onPressed: () => context.push('/admin/timetable/${weekStart(today)}')),
          )
        else
          for (final s in slots) Padding(padding: const EdgeInsets.only(bottom: 10), child: SlotCard(s, onTap: () => showSlotSheet(context, s.id))),
      ],
    );
  }
}

/// What the admin should act on now: parents' absence notices for today and tomorrow, today's finished
/// sessions without attendance, and overdue fees. Short by design; each item opens where it's fixed.
List<_Item> _attention(BuildContext context, AppStore store, String today, List<Session> todays) {
  final items = <_Item>[];
  final tomorrow = addDays(today, 1);
  final dayView = '/admin/timetable/${weekStart(today)}?view=day';

  // Unread messages from families and from therapists.
  void unreadItem(int unread, List<({String id, Message last, int unread})> threads, String who, String Function(String id) name, String list, String chat) {
    if (unread == 0) return;
    final from = [for (final t in threads) if (t.unread > 0) name(t.id)];
    items.add(_Item(
      icon: Icons.chat_bubble_outline_rounded,
      color: C.brand600,
      title: unread == 1 ? '1 unread message from $who' : '$unread unread messages from ${who == 'a family' ? 'families' : 'therapists'}',
      subtitle: from.isEmpty ? 'Open Messages' : 'From ${from.take(3).join(', ')}${from.length > 3 ? ' +${from.length - 3}' : ''}',
      onTap: () => from.length == 1 ? context.push('$chat${threads.firstWhere((t) => t.unread > 0).id}') : context.push(list),
    ));
  }

  unreadItem(store.unreadFromFamilies, store.threads, 'a family', (id) => store.child(id)?.first ?? 'A family', '/admin/messages/parents', '/admin/messages/');
  unreadItem(store.unreadFromTherapists, store.therapistThreads, 'a therapist', (id) => store.therapist(id)?.first ?? 'A therapist', '/admin/messages/therapists',
      '/admin/messages/therapists/');

  // Families asking to move sessions have their own highlighted card above this list. Requests whose session
  // has already started can't be answered any more; they only need closing, so they wait quietly here.
  final expired = store.expiredRequests;
  if (expired.isNotEmpty) {
    items.add(_Item(
      icon: Icons.event_repeat_rounded,
      color: C.muted,
      title: expired.length == 1 ? '1 request passed unanswered · close it' : '${expired.length} requests passed unanswered · close them',
      subtitle: expired.length == 1
          ? "${store.child(expired.first.childId)?.first ?? 'A child'}'s session ${_onDay(expired.first.fromDate)} started before anyone answered"
          : 'Their sessions started before anyone answered',
      onTap: () => context.push('/admin/requests'),
    ));
  }

  // Session reports therapists still owe (rating + a few words for the parents).
  final reports = store.pendingReports;
  if (reports.isNotEmpty) {
    final who = {for (final r in reports) r.therapistId}.map((id) => store.therapist(id)?.first ?? 'A therapist').toList();
    items.add(_Item(
      icon: Icons.rate_review_outlined,
      color: C.amber,
      title: '${plural(reports.length, 'session report')} pending',
      subtitle: 'From ${who.take(3).join(', ')}${who.length > 3 ? ' +${who.length - 3}' : ''} · oldest ${_lowerDay(reports.first.date)}',
      onTap: () => context.push('/admin/reports'),
    ));
  }

  // UPI payments waiting for the admin's check, and ones the UPI app confirmed that still need ticking off against the bank.
  final verify = store.paymentsToVerify, reconcile = store.paymentsToReconcile;
  if (verify.isNotEmpty || reconcile.isNotEmpty) {
    items.add(_Item(
      icon: Icons.fact_check_outlined,
      color: C.blue,
      title: verify.isEmpty
          ? (reconcile.length == 1 ? 'Tick off a UPI payment of ${money(reconcile.first.amount)}' : 'Tick off ${reconcile.length} UPI payments')
          : (verify.length == 1 ? 'Verify a payment of ${money(verify.first.amount)}' : 'Verify ${verify.length} payments'),
      subtitle: [if (verify.isNotEmpty && reconcile.isNotEmpty) '${reconcile.length} more to tick off', 'Check them against the centre\'s bank or UPI app'].join(' · '),
      onTap: () => context.push('/admin/fees/verify'),
    ));
  }

  // Absence notices, one row per session.
  final noticed = [
    for (final d in [today, tomorrow])
      for (final slot in store.slotsOn(d))
        for (final s in slot.sessions)
          if (s.seats.values.where(openNotice).toList() case final seats when seats.isNotEmpty) (s: s, seats: seats),
  ];
  for (final n in noticed.take(3)) {
    final names = n.seats.map((x) => store.child(x.childId)?.first ?? 'A child').toList();
    final reason = n.seats.length == 1 ? (n.seats.first.absenceReason ?? '').trim() : '';
    items.add(_Item(
      icon: Icons.event_busy_rounded,
      color: C.amber,
      title: '${names.length > 2 ? '${names.take(2).join(', ')} +${names.length - 2}' : names.join(' & ')} away',
      subtitle: '${relDay(n.s.date)} ${fmtTime(n.s.start)} · ${n.s.name}${reason.isEmpty ? '' : ' · $reason'}',
      onTap: () => showSessionSheet(context, n.s.id),
    ));
  }
  if (noticed.length > 3) {
    final more = noticed.skip(3).fold<int>(0, (a, n) => a + n.seats.length);
    items.add(_Item(
      icon: Icons.event_busy_rounded,
      color: C.amber,
      title: '${plural(more, 'more absence', 'more absences')} reported',
      subtitle: 'For today and tomorrow',
      onTap: () => context.push(dayView),
    ));
  }

  // Families who haven't answered today's or tomorrow's sessions yet: worth a call before the day starts.
  final unanswered = [
    for (final d in [today, tomorrow])
      for (final slot in store.slotsOn(d))
        for (final s in slot.sessions)
          for (final id in s.childIds)
            if (s.unconfirmed(id) && store.requestCovering(id, s) == null) (s: s, childId: id),
  ];
  if (unanswered.isNotEmpty) {
    final names = {for (final u in unanswered) store.child(u.childId)?.first ?? 'A child'}.toList();
    items.add(_Item(
      icon: Icons.fact_check_outlined,
      color: C.amber,
      title: unanswered.length == 1 ? "${names.first} hasn't confirmed ${relDay(unanswered.first.s.date).toLowerCase()}'s session" : '${plural(unanswered.length, 'session')} not confirmed by families',
      subtitle: unanswered.length == 1
          ? '${fmtTime(unanswered.first.s.start)} · ${unanswered.first.s.name}'
          : 'Today and tomorrow · ${names.take(3).join(', ')}${names.length > 3 ? ' +${names.length - 3}' : ''}',
      onTap: () => unanswered.length == 1 ? showSessionSheet(context, unanswered.first.s.id) : context.push(dayView),
    ));
  }

  // Today's finished sessions with children not marked yet.
  final unmarked = todays.where((s) => s.phase == 'done' && s.markedCount < s.seats.length).toList();
  if (unmarked.length == 1) {
    final s = unmarked.first;
    items.add(_Item(
      icon: Icons.fact_check_outlined,
      color: C.blue,
      title: 'Mark attendance · ${s.name}',
      subtitle: '${fmtSpan(s.start, s.end)} · ${s.markedCount} of ${s.seats.length} marked',
      onTap: () => showSessionSheet(context, s.id),
    ));
  } else if (unmarked.length > 1) {
    items.add(_Item(
      icon: Icons.fact_check_outlined,
      color: C.blue,
      title: '${unmarked.length} finished sessions need attendance',
      subtitle: unmarked.map((s) => s.name).join(', '),
      onTap: () => context.push(dayView),
    ));
  }

  // Earlier sessions still without attendance (bills wait for them); today's finished ones are counted above.
  final todayUnmarked = unmarked.fold<int>(0, (a, s) => a + s.seats.length - s.markedCount);
  final pastWeeks = store.feeWeeks.where((w) => w.unmarked > 0).toList();
  final pastUnmarked = pastWeeks.fold<int>(0, (a, w) => a + w.unmarked) - todayUnmarked;
  if (pastUnmarked > 0) {
    final oldest = pastWeeks.map((w) => w.monday).reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
    final kids = {for (final w in pastWeeks) w.childId}.length;
    items.add(_Item(
      icon: Icons.fact_check_outlined,
      color: C.blue,
      title: '${plural(pastUnmarked, 'past session')} still need${pastUnmarked == 1 ? 's' : ''} attendance',
      subtitle: '${plural(kids, 'child', 'children')} · oldest in ${oldest == weekStart(today) ? 'this week' : 'the week of ${fmtDate(oldest, 'd MMM')}'} · bills wait for it',
      onTap: () => context.push('/admin/timetable/$oldest?view=day'),
    ));
  }

  // Overdue fees: earlier weeks still unpaid. This week's running bills are on the Fees card, not here.
  final thisWeek = weekStart(today);
  final overdue = <Child, double>{};
  for (final o in store.owing) {
    final owed = o.weeks.where((w) => w.monday != thisWeek).fold(0.0, (a, w) => a + w.due);
    if (owed > 0) overdue[o.child] = owed;
  }
  if (overdue.isNotEmpty) {
    final total = overdue.values.fold(0.0, (a, v) => a + v);
    final one = overdue.length == 1 ? overdue.keys.first : null;
    items.add(_Item(
      icon: Icons.account_balance_wallet_outlined,
      color: C.red,
      title: one == null ? '${overdue.length} children have unpaid earlier weeks' : '${one.first} has an unpaid earlier week',
      subtitle: '${money(total)} overdue${one == null ? '' : ' · ${one.code}'}',
      onTap: () => one == null ? context.go('/admin/fees') : context.push('/admin/fees/${one.id}'),
    ));
  }
  return items;
}

/// Families asking for another slot: these need an answer before the session, so they get their own
/// card instead of a row in "Needs attention". Each row says who, which session, and what they asked for,
/// and opens that request on the requests screen. [requests] are still answerable and come soonest session
/// first ([AppStore.actionableRequests]), so the most urgent one is always among the rows shown.
class _RequestsAlert extends StatelessWidget {
  final List<RescheduleRequest> requests;
  const _RequestsAlert({required this.requests});

  static const _shown = 3;

  /// "today", "tomorrow" or "Tue, 6 Oct".
  static String _when(String d) {
    final r = relDay(d);
    return r == 'Today' || r == 'Tomorrow' ? r.toLowerCase() : fmtDate(d, 'EEE, d MMM');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final soonest = requests.first.fromDate;
    final families = {for (final r in requests) r.childId}.length;
    return Container(
      decoration: BoxDecoration(
        color: C.violetBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: C.violet.withValues(alpha: 0.55), width: 1.5),
        boxShadow: [BoxShadow(color: C.violet.withValues(alpha: 0.16), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          color: C.violet,
          child: Row(children: [
            const Icon(Icons.event_repeat_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(families == 1 && requests.length == 1 ? 'A family needs another slot' : (families == requests.length ? '$families families need another slot' : '${plural(requests.length, 'slot request')} waiting'),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15.5, weight: FontWeight.w800, color: Colors.white)),
                Text('Answer before the session · soonest ${_when(soonest)}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.85))),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
              child: Text('${requests.length}', style: body(12.5, weight: FontWeight.w800, color: C.violet).copyWith(fontFeatures: tnum)),
            ),
          ]),
        ),
        for (var i = 0; i < requests.length && i < _shown; i++) ...[
          if (i > 0) Divider(height: 1, indent: 62, color: C.violet.withValues(alpha: 0.18)),
          _row(context, store, requests[i]),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
          child: FilledButton.icon(
            onPressed: () => context.push('/admin/requests'),
            style: FilledButton.styleFrom(backgroundColor: C.violet, foregroundColor: Colors.white, minimumSize: const Size(0, 44)),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(requests.length > _shown ? 'Review all ${requests.length} requests' : (requests.length == 1 ? 'Review request' : 'Review requests')),
          ),
        ),
      ]),
    );
  }

  Widget _row(BuildContext context, AppStore store, RescheduleRequest r) {
    final kid = store.child(r.childId);
    return InkWell(
      onTap: () => context.push('/admin/requests?focus=${r.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(children: [
          Avatar(kid?.name ?? '?', size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${kid?.first ?? 'A child'} · ${r.series ? 'regularly' : 'this day only'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text("Can't make ${_when(r.fromDate)} ${fmtTime(r.fromStart)} · ${r.sessionName}",
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, color: C.muted)),
              Text('Asks for: ${preferredLabel(r)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, weight: FontWeight.w700, color: C.violet)),
            ]),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: C.violet.withValues(alpha: 0.7), size: 22),
        ]),
      ),
    );
  }
}

/// "today", "tomorrow", "yesterday" or "on Tue, 6 Oct", after a noun ("the session on Tue, 6 Oct").
String _onDay(String d) {
  final r = relDay(d);
  return const {'Today', 'Tomorrow', 'Yesterday'}.contains(r) ? r.toLowerCase() : 'on $r';
}

/// "today", "tomorrow", "yesterday" or "Tue, 6 Oct": [relDay] for the middle of a sentence.
String _lowerDay(String d) {
  final r = relDay(d);
  return const {'Today', 'Tomorrow', 'Yesterday'}.contains(r) ? r.toLowerCase() : r;
}

int _paymentsToCheck(AppStore store) => store.paymentsToVerify.length + store.paymentsToReconcile.length;

/// The Payments card: what needs checking, else the UPI ID families pay to.
String _paymentsValue(AppStore store) {
  final verify = store.paymentsToVerify.length, reconcile = store.paymentsToReconcile.length;
  if (verify + reconcile == 0) return store.activeUpi?.vpa ?? 'Set up UPI';
  return verify > 0 ? '$verify to verify${reconcile > 0 ? ' · $reconcile to tick off' : ''}' : '$reconcile to tick off';
}

class _Item {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;
  const _Item({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});
}

class _AttentionCard extends StatelessWidget {
  final List<_Item> items;
  const _AttentionCard({required this.items});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Flexible(child: Text('Needs attention', maxLines: 1, overflow: TextOverflow.ellipsis, style: display(19))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: C.clay600, borderRadius: BorderRadius.circular(99)),
              child: Text('${items.length}', style: body(11.5, weight: FontWeight.w800, color: Colors.white).copyWith(fontFeatures: tnum)),
            ),
          ]),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(indent: 64),
              InkWell(
                onTap: items[i].onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  child: Row(children: [
                    IconTile(items[i].icon, color: items[i].color, size: 38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(items[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(items[i].subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(12.5, color: C.muted, height: 1.35)),
                      ]),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, color: C.muted, size: 20),
                  ]),
                ),
              ),
            ],
          ]),
        ),
      ]);
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
              Text('${greeting()},', style: body(14, weight: FontWeight.w600, color: C.muted)),
              Text(firstWord(name.isEmpty ? 'Admin' : name), style: display(30)),
            ]),
          ),
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => showAccountSheet(context),
            child: Avatar(name.isEmpty ? 'Admin' : name, size: 46),
          ),
        ]),
      );
}

class _TodayHero extends StatelessWidget {
  final List<Slot> slots;
  final int sessions, kids, staff;

  /// Attendance across today's sessions that have started; [away] counts open absence notices for the whole day.
  final Roll roll;
  final int away;
  const _TodayHero({required this.slots, required this.sessions, required this.kids, required this.staff, required this.roll, required this.away});

  @override
  Widget build(BuildContext context) {
    final now = slots.where((s) => slotPhase(s) == 'now').toList();
    final next = slots.where((s) => slotPhase(s) == 'upcoming').firstOrNull;
    final line = now.isNotEmpty
        ? 'Now · ${fmtSpan(now.first.start, now.first.end)} · ${plural(now.fold<int>(0, (a, s) => a + s.sessions.length), 'session')}'
        : next != null
            ? 'Next · ${fmtSpan(next.start, next.end)} · ${plural(next.sessions.length, 'session')}'
            : slots.isEmpty
                ? 'No time slots today'
                : 'All of today\'s sessions are done';
    return HeroSurface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(fmtDate(todayISO(), 'EEEE, d MMMM'), style: body(13, weight: FontWeight.w600, color: C.brand200))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: now.isNotEmpty ? const Color(0xFF6EE7B7) : C.brand300, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(now.isNotEmpty ? 'In session' : 'Today', style: body(11, weight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Text(line, style: display(19, color: Colors.white, height: 1.25)),
        const SizedBox(height: 18),
        Row(children: [
          _heroStat('${slots.length}', 'Slots'),
          _divider(),
          _heroStat('$sessions', 'Sessions'),
          _divider(),
          _heroStat('$kids', 'Children'),
          _divider(),
          _heroStat('$staff', 'Therapists'),
        ]),
        if (roll.total > 0 || away > 0) ...[
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.12)),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Padding(padding: const EdgeInsets.only(right: 2), child: Text('Attendance', style: body(12, weight: FontWeight.w700, color: C.brand200))),
            if (roll.total > 0) ...[
              _pill('${roll.present} present', const Color(0xFF6EE7B7)),
              if (roll.late > 0) _pill('${roll.late} late', const Color(0xFFFCD34D)),
              _pill('${roll.absent} absent', const Color(0xFFFCA5A5)),
              if (roll.marked < roll.total) _pill('${roll.total - roll.marked} to mark', Colors.white.withValues(alpha: 0.5)),
            ],
            if (away > 0) _pill('$away away', const Color(0xFFF59E0B)),
          ]),
        ],
      ]),
    );
  }

  Widget _pill(String label, Color dot) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: body(11.5, weight: FontWeight.w700, color: Colors.white).copyWith(fontFeatures: tnum)),
        ]),
      );

  Widget _heroStat(String v, String l) => Expanded(
        child: Column(children: [
          Text(v, style: display(24, color: Colors.white).copyWith(fontFeatures: tnum)),
          const SizedBox(height: 2),
          Text(l, style: body(11, weight: FontWeight.w600, color: C.brand200)),
        ]),
      );

  Widget _divider() => Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.12));
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, value, to;
  final bool push;
  const _NavCard({required this.icon, required this.color, required this.title, required this.value, required this.to, this.push = false});

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: () => push ? context.push(to) : context.go(to),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconTile(icon, color: color, size: 36),
            const Spacer(),
            Icon(Icons.arrow_outward_rounded, size: 16, color: C.muted.withValues(alpha: 0.6)),
          ]),
          const Spacer(),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14.5, weight: FontWeight.w700)),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted)),
        ]),
      );
}

class _FeesCard extends StatelessWidget {
  /// This week so far: billed for attended sessions, and collected of that.
  final double billed, paid;

  /// Every week, this one included: what is still due, and from how many children.
  final double outstanding;
  final int owing;
  const _FeesCard({required this.billed, required this.paid, required this.outstanding, required this.owing});

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: () => context.go('/admin/fees'),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const IconTile(Icons.account_balance_wallet_rounded, color: Color(0xFFA3791C), size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Fees', style: body(14.5, weight: FontWeight.w700)),
                Text(
                  outstanding > 0.005 ? '${money(outstanding)} outstanding from ${plural(owing, 'child', 'children')}' : 'Every attended session is paid for',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: body(12, color: C.muted),
                ),
              ]),
            ),
            Icon(Icons.arrow_outward_rounded, size: 16, color: C.muted.withValues(alpha: 0.6)),
          ]),
          const SizedBox(height: 14),
          Bar(billed == 0 ? 0 : paid / billed, color: C.green),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            StatusChip(billed == 0 ? 'Nothing billed this week yet' : 'This week: ${money(paid)} of ${money(billed)} collected', tone: billed > 0 && paid >= billed - 0.005 ? Tone.green : Tone.neutral, dot: false),
            if (owing > 0) StatusChip('${plural(owing, 'child', 'children')} to collect from', tone: Tone.red),
          ]),
        ]),
      );
}
