import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_spacing.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../shared/models/activity.dart';
import '../../../shared/models/growth.dart';
import '../../../shared/widgets/premium_card.dart';

String skillLevelLabel(BuildContext context, String level) {
  final l10n = context.l10n;
  return switch (level.toLowerCase()) {
    'emerging' => l10n.skillLevelEmerging,
    'developing' => l10n.skillLevelDeveloping,
    'proficient' => l10n.skillLevelProficient,
    'advanced' => l10n.skillLevelAdvanced,
    _ => level,
  };
}

Color observationColor(ObservationTone tone) => switch (tone) {
      ObservationTone.positive => AppColors.success,
      ObservationTone.neutral => AppColors.info,
      ObservationTone.attention => AppColors.warning,
    };

String shortDate(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).toString();
  final now = DateTime.now();
  final d = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  if (d == today) return context.l10n.todayLabel;
  if (d == today.subtract(const Duration(days: 1))) return context.l10n.yesterday;
  return date.year == now.year
      ? DateFormat.MMMd(locale).format(date)
      : DateFormat.yMMMd(locale).format(date);
}

/// The big, warm star card at the top of Progress.
class StarsHeroCard extends StatelessWidget {
  final StarSummary summary;
  final VoidCallback? onTap;

  const StarsHeroCard({super.key, required this.summary, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final latest = summary.latest;
    final week = summary.thisWeek;
    return Semantics(
      button: onTap != null,
      label: '${l10n.starsEarned}: ${summary.total}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFB938), Color(0xFFF59E0B), Color(0xFFEA7C0C)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.star.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.22),
                ),
                child: const Icon(Icons.star_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${summary.total}',
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            l10n.starsEarned,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (latest == null)
                      Text(
                        l10n.noStarsTitle,
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                      )
                    else
                      Text(
                        latest.reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (week > 0) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Text(
                          l10n.starsThisWeek(week),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact number tile (attendance %, homework, exam).
class ProgressStatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool warn;

  const ProgressStatTile({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
    this.warn = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: warn ? AppColors.warning : color, size: 22),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: warn ? AppColors.warning : null,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class ObservationTile extends StatelessWidget {
  final GrowthObservation observation;
  const ObservationTile({super.key, required this.observation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final o = observation;
    final color = observationColor(o.tone);
    return PremiumCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 44,
            margin: const EdgeInsets.only(right: AppSpacing.sm, top: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(o.title, style: theme.textTheme.titleMedium)),
                    if (o.tone == ObservationTone.attention)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Text(
                          l10n.needsAttention,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(o.body, style: theme.textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  [
                    if (o.source.isNotEmpty) o.source,
                    shortDate(context, o.date),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SkillRow extends StatelessWidget {
  final AssessedSkill skill;
  const SkillRow({super.key, required this.skill});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = skill.step;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(skill.name, style: theme.textTheme.titleSmall)),
              Text(
                skillLevelLabel(context, skill.level),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 1; i <= 4; i++)
                Expanded(
                  child: Container(
                    height: 7,
                    margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: i <= step
                          ? Color.lerp(AppColors.skyBlue, AppColors.primaryBlue, i / 4)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class StarAwardTile extends StatelessWidget {
  final StarAward award;
  const StarAwardTile({super.key, required this.award});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.star.withValues(alpha: 0.16),
            ),
            child: const Icon(Icons.star_rounded, color: AppColors.star),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(award.reason, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  [
                    if (award.teacherName.isNotEmpty) l10n.starFrom(award.teacherName),
                    shortDate(context, award.date),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '+${award.points}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.starDeep,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

IconData activityIcon(String category) => switch (category.toLowerCase()) {
      'sports' => Icons.sports_soccer_rounded,
      'arts' => Icons.palette_rounded,
      'academic' => Icons.school_rounded,
      'cultural' => Icons.theater_comedy_rounded,
      'clubs' => Icons.groups_rounded,
      _ => Icons.emoji_events_rounded,
    };

/// Compact activity row used on the Progress overview.
class ActivityMiniTile extends StatelessWidget {
  final SchoolActivity activity;
  const ActivityMiniTile({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = activity;
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: AppColors.brandSweep(opacity: 0.16),
            ),
            child: Icon(activityIcon(a.category), color: AppColors.primaryBlue, size: 21),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.name, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  [if (a.category.isNotEmpty) a.category, shortDate(context, a.date)].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if ((a.result ?? '').isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.leafGreen.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(
                a.result!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
