import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/app_spacing.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../shared/models/class_timetable.dart';
import '../../../shared/widgets/premium_card.dart';
import '../../school_life/school_life_providers.dart';
import '../../school_life/timetable_screen.dart';

/// Today's classes at a glance: what's on now and next first, the rest of
/// the day compact below. Hidden on days without classes.
class TodayPeriodsCard extends ConsumerWidget {
  const TodayPeriodsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final timetable = ref.watch(classTimetableProvider).asData?.value;
    if (timetable == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final today = ClassTimetable.weekdays[now.weekday - 1];
    final all = timetable.periodsOn(today, date: now);
    final classes = all.where((p) => !p.isBreak).toList();
    if (classes.isEmpty) return const SizedBox.shrink();

    final nowMin = now.hour * 60 + now.minute;
    final current = all.where((p) => p.startMinutes <= nowMin && nowMin < p.endMinutes).firstOrNull;
    final upcoming = classes.where((p) => p.startMinutes > nowMin).toList();
    final over = classes.last.endMinutes <= nowMin;

    return PremiumCard(
      onTap: () => AppRoutes.push(context, const TimetableScreen()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(l10n.todaysPeriods, style: theme.textTheme.titleMedium)),
              Text(l10n.fullWeek,
                  style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
              Icon(Icons.chevron_right_rounded, size: 18, color: theme.colorScheme.primary),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (over)
            Text(l10n.schoolDayOver, style: theme.textTheme.bodyMedium)
          else ...[
            if (current != null) _highlight(context, current, l10n.periodNow),
            if (upcoming.isNotEmpty && (current == null || current.isBreak || upcoming.first != current))
              _highlight(context, upcoming.first, l10n.periodNext),
            for (final p in upcoming.skip(1).take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(formatClock(context, p.startTime), style: theme.textTheme.labelMedium),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: AppSpacing.xs),
                      decoration: BoxDecoration(color: subjectColor(p.name), shape: BoxShape.circle),
                    ),
                    Expanded(
                      child: Text(p.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _highlight(BuildContext context, TimetablePeriod p, String label) {
    final theme = Theme.of(context);
    final color = p.isBreak ? theme.colorScheme.onSurface.withValues(alpha: 0.6) : subjectColor(p.name);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
            child: Text(label,
                style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                if (!p.isBreak && (p.teacherName ?? '').isNotEmpty)
                  Text(p.teacherName!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            '${formatClock(context, p.startTime)} – ${formatClock(context, p.endTime)}',
            style: theme.textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}
