import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../actions.dart';
import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/account.dart' show AddChildSheet;
import '../../widgets/ui.dart';
import 'reschedule.dart';

// Building blocks shared by the parent tabs: which child is selected, how a session reads from a
// parent's point of view, and the "Can't make it?" flow.

/// Shown wherever there is no child to show.
const noChildTitle = 'No child linked yet';
const noChildHint = "Your login isn't linked to a child yet. Please contact the centre.";

void openChat(BuildContext context, Child kid) => context.push('/parent/messages/${kid.id}');

/// A quiet one-line link to the child's chat with the centre, e.g. "Question about fees? Message the centre".
class MessageLink extends StatelessWidget {
  final String prompt;
  final Child kid;
  const MessageLink(this.prompt, {super.key, required this.kid});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => openChat(context, kid),
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: C.brand700),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$prompt '),
                  TextSpan(
                    text: 'Message the centre',
                    style: body(12.5, weight: FontWeight.w700, color: C.brand700),
                  ),
                ],
              ),
              style: body(12.5, color: C.muted, height: 1.4),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Set to a Monday to make the Schedule tab show that week (e.g. from Home's "Confirm slots").
final scheduleWeek = ValueNotifier<String?>(null);

/// The child the parent is looking at. Shared by every parent tab, so switching on one carries over.
final selectedChildId = ValueNotifier<String?>(null);

/// The parent's children; ones who have left the centre only show if no current child remains, or while they
/// still owe fees or have a payment to finish (so the family can still see and pay them).
List<Child> family(AppStore store) {
  final active = store.activeChildren;
  if (active.isEmpty) return store.children;
  return [for (final c in store.children) if (c.active || owesAfterLeaving(store, c)) c];
}

/// A child who has left the centre but still has fees due or an unfinished payment.
bool owesAfterLeaving(AppStore store, Child c) => !c.active && (store.dueTotal(c.id) > 0 || store.paymentsOf(c.id).any((p) => p.status == PayStatus.initiated));

/// The selected child, falling back to the first. Null when no child is linked to this account.
Child? currentChild(AppStore store) {
  final kids = family(store);
  if (kids.isEmpty) return null;
  return kids.where((c) => c.id == selectedChildId.value).firstOrNull ?? kids.first;
}

/// Rebuilds [builder] when the parent switches child.
class ChildScope extends StatelessWidget {
  final Widget Function(BuildContext context, AppStore store, Child? child) builder;
  const ChildScope({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return ValueListenableBuilder<String?>(valueListenable: selectedChildId, builder: (c, _, _) => builder(c, store, currentChild(store)));
  }
}

int byTime(Session a, Session b) => '${a.date} ${a.start}'.compareTo('${b.date} ${b.start}');

List<Session> sessionsOf(AppStore store, String childId, String monday) => store.sessionsOfChild(childId, monday)..sort(byTime);

/// Loads any of [mondays] not cached yet. Failures are quiet here; screens offer pull-to-refresh.
Future<void> ensureWeeks(AppStore store, Iterable<String> mondays) async {
  final missing = [
    for (final m in mondays)
      if (store.weekSlots(m) == null) m,
  ];
  if (missing.isEmpty) return;
  await Future.wait([for (final m in missing) store.loadWeek(m).catchError((_) {})]);
  store.touch();
}

/// The next session that hasn't finished yet (one in progress counts), looking this week and next.
Session? nextSession(AppStore store, String childId) {
  final monday = weekStart(todayISO());
  return [...sessionsOf(store, childId, monday), ...sessionsOf(store, childId, addDays(monday, 7))].where((s) => s.phase != 'done').firstOrNull;
}

/// Sessions with a therapist's note for [childId] across the recently loaded weeks, newest first.
List<Session> notedSessions(AppStore store, String childId, {int weeks = 8}) {
  final monday = weekStart(todayISO());
  return [
    for (var i = 0; i <= weeks; i++)
      for (final s in store.sessionsOfChild(childId, addDays(monday, -7 * i)))
        if ((s.seat(childId)?.note ?? '').trim().isNotEmpty) s,
  ]..sort((a, b) => byTime(b, a));
}

/// How one session looks to a parent.
enum Visit {
  upcoming('Coming up', Tone.blue, Icons.schedule_rounded),
  away('Away', Tone.amber, Icons.event_busy_rounded),
  live('In session now', Tone.green, Icons.play_circle_outline_rounded),
  present('Attended', Tone.green, Icons.check_circle_rounded),
  late('Late', Tone.green, Icons.check_circle_outline_rounded),
  absent('Absent', Tone.red, Icons.cancel_outlined),
  pending('Awaiting update', Tone.neutral, Icons.hourglass_empty_rounded);

  final String label;
  final Tone tone;
  final IconData icon;
  const Visit(this.label, this.tone, this.icon);
}

Visit visitOf(Session s, String childId) {
  final seat = s.seat(childId);
  // Before the start, a reported absence wins over attendance staff may have marked early.
  if (s.phase == 'upcoming' && (seat?.noticed ?? false)) return Visit.away;
  switch (seat?.attendance) {
    case 'present':
      return Visit.present;
    case 'late':
      return Visit.late;
    case 'absent':
      return Visit.absent;
  }
  if (seat?.noticed ?? false) return Visit.away;
  return switch (s.phase) {
    'live' => Visit.live,
    'done' => Visit.pending,
    _ => Visit.upcoming,
  };
}

/// Absence can be reported (or withdrawn) until the session actually starts, even if attendance was marked early.
bool canReport(Session s, String childId) => s.phase == 'upcoming' && s.seat(childId) != null;

/// Keeps a wide piece of content inside its box by shrinking it rather than overflowing.
Widget fit(Widget w, {Alignment alignment = Alignment.centerLeft}) => FittedBox(fit: BoxFit.scaleDown, alignment: alignment, child: w);

// ---- look & feel -------------------------------------------------------------

/// The navy hero used at the top of the parent tabs.
class HeroPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const HeroPanel({super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  @override
  Widget build(BuildContext context) => HeroSurface(padding: padding, child: child);
}

/// Small pill on the dark hero.
class HeroPill extends StatelessWidget {
  final String label;
  final Color dot;
  const HeroPill(this.label, {super.key, this.dot = C.brand300});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: body(11, weight: FontWeight.w700, color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

Color heroDot(Tone t) => switch (t) {
  Tone.green => const Color(0xFF6EE7B7),
  Tone.amber => const Color(0xFFFCD34D),
  Tone.red => const Color(0xFFFCA5A5),
  Tone.violet => const Color(0xFFC4B5FD),
  Tone.blue => const Color(0xFF93C5FD),
  Tone.neutral => C.brand300,
};

/// Header line for the light overline labels on the dark hero.
Text heroOverline(String text) => Text(
  text.toUpperCase(),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: body(11, weight: FontWeight.w800, color: C.brand200).copyWith(letterSpacing: 1.1),
);

/// The family's profiles, like accounts in Instagram: every child this login can see, every other child's
/// login remembered on this device (one tap switches to it), and "Add child" to sign in to another one.
class ChildSwitcher extends StatelessWidget {
  const ChildSwitcher({super.key});

  @override
  Widget build(BuildContext context) => ChildScope(
    builder: (context, store, current) {
      final kids = family(store);
      if (current == null) return const SizedBox.shrink();
      final codes = {for (final c in kids) c.code};
      final others = store.accounts.where((a) => a.userId != store.userId && !codes.contains(a.login)).toList();
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final c in kids)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ChildChip(child: c, selected: c.id == current.id),
                ),
              for (final a in others)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _AccountChip(account: a),
                ),
              const _AddChip(),
            ],
          ),
        ),
      );
    },
  );
}

