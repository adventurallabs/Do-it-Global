import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../actions.dart';
import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/ui.dart';
import 'fees.dart' show askNote;

/// Families' requests for another slot: for one day, or regularly. Approving moves the child's seat in the
/// timetable in one step (into the session the family picked, or one the admin arranges) and fails as a whole
/// if anyone would be double-booked.
class RequestsScreen extends StatelessWidget {
  /// A request opened from the admin home: shown first and highlighted.
  final String? focus;
  const RequestsScreen({super.key, this.focus});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    // Soonest session first (the focused request on top); ones whose session has started can only be closed.
    final pending = [...store.actionableRequests]..sort((a, b) => (a.id == focus ? 0 : 1).compareTo(b.id == focus ? 0 : 1));
    final passed = [...store.expiredRequests]..sort((a, b) => (a.id == focus ? 0 : 1).compareTo(b.id == focus ? 0 : 1));
    final done = (store.requests.where((r) => !r.pending).toList()..sort((a, b) => (b.resolvedAt ?? b.createdAt).compareTo(a.resolvedAt ?? a.createdAt))).take(30).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Slot requests')),
      body: PageList(
        onRefresh: store.refresh,
        children: [
          SectionTitle('Waiting for you', hint: pending.isEmpty ? null : plural(pending.length, 'request')),
          if (pending.isEmpty)
            EmptyState(icon: Icons.event_available_rounded, title: passed.isEmpty ? 'No requests' : 'Nothing to answer', hint: 'When a family asks for another slot, it shows up here.')
          else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text("Each family can't make the planned session. Approve the slot they picked, arrange another one, or tell them it's not possible.",
                  style: body(12.5, color: C.muted, height: 1.4)),
            ),
            for (final r in pending) Padding(padding: const EdgeInsets.only(bottom: 10), child: RequestCard(r, admin: true, highlight: r.id == focus)),
          ],
          if (passed.isNotEmpty) ...[
            const SizedBox(height: 18),
            SectionTitle('Session passed', hint: plural(passed.length, 'request')),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('These sessions started before anyone answered, so they stayed as planned. Close each request to let the family know.', style: body(12.5, color: C.muted, height: 1.4)),
            ),
            for (final r in passed) Padding(padding: const EdgeInsets.only(bottom: 10), child: RequestCard(r, admin: true, highlight: r.id == focus)),
          ],
          if (done.isNotEmpty) ...[
            const SizedBox(height: 18),
            const SectionTitle('Answered'),
            for (final r in done) Padding(padding: const EdgeInsets.only(bottom: 10), child: RequestCard(r, admin: true)),
          ],
        ],
      ),
    );
  }
}

Tone requestTone(RequestStatus s) => switch (s) {
      RequestStatus.pending => Tone.violet,
      RequestStatus.approved => Tone.green,
      RequestStatus.rejected => Tone.red,
      RequestStatus.cancelled => Tone.neutral,
    };

/// What the family asked for, in words: the session they picked, or the time they suggested.
String preferredLabel(RescheduleRequest r) {
  final day = r.series ? 'Every ${fmtDate(r.fromDate, 'EEEE')}' : (r.preferredDate == null ? null : fmtDate(r.preferredDate!, 'EEE, d MMM'));
  final time = r.preferredStart == null ? null : (r.preferredEnd == null ? fmtTime(r.preferredStart!) : fmtSpan(r.preferredStart!, r.preferredEnd!));
  if (time == null) return 'Any time that suits the centre';
  return [?day, time].join(' · ');
}

/// One request, from either side. Admins approve or turn it down; parents can withdraw a pending one.
class RequestCard extends StatelessWidget {
  final RescheduleRequest request;
  final bool admin;

