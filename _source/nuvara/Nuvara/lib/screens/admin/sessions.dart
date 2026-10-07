import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../actions.dart';
import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/account.dart' show callNumber;
import '../../widgets/charts.dart' show RatingPill;
import '../../widgets/ui.dart';

// Time slots and the sessions inside them: cards, detail sheets and the two create forms.

/// 'now' | 'done' | 'upcoming' for slots today; null for other days.
String? slotPhase(Slot s) {
  if (s.date != todayISO()) return null;
  final now = nowHM();
  if (now.compareTo(s.end) >= 0) return 'done';
  if (now.compareTo(s.start) >= 0) return 'now';
  return 'upcoming';
}

// ---- attendance ------------------------------------------------------------

String attendanceLabel(String? a) => switch (a) { 'present' => 'Present', 'late' => 'Late', 'absent' => 'Absent', _ => 'To mark' };
Tone attendanceTone(String? a) => switch (a) { 'present' => Tone.green, 'late' => Tone.amber, 'absent' => Tone.red, _ => Tone.neutral };


/// Past days, or today once the slot has begun: from then on, unmarked attendance is worth showing.
bool slotStarted(Slot s) {
  final t = todayISO();
  return s.date.compareTo(t) < 0 || (s.date == t && s.start.compareTo(nowHM()) <= 0);
}

/// A parent's absence notice that nobody has acted on yet (once marked, the notice is settled).
bool openNotice(Seat s) => s.noticed && s.attendance == null;

/// A parent's absence notice, worded and coloured the same everywhere: "Away · reason".
class AwayChip extends StatelessWidget {
  final String? reason;
  final String? label;
  const AwayChip({super.key, this.reason, this.label});

  @override
  Widget build(BuildContext context) {
    final r = (reason ?? '').trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: C.amberBg, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.event_busy_rounded, size: 13, color: C.amber),
        const SizedBox(width: 5),
        Flexible(child: Text(label ?? (r.isEmpty ? 'Away' : 'Away · $r'), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11, weight: FontWeight.w700, color: C.amber, height: 1.1))),
      ]),
    );
  }
}

typedef Roll = ({int total, int marked, int present, int late, int absent, int away, int unconfirmed});

/// Attendance totals across [sessions]. Seats whose family asked for another slot aren't counted as "to confirm".
Roll rollOf(Iterable<Session> sessions, AppStore store) {
  var total = 0, marked = 0, present = 0, late = 0, absent = 0, away = 0, unconfirmed = 0;
  // Only children with a request waiting need the (slower) covering check; the timetable draws many slots.
  final asking = {for (final r in store.requests) if (r.pending) r.childId};
  for (final s in sessions) {
    for (final seat in s.seats.values) {
      if (s.unconfirmed(seat.childId) && (!asking.contains(seat.childId) || store.requestCovering(seat.childId, s) == null)) unconfirmed++;
      total++;
      if (seat.attendance != null) marked++;
      if (seat.attendance == 'present') present++;
      if (seat.attendance == 'late') late++;
      if (seat.attendance == 'absent') absent++;
      if (openNotice(seat)) away++;
    }
  }
  return (total: total, marked: marked, present: present, late: late, absent: absent, away: away, unconfirmed: unconfirmed);
}

/// Small chips for a slot or session: open absence notices, seats families haven't confirmed yet, and
/// attendance progress once it has started.
List<Widget> rollChips(Roll r, {required bool started}) => [
      if (r.away > 0) AwayChip(label: '${r.away} away'),
      if (!started && r.unconfirmed > 0) StatusChip('${r.unconfirmed} to confirm', tone: Tone.amber, dot: false),
      if (started && r.total > 0)
        StatusChip(r.marked == r.total ? 'All marked' : '${r.marked}/${r.total} marked', tone: r.marked == r.total ? Tone.green : Tone.neutral, dot: r.marked == r.total),
    ];

class SlotCard extends StatelessWidget {
  final Slot slot;
  final VoidCallback? onTap;

  /// Lists each session inside the card (day view) instead of only summarising them.
  final bool expanded;
  final VoidCallback? onAddSession;
  const SlotCard(this.slot, {super.key, this.onTap, this.expanded = false, this.onAddSession});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final phase = slotPhase(slot);
    final kids = {for (final s in slot.sessions) ...s.childIds}.length;
    final live = phase == 'now';
    final chips = rollChips(rollOf(slot.sessions, store), started: slotStarted(slot));
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      border: live ? C.brand400 : C.line,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              width: 86,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: live ? C.brand800 : C.brand50),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(fmtTimeShort(slot.start), style: display(19, color: live ? Colors.white : C.brand900).copyWith(fontFeatures: tnum)),
                Text(fmtTime(slot.end), style: body(11.5, weight: FontWeight.w600, color: live ? C.brand200 : C.brand600).copyWith(fontFeatures: tnum)),
                const SizedBox(height: 6),
                Text(minutesLabel(slot.minutes), style: body(10.5, weight: FontWeight.w700, color: live ? C.brand300 : C.muted)),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Row(children: [
                    Expanded(
                      child: Text(slot.sessions.isEmpty ? 'No sessions yet' : plural(slot.sessions.length, 'session'),
                          style: body(15.5, weight: FontWeight.w700, color: slot.sessions.isEmpty ? C.muted : C.ink)),
                    ),
                    if (phase == 'now') const StatusChip('Now', tone: Tone.green),
                    if (phase == 'done') const StatusChip('Done', tone: Tone.neutral, dot: false),
                  ]),
                  const SizedBox(height: 6),
                  if (slot.sessions.isEmpty)
                    Text(onAddSession == null ? 'Tap to add a session' : 'Add the first session to this slot', style: body(12.5, color: C.muted))
                  else
                    Row(children: [
                      AvatarStack([for (final s in slot.sessions) store.therapistName(s.therapistId)], size: 24),
                      const SizedBox(width: 8),
                      Expanded(child: Text(plural(kids, 'child', 'children'), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, weight: FontWeight.w600, color: C.muted))),
                    ]),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: chips),
                  ],
                ]),
              ),
            ),
            if (!expanded) const Padding(padding: EdgeInsets.only(right: 10), child: Icon(Icons.chevron_right_rounded, color: C.muted)),
          ]),
        ),
        if (expanded) ...[
          if (slot.sessions.isNotEmpty) const Divider(),
          for (final s in slot.sessions) SessionTile(s, onTap: () => showSessionSheet(context, s.id)),
          if (onAddSession != null) ...[
            const Divider(),
            InkWell(
              onTap: onAddSession,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.add_rounded, size: 18, color: C.brand700),
                  const SizedBox(width: 6),
                  Text('Create session', style: body(13.5, weight: FontWeight.w700, color: C.brand700)),
                ]),
              ),
            ),
          ],
        ],
      ]),
    );
  }
}

