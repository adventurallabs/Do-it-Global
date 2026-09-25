import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/session_provider.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/features/feature_registry.dart';
import '../../core/localization/l10n_ext.dart';
import '../../core/navigation/app_routes.dart';
import '../../shared/models/activity.dart';
import '../../shared/models/growth.dart';
import '../../shared/models/marks.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/student_switcher.dart';
import '../exams/exam_dashboard_cards.dart';
import '../homework/homework_screen.dart';
import '../parent/parent_store.dart';
import 'academics_screen.dart';
import 'activities_screen.dart';
import 'attendance_screen.dart';
import 'growth_screen.dart';
import 'stars_screen.dart';
import 'widgets/progress_widgets.dart';

/// How the child is doing — only what a parent needs, all of it fed by the
/// teacher side (stars, notes, skills, activities) plus attendance, homework
/// and marks. Transport, timetable and events live on Today instead.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final registry = ref.watch(featureRegistryProvider);
    final loaded = ref.watch(studentLoadedProvider);
    final homework = ref.watch(studentHomeworkProvider);
    final attendance = ref.watch(studentAttendanceProvider);
    final marks = ref.watch(studentMarksProvider);
    final activities = ref.watch(studentActivitiesProvider);
    final growth = ref.watch(studentGrowthProvider);
    final stars = ref.watch(studentStarsProvider);

    final showStars = registry.isEnabled('stars');
    final showGrowth = registry.isEnabled('growth');
    final showActivities = registry.isEnabled('activities');
    final List<GrowthObservation> notes =
        showGrowth ? (growth?.observations ?? const []) : const [];
    final List<AssessedSkill> skills = showGrowth ? (growth?.skills ?? const []) : const [];
    final List<SchoolActivity> acts = showActivities ? activities : const [];

    final stats = <Widget>[
      if (registry.isEnabled('attendance'))
        ProgressStatTile(
          icon: Icons.event_available_rounded,
          color: AppColors.success,
          label: l10n.attendance,
          value: attendance == null ? '—' : '${attendance.percent}%',
          warn: attendance?.needsAttention ?? false,
          onTap: () => AppRoutes.push(context, const AttendanceScreen()),
        ),
      if (registry.isEnabled('homework'))
        ProgressStatTile(
          icon: Icons.menu_book_rounded,
          color: AppColors.primaryBlue,
          label: l10n.homeworkPerformance,
          value: homework.isEmpty
              ? '—'
              : '${homework.where((h) => h.isCompleted).length}/${homework.length}',
          onTap: () => AppRoutes.push(context, const HomeworkScreen()),
        ),
      if (registry.isEnabled('marks'))
        ProgressStatTile(
          icon: Icons.school_rounded,
          color: AppColors.royalBlue,
          label: marks.isEmpty ? l10n.academics : l10n.latestExam,
          value: _latestExamPercent(marks),
          onTap: () => AppRoutes.push(context, const AcademicsScreen()),
        ),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.read(sessionProvider.notifier).refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 108),
            children: [
              Text(l10n.tabProgress, style: theme.textTheme.headlineMedium),
              const StudentSwitcherHeader(compact: true),
              const SizedBox(height: AppSpacing.md),
              if (!loaded)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (showStars) ...[
                  StarsHeroCard(
                    summary: stars,
                    onTap: () => AppRoutes.push(context, const StarsScreen()),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                const ExamDashboardCards(),
                const SizedBox(height: AppSpacing.md),
                if (stats.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < stats.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.xs),
                        Expanded(child: stats[i]),
                      ],
                    ],
                  ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(
                    title: l10n.teacherNotes,
                    actionLabel: l10n.seeAll,
                    onAction: () => AppRoutes.push(context, const GrowthScreen()),
                  ),
                  for (final o in notes.take(2)) ...[
                    ObservationTile(observation: o),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
                if (skills.isNotEmpty) ...[
                  SizedBox(height: notes.isEmpty ? AppSpacing.lg : AppSpacing.xs),
                  SectionHeader(
                    title: l10n.skills,
                    actionLabel: skills.length > 4 ? l10n.seeAll : null,
                    onAction: () => AppRoutes.push(context, const GrowthScreen()),
                  ),
                  PremiumCard(
                    onTap: () => AppRoutes.push(context, const GrowthScreen()),
                    child: Column(children: [for (final s in skills.take(4)) SkillRow(skill: s)]),
                  ),
                ],
                if (acts.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(
                    title: l10n.activities,
                    actionLabel: l10n.seeAll,
                    onAction: () => AppRoutes.push(context, const ActivitiesScreen()),
                  ),
                  for (final a in acts.take(3)) ...[
                    ActivityMiniTile(activity: a),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
                if (notes.isEmpty && skills.isEmpty && acts.isEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  PremiumCard(
                    child: Row(
                      children: [
                        Icon(Icons.spa_outlined, color: theme.colorScheme.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(l10n.progressEmptyHint, style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Overall % of the most recent exam (marks come newest-exam first).
  static String _latestExamPercent(List<ExamResult> marks) {
    if (marks.isEmpty) return '—';
    final latest = marks.first.examName;
    var scored = 0, max = 0;
    for (final m in marks) {
      if (m.examName != latest) continue;
      scored += m.scored;
      max += m.maxMarks;
    }
    if (max == 0) return '—';
    return '${(scored * 100 / max).round()}%';
  }
}