  /// Opened from a link to this request: drawn with a strong outline so it's easy to find.
  final bool highlight;
  const RequestCard(this.request, {super.key, required this.admin, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final r = request;
    final kid = store.child(r.childId);
    final approved = r.status == RequestStatus.approved && r.newDate != null;
    final newTherapist = approved && r.newTherapistId != null && r.newTherapistId != r.therapistId ? ' with ${store.therapist(r.newTherapistId)?.first ?? 'another therapist'}' : '';
    return AppCard(
      border: highlight ? C.violet : (admin && r.pending && !r.expired ? C.violet.withValues(alpha: 0.35) : C.line),
      color: highlight ? C.violetBg : C.surface,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (admin) ...[Avatar(kid?.name ?? '?', size: 34), const SizedBox(width: 10)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(admin ? '${kid?.name ?? 'Child'} · ${kid?.code ?? ''}' : r.sessionName, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14.5, weight: FontWeight.w700)),
              Text(r.series ? 'Regularly, from this session on' : 'For this day only', style: body(12, color: C.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          Flexible(child: r.expired ? const StatusChip('Session passed', tone: Tone.neutral) : StatusChip(r.pending && admin ? 'Needs your answer' : r.status.label, tone: requestTone(r.status))),
        ]),
        const SizedBox(height: 12),
        _Move(
          toLabel: approved ? 'Moved to' : (admin ? 'Family asks for' : 'You asked for'),
          from: '${fmtDate(r.fromDate, 'EEE, d MMM')} · ${fmtSpan(r.fromStart, r.fromEnd)}',
          fromHint: '${r.sessionName} · ${store.therapistName(r.therapistId)}',
          to: approved ? '${fmtDate(r.newDate!, 'EEE, d MMM')} · ${fmtSpan(r.newStart!, r.newEnd!)}$newTherapist' : preferredLabel(r),
          toHint: approved
              ? (r.moved > 1 ? '${r.moved} sessions moved' : 'Moved')
              : switch (r.status) {
                  RequestStatus.rejected => admin ? 'Turned down; the original session stands.' : "The centre couldn't move it; the original session stands.",
                  RequestStatus.cancelled => admin ? 'The family withdrew this; the session stands.' : 'You withdrew this; the original session stands.',
                  _ when r.expired => 'The session went ahead as planned.',
                  _ => r.picked
                      ? 'Picked an existing session with ${store.therapistName(r.targetTherapistId)}'
                      : (admin ? 'Suggested time: a session needs arranging' : 'You suggested this time; the centre will arrange it.'),
                },
          moved: approved,
        ),
        if (r.reason.isNotEmpty) ...[const SizedBox(height: 10), Text('"${r.reason}"', style: body(13, color: C.ink, height: 1.4).copyWith(fontStyle: FontStyle.italic))],
        if (r.adminNote.isNotEmpty) ...[const SizedBox(height: 8), Text('Centre: ${r.adminNote}', style: body(12.5, weight: FontWeight.w600, color: C.brand700, height: 1.4))],
        const SizedBox(height: 6),
        Text('Asked ${timeAgo(r.createdAt)}${r.resolvedAt == null ? '' : ' · answered ${timeAgo(r.resolvedAt!)}'}', style: body(11.5, color: C.muted)),
        if (r.pending) ...[
          const SizedBox(height: 10),
          if (admin) _AdminActions(r) else _Withdraw(r),
        ],
      ]),
    );
  }
}

class _Withdraw extends StatelessWidget {
  final RescheduleRequest r;
  const _Withdraw(this.r);

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: ActionButton(
          r.expired ? 'Close request' : 'Withdraw request',
          icon: Icons.undo_rounded,
          kind: 'text',
          onPressed: () async {
            await context.read<AppStore>().cancelReschedule(r.id);
            return r.expired ? 'Request closed' : 'Request withdrawn. Confirm the original slot in Schedule.';
          },
        ),
      );
}

class _AdminActions extends StatelessWidget {
  final RescheduleRequest r;
  const _AdminActions(this.r);

  Future<String?> _reject(BuildContext context, {String? preset}) async {
    final store = context.read<AppStore>();
    final note = preset ?? await askNote(context, title: 'Turn down this request?', hint: 'Let the family know why (optional)', action: 'Send');
    if (note == null) return null;
    await store.resolveReschedule(r, approve: false, note: note);
    return 'The family has been told';
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    if (r.expired) {
      return Align(
        alignment: Alignment.centerRight,
        child: ActionButton('Close request', icon: Icons.close_rounded, kind: 'outlined', onPressed: () => _reject(context, preset: 'The session had already started, so it stayed as planned.')),
      );
    }
    final target = r.targetSessionId == null ? null : store.sessionById(r.targetSessionId!);
    // A picked session whose therapist has since been marked inactive can't be approved as asked.
    final picked = r.picked && (store.therapist(r.targetTherapistId)?.active ?? false);
    return Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 8, children: [
      ActionButton('Not possible', icon: Icons.close_rounded, kind: 'outlined', onPressed: () => _reject(context)),
      if (picked) btn('Other time', icon: Icons.event_repeat_rounded, onPressed: () => showSheet(context, builder: (_) => _ApproveSheet(r))),
      if (picked)
        ActionButton(
          'Approve',
          icon: Icons.check_rounded,
          onPressed: () async {
            final ok = await confirm(
              context,
              title: 'Move ${store.child(r.childId)?.first ?? 'the child'}?',
              message: "${r.series ? 'This and every later session' : 'The session'} moves to ${preferredLabel(r)}"
                  "${target == null ? '' : ' (${target.name})'} with ${store.therapistName(r.targetTherapistId)}. The family won't need to confirm it again.",
              action: 'Approve',
              danger: false,
            );
            if (!ok) return null;
            final n = await store.resolveReschedule(r, approve: true, date: r.preferredDate, start: r.preferredStart, end: r.preferredEnd, therapistId: r.targetTherapistId);
            return n == 1 ? 'Moved. The family can see it now.' : '$n sessions moved. The family can see them now.';
          },
        )
      else
        btn('Arrange slot', icon: Icons.event_available_rounded, kind: 'filled', onPressed: () => showSheet(context, builder: (_) => _ApproveSheet(r))),
    ]);
  }
}