/// One session: name, therapist and children, with a colour bar per therapist.
class SessionTile extends StatelessWidget {
  final Session session;
  final VoidCallback? onTap;
  const SessionTile(this.session, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final t = store.therapist(session.therapistId);
    final name = t?.name ?? 'Therapist';
    final chips = rollChips(rollOf([session], store), started: slotStarted(session.slot));
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(children: [
          Container(width: 4, height: 40, decoration: BoxDecoration(color: avatarColor(name), borderRadius: BorderRadius.circular(9))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(session.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14.5, weight: FontWeight.w700)),
              Text(store.therapyName(session.therapyId), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, weight: FontWeight.w600, color: store.therapy(session.therapyId)?.color ?? C.muted)),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.person_rounded, size: 14, color: C.muted),
                const SizedBox(width: 4),
                Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, weight: FontWeight.w600, color: C.muted))),
                const SizedBox(width: 10),
                const Icon(Icons.child_care_rounded, size: 14, color: C.muted),
                const SizedBox(width: 4),
                Text('${session.childIds.length}', style: body(12.5, weight: FontWeight.w600, color: C.muted)),
              ]),
            ]),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 112),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (var i = 0; i < chips.length; i++) ...[if (i > 0) const SizedBox(height: 4), chips[i]],
              ]),
            ),
          ],
          if (onTap != null) const Icon(Icons.chevron_right_rounded, color: C.muted, size: 20),
        ]),
      ),
    );
  }
}

/// What else deleting [sessions] undoes, for a confirm message (empty when nothing): families' requests to
/// move them are turned down (the database tells the family), and attended places come off the bills.
String deleteImpact(AppStore store, List<Session> sessions) {
  final ids = {for (final s in sessions) s.id};
  final asks = store.pendingRequests.where((r) => ids.contains(r.sessionId)).length;
  final attended = sessions.fold<int>(0, (a, s) => a + s.seats.values.where((x) => x.attended).length);
  return [
    if (asks > 0) asks == 1 ? 'A family is waiting for an answer to move it; their request is turned down and they are told.' : '$asks families are waiting for an answer to move them; their requests are turned down and they are told.',
    if (attended > 0) '${plural(attended, 'attended place')} (children marked present or late) will come off the families\' bills.',
  ].map((x) => ' $x').join();
}

// ---------------------------------------------------------------------------
// Slot sheet: the sessions running in one time slot.

Future<void> showSlotSheet(BuildContext context, String slotId, {bool admin = true}) => showSheet(context, builder: (_) => _SlotSheet(slotId, admin: admin));

class _SlotSheet extends StatelessWidget {
  final String slotId;
  final bool admin;
  const _SlotSheet(this.slotId, {required this.admin});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final slot = store.slotById(slotId);
    if (slot == null) {
      return const SheetBody(title: 'Slot removed', child: Text('This time slot no longer exists.'));
    }
    return SheetBody(
      title: fmtSpan(slot.start, slot.end),
      subtitle: '${fmtDate(slot.date, 'EEEE, d MMM')} · ${minutesLabel(slot.minutes)}',
      trailing: admin
          ? PopupMenuButton<String>(
              tooltip: 'More',
              icon: const Icon(Icons.more_horiz_rounded, color: C.muted),
              onSelected: (_) => _deleteSlot(context, slot),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete_outline_rounded, color: C.red, size: 20), const SizedBox(width: 10), Text('Delete time slot', style: body(14, color: C.red))])),
              ],
            )
          : null,
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
      footer: admin ? [btn('Create session', icon: Icons.add_rounded, kind: 'filled', onPressed: () => showSessionForm(context, date: slot.date, start: slot.start, end: slot.end))] : const [],
      child: slot.sessions.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: EmptyState(icon: Icons.groups_2_outlined, title: 'No sessions in this slot', hint: 'Create a session to assign a therapist and children to this time.'),
            )
          : Column(children: [
              for (var i = 0; i < slot.sessions.length; i++) ...[
                if (i > 0) const Divider(indent: 20, endIndent: 20),
                SessionTile(slot.sessions[i], onTap: () => showSessionSheet(context, slot.sessions[i].id, admin: admin)),
              ],
            ]),
    );
  }

  Future<void> _deleteSlot(BuildContext context, Slot slot) async {
    final n = slot.sessions.length;
    final ok = await confirm(context,
        title: 'Delete this time slot?',
        message: '${fmtSpan(slot.start, slot.end)} on ${fmtDate(slot.date, 'EEEE')}${n > 0 ? ' and its ${plural(n, 'session')} will be removed' : ' will be removed'}.'
            '${deleteImpact(context.read<AppStore>(), slot.sessions)} This cannot be undone.');
    if (!ok || !context.mounted) return;
    final store = context.read<AppStore>();
    final nav = Navigator.of(context);
    try {
      await store.deleteSlot(slot);
      nav.pop();
      if (context.mounted) toast(context, 'Time slot deleted');
    } catch (e) {
      if (context.mounted) toast(context, cleanError(e), error: true);
    }
  }
}

