import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../actions.dart';
import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/ui.dart';
import 'sessions.dart';

/// One week's timetable. Grid: days are rows, time slots are columns, each cell counts its sessions.
/// Day view: the slots of one day with their sessions listed.
class WeekScreen extends StatefulWidget {
  final String monday;
  final bool startInDayView;
  const WeekScreen({super.key, required this.monday, this.startInDayView = false});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  late String monday = weekStart(widget.monday);
  late bool grid = !widget.startInDayView;
  late String day;
  Object? loadError;

  @override
  void initState() {
    super.initState();
    final today = todayISO();
    day = weekDates(monday).contains(today) ? today : monday;
    _load();
  }

  Future<void> _load({bool force = false}) async {
    final store = context.read<AppStore>();
    setState(() => loadError = null);
    try {
      await Future.wait([store.loadWeek(monday, force: force), store.loadWeek(addDays(monday, -7))]);
    } catch (e) {
      loadError = e;
    }
    if (mounted) setState(() {});
  }

  void _shift(int weeks) {
    setState(() {
      monday = addDays(monday, 7 * weeks);
      day = weekDates(monday).contains(todayISO()) ? todayISO() : monday;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final slots = store.weekSlots(monday);
    final sessions = slots?.fold<int>(0, (a, s) => a + s.sessions.length) ?? 0;
    final kids = {for (final s in slots ?? const <Slot>[]) for (final x in s.sessions) ...x.childIds}.length;
    final thisWeek = monday == weekStart(todayISO());

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded), tooltip: 'Previous week'),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Text(thisWeek ? 'This week' : 'Week of ${fmtDate(monday, 'd MMM')}', style: body(15.5, weight: FontWeight.w700)),
              Text(weekLabel(monday), style: body(12, color: C.muted)),
            ]),
          ),
          IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right_rounded), tooltip: 'Next week'),
        ]),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) => v == 'copy' ? _copyPrevious(store) : _load(force: true),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'copy', child: _menuRow(Icons.copy_all_rounded, 'Copy previous week')),
              PopupMenuItem(value: 'refresh', child: _menuRow(Icons.refresh_rounded, 'Refresh')),
            ],
          ),
        ],
      ),
      floatingActionButton: slots == null || slots.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showSlotForm(context, monday: monday, date: grid ? null : day),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create slot'),
              backgroundColor: C.brand700,
              foregroundColor: Colors.white,
            ),
      body: slots == null
          ? Center(
              child: loadError == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: EmptyState(icon: Icons.wifi_off_rounded, title: 'Couldn\'t load this week', hint: cleanError(loadError!), action: btn('Try again', onPressed: _load)),
                    ),
            )
          : RefreshIndicator(
              color: C.brand700,
              onRefresh: () => _load(force: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: EdgeInsets.fromLTRB(16, 4, 16, 100 + MediaQuery.paddingOf(context).bottom),
                children: [
                  Constrained(
                    child: Row(children: [
                      Expanded(child: _Stat(value: '${slots.length}', label: 'Slots', icon: Icons.schedule_rounded)),
                      const SizedBox(width: 8),
                      Expanded(child: _Stat(value: '$sessions', label: 'Sessions', icon: Icons.groups_2_rounded)),
                      const SizedBox(width: 8),
                      Expanded(child: _Stat(value: '$kids', label: 'Children', icon: Icons.child_care_rounded)),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Constrained(
                    child: Segmented<bool>(
                      expand: true,
                      value: grid,
                      onChanged: (v) => setState(() => grid = v),
                      options: [seg(true, 'Grid view', Icons.grid_view_rounded), seg(false, 'Day view', Icons.view_agenda_outlined)],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (slots.isEmpty)
                    Constrained(child: _EmptyWeek(monday: monday, onCopy: () => _copyPrevious(store)))
                  else
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: grid
                          ? _Grid(key: const ValueKey('grid'), monday: monday, slots: slots, onOpenDay: (d) => setState(() {
                                day = d;
                                grid = false;
                              }))
                          : Constrained(key: const ValueKey('day'), child: _DayView(monday: monday, day: day, slots: slots, onDay: (d) => setState(() => day = d))),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _menuRow(IconData i, String t) => Row(children: [Icon(i, size: 20, color: C.muted), const SizedBox(width: 12), Text(t, style: body(14))]);

  Future<void> _copyPrevious(AppStore store) async {
    final from = addDays(monday, -7);
    try {
      await store.loadWeek(from);
    } catch (e) {
      if (mounted) toast(context, 'Couldn\'t load the previous week. ${cleanError(e)}', error: true);
      return;
    }
    if (!mounted) return;
    final prev = store.weekSlots(from) ?? const [];
    if ((store.weekSlots(monday) ?? const []).isNotEmpty) {
      toast(context, 'This week already has time slots. Copying only works into an empty week.', error: true);
      return;
    }
    if (prev.isEmpty) {
      toast(context, 'The previous week has no timetable to copy.', error: true);
      return;
    }
    final n = prev.fold<int>(0, (a, s) => a + s.sessions.length);
    final ok = await confirm(context,
        title: 'Copy previous week?',
        message: 'Copies ${plural(prev.length, 'time slot')} and ${plural(n, 'session')} from ${weekLabel(from)} into this week.',
        action: 'Copy week',
        danger: false);
    if (!ok || !mounted) return;
    try {
      final copied = await store.copyWeek(from, monday);
      // Sessions of inactive therapists, or with only inactive children, aren't carried over.
      if (mounted) toast(context, 'Copied ${plural(prev.length, 'slot')} and ${plural(copied, 'session')}${copied < n ? ' · ${n - copied} skipped (inactive therapist or children)' : ''}');
    } catch (e) {
      if (mounted) toast(context, cleanError(e), error: true);
    }
  }
}

class _Stat extends StatelessWidget {
  final String value, label;
  final IconData icon;
  const _Stat({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
        child: Row(children: [
          Icon(icon, size: 18, color: C.brand600),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: display(19).copyWith(fontFeatures: tnum)),
              Text(label, style: body(11, weight: FontWeight.w600, color: C.muted)),
            ]),
          ),
        ]),
      );
}

class _EmptyWeek extends StatelessWidget {
  final String monday;
  final VoidCallback onCopy;
  const _EmptyWeek({required this.monday, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final prev = context.watch<AppStore>().weekSlots(addDays(monday, -7)) ?? const [];
    return EmptyState(
      icon: Icons.calendar_view_week_rounded,
      title: 'Start this week\'s timetable',
      hint: 'Create time slots first, then add sessions with a therapist and children inside each slot.',
      action: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
        btn('Create time slot', icon: Icons.add_rounded, kind: 'filled', onPressed: () => showSlotForm(context, monday: monday)),
        if (prev.isNotEmpty) btn('Copy previous week', icon: Icons.copy_all_rounded, onPressed: onCopy),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid

class _Grid extends StatelessWidget {
  final String monday;
  final List<Slot> slots;
  final ValueChanged<String> onOpenDay;
  const _Grid({super.key, required this.monday, required this.slots, required this.onOpenDay});

  static const dayW = 70.0, colW = 112.0, _maxText = 1.15;

  @override
  Widget build(BuildContext context) {
    final week = weekDates(monday);
    // Every day, Sunday included: intervention centres run sessions all week.
    final days = week;
    final cols = <String, Slot>{for (final s in slots) s.key: s}.values.toList()
      ..sort((a, b) {
        final c = a.start.compareTo(b.start);
        return c != 0 ? c : a.end.compareTo(b.end);
      });
    final byCell = {for (final s in slots) '${s.date}|${s.key}': s};
    final maxCount = slots.fold<int>(1, (a, s) => s.sessions.length > a ? s.sessions.length : a);
    final today = todayISO();
    // The grid is dense: large text is capped at 1.15x here, and rows grow with it so nothing overflows.
    final k = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, _maxText);
    final headH = 78.0 * k, rowH = 96.0 * k;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxText,
      child: Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: C.line), boxShadow: softShadow),
      clipBehavior: Clip.antiAlias,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Sticky day column.
        Container(
          width: dayW,
          decoration: const BoxDecoration(color: C.canvas, border: Border(right: BorderSide(color: C.line))),
          child: Column(children: [
            SizedBox(height: headH, child: Center(child: Text('DAY', style: body(10, weight: FontWeight.w800, color: C.muted).copyWith(letterSpacing: 1.2)))),
            for (final d in days)
              InkWell(
                onTap: () => onOpenDay(d),
                child: Container(
                  height: rowH,
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.line))),
                  alignment: Alignment.center,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(fmtDate(d, 'EEE').toUpperCase(), style: body(10.5, weight: FontWeight.w800, color: d == today ? C.brand700 : C.muted).copyWith(letterSpacing: 0.8)),
                    const SizedBox(height: 4),
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: d == today ? C.brand700 : Colors.transparent, shape: BoxShape.circle),
                      child: Text(fmtDate(d, 'd'), style: display(17, color: d == today ? Colors.white : C.ink)),
                    ),
                  ]),
                ),
              ),
          ]),
        ),
        // Time columns are built as they scroll into view: a busy week has dozens of slots, and a phone shows two or
        // three columns at a time.
        Expanded(
          child: SizedBox(
            height: headH + rowH * days.length,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemExtent: colW,
              itemCount: cols.length,
              itemBuilder: (context, i) {
                final c = cols[i];
                return Material(
                  type: MaterialType.transparency,
                  child: Column(children: [
                    _header(c, headH),
                    for (final d in days)
                      Container(
                        height: rowH,
                        decoration: BoxDecoration(color: d == today ? C.brand50.withValues(alpha: 0.5) : null, border: const Border(top: BorderSide(color: C.line))),
                        child: _Cell(
                          slot: byCell['$d|${c.key}'],
                          maxCount: maxCount,
                          onEmptyTap: () => showSlotForm(context, monday: monday, date: d, start: c.start, end: c.end),
                          label: '${fmtDate(d, 'EEE')} ${fmtTime(c.start)}',
                        ),
                      ),
                  ]),
                );
              },
            ),
          ),
        ),
      ]),
      ),
    );
  }

  Widget _header(Slot c, double headH) => Container(
        width: colW,
        height: headH,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: const BoxDecoration(color: C.canvas, border: Border(left: BorderSide(color: C.line, width: 0.5))),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(fmtTimeShort(c.start), style: body(14, weight: FontWeight.w800).copyWith(fontFeatures: tnum)),
          Text('to ${fmtTime(c.end)}', style: body(10.5, weight: FontWeight.w600, color: C.muted).copyWith(fontFeatures: tnum)),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(color: C.sand, borderRadius: BorderRadius.circular(99)),
            child: Text('${c.minutes}m', style: body(9.5, weight: FontWeight.w800, color: C.muted)),
          ),
        ]),
      );
}

