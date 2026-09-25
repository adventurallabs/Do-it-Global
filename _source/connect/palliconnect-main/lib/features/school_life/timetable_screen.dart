import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/localization/l10n_ext.dart';
import '../../shared/models/class_timetable.dart';
import '../../shared/widgets/empty_state.dart';
import 'school_life_providers.dart';

/// The child's class timetable: this week's days as a date strip, one
/// swipeable list per day, with today's current class highlighted.
class TimetableScreen extends ConsumerWidget {
  const TimetableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(classTimetableProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.timetable)),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: l10n.timetableErrorTitle,
                  body: l10n.timetableErrorBody,
                ),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(classTimetableProvider),
                  child: Text(l10n.tryAgain),
                ),
              ],
            ),
          ),
          data: (timetable) {
            if (timetable == null || timetable.schoolDays.isEmpty) {
              return RefreshIndicator(
                onRefresh: () => ref.refresh(classTimetableProvider.future),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 80),
                    AppEmptyState(
                      icon: Icons.calendar_today_outlined,
                      title: l10n.timetableNoneTitle,
                      body: l10n.timetableNoneBody,
                    ),
                  ],
                ),
              );
            }
            return _WeekView(timetable: timetable);
          },
        ),
      ),
    );
  }
}

class _WeekView extends ConsumerStatefulWidget {
  final ClassTimetable timetable;
  const _WeekView({required this.timetable});

  @override
  ConsumerState<_WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends ConsumerState<_WeekView> {
  List<String> get _days => widget.timetable.schoolDays;
  late int _index = _initialIndex();
  late final PageController _pages = PageController(initialPage: _index);
  Timer? _tick;

  DateTime get _monday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
  }

  DateTime _dateOf(String day) =>
      _monday.add(Duration(days: ClassTimetable.weekdays.indexOf(day)));

  int _initialIndex() {
    final todayIdx = DateTime.now().weekday - 1;
    final exact = _days.indexOf(ClassTimetable.weekdays[todayIdx]);
    if (exact >= 0) return exact;
    final next = _days.indexWhere((d) => ClassTimetable.weekdays.indexOf(d) > todayIdx);
    return next < 0 ? 0 : next;
  }

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
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
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final today = DateTime.now();
    if (_index >= _days.length) _index = _days.length - 1;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, AppSpacing.sm),
          child: Row(
            children: [
              for (var i = 0; i < _days.length; i++)
                Expanded(
                  child: Builder(builder: (context) {
                    final date = _dateOf(_days[i]);
                    final selected = i == _index;
                    final isToday =
                        date.year == today.year && date.month == today.month && date.day == today.day;
                    final fg = selected ? Colors.white : theme.colorScheme.onSurface;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Semantics(
                        button: true,
                        selected: selected,
                        label: DateFormat.MMMMEEEEd(locale).format(date),
                        child: Material(
                          color: selected ? AppColors.primaryBlue : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 4),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 4),
                            onTap: () => _go(i),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                children: [
                                  Text(
                                    DateFormat.E(locale).format(date),
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: selected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text('${date.day}',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(color: fg, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 3),
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isToday
                                          ? (selected ? Colors.white : AppColors.primaryBlue)
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
        ),
        Expanded(
          child: PageView.builder(
            controller: _pages,
            itemCount: _days.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => RefreshIndicator(
              onRefresh: () => ref.refresh(classTimetableProvider.future),
              child: _DayList(
                timetable: widget.timetable,
                day: _days[i],
                date: _dateOf(_days[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shared by the full timetable and Today's card.
Color subjectColor(String subject) {
  const palette = [
    Color(0xFF2F6BFF), Color(0xFF16A34A), Color(0xFF9333EA), Color(0xFFEA580C),
    Color(0xFF0891B2), Color(0xFFDB2777), Color(0xFF4F46E5), Color(0xFF65A30D),
  ];
  var h = 0;
  for (final c in subject.toLowerCase().codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return palette[h % palette.length];
}

String formatClock(BuildContext context, String hhmm) {
  final parts = hhmm.split(':');
  final t = DateTime(2000, 1, 1, int.tryParse(parts[0]) ?? 0, parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0);
  return DateFormat.jm(Localizations.localeOf(context).toString()).format(t);
}

class _DayList extends StatelessWidget {
  final ClassTimetable timetable;
  final String day;
  final DateTime date;

  const _DayList({required this.timetable, required this.day, required this.date});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final list = timetable.periodsOn(day, date: date);
    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          AppEmptyState(
            icon: Icons.wb_sunny_outlined,
            title: l10n.noClassesOnDay(DateFormat.EEEE(locale).format(date)),
            body: '',
          ),
        ],
      );
    }
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final nowMin = now.hour * 60 + now.minute;
    final current = isToday ? list.indexWhere((p) => p.startMinutes <= nowMin && nowMin < p.endMinutes) : -1;
    final next = isToday ? list.indexWhere((p) => !p.isBreak && p.startMinutes > nowMin) : -1;
    final classes = list.where((p) => !p.isBreak).length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 40),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 2),
          child: Text(
            '${formatClock(context, list.first.startTime)} – ${formatClock(context, list.last.endTime)}'
            ' · ${l10n.periodsCount(classes)}',
            style: theme.textTheme.bodySmall,
          ),
        ),
        for (var i = 0; i < list.length; i++)
          list[i].isBreak
              ? _BreakRow(period: list[i], current: i == current)
              : _PeriodRow(
                  period: list[i],
                  current: i == current,
                  next: i == next && next != current,
                  past: isToday && list[i].endMinutes <= nowMin,
                  nowMinutes: nowMin,
                ),
      ],
    );
  }
}

class _PeriodRow extends StatelessWidget {
  final TimetablePeriod period;
  final bool current;
  final bool next;
  final bool past;
  final int nowMinutes;

  const _PeriodRow({
    required this.period,
    required this.current,
    required this.next,
    required this.past,
    required this.nowMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final color = subjectColor(period.name);
    final progress =
        current ? ((nowMinutes - period.startMinutes) / period.durationMinutes).clamp(0.0, 1.0) : 0.0;
    return Opacity(
      opacity: past ? 0.55 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 66,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatClock(context, period.startTime),
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                    Text(formatClock(context, period.endTime), style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: current ? 0.16 : 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: current ? color : color.withValues(alpha: 0.15), width: current ? 1.6 : 1),
                ),
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
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                if ((period.teacherName ?? '').isNotEmpty)
                                  Text(period.teacherName!,
                                      maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                          if (period.isTemporary) _tag(context, l10n.periodCover, AppColors.warning),
                          if (current)
                            _tag(context, l10n.periodNow, color)
                          else if (next)
                            _tag(context, l10n.periodNext, theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        ],
                      ),
                    ),
                    if (current)
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.15),
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

  Widget _tag(BuildContext context, String text, Color color) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        child: Text(text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w800)),
      );
}

class _BreakRow extends StatelessWidget {
  final TimetablePeriod period;
  final bool current;
  const _BreakRow({required this.period, required this.current});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final lunch = period.name.toLowerCase().contains('lunch');
    const color = AppColors.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 66,
            child: Text(formatClock(context, period.startTime), style: theme.textTheme.labelSmall),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: current ? 0.18 : 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(lunch ? Icons.restaurant_rounded : Icons.coffee_rounded, size: 16, color: color),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      '${period.name} · ${l10n.minutesShort(period.durationMinutes)}'
                      '${current ? ' · ${l10n.periodNow}' : ''}',
                      style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
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