class _Move extends StatelessWidget {
  final String from, fromHint, to, toHint, toLabel;

  /// Only an approved move replaces the planned session; otherwise it still stands, so it isn't struck through.
  final bool moved;
  const _Move({required this.from, required this.fromHint, required this.to, required this.toHint, required this.toLabel, this.moved = false});

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(left: 24, bottom: 2),
        child: Text(t.toUpperCase(), style: body(10, weight: FontWeight.w800, color: C.muted).copyWith(letterSpacing: 0.8)),
      );

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: C.canvas, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _label('Planned'),
          Row(children: [
            const Icon(Icons.event_rounded, size: 16, color: C.muted),
            const SizedBox(width: 8),
            Expanded(child: Text(from, style: moved ? body(13.5, weight: FontWeight.w600, color: C.muted).copyWith(decoration: TextDecoration.lineThrough, decorationColor: C.muted) : body(13.5, weight: FontWeight.w600, color: C.ink))),
          ]),
          Padding(padding: const EdgeInsets.only(left: 24), child: Text(fromHint, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11.5, color: C.muted))),
          const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Icon(Icons.south_rounded, size: 16, color: C.brand600)),
          _label(toLabel),
          Row(children: [
            const Icon(Icons.event_available_rounded, size: 16, color: C.brand700),
            const SizedBox(width: 8),
            Expanded(child: Text(to, style: body(13.5, weight: FontWeight.w700, color: C.brand800))),
          ]),
          Padding(padding: const EdgeInsets.only(left: 24), child: Text(toHint, style: body(11.5, color: C.muted))),
        ]),
      );
}

/// Pick the new day, time and therapist (or tap an existing session to join it), see who would be busy, then
/// move the session(s). A time with no session there creates one for the child.
class _ApproveSheet extends StatefulWidget {
  final RescheduleRequest request;
  const _ApproveSheet(this.request);

  @override
  State<_ApproveSheet> createState() => _ApproveSheetState();
}

