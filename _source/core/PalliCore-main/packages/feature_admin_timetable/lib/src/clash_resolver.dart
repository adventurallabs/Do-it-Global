import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_models/core_models.dart';
import 'timetable_bloc.dart';

/// The same period repeated on other days — same subject, time, length and
/// staff (what "Repeat Mon–Fri" creates).
List<Period> periodSiblings(List<Period> all, Period period) => [
      for (final p in all)
        if (!p.isTemporary &&
            p.id != period.id &&
            p.dayOfWeek != period.dayOfWeek &&
            p.name.trim().toLowerCase() == period.name.trim().toLowerCase() &&
            p.startTime == period.startTime &&
            p.durationMinutes == period.durationMinutes &&
            p.staffId == period.staffId)
          p,
    ];

String _shortDays(Iterable<Period> periods) {
  final days = {for (final p in periods) p.dayOfWeek};
  return Schedule.weekdays.where(days.contains).map((d) => d.substring(0, 3)).join(', ');
}

/// Asks before deleting a period, spelling out exactly which one (day, time,
/// staff). When the same period sits on other days, offers to remove those
/// too. Returns the ids to delete, or null when cancelled.
Future<Set<String>?> confirmPeriodDelete(
  BuildContext context, {
  required Period period,
  List<Period> siblings = const [],
  bool siblingsByDefault = false,
  String? staffName,
}) {
  var includeSiblings = siblingsByDefault && siblings.isNotEmpty;
  return showDialog<Set<String>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text('Delete ${period.name}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PeriodSummary(period: period, staffName: staffName),
              if (siblings.isNotEmpty) ...[
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: includeSiblings,
                  onChanged: (v) => setState(() => includeSiblings = v ?? false),
                  title: Text('Also delete it on ${_shortDays(siblings)}'),
                  subtitle: const Text('Same subject at the same time on those days'),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Teachers and parents will stop seeing '
                '${includeSiblings ? 'these periods' : 'this period'}.',
                style: TextStyle(color: AppColors.onSurfaceMuted(ctx), fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
              onPressed: () => Navigator.pop(ctx, {
                period.id,
                if (includeSiblings) ...siblings.map((s) => s.id),
              }),
              child: Text(includeSiblings ? 'Delete ${siblings.length + 1}' : 'Delete'),
            ),
          ],
        );
      },
    ),
  );
}

class _PeriodSummary extends StatelessWidget {
  final Period period;
  final String? staffName;
  const _PeriodSummary({required this.period, this.staffName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(period.dayOfWeek, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            '${Schedule.range(period)} · ${period.durationMinutes} min'
            '${staffName == null || staffName!.isEmpty ? '' : ' · $staffName'}',
            style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Opens the "fix overlapping periods" sheet. It lists every day and time
/// where periods collide, draws them on a mini timeline so the overlap is
/// visible, and lets the admin edit or delete the right one in place.
Future<void> showClashResolver(
  BuildContext context, {
  required Timetable timetable,
  required Map<String, String> staffNames,
  required void Function(Period period) onEdit,
  String? focusDay,
}) {
  final bloc = context.read<TimetableBloc>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => BlocProvider.value(
      value: bloc,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, controller) => _ClashResolver(
          fallback: timetable,
          staffNames: staffNames,
          onEdit: onEdit,
          focusDay: focusDay,
          controller: controller,
        ),
      ),
    ),
  );
}

class _ClashResolver extends StatelessWidget {
  final Timetable fallback;
  final Map<String, String> staffNames;
  final void Function(Period period) onEdit;
  final String? focusDay;
  final ScrollController controller;

  const _ClashResolver({
    required this.fallback,
    required this.staffNames,
    required this.onEdit,
    required this.controller,
    this.focusDay,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TimetableBloc, TimetableState>(
      builder: (context, state) {
        final timetable = state is TimetablesLoaded
            ? state.timetables.firstWhere((t) => t.id == fallback.id, orElse: () => fallback)
            : fallback;
        final days = [
          ?focusDay,
          ...Schedule.weekdays.where((d) => d != focusDay),
        ];
        final sections = [
          for (final day in days)
            for (final group in Schedule.clashGroupsOn(timetable.periods, day)) (day, group),
        ];
        final clashIds = {for (final (_, g) in sections) ...g.map((p) => p.id)};

        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.onSurfaceHint(context).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Fix overlapping periods',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            if (sections.isEmpty)
              _AllClear(onDone: () => Navigator.pop(context))
            else ...[
              Text(
                'A class can only be in one period at a time. Each box below is one '
                'time slot where periods run into each other. Keep the right one and '
                'delete or shorten the others.',
                style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                '${sections.length} to fix · on ${sections.map((s) => s.$1.substring(0, 3)).toSet().join(', ')}',
                style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 16),
              for (final (day, group) in sections)
                _ClashCard(
                  day: day,
                  group: group,
                  staffNames: staffNames,
                  onEdit: onEdit,
                  onDelete: (period) async {
                    final siblings = periodSiblings(timetable.periods, period)
                        .where((s) => clashIds.contains(s.id))
                        .toList();
                    final ids = await confirmPeriodDelete(
                      context,
                      period: period,
                      siblings: siblings,
                      siblingsByDefault: true,
                      staffName: staffNames[period.staffId],
                    );
                    if (ids == null || !context.mounted) return;
                    context.read<TimetableBloc>().add(DeletePeriods(timetable.id, ids));
                  },
                ),
            ],
          ],
        );
      },
    );
  }
}

