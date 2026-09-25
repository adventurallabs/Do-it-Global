import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/localization/l10n_ext.dart';
import '../../core/utils/formatters.dart';
import '../../shared/models/attendance.dart';
import '../../shared/widgets/attendance_summary_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../parent/parent_store.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = ref.watch(studentAttendanceProvider);
    final loaded = ref.watch(studentLoadedProvider);
    final theme = Theme.of(context);
    if (summary == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.attendance)),
        body: loaded
            ? AppEmptyState(
                icon: Icons.event_available_outlined,
                title: l10n.noAttendanceTitle,
                body: l10n.noAttendanceBody,
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }

    final month = _month;
    final now = DateTime.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;
    final locale = Localizations.localeOf(context).toString();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.attendance)),
      body: SafeArea(
        child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AttendanceSummaryCard(summary: summary),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: Text(l10n.calendar, style: theme.textTheme.titleLarge)),
              IconButton(
                tooltip: l10n.previousMonth,
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => setState(() => _month = DateTime(month.year, month.month - 1)),
              ),
              Text(DateFormat.yMMM(locale).format(month), style: theme.textTheme.titleSmall),
              IconButton(
                tooltip: l10n.nextMonth,
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: isCurrentMonth
                    ? null
                    : () => setState(() => _month = DateTime(month.year, month.month + 1)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _MonthGrid(month: month, days: summary.days),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            children: [
              _Legend(color: AppColors.success, label: l10n.present),
              _Legend(color: AppColors.error, label: l10n.absent),
              _Legend(color: AppColors.warning, label: l10n.leave),
            ],
          ),
        ],
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final Map<DateTime, AttendanceMark> days;

  const _MonthGrid({required this.month, required this.days});

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startWeekday = first.weekday % 7;
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
              .map((d) => Expanded(
                    child: Text(d, textAlign: TextAlign.center, style: theme.textTheme.labelMedium),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.sm),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: startWeekday + daysInMonth,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
          itemBuilder: (context, i) {
            if (i < startWeekday) return const SizedBox.shrink();
            final day = i - startWeekday + 1;
            final date = DateTime(month.year, month.month, day);
            final mark = days[dateOnly(date)] ?? AttendanceMark.none;
            final isToday = dateOnly(date) == dateOnly(DateTime.now());
            final color = switch (mark) {
              AttendanceMark.present => AppColors.success,
              AttendanceMark.absent => AppColors.error,
              AttendanceMark.leave => AppColors.warning,
              AttendanceMark.none => Colors.transparent,
            };
            return Center(
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color == Colors.transparent ? null : color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: isToday ? Border.all(color: theme.colorScheme.primary, width: 1.5) : null,
                ),
                child: Text(
                  '$day',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color == Colors.transparent ? theme.colorScheme.onSurface : color,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