/// Another child's login on this device: tapping switches to it.
class _AccountChip extends StatelessWidget {
  final SavedAccount account;
  const _AccountChip({required this.account});

  Future<void> _switch(BuildContext context) async {
    final store = context.read<AppStore>();
    final messenger = ScaffoldMessenger.of(context);
    HapticFeedback.selectionClick();
    selectedChildId.value = null;
    try {
      await store.switchAccount(account);
      messenger.showSnackBar(SnackBar(content: Text('Switched to ${account.childName}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(cleanError(e)), backgroundColor: C.red));
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Switch to ${account.childName}',
    child: GestureDetector(
      onTap: () => _switch(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99), border: Border.all(color: C.line), boxShadow: softShadow),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(account.childName, size: 32),
            const SizedBox(width: 9),
            Text(firstWord(account.childName), style: body(14, weight: FontWeight.w700)),
            const SizedBox(width: 7),
            IdBadge(account.login),
            const SizedBox(width: 6),
            const Icon(Icons.swap_horiz_rounded, size: 16, color: C.muted),
          ],
        ),
      ),
    ),
  );
}

class _AddChip extends StatelessWidget {
  const _AddChip();

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Add another child',
    child: GestureDetector(
      onTap: () => showSheet(context, builder: (_) => const AddChildSheet()),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
        decoration: BoxDecoration(color: C.canvas, borderRadius: BorderRadius.circular(99), border: Border.all(color: C.brand300)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 30, height: 30, decoration: const BoxDecoration(color: C.brand50, shape: BoxShape.circle), child: const Icon(Icons.add_rounded, size: 18, color: C.brand700)),
            const SizedBox(width: 8),
            Text('Add child', style: body(13.5, weight: FontWeight.w700, color: C.brand700)),
          ],
        ),
      ),
    ),
  );
}

