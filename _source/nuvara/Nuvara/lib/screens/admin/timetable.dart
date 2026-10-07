import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../store.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/ui.dart';

/// Timetables: create a week's timetable, or open one that already exists.
class TimetablesTab extends StatelessWidget {
  const TimetablesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final thisWeek = weekStart(todayISO());
    final weeks = {thisWeek, addDays(thisWeek, 7), ...store.weekIndex.keys}.toList()..sort((a, b) => b.compareTo(a));
    final upcoming = weeks.where((w) => w.compareTo(thisWeek) >= 0).toList().reversed.toList();
    final past = weeks.where((w) => w.compareTo(thisWeek) < 0).toList();

    return PageList(
      onRefresh: store.refresh,
      children: [
        const TabHeader('Timetables', subtitle: 'Plan each week: time slots, then sessions'),
        _CreateCard(onTap: () => _create(context, store)),
        const SizedBox(height: 24),
        const SectionTitle('Current & upcoming'),
        for (final w in upcoming) _WeekTile(monday: w),
        if (past.isNotEmpty) ...[
          const SizedBox(height: 14),
          const SectionTitle('Past weeks'),
          for (final w in past) _WeekTile(monday: w),
        ],
      ],
    );
  }

  Future<void> _create(BuildContext context, AppStore store) async {
    final monday = await showWeekPicker(context, initial: weekStart(todayISO()));
    if (monday != null && context.mounted) context.push('/admin/timetable/$monday');
  }
}

class _CreateCard extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateCard({required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [C.brand800, C.brand600])),
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.edit_calendar_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Create timetable', style: display(21, color: Colors.white)),
                  const SizedBox(height: 3),
                  Text('Pick a week to plan its slots and sessions', style: body(13, color: C.brand100)),
                ]),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ]),
          ),
        ),
      );
}

class _WeekTile extends StatelessWidget {
  final String monday;
  const _WeekTile({required this.monday});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final info = store.weekIndex[monday];
    final thisWeek = weekStart(todayISO());
    final label = monday == thisWeek ? 'This week' : (monday == addDays(thisWeek, 7) ? 'Next week' : (monday == addDays(thisWeek, -7) ? 'Last week' : null));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => context.push('/admin/timetable/$monday'),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 52,
            height: 56,
            decoration: BoxDecoration(color: monday == thisWeek ? C.brand700 : C.brand50, borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.all(4),
            // Shrinks with very large text instead of overflowing the fixed tile.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(fmtDate(monday, 'MMM').toUpperCase(), style: body(10, weight: FontWeight.w800, color: monday == thisWeek ? C.brand200 : C.brand600).copyWith(letterSpacing: 0.8)),
                Text(fmtDate(monday, 'd'), style: display(21, color: monday == thisWeek ? Colors.white : C.brand900)),
              ]),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(weekLabel(monday), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15, weight: FontWeight.w700))),
                if (label != null) ...[const SizedBox(width: 8), StatusChip(label, tone: monday == thisWeek ? Tone.green : Tone.neutral, dot: false)],
              ]),
              const SizedBox(height: 4),
              Text(
                info == null ? 'Not planned yet' : '${plural(info.slots, 'time slot')} · ${plural(info.sessions, 'session')}',
                style: body(12.5, weight: FontWeight.w500, color: info == null ? C.clay600 : C.muted),
              ),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: C.muted),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Week picker: a month calendar where a whole week is the unit of selection.

Future<String?> showWeekPicker(BuildContext context, {required String initial}) => showSheet<String>(context, builder: (_) => _WeekPicker(initial: initial));

class _WeekPicker extends StatefulWidget {
  final String initial;
  const _WeekPicker({required this.initial});

  @override
  State<_WeekPicker> createState() => _WeekPickerState();
}

class _WeekPickerState extends State<_WeekPicker> {
  late String selected = weekStart(widget.initial);
  late DateTime month = DateTime(parseD(selected).year, parseD(selected).month);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final first = DateTime(month.year, month.month, 1);
    final gridStart = weekStart(iso(first));
    final last = DateTime(month.year, month.month + 1, 0);
    final weeks = <String>[for (var m = gridStart; m.compareTo(iso(last)) <= 0; m = addDays(m, 7)) m];
    final today = todayISO();

    return SheetBody(
      title: 'Select a week',
      subtitle: 'Tap any day to choose its whole week',
      footer: [
        btn('Cancel', onPressed: () => Navigator.pop(context)),
        btn('Open ${fmtDate(selected, 'd MMM')} week', icon: Icons.arrow_forward_rounded, kind: 'filled', onPressed: () => Navigator.pop(context, selected)),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left_rounded), tooltip: 'Previous month'),
          Expanded(child: Text(DateFormat('MMMM yyyy').format(month), textAlign: TextAlign.center, style: display(19))),
          IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right_rounded), tooltip: 'Next month'),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S']) Expanded(child: Center(child: Text(d, style: body(11.5, weight: FontWeight.w800, color: C.muted)))),
          const SizedBox(width: 22),
        ]),
        const SizedBox(height: 6),
        for (final w in weeks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Material(
              color: w == selected ? C.brand700 : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => selected = w),
                child: SizedBox(
                  height: 46,
                  child: Row(children: [
                    for (final d in weekDates(w))
                      Expanded(
                        child: Center(
                          child: Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: d == today ? Border.all(color: w == selected ? Colors.white : C.brand600, width: 1.5) : null),
                            child: Text(
                              '${parseD(d).day}',
                              style: body(14, weight: FontWeight.w600, color: w == selected ? Colors.white : (parseD(d).month == month.month ? C.ink : C.muted.withValues(alpha: 0.5))),
                            ),
                          ),
                        ),
                      ),
                    SizedBox(
                      width: 22,
                      child: store.weekIndex.containsKey(w)
                          ? Icon(Icons.event_available_rounded, size: 15, color: w == selected ? C.brand200 : C.brand600)
                          : null,
                    ),
                  ]),
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.event_available_rounded, size: 15, color: C.brand600),
          const SizedBox(width: 6),
          Expanded(child: Text('Week already has a timetable', style: body(12, color: C.muted))),
        ]),
      ]),
    );
  }
}
