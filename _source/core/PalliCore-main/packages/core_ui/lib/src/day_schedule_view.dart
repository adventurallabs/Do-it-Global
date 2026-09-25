import 'dart:async';

import 'package:flutter/material.dart';
import 'package:core_models/core_models.dart';
import 'admin_look.dart';
import 'app_colors.dart';

/// Phone-first, read-only timetable: a strip of this week's days (with
/// dates) and one swipeable, vertical list per day. Today's current period is
/// highlighted with a progress bar and the next one is labelled.
///
/// Replaces the 7-column grid for anyone who only needs to *read* a schedule
/// — that grid needs scrolling both ways on a phone.
class DayScheduleView extends StatefulWidget {
  final List<Period> periods;

  /// staffId -> teacher name, used for the default subtitle.
  final Map<String, String> staffNames;

  /// Override the line under the subject (e.g. the class name on a
  /// teacher's own week).
  final String Function(Period period)? subtitleOf;

  final String emptyTitle;
  final String emptySubtitle;

  /// What runs on a given day/date. Defaults to [Schedule.periodsOn] over
  /// [periods]; a teacher's own week (several class timetables merged)
  /// resolves each timetable separately so one class's cover period can't
  /// hide another class's period in the same slot.
  final List<Period> Function(String day, DateTime date)? resolver;

  const DayScheduleView({
    super.key,
    required this.periods,
    this.staffNames = const {},
    this.subtitleOf,
    this.resolver,
    this.emptyTitle = 'No timetable yet',
    this.emptySubtitle = 'The schedule will show here once the school publishes it.',
  });

  @override
  State<DayScheduleView> createState() => _DayScheduleViewState();
}

class _DayScheduleViewState extends State<DayScheduleView> {
  static const _short = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  late List<String> _days;
  late PageController _pages;
  int _index = 0;
  Timer? _tick;