// ---------------------------------------------------------------------------
// Session sheet: who and when.

Future<void> showSessionSheet(BuildContext context, String sessionId, {bool admin = true}) => showSheet(context, builder: (_) => _SessionSheet(sessionId, admin: admin));

class _SessionSheet extends StatelessWidget {
  final String sessionId;
  final bool admin;
  const _SessionSheet(this.sessionId, {required this.admin});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final s = store.sessionById(sessionId);
    if (s == null) return const SheetBody(title: 'Session removed', child: Text('This session no longer exists.'));
    final t = store.therapist(s.therapistId);
    final kids = [for (final id in s.childIds) store.child(id)].whereType<Child>().toList()..sort((a, b) => a.no.compareTo(b.no));
    final markable = admin && s.attendanceOpen;
    final roll = rollOf([s], store);
    final unmarked = [for (final c in kids) if (s.seat(c.id)?.attendance == null) c.id];
    final phone = t?.details?.phone ?? '';
    return SheetBody(
      title: s.name,
      subtitle: '${store.therapyName(s.therapyId)} · ${fmtDate(s.date, 'EEE, d MMM')} · ${fmtSpan(s.start, s.end)}',
      footer: admin
          ? [
              ActionButton('Delete', icon: Icons.delete_outline_rounded, kind: 'danger', onPressed: () async {
                await _delete(context, s);
                return null;
              }),
              btn('Edit session', icon: Icons.edit_rounded, kind: 'filled', onPressed: () {
                // This sheet's context dies on pop; open the form from the navigator's.
                final host = Navigator.of(context);
                host.pop();
                showSessionForm(host.context, date: s.date, start: s.start, end: s.end, sessionId: s.id);
              }),
            ]
          : const [],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: _Fact(icon: Icons.schedule_rounded, label: 'Duration', value: minutesLabel(s.slot.minutes))),
          const SizedBox(width: 10),
          Expanded(
            child: s.attendanceOpen
                ? _Fact(icon: Icons.fact_check_outlined, label: 'Attendance', value: '${roll.marked} of ${roll.total} marked')
                : _Fact(icon: Icons.child_care_rounded, label: 'Children', value: roll.away > 0 ? '${s.childIds.length} · ${roll.away} away' : '${s.childIds.length}'),
          ),
        ]),
        const SizedBox(height: 20),
        const Overline('Therapist'),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
          decoration: BoxDecoration(color: C.canvas, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Avatar(t?.name ?? '?', size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                NameWithId(t?.name ?? 'Therapist', t?.code ?? ''),
                if (t != null && t.therapyIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(t.therapyIds.map(store.therapyName).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, color: C.muted)),
                  ),
              ]),
            ),
            if (admin && phone.isNotEmpty) _CallButton(number: phone, tooltip: 'Call ${t?.first ?? 'therapist'}'),
          ]),
        ),
        const SizedBox(height: 20),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Overline('Children (${kids.length})')),
          if (markable && unmarked.isNotEmpty)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _MarkAllButton(session: s, childIds: unmarked, label: unmarked.length == kids.length ? 'Mark all present' : 'Mark rest present'),
              ),
            ),
        ]),
        if (markable && unmarked.isNotEmpty && kids.any((c) => s.seat(c.id)?.noticed ?? false))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Children whose parents reported an absence are marked absent.', style: body(11.5, color: C.muted)),
          ),
        for (final c in kids)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SeatCard(
              session: s,
              child: c,
              markable: markable,
              onOpen: admin
                  ? () {
                      final router = GoRouter.of(context);
                      Navigator.pop(context);
                      router.push('/admin/children/${c.id}');
                    }
                  : null,
            ),
          ),
      ]),
    );
  }

  Future<void> _delete(BuildContext context, Session s) async {
    final ok = await confirm(context,
        title: 'Delete this session?', message: '"${s.name}" on ${fmtDate(s.date, 'EEEE')} at ${fmtTime(s.start)} will be removed from the timetable.${deleteImpact(context.read<AppStore>(), [s])}');
    if (!ok || !context.mounted) return;
    final store = context.read<AppStore>();
    final nav = Navigator.of(context);
    try {
      await store.deleteSession(s);
      nav.pop();
      if (context.mounted) toast(context, 'Session deleted');
    } catch (e) {
      if (context.mounted) toast(context, cleanError(e), error: true);
    }
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _Fact({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: C.line), borderRadius: BorderRadius.circular(16)),
        child: KV(label, value, icon: icon),
      );
}

