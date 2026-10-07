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
import 'kit.dart';
import 'progress.dart' show TodayProgress;

export 'fees.dart' show ParentFees;
export 'progress.dart' show ParentProgress;
export 'schedule.dart' show ParentSchedule;

// A parent only ever receives their own children from the database (the child IDs their login is
// linked to), so `store.children` is exactly "my children" here. Session rows likewise only carry
// this family's children.

class ParentHome extends StatefulWidget {
  const ParentHome({super.key});

  @override
  State<ParentHome> createState() => _ParentHomeState();
}

class _ParentHomeState extends State<ParentHome> {
  Timer? _tick;
  late String _today = todayISO();
  late String _minute = nowHM();
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _loadAhead();
    // Moves "next session" along as sessions finish, and rolls over at midnight.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      if (todayISO() != _today) {
        _today = todayISO();
        _loadAhead();
      }
      // A session that has started no longer needs confirming: let the Schedule tab badge (and every tab) recount.
      if (nowHM() != _minute) {
        _minute = nowHM();
        context.read<AppStore>().touch();
      }
      setState(() {});
    });
  }

  /// This week and next, so the hero can show the next session even late on a Sunday.
  void _loadAhead() {
    final monday = weekStart(todayISO());
    ensureWeeks(context.read<AppStore>(), [monday, addDays(monday, 7)]).then((_) {
      if (mounted) setState(() => _checked = true);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChildScope(
    builder: (context, store, kid) {
      final today = kid == null ? <Session>[] : sessionsOf(store, kid.id, weekStart(todayISO())).where((s) => s.date == todayISO()).toList();
      return PageList(
        onRefresh: () async {
          await store.refresh();
          _loadAhead();
        },
        children: [
          _Header(name: store.userName),
          const ChildSwitcher(),
          if (kid == null)
            const EmptyState(icon: Icons.child_care_rounded, title: noChildTitle, hint: noChildHint)
          else ...[
            _NextHero(kid: kid, checked: _checked),
            const SizedBox(height: 12),
            for (final m in [weekStart(todayISO()), addDays(weekStart(todayISO()), 7)])
              ConfirmWeekCard(
                kid: kid,
                monday: m,
                onOpen: () {
                  scheduleWeek.value = m;
                  context.go('/parent/schedule');
                },
              ),
            _MessageCard(kid: kid),
            const SizedBox(height: 22),
            _Today(kid: kid),
            // Nothing today: _Today already says so, once is enough.
            if (today.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: TodayProgress(kid: kid, sessions: today),
              ),
            _FeeDue(kid: kid),
            _LatestNote(kid: kid),
          ],
        ],
      );
    },
  );
}

/// "Message the centre", with the latest word from the centre for this child when there is one.
class _MessageCard extends StatelessWidget {
  final Child kid;
  const _MessageCard({required this.kid});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final last = store.thread(Convo.family(kid.id)).where((m) => m.fromAdmin).lastOrNull;
    final unread = store.unreadIn(Convo.family(kid.id));
    final title = unread > 0 ? 'New from the centre' : 'Message the centre';
    final line = last == null ? 'Have a question? Write to the centre, no need to call.' : last.body.trim();
    return AppCard(
      onTap: () => openChat(context, kid),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      border: unread > 0 ? C.brand300 : C.line,
      child: Row(
        children: [
          IconTile(unread > 0 ? Icons.mark_chat_unread_rounded : Icons.chat_bubble_outline_rounded, color: C.brand700, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  last == null ? title : '$title · ${timeAgo(last.at)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: body(14, weight: FontWeight.w700, color: unread > 0 ? C.brand800 : C.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  line,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: body(12.5, color: C.muted, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: C.brand700, borderRadius: BorderRadius.circular(99)),
              child: Text(
                '$unread',
                style: body(11.5, weight: FontWeight.w800, color: Colors.white).copyWith(fontFeatures: tnum),
              ),
            )
          else
            const Icon(Icons.chevron_right_rounded, color: C.muted),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String name;
  const _Header({required this.name});

  @override
  Widget build(BuildContext context) {
    // The centre's placeholder name ("Parent of Aarav") isn't a name to greet anyone by.
    final n = name.isEmpty || name.startsWith('Parent of ') ? 'there' : firstWord(name);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${greeting()},',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: body(14, weight: FontWeight.w600, color: C.muted),
                ),
                Text(n, maxLines: 1, overflow: TextOverflow.ellipsis, style: display(30)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const AccountAvatar(),
        ],
      ),
    );
  }
}

/// The next session, big and clear, with the one thing a parent may need to do about it.
class _NextHero extends StatelessWidget {
  final Child kid;

  /// The look-ahead load has finished (even if it failed), so an empty result means nothing is planned.
  final bool checked;
  const _NextHero({required this.kid, required this.checked});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final s = nextSession(store, kid.id);
    if (s == null) {
      final loaded = checked || store.weekSlots(addDays(weekStart(todayISO()), 7)) != null;
      return HeroPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heroOverline('Next session'),
            const SizedBox(height: 8),
            Text(loaded ? 'Nothing planned yet' : 'Checking the timetable…', style: display(24, color: Colors.white)),
            const SizedBox(height: 6),
            Text(
              loaded ? "The centre will add ${kid.first}'s next sessions soon. They'll appear here as soon as they do." : "Just a moment while we look up ${kid.first}'s next session.",
              style: body(13.5, color: C.brand100, height: 1.4),
            ),
          ],
        ),
      );
    }
    final v = visitOf(s, kid.id);
    final therapist = store.therapistName(s.therapistId);
    return HeroPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: heroOverline(v == Visit.live ? 'Happening now' : 'Next session')),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(3, 3, 10, 3),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Avatar(kid.name, size: 22),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          kid.first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: body(12, weight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${relDay(s.date)} · ${fmtTime(s.start)}',
            style: display(28, color: Colors.white, height: 1.15).copyWith(fontFeatures: tnum),
          ),
          const SizedBox(height: 6),
          Text(
            '${s.name} with ${firstWord(therapist)}',
            style: body(15.5, weight: FontWeight.w600, color: C.brand50),
          ),
          const SizedBox(height: 4),
          Text(
            '${minutesLabel(s.slot.minutes)} · until ${fmtTime(s.end)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: body(12.5, weight: FontWeight.w600, color: C.brand200),
          ),
          const SizedBox(height: 18),
          SlotActions(session: s, kid: kid, dark: true),
        ],
      ),
    );
  }
}

