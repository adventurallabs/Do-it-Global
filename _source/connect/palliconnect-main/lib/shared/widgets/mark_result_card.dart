import 'package:flutter/material.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../models/marks.dart';
import 'premium_card.dart';

/// One exam or test, read as a result sheet: a row per subject, the marks
/// scored, and the percentage — plus the total the whole card adds up to.
///
/// It was a bare list of "subject … 40/50" lines before, which is the one
/// thing a parent wants to scan and compare and the one shape a list makes
/// hard. The columns here line up with the table the teacher types into, so
/// both sides read the same sheet.
class MarkResultCard extends StatelessWidget {
  final String title;
  final List<ExamResult> results;
  final void Function(String subject)? onSubjectTap;

  const MarkResultCard({
    super.key,
    required this.title,
    required this.results,
    this.onSubjectTap,
  });

  static Color bandColor(int percent) {
    if (percent >= 75) return AppColors.leafGreen;
    if (percent >= 50) return AppColors.warning;
    return AppColors.heart;
  }

  int get _scored => results.fold(0, (sum, r) => sum + r.scored);

  int get _max => results.fold(0, (sum, r) => sum + r.maxMarks);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overall = _max == 0 ? null : ((_scored / _max) * 100).round();

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
              if (overall != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: bandColor(overall).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text(
                    '$overall%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: bandColor(overall),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _headerRow(context),
          const Divider(height: AppSpacing.md),
          ...results.map((r) => _subjectRow(context, r)),
          if (results.length > 1) ...[
            const Divider(height: AppSpacing.md),
            _totalRow(context, overall),
          ],
        ],
      ),
    );
  }

  Widget _headerRow(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return Row(
      children: [
        Expanded(child: Text('SUBJECT', style: style)),
        SizedBox(width: 74, child: Text('MARKS', textAlign: TextAlign.end, style: style)),
        SizedBox(width: 52, child: Text('%', textAlign: TextAlign.end, style: style)),
      ],
    );
  }

  Widget _subjectRow(BuildContext context, ExamResult r) {
    final theme = Theme.of(context);
    final percent = r.maxMarks == 0 ? null : ((r.scored / r.maxMarks) * 100).round();
    return InkWell(
      onTap: onSubjectTap == null ? null : () => onSubjectTap!(r.subject),
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Text(
                r.subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            SizedBox(
              width: 74,
              child: Text(
                '${r.scored}/${r.maxMarks}',
                textAlign: TextAlign.end,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(
              width: 52,
              child: Text(
                percent == null ? '—' : '$percent',
                textAlign: TextAlign.end,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: percent == null
                      ? theme.colorScheme.onSurfaceVariant
                      : bandColor(percent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(BuildContext context, int? overall) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(
            child: Text('Total',
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
          ),
          SizedBox(
            width: 74,
            child: Text(
              '$_scored/$_max',
              textAlign: TextAlign.end,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              overall == null ? '—' : '$overall',
              textAlign: TextAlign.end,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: overall == null
                    ? theme.colorScheme.onSurfaceVariant
                    : bandColor(overall),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