class _CallButton extends StatelessWidget {
  final String number, tooltip;
  const _CallButton({required this.number, required this.tooltip});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: () => callNumber(context, number),
        style: IconButton.styleFrom(backgroundColor: C.brand50, foregroundColor: C.brand700),
        icon: const Icon(Icons.call_rounded, size: 19),
      );
}

/// Marks every unmarked child present, except those whose parents sent an absence notice (absent).
class _MarkAllButton extends StatefulWidget {
  final Session session;
  final List<String> childIds;
  final String label;
  const _MarkAllButton({required this.session, required this.childIds, required this.label});

  @override
  State<_MarkAllButton> createState() => _MarkAllButtonState();
}

class _MarkAllButtonState extends State<_MarkAllButton> {
  bool busy = false;

  Future<void> _run() async {
    final store = context.read<AppStore>();
    final s = widget.session;
    final away = [for (final id in widget.childIds) if (s.seat(id)?.noticed ?? false) id];
    final here = [for (final id in widget.childIds) if (!away.contains(id)) id];
    setState(() => busy = true);
    try {
      await Future.wait([
        if (here.isNotEmpty) store.markAttendance(s, here, 'present'),
        if (away.isNotEmpty) store.markAttendance(s, away, 'absent'),
      ]);
    } catch (e) {
      if (mounted) toast(context, cleanError(e), error: true);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: busy ? null : _run,
        style: TextButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 10), visualDensity: VisualDensity.compact),
        icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.done_all_rounded, size: 18),
        label: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
}

/// One child's place in a session: who, any absence notice from the parent, attendance and the therapist's note.
class _SeatCard extends StatelessWidget {
  final Session session;
  final Child child;
  final bool markable;
  final VoidCallback? onOpen;
  const _SeatCard({required this.session, required this.child, required this.markable, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final seat = session.seat(child.id);
    final status = seat?.attendance;
    final noticed = seat?.noticed ?? false;
    return Material(
      color: C.canvas,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(children: [
              Avatar(child.name, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  NameWithId(child.name, child.code, style: body(14.5, weight: FontWeight.w600)),
                  Text(ageLong(child.dob), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted)),
                ]),
              ),
              if (seat?.rating != null) ...[const SizedBox(width: 8), RatingPill(seat!.rating!)],
              if (session.phase == 'upcoming' && seat != null && !noticed) ...[
                const SizedBox(width: 8),
                _ConfirmChip(session: session, childId: child.id),
              ],
              if (session.phase != 'upcoming' && (seat?.reportPending ?? false)) ...[const SizedBox(width: 8), const StatusChip('Report pending', tone: Tone.amber)],
              if (!markable && (status != null || noticed)) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 104),
                  child: status != null ? StatusChip(attendanceLabel(status), tone: attendanceTone(status)) : const AwayChip(),
                ),
              ],
              if (onOpen != null) const Icon(Icons.chevron_right_rounded, color: C.muted, size: 20),
            ]),
          ),
        ),
        if (noticed)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(color: C.amberBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.amber.withValues(alpha: 0.18))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.event_busy_rounded, size: 17, color: C.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    (seat!.absenceReason ?? '').trim().isEmpty ? 'Away' : 'Away · ${seat.absenceReason!.trim()}',
                    style: body(13, weight: FontWeight.w700, color: C.amber, height: 1.3),
                  ),
                  Text(seat.absenceAt == null ? 'Reported by the parent' : 'Reported by the parent ${timeAgo(seat.absenceAt!)}', style: body(11.5, color: C.muted)),
                ]),
              ),
            ]),
          ),
        if (markable && seat != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _AttendanceToggle(
              value: status,
              onChanged: (v) async {
                try {
                  await context.read<AppStore>().markAttendance(session, [child.id], v);
                } catch (e) {
                  if (context.mounted) toast(context, cleanError(e), error: true);
                }
              },
            ),
          ),
        if ((seat?.note ?? '').trim().isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.sticky_note_2_outlined, size: 16, color: C.brand600),
              const SizedBox(width: 8),
              Expanded(child: Text(seat!.note.trim(), style: body(13, height: 1.4))),
            ]),
          ),
      ]),
    );
  }
}

/// Whether the family has confirmed an upcoming session, or asked for another slot.
class _ConfirmChip extends StatelessWidget {
  final Session session;
  final String childId;
  const _ConfirmChip({required this.session, required this.childId});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    if (store.requestCovering(childId, session) != null) return const StatusChip('Change requested', tone: Tone.violet);
    return (session.seat(childId)?.confirmed ?? false) ? const StatusChip('Confirmed', tone: Tone.green) : const StatusChip('Not confirmed', tone: Tone.amber);
  }
}