class _ChildChip extends StatelessWidget {
  final Child child;
  final bool selected;
  const _ChildChip({required this.child, required this.selected});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'Show ${child.name}',
    child: GestureDetector(
      onTap: () {
        if (!selected) HapticFeedback.selectionClick();
        selectedChildId.value = child.id;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
        decoration: BoxDecoration(
          color: selected ? C.brand900 : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? C.brand900 : C.line),
          boxShadow: selected ? const [BoxShadow(color: Color(0x33010039), blurRadius: 14, spreadRadius: -4, offset: Offset(0, 6))] : softShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(child.name, size: 32, ring: selected),
            const SizedBox(width: 9),
            Text(
              child.first,
              style: body(14, weight: FontWeight.w700, color: selected ? Colors.white : C.ink),
            ),
            const SizedBox(width: 7),
            IdBadge(child.code, light: selected),
            if (!child.active) ...[
              const SizedBox(width: 6),
              Text('Left', style: body(11, weight: FontWeight.w700, color: selected ? C.brand100 : C.muted)),
            ],
            if (!selected && toConfirmSoon(context.read<AppStore>(), child.id) > 0) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: 'Sessions to confirm',
                child: Semantics(
                  label: 'sessions to confirm',
                  child: Container(width: 9, height: 9, decoration: const BoxDecoration(color: C.amber, shape: BoxShape.circle)),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// [childId]'s sessions to confirm this week and next: the same weeks the Schedule tab badge counts.
int toConfirmSoon(AppStore store, String childId) {
  final monday = weekStart(todayISO());
  return store.awaitingConfirmation(childId, monday).length + store.awaitingConfirmation(childId, addDays(monday, 7)).length;
}

/// Previous / next week with a quick way back to this week.
class WeekPager extends StatelessWidget {
  final String monday;
  final ValueChanged<String> onChanged;

  /// Sessions waiting for confirmation in earlier / later weeks: shown as a badge on that arrow.
  final int earlier, later;
  const WeekPager({super.key, required this.monday, required this.onChanged, this.earlier = 0, this.later = 0});

  Widget _arrow(IconData icon, String tip, int n, VoidCallback onTap) => IconButton(
        onPressed: onTap,
        tooltip: n > 0 ? '$tip · ${plural(n, 'session')} to confirm' : tip,
        icon: Badge(isLabelVisible: n > 0, label: Text('$n'), backgroundColor: C.amber, child: Icon(icon)),
      );

  @override
  Widget build(BuildContext context) {
    final thisWeek = weekStart(todayISO());
    final label = monday == thisWeek
        ? 'This week'
        : monday == addDays(thisWeek, 7)
        ? 'Next week'
        : monday == addDays(thisWeek, -7)
        ? 'Last week'
        : 'Week of ${fmtDate(monday, 'd MMM')}';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.line),
        boxShadow: softShadow,
      ),
      child: Row(
        children: [
          _arrow(Icons.chevron_left_rounded, 'Previous week', earlier, () => onChanged(addDays(monday, -7))),
          Expanded(
            child: Column(
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: body(14.5, weight: FontWeight.w700),
                ),
                Text(
                  weekLabel(monday),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: body(12, color: C.muted).copyWith(fontFeatures: tnum),
                ),
                if (monday != thisWeek)
                  TextButton(
                    onPressed: () => onChanged(thisWeek),
                    style: TextButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 10), textStyle: body(12, weight: FontWeight.w700)),
                    child: const Text('Back to this week', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          ),
          _arrow(Icons.chevron_right_rounded, 'Next week', later, () => onChanged(addDays(monday, 7))),
        ],
      ),
    );
  }
}

/// A therapist's note, set apart as a soft quote.
class NoteQuote extends StatelessWidget {
  final String note;
  final int? maxLines;
  const NoteQuote(this.note, {super.key, this.maxLines});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
    decoration: BoxDecoration(color: C.brand50, borderRadius: BorderRadius.circular(14)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.format_quote_rounded, size: 18, color: C.brand400),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            note.trim(),
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
            style: body(13.5, color: C.ink, height: 1.45),
          ),
        ),
      ],
    ),
  );
}