class _AllClear extends StatelessWidget {
  final VoidCallback onDone;
  const _AllClear({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded, size: 56, color: AppColors.success),
          const SizedBox(height: 12),
          const Text('No overlaps left', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Every period now has its own time slot.',
            style: TextStyle(color: AppColors.onSurfaceMuted(context)),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: onDone, child: const Text('Done')),
        ],
      ),
    );
  }
}

class _ClashCard extends StatelessWidget {
  final String day;
  final List<Period> group;
  final Map<String, String> staffNames;
  final void Function(Period) onEdit;
  final void Function(Period) onDelete;

  const _ClashCard({
    required this.day,
    required this.group,
    required this.staffNames,
    required this.onEdit,
    required this.onDelete,
  });

  /// One plain sentence describing what is wrong in this slot.
  String _explain() {
    for (var i = 0; i < group.length; i++) {
      for (var j = i + 1; j < group.length; j++) {
        final a = group[i], b = group[j];
        if (a.startTime == b.startTime && a.name.trim().toLowerCase() == b.name.trim().toLowerCase()) {
          return '${a.name} is entered twice at ${Schedule.format12(a.startTime)}. Delete one copy.';
        }
      }
    }
    for (var i = 0; i < group.length; i++) {
      for (var j = i + 1; j < group.length; j++) {
        final a = group[i], b = group[j];
        if (Schedule.minutesOf(b.startTime) < Schedule.endMinutes(a)) {
          final overlap = Schedule.endMinutes(a).clamp(0, Schedule.endMinutes(b)) - Schedule.minutesOf(b.startTime);
          if (a.startTime == b.startTime) {
            return '${a.name} and ${b.name} both start at ${Schedule.format12(a.startTime)}. '
                'Delete one or move it to another time.';
          }
          return '${a.name} ends at ${Schedule.format12(Schedule.endTime(a))}, but ${b.name} '
              'starts at ${Schedule.format12(b.startTime)} — they overlap by $overlap min. '
              'Shorten ${a.name} or move ${b.name} later.';
        }
      }
    }
    return 'These periods run at the same time.';
  }

  @override
  Widget build(BuildContext context) {
    final start = group.map((p) => Schedule.minutesOf(p.startTime)).reduce((a, b) => a < b ? a : b);
    final end = group.map(Schedule.endMinutes).reduce((a, b) => a > b ? a : b);
    final span = (end - start).clamp(1, 24 * 60);
    final dupKeys = <String>{};
    final seen = <String>{};
    for (final p in group) {
      final key = '${p.name.trim().toLowerCase()}@${p.startTime}';
      if (!seen.add(key)) dupKeys.add(key);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.07),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(99)),
                child: Text(day,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${Schedule.format12(Schedule.hhmm(start))} – ${Schedule.format12(Schedule.hhmm(end))}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(_explain(), style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.onSurface(context))),
          const SizedBox(height: 12),
          for (final p in group)
            _ClashRow(
              period: p,
              staffName: staffNames[p.staffId],
              duplicate: dupKeys.contains('${p.name.trim().toLowerCase()}@${p.startTime}'),
              barStart: (Schedule.minutesOf(p.startTime) - start) / span,
              barWidth: p.durationMinutes / span,
              onEdit: () => onEdit(p),
              onDelete: () => onDelete(p),
            ),
        ],
      ),
    );
  }
}

class _ClashRow extends StatelessWidget {
  final Period period;
  final String? staffName;
  final bool duplicate;
  final double barStart;
  final double barWidth;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ClashRow({
    required this.period,
    required this.staffName,
    required this.duplicate,
    required this.barStart,
    required this.barWidth,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(period.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        if (duplicate)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Entered twice',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.warning)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Schedule.range(period)} · ${period.durationMinutes} min'
                      '${staffName == null || staffName!.isEmpty ? '' : ' · $staffName'}',
                      style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit time',
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEdit,
              ),
              IconButton(
                tooltip: 'Delete',
                icon: Icon(Icons.delete_outline_rounded, size: 20, color: scheme.error),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: LayoutBuilder(
              builder: (context, c) => Container(
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.onSurfaceHint(context).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: c.maxWidth * barStart.clamp(0.0, 1.0),
                      width: (c.maxWidth * barWidth).clamp(4.0, c.maxWidth),
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