/// Present / Late / Absent in one compact control. Tapping the selected option clears it.
class _AttendanceToggle extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _AttendanceToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
        child: Row(children: [
          for (final o in const ['present', 'late', 'absent'])
            Expanded(
              child: Semantics(
                button: true,
                selected: value == o,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(value == o ? null : o);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 42,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(color: value == o ? toneColors(attendanceTone(o)).bg : Colors.transparent, borderRadius: BorderRadius.circular(9)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (value == o) ...[Icon(Icons.check_rounded, size: 15, color: toneColors(attendanceTone(o)).fg), const SizedBox(width: 4)],
                      Flexible(
                        child: Text(attendanceLabel(o), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, weight: FontWeight.w700, color: value == o ? toneColors(attendanceTone(o)).fg : C.muted)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      );
}

// ---------------------------------------------------------------------------
// Create / edit a session.

/// Every day (Mon–Sun) of the week containing [date]: centres run sessions on weekends too.
/// In the current week, days before today are left out (except [date], which was picked on purpose)
/// so repeating doesn't book the past by accident. A past or future week keeps every day.
List<String> repeatDates(String date) {
  final today = todayISO();
  final all = weekDates(date);
  if (!weekDates(date).contains(today)) return all;
  return all.where((d) => d == date || d.compareTo(today) >= 0).toList();
}

/// The days [repeatDates] leaves out.
List<String> skippedRepeatDates(String date) {
  final kept = repeatDates(date);
  return weekDates(date).where((d) => !kept.contains(d)).toList();
}

String _days(List<String> dates) => dates.map((d) => fmtDate(d, 'EEE')).join(', ');

/// The repeat switch's title: the whole week, or only what is left of it when earlier days are skipped.
String repeatTitle(String date) => skippedRepeatDates(date).isEmpty ? 'Repeat all week (Mon – Sun)' : 'Repeat on the rest of this week';

Future<void> showSessionForm(BuildContext context, {required String date, required String start, required String end, String? sessionId}) =>
    showSheet(context, builder: (_) => _SessionForm(date: date, start: start, end: end, sessionId: sessionId));

class _SessionForm extends StatefulWidget {
  final String date, start, end;
  final String? sessionId;
  const _SessionForm({required this.date, required this.start, required this.end, this.sessionId});

  @override
  State<_SessionForm> createState() => _SessionFormState();
}

typedef _Clash = ({String date, Session session});

class _SessionFormState extends State<_SessionForm> {
  final name = TextEditingController();
  String? therapistId, therapyId;
  final Set<String> childIds = {};
  bool repeat = false;
  bool tried = false;

  bool get editing => widget.sessionId != null;
  List<String> get dates => repeat ? repeatDates(widget.date) : [widget.date];

  @override
  void initState() {
    super.initState();
    if (editing) {
      final s = context.read<AppStore>().sessionById(widget.sessionId!);
      if (s != null) {
        name.text = s.name;
        therapistId = s.therapistId;
        therapyId = s.therapyId.isEmpty ? null : s.therapyId;
        childIds.addAll(s.childIds);
      }
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  _Clash? _therapistClash(AppStore s, String id) {
    for (final d in dates) {
      final x = s.therapistClash(id, d, widget.start, widget.end, exceptSession: widget.sessionId);
      if (x != null) return (date: d, session: x);
    }
    return null;
  }

  _Clash? _childClash(AppStore s, String id) {
    for (final d in dates) {
      final x = s.childClash(id, d, widget.start, widget.end, exceptSession: widget.sessionId);
      if (x != null) return (date: d, session: x);
    }
    return null;
  }

  String _why(AppStore s, _Clash c) => 'In "${c.session.name}" · ${fmtDate(c.date, 'EEE')} ${fmtSpan(c.session.start, c.session.end)}';

  /// Editing an upcoming session with a new therapist: every family in it must confirm again (`update_session`
  /// clears their confirmations). How many families that is; 0 otherwise.
  int _reconfirming(AppStore store) {
    if (!editing) return 0;
    final s = store.sessionById(widget.sessionId!);
    if (s == null || s.phase != 'upcoming' || therapistId == null || therapistId == s.therapistId) return 0;
    return childIds.length;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final therapist = store.therapist(therapistId);
    final tClash = therapistId == null ? null : _therapistClash(store, therapistId!);
    final kids = [for (final id in childIds) store.child(id)].whereType<Child>().toList()..sort((a, b) => a.no.compareTo(b.no));
    final kidClashes = {for (final c in kids) c.id: _childClash(store, c.id)}..removeWhere((_, v) => v == null);
    final reconfirm = _reconfirming(store);

    return SheetBody(
      title: editing ? 'Edit session' : 'Create session',
      subtitle: '${fmtDate(widget.date, 'EEE, d MMM')} · ${fmtSpan(widget.start, widget.end)}',
      footer: [
        btn('Cancel', onPressed: () => Navigator.pop(context)),
        ActionButton(editing ? 'Save changes' : 'Create session', icon: Icons.check_rounded, onPressed: () => _save(store, tClash != null || kidClashes.isNotEmpty)),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Field(
          'Session name',
          child: TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            style: body(15),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: 'e.g. Speech group · Room 2', errorText: tried && name.text.trim().isEmpty ? 'Enter a session name' : null),
          ),
        ),
        const SizedBox(height: 18),
        Field(
          'Therapy',
          hint: 'Each child is charged their fee for this therapy when marked present or late.',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in store.therapies)
                TogglePill(t.name, active: therapyId == t.id, color: t.color, onTap: () => setState(() {
                      therapyId = t.id;
                      // A therapist who doesn't deliver it is still allowed, but pick one who does when possible.
                      final current = store.therapist(therapistId);
                      if (current != null && !current.therapyIds.contains(t.id)) {
                        final match = store.activeTherapists.where((x) => x.therapyIds.contains(t.id) && _therapistClash(store, x.id) == null).toList();
                        if (match.length == 1) therapistId = match.first.id;
                      }
                    })),
            ]),
            if (tried && therapyId == null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Select a therapy', style: body(11.5, weight: FontWeight.w600, color: C.red))),
          ]),
        ),
        const SizedBox(height: 18),
        Field(
          'Therapist',
          child: PickerField(
            text: therapist == null ? 'Select a therapist' : '${therapist.name}  ·  ${therapist.code}',
            placeholder: therapist == null,
            icon: Icons.unfold_more_rounded,
            error: tried && therapistId == null
                ? 'Select a therapist'
                : (tClash != null
                    ? '${therapist?.first} is busy: ${_why(store, tClash)}'
                    : (therapist != null && therapyId != null && !therapist.therapyIds.contains(therapyId) ? '${therapist.first} isn\'t listed for ${store.therapyName(therapyId)}' : null)),
            onTap: () async {
              final picked = await showSheet<String>(context, builder: (_) => _TherapistPicker(selected: therapistId, therapyId: therapyId, clashOf: (id) => _therapistClash(store, id), why: (c) => _why(store, c)));
              if (picked != null) setState(() => therapistId = picked);
            },
          ),
        ),
        if (reconfirm > 0) ...[
          const SizedBox(height: 10),
          _Note(icon: Icons.fact_check_outlined, tone: Tone.amber, text: '${reconfirm == 1 ? '1 family' : '$reconfirm families'} will be asked to confirm again: the therapist is changing.'),
        ],
        const SizedBox(height: 18),
        Field(
          'Children',
          child: PickerField(
            text: childIds.isEmpty ? 'Select children' : '${plural(childIds.length, 'child', 'children')} selected',
            placeholder: childIds.isEmpty,
            icon: Icons.unfold_more_rounded,
            error: tried && childIds.isEmpty ? 'Select at least one child' : null,
            onTap: () async {
              final picked = await showSheet<Set<String>>(context, builder: (_) => _ChildrenPicker(selected: childIds, clashOf: (id) => _childClash(store, id), why: (c) => _why(store, c)));
              if (picked != null) {
                setState(() => childIds
                  ..clear()
                  ..addAll(picked));
              }
            },
          ),
        ),
        if (kids.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in kids)
              InputChip(
                avatar: Avatar(c.name, size: 22),
                label: Text('${c.first} · ${c.code}'),
                labelStyle: body(12.5, weight: FontWeight.w600, color: kidClashes.containsKey(c.id) ? C.red : C.ink),
                backgroundColor: kidClashes.containsKey(c.id) ? C.redBg : C.canvas,
                side: BorderSide(color: kidClashes.containsKey(c.id) ? const Color(0xFFF3C4CB) : C.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                deleteIcon: const Icon(Icons.close_rounded, size: 16),
                onDeleted: () => setState(() => childIds.remove(c.id)),
              ),
          ]),
          for (final e in kidClashes.entries)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${store.child(e.key)?.first} is busy: ${_why(store, e.value!)}', style: body(11.5, weight: FontWeight.w600, color: C.red)),
            ),
        ],
        // Nothing to repeat onto when the picked day is the week's last one left (e.g. today is Sunday).
        if (!editing && repeatDates(widget.date).length > 1) ...[
          const SizedBox(height: 16),
          Material(
            color: repeat ? C.brand50 : C.canvas,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: repeat ? C.brand200 : C.line)),
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              value: repeat,
              onChanged: (v) => setState(() => repeat = v),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(repeatTitle(widget.date), style: body(14.5, weight: FontWeight.w700)),
              subtitle: Text(
                repeat
                    ? 'Adds this session at ${fmtTime(widget.start)} on ${_days(dates)}${skippedRepeatDates(widget.date).isEmpty ? '' : ' — earlier days skipped'}'
                    : (skippedRepeatDates(widget.date).isEmpty ? 'Add the same session on every day of this week' : 'Add the same session on ${_days(repeatDates(widget.date))}'),
                style: body(12.5, color: C.muted),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Future<String?> _save(AppStore store, bool hasClash) async {
    setState(() => tried = true);
    if (name.text.trim().isEmpty || therapistId == null || therapyId == null || childIds.isEmpty) throw Exception('Fill in the highlighted fields.');
    if (hasClash) throw Exception('Someone selected is already in another session at this time.');
    final nav = Navigator.of(context);
    if (editing) {
      final s = store.sessionById(widget.sessionId!);
      if (s == null) throw Exception('This session no longer exists.');
      final reconfirm = _reconfirming(store);
      await store.updateSession(s, name: name.text, therapistId: therapistId!, therapyId: therapyId!, childIds: childIds.toList());
      nav.pop();
      return reconfirm == 0 ? 'Session updated' : 'Session updated. ${reconfirm == 1 ? '1 family' : '$reconfirm families'} will be asked to confirm again.';
    }
    final n = await store.createSessions(dates: dates, start: widget.start, end: widget.end, name: name.text, therapistId: therapistId!, therapyId: therapyId!, childIds: childIds.toList());
    nav.pop();
    return n == 1 ? 'Session created' : 'Session added to $n days';
  }
}

class _TherapistPicker extends StatelessWidget {
  final String? selected, therapyId;
  final _Clash? Function(String) clashOf;
  final String Function(_Clash) why;
  const _TherapistPicker({required this.selected, required this.clashOf, required this.why, this.therapyId});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    int rank(Therapist t, _Clash? c) => (c == null ? 0 : 2) + (therapyId == null || t.therapyIds.contains(therapyId) ? 0 : 1);
    final rows = [for (final t in store.activeTherapists) (t: t, clash: clashOf(t.id))]..sort((a, b) => rank(a.t, a.clash).compareTo(rank(b.t, b.clash)));
    final free = rows.where((r) => r.clash == null).length;
    return SheetBody(
      title: 'Select therapist',
      subtitle: '$free of ${rows.length} available at this time',
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: rows.isEmpty
          ? EmptyState(
              icon: Icons.badge_outlined,
              title: 'No therapists yet',
              hint: 'Add a therapist, then come back to assign them.',
              action: btn('Add therapist', icon: Icons.person_add_alt_1_rounded, kind: 'filled', onPressed: () => _leaveTo(context, '/admin/therapists/new')),
            )
          : Column(children: [
              for (final r in rows)
                ListTile(
                  enabled: r.clash == null,
                  onTap: () => Navigator.pop(context, r.t.id),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  selected: r.t.id == selected,
                  selectedTileColor: C.brand50,
                  leading: Opacity(opacity: r.clash == null ? 1 : 0.45, child: Avatar(r.t.name, size: 40)),
                  title: NameWithId(r.t.name, r.t.code, style: body(14.5, weight: FontWeight.w600, color: r.clash == null ? C.ink : C.muted)),
                  subtitle: Text(
                    r.clash == null ? (r.t.therapyIds.isEmpty ? 'Available' : 'Available · ${r.t.therapyIds.map(store.therapyName).join(', ')}') : 'Busy · ${why(r.clash!)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: body(12, weight: FontWeight.w500, color: r.clash == null ? C.green : C.red),
                  ),
                  trailing: r.t.id == selected ? const Icon(Icons.check_circle_rounded, color: C.brand700) : null,
                ),
            ]),
    );
  }
}