/// Today's sessions and how each went, once the therapist has marked them.
class _Today extends StatelessWidget {
  final Child kid;
  const _Today({required this.kid});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final today = todayISO();
    final sessions = sessionsOf(store, kid.id, weekStart(today)).where((s) => s.date == today).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle('Today', hint: fmtDate(today, 'EEEE, d MMMM')),
          if (sessions.isEmpty)
            AppCard(
              child: Row(
                children: [
                  const IconTile(Icons.wb_sunny_outlined, color: Color(0xFFA3791C), size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('No sessions for ${kid.first} today.', style: body(14, weight: FontWeight.w600)),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < sessions.length; i++)
              GroupedRow(
                index: i,
                count: sessions.length,
                child: InkWell(
                  onTap: () {
                    // Today is in this week: Schedule may have been left on another one.
                    scheduleWeek.value = weekStart(todayISO());
                    context.go('/parent/schedule');
                  },
                  child: _TodayRow(session: sessions[i], kid: kid),
                ),
              ),
        ],
      ),
    );
  }
}

class _TodayRow extends StatelessWidget {
  final Session session;
  final Child kid;
  const _TodayRow({required this.session, required this.kid});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final v = visitOf(session, kid.id);
    final requested = v == Visit.upcoming && store.requestCovering(kid.id, session) != null;
    final waiting = !requested && session.unconfirmed(kid.id);
    final label = requested ? 'Change requested' : (waiting ? 'To confirm' : (v == Visit.upcoming && (session.seat(kid.id)?.confirmed ?? false) ? 'Confirmed' : v.label));
    final tone = requested ? Tone.violet : (waiting ? Tone.amber : (label == 'Confirmed' ? Tone.green : v.tone));
    final c = toneColors(tone);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
            child: Icon(v.icon, size: 19, color: c.fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: body(14.5, weight: FontWeight.w700),
                ),
                Text(
                  '${fmtSpan(session.start, session.end)} · ${firstWord(store.therapistName(session.therapistId))}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: body(12.5, color: C.muted).copyWith(fontFeatures: tnum),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(child: StatusChip(label, tone: tone)),
        ],
      ),
    );
  }
}

class _FeeDue extends StatelessWidget {
  final Child kid;
  const _FeeDue({required this.kid});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final due = store.dueBills(kid.id);
    final unfinished = store.paymentsOf(kid.id).any((p) => p.status == PayStatus.initiated);
    if (due.isEmpty && !unfinished) return const SizedBox.shrink();
    final total = store.dueTotal(kid.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: AppCard(
        onTap: () => context.go('/parent/fees'),
        child: Row(children: [
          const IconTile(Icons.account_balance_wallet_rounded, color: C.clay600, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(unfinished && due.isEmpty ? 'Payment to finish' : 'Fee due', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, weight: FontWeight.w600, color: C.muted)),
              if (total > 0) fit(Text(money(total), style: display(22).copyWith(fontFeatures: tnum))),
              Text(
                due.isEmpty ? 'Tell us whether your last payment went through' : '${due.length == 1 ? 'Week of ${fmtDate(due.first.monday, 'd MMM')}' : plural(due.length, 'week')} · pay with UPI',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: body(12, color: C.muted),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: C.muted),
        ]),
      ),
    );
  }
}

class _LatestNote extends StatelessWidget {
  final Child kid;
  const _LatestNote({required this.kid});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final s = notedSessions(store, kid.id).firstOrNull;
    if (s == null) return const SizedBox.shrink();
    final therapist = store.therapistName(s.therapistId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            'From the therapist',
            action: TextButton(onPressed: () => context.go('/parent/progress'), child: const Text('All notes')),
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Avatar(therapist, size: 38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            therapist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: body(14.5, weight: FontWeight.w700),
                          ),
                          Text(
                            '${s.name} · ${relDay(s.date)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: body(12.5, color: C.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                NoteQuote(s.seat(kid.id)!.note, maxLines: 5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