// ---- telling the centre about an absence ----------------------------------------

const _reasons = [
  ('Unwell', Icons.sick_outlined),
  ("Doctor's appointment", Icons.medical_services_outlined),
  ('Family function', Icons.celebration_outlined),
  ('Travelling', Icons.luggage_outlined),
  ('Other', Icons.edit_note_rounded),
];

Future<void> showAwaySheet(BuildContext context, Session session, Child kid) => showSheet(
  context,
  builder: (_) => _AwaySheet(session: session, kid: kid),
);

class _AwaySheet extends StatefulWidget {
  final Session session;
  final Child kid;
  const _AwaySheet({required this.session, required this.kid});

  @override
  State<_AwaySheet> createState() => _AwaySheetState();
}

class _AwaySheetState extends State<_AwaySheet> {
  String? reason;
  final note = TextEditingController();

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  String get _message {
    final extra = note.text.trim();
    if (reason == 'Other') return extra.isEmpty ? 'Other' : extra;
    return extra.isEmpty ? reason! : '$reason · $extra';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session, kid = widget.kid;
    final store = context.read<AppStore>();
    return SheetBody(
      title: "Can't make it?",
      subtitle: '${relDay(s.date)}, ${fmtTime(s.start)} · ${s.name}',
      footer: [
        btn('Cancel', onPressed: () => Navigator.pop(context)),
        ActionButton(
          'Tell the centre',
          icon: Icons.send_rounded,
          onPressed: reason == null
              ? null
              : () async {
                  await store.reportAbsence(s, kid.id, _message);
                  if (context.mounted) Navigator.pop(context);
                  return 'Thank you. The centre knows ${kid.first} will be away.';
                },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Avatar(kid.name, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: NameWithId(kid.name, kid.code, style: body(15, weight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Let the centre know ${kid.first} will be away. ${store.therapistName(s.therapistId).split(' ').first} will see it straight away, so there is no need to call.',
            style: body(13.5, color: C.muted, height: 1.45),
          ),
          const SizedBox(height: 20),
          const Overline('Reason'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final (label, icon) in _reasons) _ReasonChip(label: label, icon: icon, active: reason == label, onTap: () => setState(() => reason = label))],
          ),
          const SizedBox(height: 20),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: reason == 'Other' ? 'Tell us a little more' : 'Anything to add?',
                  style: body(12.5, weight: FontWeight.w700),
                ),
                if (reason != 'Other')
                  TextSpan(
                    text: '  Optional',
                    style: body(11.5, color: C.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          TextField(
            controller: note,
            minLines: 2,
            maxLines: 4,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            style: body(14.5),
            decoration: const InputDecoration(hintText: 'For example: fever since last night', counterText: ''),
          ),
        ],
      ),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ReasonChip({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: active,
    child: GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: active ? C.brand800 : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: active ? C.brand800 : C.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? Icons.check_rounded : icon, size: 16, color: active ? Colors.white : C.brand700),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: body(13, weight: FontWeight.w600, color: active ? Colors.white : C.ink),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// "Away · reason" with an Undo. [dark] is for use on the hero.
class AwayNotice extends StatefulWidget {
  final Session session;
  final Child kid;
  final bool dark;
  const AwayNotice({super.key, required this.session, required this.kid, this.dark = false});

  @override
  State<AwayNotice> createState() => _AwayNoticeState();
}

class _AwayNoticeState extends State<AwayNotice> {
  bool busy = false;

  Future<void> _undo() async {
    final store = context.read<AppStore>();
    setState(() => busy = true);
    try {
      await store.reportAbsence(widget.session, widget.kid.id, null);
      if (mounted) toast(context, "Done. We'll expect ${widget.kid.first} as usual.");
    } catch (e) {
      if (mounted) toast(context, cleanError(e), error: true);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final seat = widget.session.seat(widget.kid.id);
    final dark = widget.dark;
    final fg = dark ? Colors.white : C.amber;
    final undo = canReport(widget.session, widget.kid.id);
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, undo ? 4 : 12, 8),
      decoration: BoxDecoration(color: dark ? Colors.white.withValues(alpha: 0.1) : C.amberBg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(Icons.event_busy_rounded, size: 18, color: dark ? const Color(0xFFFCD34D) : C.amber),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (seat?.absenceReason ?? '').isEmpty ? 'Away' : 'Away · ${seat!.absenceReason}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: body(13, weight: FontWeight.w700, color: fg),
                ),
              ],
            ),
          ),
          if (undo)
            busy
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fg)),
                  )
                : TextButton(
                    onPressed: _undo,
                    style: TextButton.styleFrom(foregroundColor: fg, minimumSize: const Size(0, 36)),
                    child: const Text('Undo'),
                  ),
        ],
      ),
    );
  }
}