class _ChildrenPicker extends StatefulWidget {
  final Set<String> selected;
  final _Clash? Function(String) clashOf;
  final String Function(_Clash) why;
  const _ChildrenPicker({required this.selected, required this.clashOf, required this.why});

  @override
  State<_ChildrenPicker> createState() => _ChildrenPickerState();
}

class _ChildrenPickerState extends State<_ChildrenPicker> {
  late final Set<String> picked = {...widget.selected};
  String q = '';

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final rows = [for (final c in store.activeChildren.where((c) => c.matches(q))) (c: c, clash: widget.clashOf(c.id))];
    return SheetBody(
      title: 'Select children',
      subtitle: picked.isEmpty ? 'Tick one or more children' : '${picked.length} selected',
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      footer: [
        btn('Clear', onPressed: picked.isEmpty ? null : () => setState(picked.clear)),
        btn(picked.isEmpty ? 'Done' : 'Done · ${picked.length}', icon: Icons.check_rounded, kind: 'filled', onPressed: () => Navigator.pop(context, picked)),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: SearchField(hint: 'Search by name or ID', onChanged: (v) => setState(() => q = v))),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: store.activeChildren.isEmpty
                ? EmptyState(
                    icon: Icons.child_care_rounded,
                    title: 'No children yet',
                    hint: 'Add a child, then come back to seat them.',
                    action: btn('Add child', icon: Icons.person_add_alt_1_rounded, kind: 'filled', onPressed: () => _leaveTo(context, '/admin/children/new')),
                  )
                : EmptyState(icon: Icons.search_off_rounded, title: 'No match for "$q"', hint: 'Try a name, or an ID like C004 or 4.'),
          )
        else
          for (final r in rows)
            CheckboxListTile(
              value: picked.contains(r.c.id),
              // A child who is busy can still be unticked if they were already picked.
              onChanged: r.clash != null && !picked.contains(r.c.id) ? null : (v) => setState(() => v! ? picked.add(r.c.id) : picked.remove(r.c.id)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              controlAffinity: ListTileControlAffinity.trailing,
              secondary: Opacity(opacity: r.clash == null ? 1 : 0.45, child: Avatar(r.c.name, size: 38)),
              title: NameWithId(r.c.name, r.c.code, style: body(14.5, weight: FontWeight.w600, color: r.clash == null ? C.ink : C.muted)),
              subtitle: Text(
                r.clash == null ? '${ageLong(r.c.dob)}${r.c.therapies.isEmpty ? '' : ' · ${r.c.therapyIds.map(store.therapyName).join(', ')}'}' : 'Busy · ${widget.why(r.clash!)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: body(12, color: r.clash == null ? C.muted : C.red),
              ),
            ),
      ]),
    );
  }
}