class _ApproveSheetState extends State<_ApproveSheet> {
  late final RescheduleRequest r = widget.request;
  late String date = r.preferredDate ?? r.fromDate;
  late String start = r.preferredStart ?? r.fromStart;
  late String end = r.preferredEnd ?? endTime(start, toMin(r.fromEnd) - toMin(r.fromStart));
  // An inactive therapist can't take sessions (the server refuses), so never start with one picked.
  late String? therapistId = [r.targetTherapistId, r.therapistId].where((id) => id != null && (context.read<AppStore>().therapist(id)?.active ?? false)).firstOrNull;
  final note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWeek();
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> _loadWeek() async {
    final store = context.read<AppStore>();
    await store.loadWeek(weekStart(date)).catchError((_) {});
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final valid = toMin(end) > toMin(start);
    final future = '$date $start'.compareTo('${todayISO()} ${nowHM()}') > 0;
    final busyTherapist = therapistId == null || !valid ? null : store.therapistClash(therapistId!, date, start, end, exceptSession: r.sessionId);
    final busyChild = !valid ? null : store.childClash(r.childId, date, start, end, exceptSession: r.sessionId);
    // The therapist's own session of this therapy at exactly this time is the one the child joins: not a clash.
    final joining = busyTherapist != null && busyTherapist.therapyId == r.therapyId && busyTherapist.start == start && busyTherapist.end == end;
    final therapist = store.therapist(therapistId);
    final problems = [
      if (therapistId == null) 'Choose a therapist.',
      if (!valid) 'The end time must be after the start time.',
      if (!future) 'Choose a time in the future.',
      if (busyTherapist != null && !joining) '${therapist?.first ?? 'The therapist'} is busy: "${busyTherapist.name}" ${fmtSpan(busyTherapist.start, busyTherapist.end)}.',
      if (busyChild != null) '${store.child(r.childId)?.first ?? 'The child'} is already in "${busyChild.name}" ${fmtSpan(busyChild.start, busyChild.end)}.',
    ];
    // That day's sessions of the same therapy the child could join.
    final sameTherapy = [
      for (final slot in store.slotsOn(date))
        for (final s in slot.sessions)
          if (s.therapyId == r.therapyId && s.id != r.sessionId && !s.childIds.contains(r.childId) && s.phase == 'upcoming' && (store.therapist(s.therapistId)?.active ?? false)) s,
    ];
    // The therapist the family asked for (or had) who has since been marked inactive.
    final inactive = store.therapist(r.targetTherapistId ?? r.therapistId);
    final therapists = [
      for (final t in store.activeTherapists)
        if (t.therapyIds.contains(r.therapyId) || t.id == therapistId) t,
    ];
    final asked = r.preferredStart == start && r.preferredEnd == end && (r.preferredDate == null || r.preferredDate == date) && (r.targetTherapistId == null || r.targetTherapistId == therapistId);
    final who = store.child(r.childId)?.first ?? 'the child';
    return SheetBody(
      title: 'Arrange a slot for $who',
      subtitle: r.series ? 'This and every later session at ${fmtTime(r.fromStart)}' : 'Just the session on ${fmtDate(r.fromDate, 'EEE, d MMM')}',
      footer: [
        btn('Cancel', onPressed: () => Navigator.pop(context)),
        ActionButton('Move', icon: Icons.check_rounded, onPressed: problems.isNotEmpty
            ? null
            : () async {
                final nav = Navigator.of(context);
                final n = await store.resolveReschedule(r, approve: true, date: date, start: start, end: end, therapistId: therapistId, note: note.text);
                nav.pop();
                return n == 1 ? 'Session moved. The family can see it now.' : '$n sessions moved. The family can see them now.';
              }),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Asked for: ${preferredLabel(r)}', style: body(13, weight: FontWeight.w600, color: C.brand700)),
        const SizedBox(height: 16),
        Field(
          r.series ? 'New day for the first session' : 'New day',
          hint: r.series ? 'Later sessions move by the same number of days.' : null,
          child: PickerField(
            text: fmtDate(date, 'EEEE, d MMM yyyy'),
            icon: Icons.calendar_today_rounded,
            onTap: () async {
              final d = await pickDate(context, initial: date, first: DateTime.now(), last: DateTime.now().add(const Duration(days: 120)));
              if (d != null) {
                setState(() => date = d);
                _loadWeek();
              }
            },
          ),
        ),
        if (sameTherapy.isNotEmpty) ...[
          const SizedBox(height: 14),
          Overline('${store.therapyName(r.therapyId)} sessions that day · tap to join'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in sameTherapy)
              ChoiceChip(
                selected: s.start == start && s.end == end && s.therapistId == therapistId,
                label: Text('${fmtSpan(s.start, s.end)} · ${store.therapist(s.therapistId)?.first ?? ''}'),
                onSelected: (_) => setState(() {
                  start = s.start;
                  end = s.end;
                  therapistId = s.therapistId;
                }),
              ),
          ]),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: Field(
              'Starts',
              child: TimeField(
                value: start,
                onChanged: (v) => setState(() {
                  final keep = toMin(end) - toMin(start);
                  start = v;
                  end = fromMin((toMin(v) + (keep > 0 ? keep : 45)).clamp(0, 23 * 60 + 59));
                }),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Field('Ends', child: TimeField(value: end, onChanged: (v) => setState(() => end = v)))),
        ]),
        const SizedBox(height: 14),
        const Overline('Therapist'),
        if (inactive != null && !inactive.active)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${inactive.first} is inactive, so choose another therapist.', style: body(12.5, weight: FontWeight.w600, color: C.amber)),
          ),
        if (therapists.isEmpty)
          Text('No active therapist delivers ${store.therapyName(r.therapyId)}.', style: body(12.5, color: C.red))
        else
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in therapists)
              ChoiceChip(
                selected: t.id == therapistId,
                avatar: Avatar(t.name, size: 22),
                label: Text(t.first),
                onSelected: (_) => setState(() => therapistId = t.id),
              ),
          ]),
        const SizedBox(height: 14),
        if (problems.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.greenBg, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.event_available_rounded, size: 18, color: C.green),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "${joining ? "Joins ${therapist?.first ?? 'the therapist'}'s \"${busyTherapist.name}\"" : "${therapist?.first ?? 'The therapist'} and $who are free then; a session is created"}."
                  "${asked ? ' This is what the family asked for, so it counts as confirmed.' : ' The family will be asked to confirm the new slot.'}",
                  style: body(12.5, weight: FontWeight.w600, color: C.green),
                ),
              ),
            ]),
          )
        else
          for (final p in problems) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(p, style: body(12.5, weight: FontWeight.w600, color: C.red))),
        const SizedBox(height: 14),
        Field('Note to the family', optional: true, child: TextField(controller: note, maxLength: 300, style: body(15), decoration: const InputDecoration(hintText: 'e.g. Moved to Room 2', counterText: ''))),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: () {
            Navigator.pop(context);
            context.push('/admin/timetable/${weekStart(date)}?view=day');
          },
          icon: const Icon(Icons.calendar_view_week_rounded, size: 18),
          label: const Text("See that week's timetable"),
        ),
      ]),
    );
  }
}