class _Cell extends StatelessWidget {
  final Slot? slot;
  final int maxCount;
  final VoidCallback onEmptyTap;

  /// Day and start time for screen readers, e.g. "Mon 9:30 AM".
  final String label;
  const _Cell({required this.slot, required this.maxCount, required this.onEmptyTap, required this.label});

  static const _radius = BorderRadius.all(Radius.circular(14));
  static const _emptyLook = BoxDecoration(borderRadius: _radius, border: Border.fromBorderSide(BorderSide(color: Color(0xB3E5E7F1))));
  static const _emptyIcon = Color(0x7362667F);

  @override
  Widget build(BuildContext context) {
    final s = slot;
    if (s == null) {
      // Kept light (the row provides the Material): a week at centre scale has hundreds of empty cells.
      return Padding(
        padding: const EdgeInsets.all(6),
        child: Semantics(
          button: true,
          label: 'Add time slot, $label',
          child: InkWell(
            onTap: onEmptyTap,
            borderRadius: _radius,
            child: const DecoratedBox(decoration: _emptyLook, child: Center(child: Icon(Icons.add_rounded, size: 18, color: _emptyIcon))),
          ),
        ),
      );
    }
    final n = s.sessions.length;
    final store = context.read<AppStore>();
    final phase = slotPhase(s);
    // Busier slots are a deeper green so the week's shape reads at a glance.
    final t = n == 0 ? 0.0 : 0.25 + 0.75 * (n / maxCount);
    final bg = Color.lerp(C.brand50, C.brand700, t * 0.85)!;
    final dark = t > 0.55;
    final fg = n == 0 ? C.muted : (dark ? Colors.white : C.brand900);
    final roll = rollOf(s.sessions, store);
    final showRoll = roll.total > 0 && slotStarted(s);
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Semantics(
        button: true,
        excludeSemantics: true,
        label: '$label, ${plural(n, 'session')}${roll.away > 0 ? ', ${roll.away} away' : ''}${showRoll ? ', ${roll.marked} of ${roll.total} marked' : ''}',
        child: Material(
        color: n == 0 ? Colors.white : bg,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showSlotSheet(context, s.id),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: phase == 'now' ? C.clay500 : (n == 0 ? C.brand200 : Colors.transparent), width: phase == 'now' ? 2 : 1),
            ),
            padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text('$n', style: display(24, color: fg, height: 1).copyWith(fontFeatures: tnum))),
                // Absence notices nobody has acted on yet.
                if (roll.away > 0)
                  Tooltip(
                    message: '${plural(roll.away, 'child', 'children')} away',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: C.amber, borderRadius: BorderRadius.circular(99)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.event_busy_rounded, size: 11, color: Colors.white),
                        const SizedBox(width: 2),
                        Text('${roll.away}', style: body(10, weight: FontWeight.w800, color: Colors.white, height: 1.1)),
                      ]),
                    ),
                  ),
              ]),
              Text(n == 1 ? 'session' : 'sessions', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(10, weight: FontWeight.w700, color: fg.withValues(alpha: 0.8))),
              const Spacer(),
              if (n == 0)
                Text('+ Add', style: body(11, weight: FontWeight.w700, color: C.brand600))
              else
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  // Shrinks rather than overflowing when a busy slot has several therapists in a narrow cell.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: AvatarStack([for (final x in s.sessions) store.therapistName(x.therapistId)], size: 22, max: 3),
                    ),
                  ),
                  const SizedBox(width: 2),
                  if (showRoll)
                    roll.marked == roll.total
                        ? Tooltip(message: 'Attendance marked', child: Icon(Icons.check_circle_rounded, size: 15, color: dark ? Colors.white : C.green))
                        : Flexible(
                            child: Tooltip(
                              message: '${roll.marked} of ${roll.total} marked',
                              child: Text('${roll.marked}/${roll.total}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(10, weight: FontWeight.w800, color: fg.withValues(alpha: 0.85)).copyWith(fontFeatures: tnum)),
                            ),
                          ),
                ]),
            ]),
          ),
        ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day view