/// Closes every open sheet, then opens [path]; used when a picker has nothing to pick yet.
void _leaveTo(BuildContext context, String path) {
  final router = GoRouter.of(context);
  Navigator.of(context).popUntil((r) => r is! PopupRoute);
  router.push(path);
}

// ---------------------------------------------------------------------------
// Create a time slot.

Future<void> showSlotForm(BuildContext context, {required String monday, String? date, String? start, String? end}) =>
    showSheet(context, builder: (_) => _SlotForm(monday: monday, date: date, start: start, end: end));

class _SlotForm extends StatefulWidget {
  final String monday;
  final String? date, start, end;
  const _SlotForm({required this.monday, this.date, this.start, this.end});

  @override
  State<_SlotForm> createState() => _SlotFormState();
}

class _SlotFormState extends State<_SlotForm> {
  late String date;
  late String start;
  late String end;
  bool repeat = false;

  @override
  void initState() {
    super.initState();
    final week = weekDates(widget.monday);
    date = widget.date ?? (week.contains(todayISO()) ? todayISO() : widget.monday);
    final store = context.read<AppStore>();
    final last = store.slotsOn(date).map((s) => s.end).fold<String?>(null, (a, e) => a == null || e.compareTo(a) > 0 ? e : a);
    start = widget.start ?? last ?? '09:00';
    end = widget.end ?? fromMin((toMin(start) + 45).clamp(0, 23 * 60 + 59));
  }