  DateTime get _monday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
  }

  DateTime _dateOf(String day) => _monday.add(Duration(days: Schedule.weekdays.indexOf(day)));

  @override
  void initState() {
    super.initState();
    _setupDays();
    _pages = PageController(initialPage: _index);
    // keep "Now / Next" honest while the screen stays open
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant DayScheduleView old) {
    super.didUpdateWidget(old);
    if (old.periods != widget.periods) {
      final current = _days.isEmpty ? null : _days[_index];
      _days = _computeDays();
      final i = current == null ? -1 : _days.indexOf(current);
      _index = i < 0 ? 0 : i;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients && _pages.page?.round() != _index) {
          _pages.jumpToPage(_index);
        }
      });
    }
  }

  List<String> _computeDays() {
    final active = Schedule.activeDays(widget.periods);
    // Always offer Mon–Fri once anything is scheduled, so a missing day reads
    // as "no classes" instead of silently disappearing.
    final base = active.isEmpty ? <String>[] : Schedule.weekdays.take(5).toList();
    return Schedule.weekdays.where((d) => base.contains(d) || active.contains(d)).toList();
  }

  void _setupDays() {
    _days = _computeDays();
    final today = Schedule.dayName(DateTime.now());
    final i = _days.indexOf(today);
    if (i >= 0) {
      _index = i;
    } else {
      // weekend: jump to the next school day (wraps to Monday)
      final todayIdx = DateTime.now().weekday - 1;
      final next = _days.indexWhere((d) => Schedule.weekdays.indexOf(d) > todayIdx);
      _index = next < 0 ? 0 : next;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _go(int i) {
    setState(() => _index = i);
    _pages.animateToPage(i, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    if (_days.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month_outlined, size: 40, color: AppColors.onSurfaceHint(context)),
              const SizedBox(height: 16),
              Text(widget.emptyTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.onSurface(context))),
              const SizedBox(height: 6),
              Text(widget.emptySubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.onSurfaceMuted(context))),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        _strip(context),
        Expanded(
          child: PageView.builder(
            controller: _pages,
            itemCount: _days.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => _DayList(
              day: _days[i],
              date: _dateOf(_days[i]),
              periods: widget.periods,
              staffNames: widget.staffNames,
              subtitleOf: widget.subtitleOf,
              resolver: widget.resolver,
            ),
          ),
        ),
      ],
    );
  }

  Widget _strip(BuildContext context) {
    final today = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          for (var i = 0; i < _days.length; i++)
            Expanded(
              child: Builder(builder: (context) {
                final date = _dateOf(_days[i]);
                final selected = i == _index;
                final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
                final ink = AdminLook.inkOf(context);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: '${_days[i]}${isToday ? ', today' : ''}',
                    child: Material(
                      color: selected ? ink : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _go(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              Text(
                                _short[Schedule.weekdays.indexOf(_days[i])],
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? AdminLook.canvasOf(context) : AppColors.onSurfaceMuted(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${date.day}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: selected ? AdminLook.canvasOf(context) : ink,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isToday
                                      ? (selected ? AdminLook.gold : AppColors.accent)
                                      : Colors.transparent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _DayList extends StatelessWidget {
  final String day;
  final DateTime date;
  final List<Period> periods;
  final Map<String, String> staffNames;
  final String Function(Period period)? subtitleOf;
  final List<Period> Function(String day, DateTime date)? resolver;

  const _DayList({
    required this.day,
    required this.date,
    required this.periods,
    required this.staffNames,
    required this.subtitleOf,
    required this.resolver,
  });

  static const _palette = [
    Color(0xFF8B7355), Color(0xFF5E7A5A), Color(0xFF4A5A7A), Color(0xFF6A5A8C),
    Color(0xFF3F6B6A), Color(0xFFB0664A), Color(0xFF7A5A48), Color(0xFF5B6E8C),
  ];

  static Color colorFor(String subject) {
    var h = 0;
    for (final c in subject.toLowerCase().codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _palette[h % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final list = resolver?.call(day, date) ?? Schedule.periodsOn(periods, day, date: date);
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wb_sunny_outlined, size: 36, color: AppColors.onSurfaceHint(context)),
            const SizedBox(height: 12),
            Text('No classes on $day',
                style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.onSurfaceMuted(context))),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final nowMin = now.hour * 60 + now.minute;
    final currentIdx = !isToday
        ? -1
        : list.indexWhere((p) =>
            Schedule.minutesOf(p.startTime) <= nowMin && nowMin < Schedule.endMinutes(p));
    final nextIdx = !isToday
        ? -1
        : list.indexWhere((p) => !Schedule.isBreak(p) && Schedule.minutesOf(p.startTime) > nowMin);
    final first = list.first;
    final last = list.last;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            '${Schedule.format12(first.startTime)} – ${Schedule.format12(Schedule.endTime(last))}'
            ' · ${list.where((p) => !Schedule.isBreak(p)).length} periods',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.onSurfaceMuted(context)),
          ),
        ),
        for (var i = 0; i < list.length; i++)
          Schedule.isBreak(list[i])
              ? _BreakRow(period: list[i], current: i == currentIdx)
              : _PeriodRow(
                  period: list[i],
                  color: colorFor(list[i].name),
                  subtitle: subtitleOf?.call(list[i]) ?? (staffNames[list[i].staffId] ?? ''),
                  current: i == currentIdx,
                  next: i == nextIdx && currentIdx != nextIdx,
                  past: isToday && Schedule.endMinutes(list[i]) <= nowMin,
                  nowMinutes: nowMin,
                ),
      ],
    );
  }
}

class _PeriodRow extends StatelessWidget {
  final Period period;
  final Color color;
  final String subtitle;
  final bool current;
  final bool next;
  final bool past;
  final int nowMinutes;

  const _PeriodRow({
    required this.period,
    required this.color,
    required this.subtitle,
    required this.current,
    required this.next,
    required this.past,
    required this.nowMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final ink = AdminLook.inkOf(context);
    final start = Schedule.minutesOf(period.startTime);
    final progress = current ? ((nowMinutes - start) / period.durationMinutes).clamp(0.0, 1.0) : 0.0;
    return Opacity(
      opacity: past ? 0.55 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Schedule.format12(period.startTime),
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ink)),
                    Text(Schedule.format12(Schedule.endTime(period)),
                        style: TextStyle(fontSize: 11, color: AppColors.onSurfaceHint(context))),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: current ? 0.20 : 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: current ? color : Colors.transparent, width: 1.6),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(period.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: ink)),
                                if (subtitle.isNotEmpty)
                                  Text(subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12.5, color: AppColors.onSurfaceMuted(context))),
                              ],
                            ),
                          ),
                          if (period.isTemporary) _tag('Cover', AppColors.temporaryPeriod),
                          if (current) _tag('Now', color) else if (next) _tag('Next', AppColors.onSurfaceMuted(context)),
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text('${period.durationMinutes}m',
                                style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceHint(context))),
                          ),
                        ],
                      ),
                    ),
                    if (current)
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: color.withValues(alpha: 0.15),
                        color: color,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
      );
}

class _BreakRow extends StatelessWidget {
  final Period period;
  final bool current;
  const _BreakRow({required this.period, required this.current});

  @override
  Widget build(BuildContext context) {
    final lunch = period.name.toLowerCase().contains('lunch');
    final color = lunch ? AppColors.lunchCell : AppColors.breakCell;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(Schedule.format12(period.startTime),
                style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceHint(context))),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: current ? 0.18 : 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(lunch ? Icons.restaurant_rounded : Icons.coffee_rounded, size: 16, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${period.name} · ${period.durationMinutes} min${current ? ' · now' : ''}',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