class _DayView extends StatelessWidget {
  final String monday, day;
  final List<Slot> slots;
  final ValueChanged<String> onDay;
  const _DayView({required this.monday, required this.day, required this.slots, required this.onDay});

  @override
  Widget build(BuildContext context) {
    final week = weekDates(monday);
    final today = todayISO();
    final mine = slots.where((s) => s.date == day).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // All seven days share the width, so Saturday and Sunday stay on screen even on a 320px phone.
      SizedBox(
        height: 78,
        child: Row(children: [
          for (var i = 0; i < week.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(child: _dayChip(week[i], slots.any((s) => s.date == week[i]), week[i] == day, week[i] == today)),
          ],
        ]),
      ),
      const SizedBox(height: 18),
      SectionTitle(fmtDate(day, 'EEEE, d MMMM'), hint: mine.isEmpty ? 'Nothing planned' : '${plural(mine.length, 'time slot')} · ${plural(mine.fold<int>(0, (a, s) => a + s.sessions.length), 'session')}'),
      if (mine.isEmpty)
        EmptyState(
          icon: Icons.event_note_rounded,
          title: 'No time slots on ${fmtDate(day, 'EEEE')}',
          action: btn('Create time slot', icon: Icons.add_rounded, kind: 'filled', onPressed: () => showSlotForm(context, monday: monday, date: day)),
        )
      else
        for (final s in mine)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SlotCard(
              s,
              expanded: true,
              onTap: () => showSlotSheet(context, s.id),
              onAddSession: () => showSessionForm(context, date: s.date, start: s.start, end: s.end),
            ),
          ),
    ]);
  }

  Widget _dayChip(String d, bool planned, bool on, bool today) => Semantics(
        button: true,
        selected: on,
        label: fmtDate(d, 'EEEE d MMMM'),
        excludeSemantics: true,
        child: GestureDetector(
        onTap: () => onDay(d),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: on ? C.brand800 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: on ? C.brand800 : (today ? C.brand300 : C.line)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            FittedBox(fit: BoxFit.scaleDown, child: Text(fmtDate(d, 'EEE'), style: body(11, weight: FontWeight.w700, color: on ? C.brand200 : C.muted))),
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, child: Text(fmtDate(d, 'd'), style: display(20, color: on ? Colors.white : C.ink))),
            const SizedBox(height: 4),
            Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: !planned ? Colors.transparent : (on ? C.clay500 : C.brand400))),
          ]),
        ),
        ),
      );
}