// ---- confirming the centre's plan ---------------------------------------------

/// What the family can do about one upcoming session, depending on where it stands:
/// * waiting for an answer: Confirm, Request another slot, Can't make it?
/// * confirmed: a "Confirmed" mark, with Change and Can't make it? still at hand
/// * change requested: says so (the request card above lets them withdraw it)
/// * away: the away notice with Undo.
/// [dark] is for the hero.
class SlotActions extends StatelessWidget {
  final Session session;
  final Child kid;
  final bool dark;
  const SlotActions({super.key, required this.session, required this.kid, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final s = session;
    final v = visitOf(s, kid.id);
    if (v == Visit.away) return AwayNotice(session: s, kid: kid, dark: dark);
    if (!canReport(s, kid.id)) return dark ? HeroPill(v.label, dot: heroDot(v.tone)) : StatusChip(v.label, tone: v.tone);
    // Asked for this session, or for an earlier one "Regularly" (that request moves this one too).
    final requested = store.requestCovering(kid.id, s) != null;
    final confirmed = s.seat(kid.id)?.confirmed ?? false;
    final fg = dark ? Colors.white : C.brand800;
    final link = TextButton.styleFrom(
      foregroundColor: dark ? C.brand100 : C.brand700,
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      visualDensity: VisualDensity.compact,
    );
    Widget away() => TextButton.icon(onPressed: () => showAwaySheet(context, s, kid), style: link, icon: const Icon(Icons.event_busy_outlined, size: 17), label: const Text("Can't make it?"));
    if (requested) {
      return Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        dark ? HeroPill('Change requested · waiting for the centre', dot: heroDot(Tone.violet)) : const StatusChip('Change requested', tone: Tone.violet),
        away(),
      ]);
    }
    if (confirmed) {
      return Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        dark ? HeroPill('Confirmed', dot: heroDot(Tone.green)) : const StatusChip('Confirmed', tone: Tone.green),
        TextButton.icon(onPressed: () => showRescheduleSheet(context, s, kid), style: link, icon: const Icon(Icons.event_repeat_rounded, size: 17), label: const Text('Change')),
        away(),
      ]);
    }
    final confirm = ActionButton(
      'Confirm',
      icon: Icons.check_rounded,
      style: dark ? FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: C.brand900, minimumSize: const Size(0, 44)) : FilledButton.styleFrom(minimumSize: const Size(0, 42)),
      onPressed: () async {
        HapticFeedback.lightImpact();
        await store.confirmSessions(kid.id, [s]);
        return null;
      },
    );
    const otherLabel = 'Request another slot';
    final other = OutlinedButton(
      onPressed: () => showRescheduleSheet(context, s, kid),
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        // The theme paints outlined buttons white, which hid the white label on the dark hero.
        backgroundColor: dark ? Colors.white.withValues(alpha: 0.12) : Colors.white,
        side: BorderSide(color: dark ? Colors.white.withValues(alpha: 0.4) : C.brand300),
        minimumSize: Size(0, dark ? 44 : 42),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      child: const Text(otherLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
    // Each half needs its whole label at the reader's text size, plus the button's padding (and Confirm's icon).
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final need = [
      labelWidth('Confirm', theme.filledButtonTheme.style?.textStyle?.resolve(const {}), scaler) + 18 + 8 + 2 * 18,
      labelWidth(otherLabel, theme.outlinedButtonTheme.style?.textStyle?.resolve(const {}), scaler) + 2 * 10 + 2,
    ].reduce((a, b) => a > b ? a : b);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      // Side by side when both labels fit whole; stacked on narrow phones and with large text.
      LayoutBuilder(
        builder: (context, box) => (box.maxWidth - 8) / 2 >= need + 4
            ? Row(children: [Expanded(child: confirm), const SizedBox(width: 8), Expanded(child: other)])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [confirm, const SizedBox(height: 8), other]),
      ),
      Align(alignment: Alignment.centerLeft, child: away()),
    ]);
  }
}

