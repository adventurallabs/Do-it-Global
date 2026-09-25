import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/localization/l10n_ext.dart';
import '../../shared/models/growth.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/section_header.dart';
import '../parent/parent_store.dart';
import 'widgets/progress_widgets.dart';

/// Teacher notes and skill levels — the parts of Growth a teacher records.
class GrowthScreen extends ConsumerWidget {
  const GrowthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final profile = ref.watch(studentGrowthProvider);

    if (profile == null || profile.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.growth)),
        body: AppEmptyState(
          icon: Icons.spa_outlined,
          title: l10n.growthEmptyTitle,
          body: l10n.growthEmptyBody,
        ),
      );
    }

    // skills grouped by area ("Communication", "Social", ...)
    final groups = <String, List<AssessedSkill>>{};
    for (final s in profile.skills) {
      groups.putIfAbsent(s.category, () => []).add(s);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.growth)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
          children: [
            if (profile.skills.isNotEmpty) ...[
              SectionHeader(title: l10n.skills),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 2),
                child: Text(l10n.skillScaleHint, style: theme.textTheme.bodySmall),
              ),
              for (final entry in groups.entries) ...[
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (entry.key.isNotEmpty) ...[
                        Text(entry.key.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.1)),
                        const SizedBox(height: AppSpacing.xxs),
                      ],
                      for (final s in entry.value) SkillRow(skill: s),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.md),
            ],
            if (profile.observations.isNotEmpty) ...[
              SectionHeader(title: l10n.teacherNotes),
              for (final o in profile.observations) ...[
                ObservationTile(observation: o),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
