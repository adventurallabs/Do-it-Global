import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../assessment/history.dart';
import '../../assessment/progress_chart.dart';
import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/account.dart';
import '../../widgets/progress.dart';
import '../../widgets/ui.dart';
import 'parts.dart';

// One child, from the therapist's side: who to call, how they're progressing, what was noted, what's next.

class TherapistChildDetail extends StatefulWidget {
  final String id;
  const TherapistChildDetail(this.id, {super.key});

  @override
  State<TherapistChildDetail> createState() => _TherapistChildDetailState();
}

class _TherapistChildDetailState extends State<TherapistChildDetail> {
  bool loadingOlder = false;

  /// Mondays from 12 weeks back to next week; notes and upcoming sessions come from whichever are loaded.
  List<String> get _mondays {
    final m = weekStart(todayISO());
    return [for (var i = -12; i <= 1; i++) addDays(m, 7 * i)];
  }

  Future<void> _loadOlder(AppStore store) async {
    final m = weekStart(todayISO());
    String? target;
    for (var i = 1; i <= 12; i++) {
      final w = addDays(m, -7 * i);
      if (store.weekSlots(w) == null) {
        target = w;
        break;
      }
    }
    if (target == null) return;
    setState(() => loadingOlder = true);
    try {
      await store.loadWeek(target);
      store.touch();
    } catch (e) {
      if (mounted) toast(context, cleanError(e), error: true);
    }
    if (mounted) setState(() => loadingOlder = false);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final c = store.child(widget.id);
    if (c == null) {
      return Scaffold(appBar: AppBar(), body: const PageList(children: [EmptyState(icon: Icons.person_off_outlined, title: 'Child not found', hint: 'They may no longer be in your sessions.')]));
    }
    final all = [
      for (final m in _mondays)
        if (store.weekSlots(m) != null) ...store.sessionsInWeek(m).where((s) => s.childIds.contains(c.id)),
    ];
    final today = todayISO();
    final notes = all.where((s) => s.date.compareTo(today) <= 0 && (s.seat(c.id)?.note.trim().isNotEmpty ?? false)).toList()
      ..sort((a, b) => '${b.date}${b.start}'.compareTo('${a.date}${a.start}'));
    final now = '$today ${nowHM()}';
    final upcoming = all.where((s) => s.therapistId == store.therapistId && '${s.date} ${s.end}'.compareTo(now) > 0).toList()
      ..sort((a, b) => '${a.date}${a.start}'.compareTo('${b.date}${b.start}'));
    final olderLeft = [for (var i = 1; i <= 12; i++) addDays(weekStart(today), -7 * i)].any((w) => store.weekSlots(w) == null);

    return Scaffold(
      appBar: AppBar(title: Text(c.code)),
      body: PageList(
        onRefresh: () => Future.wait([store.refresh(), store.loadProgress(c.id, force: true)]).then((_) => store.touch()),
        children: [
          _Header(c),
          const SizedBox(height: 14),
          _Family(c),
          const SizedBox(height: 26),
          AssessmentHistory(child: c, base: '/therapist/children/${c.id}'),
          const SizedBox(height: 22),
          AssessmentProgressCard(child: c),
          const SizedBox(height: 26),
          if (upcoming.isNotEmpty) ...[
            SectionTitle('Next with me', hint: plural(upcoming.length, 'session')),
            for (var i = 0; i < upcoming.length && i < 4; i++) GroupedRow(index: i, count: upcoming.length.clamp(0, 4), indent: 70, child: _SessionRow(upcoming[i], childId: c.id)),
            const SizedBox(height: 26),
          ],
          const SectionTitle('Progress', hint: 'Session ratings from every therapist'),
          ProgressPanel(c),
          const SizedBox(height: 14),
          SectionTitle('Recent notes', hint: notes.isEmpty ? null : 'What parents have been told'),
          if (notes.isEmpty)
            const EmptyState(icon: Icons.sticky_note_2_outlined, title: 'No notes yet', hint: 'Notes you write in a session appear here.')
          else
            for (final s in notes.take(8)) Padding(padding: const EdgeInsets.only(bottom: 10), child: _NoteCard(s, childId: c.id)),
          if (olderLeft)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Center(
                child: TextButton.icon(
                  onPressed: loadingOlder ? null : () => _loadOlder(store),
                  icon: loadingOlder ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.history_rounded, size: 18),
                  label: const Text('Look further back'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Child child;
  const _Header(this.child);

  @override
  Widget build(BuildContext context) {
    final c = child;
    final base = avatarColor(c.name);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [base, Color.lerp(base, Colors.black, 0.3)!]),
        boxShadow: [BoxShadow(color: base.withValues(alpha: 0.3), blurRadius: 24, spreadRadius: -8, offset: const Offset(0, 12))],
      ),
      child: Row(children: [
        Container(
          width: 62,
          height: 62,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5)),
          child: Text(initials(c.name), style: display(23, color: Colors.white)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: display(23, color: Colors.white)),
            const SizedBox(height: 6),
            Row(children: [
              IdBadge(c.code, light: true),
              const SizedBox(width: 8),
              Flexible(child: Text(ageLong(c.dob), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9)))),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Family extends StatelessWidget {
  final Child child;
  const _Family(this.child);

  @override
  Widget build(BuildContext context) {
    final c = child;
    final numbers = [if (c.phone.trim().isNotEmpty) ('Main number', c.phone), if (c.altPhone.trim().isNotEmpty) ('Other number', c.altPhone)];
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Overline('Parents'),
        Row(children: [
          Expanded(child: KV('Father', c.fatherName, icon: Icons.person_outline_rounded)),
          const SizedBox(width: 10),
          Expanded(child: KV('Mother', c.motherName, icon: Icons.person_outline_rounded)),
        ]),
        const SizedBox(height: 14),
        if (numbers.isEmpty)
          Text('No contact number on file.', style: body(13, color: C.muted))
        else
          for (final (label, number) in numbers)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Material(
                color: C.greenBg,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => callNumber(context, number),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                    child: Row(children: [
                      Container(width: 36, height: 36, decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle), child: const Icon(Icons.call_rounded, size: 18, color: Colors.white)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11.5, weight: FontWeight.w600, color: C.green)),
                          Text(number, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15, weight: FontWeight.w700).copyWith(fontFeatures: tnum)),
                        ]),
                      ),
                      Text('Call', style: body(13, weight: FontWeight.w800, color: C.green)),
                    ]),
                  ),
                ),
              ),
            ),
      ]),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final Session session;
  final String childId;
  const _SessionRow(this.session, {required this.childId});

  @override
  Widget build(BuildContext context) {
    final s = session;
    final seat = s.seat(childId);
    return InkWell(
      onTap: () => openSession(context, s),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(color: s.date == todayISO() ? C.brand800 : C.brand50, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text(fmtDate(s.date, 'EEE'), maxLines: 1, style: body(10.5, weight: FontWeight.w700, color: s.date == todayISO() ? C.brand200 : C.brand600)),
              Text(fmtDate(s.date, 'd'), maxLines: 1, style: display(17, color: s.date == todayISO() ? Colors.white : C.brand900).copyWith(fontFeatures: tnum)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14.5, weight: FontWeight.w700)),
              Text('${relDay(s.date)} · ${fmtSpan(s.start, s.end)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, color: C.muted)),
              if (seat?.noticed ?? false) ...[const SizedBox(height: 6), AbsenceNotice(seat!.absenceReason!)],
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: C.muted, size: 20),
        ]),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Session session;
  final String childId;
  const _NoteCard(this.session, {required this.childId});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final s = session;
    final seat = s.seat(childId)!;
    final mine = s.therapistId == store.therapistId;
    final att = switch (seat.attendance) { 'present' => ('Present', Tone.green), 'late' => ('Late', Tone.amber), 'absent' => ('Absent', Tone.red), _ => (null, Tone.neutral) };
    return AppCard(
      onTap: mine ? () => openSession(context, s) : null,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(
              '${relDay(s.date)} · ${s.name}${mine ? '' : ' · ${store.therapistName(s.therapistId)}'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: body(12.5, weight: FontWeight.w700, color: C.muted),
            ),
          ),
          if (att.$1 != null) ...[const SizedBox(width: 8), StatusChip(att.$1!, tone: att.$2)],
        ]),
        const SizedBox(height: 8),
        Text(seat.note.trim(), style: body(14, height: 1.45)),
      ]),
    );
  }
}
