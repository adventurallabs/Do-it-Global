import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../actions.dart';
import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/charts.dart' show RatingPill;
import '../../widgets/ui.dart';
import 'parts.dart';

// The full record of one session: attendance, then for each child who came a 0–10 rating of how the
// session went and a description for the parents. Together these make the child's progress.

enum _Save { saved, dirty, saving, failed }

class TherapistSessionScreen extends StatefulWidget {
  final String id;
  const TherapistSessionScreen(this.id, {super.key});

  @override
  State<TherapistSessionScreen> createState() => _TherapistSessionScreenState();
}

class _TherapistSessionScreenState extends State<TherapistSessionScreen> {
  late final AppStore store;
  final _notes = <String, TextEditingController>{};
  final _focus = <String, FocusNode>{};
  final _timers = <String, Timer>{};
  final _saved = <String, String>{};
  final _state = <String, _Save>{};
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    store = context.read<AppStore>();
    // Attendance opens 15 minutes before the start and locks at the end by the clock, not by a reload.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  TextEditingController _note(Seat seat) => _notes.putIfAbsent(seat.childId, () {
    _saved[seat.childId] = seat.note;
    return TextEditingController(text: seat.note);
  });

  FocusNode _node(String childId) => _focus.putIfAbsent(childId, () {
    final f = FocusNode();
    f.addListener(() {
      if (!f.hasFocus && _state[childId] == _Save.dirty) _saveNote(childId);
    });
    return f;
  });

  void _changed(String childId) {
    final dirty = _notes[childId]!.text.trim() != (_saved[childId] ?? '').trim();
    setState(() => _state[childId] = dirty ? _Save.dirty : _Save.saved);
    _timers[childId]?.cancel();
    if (dirty) _timers[childId] = Timer(const Duration(milliseconds: 1400), () => _saveNote(childId));
  }

  Future<void> _saveNote(String childId) async {
    _timers.remove(childId)?.cancel();
    final s = store.sessionById(widget.id);
    final c = _notes[childId];
    if (s == null || c == null) return;
    final text = c.text.trim();
    if (text == (_saved[childId] ?? '').trim()) {
      if (mounted) setState(() => _state[childId] = _Save.saved);
      return;
    }
    if (mounted) setState(() => _state[childId] = _Save.saving);
    try {
      await store.saveNote(s, childId, text);
      _saved[childId] = text;
      if (mounted) setState(() => _state[childId] = c.text.trim() == text ? _Save.saved : _Save.dirty);
    } catch (e) {
      if (!mounted) return;
      setState(() => _state[childId] = _Save.failed);
      toast(context, cleanError(e), error: true);
    }
  }

  Future<void> _rate(Session s, String childId, int? v) async {
    final before = s.seat(childId)?.rating;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await store.rateSession(s, childId, v);
    } catch (e) {
      if (mounted) toast(context, cleanError(e), error: true);
      return;
    }
    if (v == null && before != null) {
      // Re-tapping the chosen number clears it; easy to do by accident, so offer the way back (once it's saved).
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Rating $before/10 removed'), action: SnackBarAction(label: 'Undo', onPressed: () => _rate(store.sessionById(s.id) ?? s, childId, before))));
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    // Anything typed but not yet saved is saved on the way out.
    for (final id in _timers.keys.toList()) {
      _saveNote(id).catchError((_) {});
    }
    for (final t in _timers.values) {
      t.cancel();
    }
    for (final c in _notes.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final s = store.sessionById(widget.id);
    if (s == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const PageList(
          children: [EmptyState(icon: Icons.event_busy_outlined, title: 'Session not found', hint: 'It may have been moved or removed. Pull down on Today or Week to refresh.')],
        ),
      );
    }
    final kids = [...s.childIds]..sort((a, b) => (store.child(a)?.no ?? 0).compareTo(store.child(b)?.no ?? 0));
    final future = !canMark(s);
    final saving = _state.values.any((x) => x == _Save.saving);
    final pending = _state.values.any((x) => x == _Save.dirty || x == _Save.failed);
    return PopScope(
      canPop: !_unsaved,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(relDay(s.date)),
          actions: [
            if (saving || pending)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          for (final e in _state.entries.toList()) {
                            if (e.value != _Save.saved) _saveNote(e.key);
                          }
                        },
                  child: Text(saving ? 'Saving…' : 'Save notes'),
                ),
              ),
          ],
        ),
        body: GestureDetector(
          // Tapping outside a field closes the keyboard; not a control, so hidden from screen readers.
          excludeFromSemantics: true,
          onTap: () => FocusScope.of(context).unfocus(),
          child: PageList(
            onRefresh: () => store.loadWeek(weekStart(s.date), force: true).then((_) => store.touch()),
            itemCount: kids.length,
            itemBuilder: (context, i) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _childCard(s, kids[i])),
            children: [
              _Hero(s),
              const SizedBox(height: 16),
              if (future) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: C.blueBg, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lock_clock_rounded, size: 18, color: C.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Attendance opens at ${attendanceOpensLabel(s)}. Rate each child once the session has started.',
                          style: body(13, weight: FontWeight.w600, color: C.blue, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (s.phase == 'done' && unmarked(s).isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: C.amberBg, borderRadius: BorderRadius.circular(16)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.edit_note_rounded, size: 18, color: C.amber),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This session isn\'t completed until every child is marked. Marks given now are final.',
                        style: body(13, weight: FontWeight.w600, color: C.amber, height: 1.35),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
              ],
              SectionTitle('Children', hint: kids.isEmpty ? null : 'Ratings and descriptions are shared with parents'),
              if (s.phase == 'done' && s.markedCount > 0) const Padding(padding: EdgeInsets.fromLTRB(4, 0, 4, 10), child: LockedNote()),
              if (kids.isEmpty) const EmptyState(icon: Icons.child_care_rounded, title: 'No children in this session'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _childCard(Session s, String childId) {
    final seat = s.seat(childId);
    final t = store.therapy(s.therapyId);
    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SeatRow(s, childId, showAge: true),
          if (seat != null) ...[
            const SizedBox(height: 16),
            _ratingBlock(s, seat, t),
            const SizedBox(height: 14),
            _noteField(s, seat),
          ],
        ],
      ),
    );
  }

  /// The session report's rating: 0–10 for how the session went. For a child who came, from the start on;
  /// until it is given the session shows "Report pending".
  Widget _ratingBlock(Session s, Seat seat, Therapy? t) {
    final value = seat.rating;
    final String? why = s.phase == 'upcoming'
        ? 'You can rate once the session starts.'
        : seat.attendance == 'absent'
            ? 'Absent, so there is nothing to rate.'
            : !seat.attended
                ? 'Mark ${store.child(seat.childId)?.first ?? 'the child'} present or late to rate the session.'
                : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Icon(Icons.insights_rounded, size: 16, color: C.muted),
        const SizedBox(width: 6),
        Expanded(child: Text('${t?.name ?? 'Session'} rating', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13, weight: FontWeight.w700))),
        if (value != null) RatingPill(value) else if (seat.reportPending && s.phase != 'upcoming') const StatusChip('Report pending', tone: Tone.amber),
      ]),
      const SizedBox(height: 8),
      if (why != null)
        Text(why, style: body(12.5, color: C.muted))
      else ...[
        // One row of 11 equal cells at any width (fits 320px), each a full-height tap target.
        Row(children: [
          for (var i = 0; i <= 10; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: Semantics(
                button: true,
                selected: value == i,
                label: 'Rate $i out of 10',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _rate(s, seat.childId, value == i ? null : i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: value == i ? RatingPill.colorOf(i) : (value != null && i < value ? RatingPill.colorOf(value).withValues(alpha: 0.12) : C.canvas),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: value == i ? RatingPill.colorOf(i) : C.line),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('$i', maxLines: 1, style: body(13, weight: FontWeight.w800, color: value == i ? Colors.white : C.ink).copyWith(fontFeatures: tnum)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Text('Needs a lot of help', style: body(10.5, color: C.muted)),
          const Spacer(),
          Text('Did brilliantly', style: body(10.5, color: C.muted)),
        ]),
      ],
    ]);
  }

  bool get _unsaved => _state.values.any((x) => x != _Save.saved);

  /// Saves every unsaved or failed note; true when all of them made it.
  Future<bool> _flushAll() async {
    await Future.wait([
      for (final e in _state.entries.toList())
        if (e.value != _Save.saved) _saveNote(e.key),
    ]);
    return !_unsaved;
  }

  Future<void> _leave() async {
    final nav = Navigator.of(context);
    if (await _flushAll()) {
      if (mounted) nav.pop();
      return;
    }
    if (!mounted) return;
    final ok = await confirm(context, title: 'Leave without saving notes?', message: 'Some notes could not be saved. If you leave now, those changes will be lost.', action: 'Leave');
    if (ok && mounted) {
      // Nothing left to flush on the way out.
      _state.clear();
      for (final t in _timers.values) {
        t.cancel();
      }
      _timers.clear();
      nav.pop();
    }
  }

  Widget _noteField(Session s, Seat seat) {
    final id = seat.childId;
    final st = _state[id] ?? _Save.saved;
    final controller = _note(seat);
    final (label, color, icon) = switch (st) {
      _Save.saving => ('Saving…', C.muted, Icons.cloud_upload_outlined),
      _Save.dirty => ('Editing', C.muted, Icons.edit_outlined),
      _Save.failed => ('Not saved', C.red, Icons.error_outline_rounded),
      _Save.saved => (controller.text.trim().isEmpty ? '' : 'Saved', C.green, Icons.check_circle_rounded),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.forum_outlined, size: 16, color: C.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Description for parents',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: body(13, weight: FontWeight.w700),
              ),
            ),
            if (label.isNotEmpty)
              Flexible(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Row(
                    key: ValueKey(st),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: color),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: body(11.5, weight: FontWeight.w700, color: color),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (st == _Save.failed) TextButton(onPressed: () => _saveNote(id), child: const Text('Retry')),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: _node(id),
          // Like the rating, the description is for a session that has started.
          enabled: s.ratingOpen,
          onChanged: (_) => _changed(id),
          minLines: 2,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          style: body(14.5, height: 1.4),
          decoration: InputDecoration(hintText: s.ratingOpen ? 'How did the session go? Parents read this with the rating.' : 'You can write this once the session starts'),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  final Session session;
  const _Hero(this.session);

  @override
  Widget build(BuildContext context) {
    final s = session;
    int count(String a) => s.seats.values.where((x) => x.attendance == a).length;
    final left = unmarked(s);
    return HeroSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  fmtDate(s.date, 'EEEE, d MMMM'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: body(13, weight: FontWeight.w600, color: C.brand200),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(child: StatusPill(sessionStatus(s, next: s.phase == 'upcoming' && s.date == todayISO()), light: true)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: display(26, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            '${fmtSpan(s.start, s.end)} · ${minutesLabel(s.slot.minutes)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: body(13.5, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.85)).copyWith(fontFeatures: tnum),
          ),
          const SizedBox(height: 18),
          Row(children: [HeroStat('${count('present')}', 'Present'), heroDivider(), HeroStat('${count('late')}', 'Late'), heroDivider(), HeroStat('${count('absent')}', 'Absent'), heroDivider(), HeroStat('${left.length}', 'To mark')]),
          if (canMark(s) && left.isNotEmpty) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => markAllPresent(context, s),
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: C.brand800),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.done_all_rounded, size: 18),
                    const SizedBox(width: 8),
                    Flexible(child: Text(left.length == s.childIds.length ? 'Mark all present' : 'Mark the rest present', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ),
            if (left.any((id) => s.seat(id)?.noticed ?? false))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(noticeAbsentHint, style: body(11.5, color: C.brand200)),
              ),
          ],
        ],
      ),
    );
  }
}