  List<String> get dates => repeat ? repeatDates(date) : [date];
  int get minutes => toMin(end) - toMin(start);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final week = weekDates(widget.monday);
    final valid = minutes > 0;
    final existing = dates.where((d) => store.slotAt(d, start, end) != null).toList();
    final overlapping = <String>[
      for (final d in dates)
        for (final s in store.slotsOn(d))
          if (!(s.start == start && s.end == end) && overlaps(start, end, s.start, s.end)) '${fmtDate(d, 'EEE')} ${fmtSpan(s.start, s.end)}',
    ];
    final fresh = dates.length - existing.length;

    return SheetBody(
      title: 'Create time slot',
      subtitle: weekLabel(widget.monday),
      footer: [
        btn('Cancel', onPressed: () => Navigator.pop(context)),
        ActionButton(
          fresh > 1 ? 'Create $fresh slots' : 'Create slot',
          icon: Icons.check_rounded,
          onPressed: !valid || fresh == 0
              ? null
              : () async {
                  final nav = Navigator.of(context);
                  final n = await store.createSlots(dates, start, end);
                  nav.pop();
                  return n == 1 ? 'Time slot created' : 'Time slot created on $n days';
                },
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Overline('Day'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final d in week)
            _DayChoice(date: d, active: dates.contains(d), primary: d == date, onTap: () => setState(() => date = d)),
        ]),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(child: Field('Starts', child: TimeField(value: start, onChanged: (v) => setState(() {
                    final keep = minutes > 0 ? minutes : 45;
                    start = v;
                    end = fromMin((toMin(v) + keep).clamp(0, 23 * 60 + 59));
                  })))),
          const SizedBox(width: 12),
          Expanded(child: Field('Ends', child: TimeField(value: end, onChanged: (v) => setState(() => end = v)))),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in const [30, 45, 60, 90])
            TogglePill(minutesLabel(m), active: minutes == m, onTap: () => setState(() => end = fromMin((toMin(start) + m).clamp(0, 23 * 60 + 59)))),
        ]),
        if (!valid) Padding(padding: const EdgeInsets.only(top: 10), child: Text('End time must be after the start time.', style: body(12.5, weight: FontWeight.w600, color: C.red))),
        // Hidden when the picked day is the only one left this week (nothing to repeat onto).
        if (repeatDates(date).length > 1) ...[
          const SizedBox(height: 18),
          Material(
            color: repeat ? C.brand50 : C.canvas,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: repeat ? C.brand200 : C.line)),
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              value: repeat,
              onChanged: (v) => setState(() => repeat = v),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(repeatTitle(date), style: body(14.5, weight: FontWeight.w700)),
              subtitle: Text(
                skippedRepeatDates(date).isNotEmpty ? (repeat ? '${_days(dates)} — earlier days skipped' : 'Create this time slot on ${_days(repeatDates(date))}') : 'Create this time slot on every day of this week',
                style: body(12.5, color: C.muted),
              ),
            ),
          ),
        ],
        if (valid) ...[
          const SizedBox(height: 16),
          _Note(
            icon: Icons.event_available_rounded,
            tone: Tone.green,
            text: fresh == 0
                ? 'This time slot already exists on ${existing.map((d) => fmtDate(d, 'EEE')).join(', ')}.'
                : '${fmtSpan(start, end)} (${minutesLabel(minutes)}) on ${dates.where((d) => !existing.contains(d)).map((d) => fmtDate(d, 'EEE')).join(', ')}.'
                    '${existing.isEmpty ? '' : ' Already on ${existing.map((d) => fmtDate(d, 'EEE')).join(', ')} — skipped.'}',
          ),
          if (overlapping.isNotEmpty) ...[
            const SizedBox(height: 8),
            _Note(icon: Icons.info_outline_rounded, tone: Tone.amber, text: 'Overlaps ${overlapping.take(3).join(', ')}${overlapping.length > 3 ? '…' : ''}. A therapist or child still can\'t be in both.'),
          ],
        ],
      ]),
    );
  }
}

class _DayChoice extends StatelessWidget {
  final String date;
  final bool active, primary;
  final VoidCallback onTap;
  const _DayChoice({required this.date, required this.active, required this.primary, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: primary,
        label: fmtDate(date, 'EEEE d MMMM'),
        excludeSemantics: true,
        child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: primary ? C.brand700 : (active ? C.brand100 : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: primary ? C.brand700 : (active ? C.brand200 : C.line)),
          ),
          child: Column(children: [
            Text(fmtDate(date, 'EEE'), style: body(11, weight: FontWeight.w700, color: primary ? C.brand100 : C.muted)),
            const SizedBox(height: 2),
            Text(fmtDate(date, 'd'), style: display(17, color: primary ? Colors.white : C.ink)),
          ]),
        ),
        ),
      );
}

class _Note extends StatelessWidget {
  final IconData icon;
  final Tone tone;
  final String text;
  const _Note({required this.icon, required this.tone, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = toneColors(tone);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: c.fg),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: body(12.5, weight: FontWeight.w600, color: c.fg, height: 1.4))),
      ]),
    );
  }
}