/// How wide [text] is on one line in [style] at the reader's text size.
double labelWidth(String text, TextStyle? style, TextScaler scaler) {
  final p = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, textScaler: scaler, maxLines: 1)..layout();
  final w = p.width;
  p.dispose();
  return w;
}

/// "The centre has planned N sessions: confirm them" with Confirm all, for one child and one week.
/// Nothing shows once every session is answered.
class ConfirmWeekCard extends StatelessWidget {
  final Child kid;
  final String monday;

  /// Shown on Home: tapping the card opens Schedule rather than confirming from there.
  final VoidCallback? onOpen;
  const ConfirmWeekCard({super.key, required this.kid, required this.monday, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final open = store.awaitingConfirmation(kid.id, monday);
    if (open.isEmpty) return const SizedBox.shrink();
    final thisWeek = monday == weekStart(todayISO());
    final which = thisWeek ? 'this week' : (monday == addDays(weekStart(todayISO()), 7) ? 'next week' : 'the week of ${fmtDate(monday, 'd MMM')}');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        onTap: onOpen,
        border: C.amber.withValues(alpha: 0.45),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const IconTile(Icons.fact_check_rounded, color: C.amber, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Confirm ${kid.first}'s slots", style: body(14.5, weight: FontWeight.w700)),
                Text(
                  '${plural(open.length, 'session')} planned for $which ${open.length == 1 ? 'is' : 'are'} waiting for you. The first is ${_onDay(open.first.date)} at ${fmtTime(open.first.start)}.',
                  style: body(12.5, color: C.muted, height: 1.35),
                ),
              ]),
            ),
            if (onOpen != null) const Icon(Icons.chevron_right_rounded, color: C.muted),
          ]),
          if (onOpen == null) ...[
            const SizedBox(height: 12),
            ActionButton(
              open.length == 1 ? 'Confirm this session' : 'Confirm all ${open.length}',
              icon: Icons.done_all_rounded,
              onPressed: () async {
                HapticFeedback.lightImpact();
                final n = await store.confirmSessions(kid.id, open);
                return n == 0 ? null : (n == 1 ? 'Session confirmed' : '$n sessions confirmed');
              },
            ),
            const SizedBox(height: 6),
            Text("Need a different time? Use \"Request another slot\" on that session. Can't come at all? Tap \"Can't make it?\".", textAlign: TextAlign.center, style: body(11.5, color: C.muted)),
          ],
        ]),
      ),
    );
  }
}

/// "today", "tomorrow" or "on Tue, 6 Oct", for the middle of a sentence.
String _onDay(String date) {
  final r = relDay(date);
  return r == 'Today' || r == 'Tomorrow' ? r.toLowerCase() : 'on $r';
}

class Spinner extends StatelessWidget {
  const Spinner({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(32),
    child: Center(child: CircularProgressIndicator(color: C.brand600)),
  );
}
