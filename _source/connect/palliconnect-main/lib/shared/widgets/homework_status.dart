import 'package:flutter/material.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../models/homework.dart';
import 'status_badge.dart';

class HomeworkStatusIndicator extends StatelessWidget {
  final HomeworkUrgency urgency;
  final String Function(HomeworkUrgency) labelFor;

  const HomeworkStatusIndicator({
    super.key,
    required this.urgency,
    required this.labelFor,
  });

  @override
  Widget build(BuildContext context) {
    late Color color;
    late Color bg;
    switch (urgency) {
      case HomeworkUrgency.overdue:
        color = AppColors.error;
        bg = AppColors.errorSoft;
        break;
      case HomeworkUrgency.dueToday:
        color = AppColors.warning;
        bg = AppColors.warningSoft;
        break;
      case HomeworkUrgency.upcoming:
        color = AppColors.info;
        bg = AppColors.infoSoft;
        break;
      case HomeworkUrgency.completed:
        color = AppColors.success;
        bg = AppColors.successSoft;
        break;
    }
    return StatusBadge(label: labelFor(urgency), color: color, background: bg);
  }
}

class HomeworkProgressBar extends StatelessWidget {
  final int done;
  final int total;
  final String label;

  const HomeworkProgressBar({
    super.key,
    required this.done,
    required this.total,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = total == 0 ? 0.0 : done / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: AppColors.grey200,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('${(value * 100).round()}%', style: theme.textTheme.bodySmall),
      ],
    );
  }
}
