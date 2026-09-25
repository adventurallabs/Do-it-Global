import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/session_provider.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/localization/l10n_ext.dart';
import '../../core/navigation/app_routes.dart';
import '../../shared/models/exams.dart';
import '../../shared/models/marks.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/mark_result_card.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/section_header.dart';
import '../parent/parent_store.dart';
import '../exams/exam_dashboard_cards.dart';
import '../exams/exam_providers.dart';
import '../exams/exam_timetable_screen.dart';
import '../exams/exam_widgets.dart';
import 'subject_detail_screen.dart';

class AcademicsScreen extends ConsumerWidget {
  const AcademicsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final student = ref.watch(currentStudentProvider);
    final marks = ref.watch(studentMarksProvider);
    final exams = ref.watch(parentExamsProvider);

    // Formal exams share an exam id; class tests / quizzes all share the
    // 'unit' group, so those are split by test name instead of merged.
    final groups = <String, List<ExamResult>>{};
    for (final m in marks) {
      final key = m.examGroup == 'unit' ? 'unit|${m.examName}' : m.examGroup;
      groups.putIfAbsent(key, () => []).add(m);
    }
    final hasExams = exams.maybeWhen(
      data: (list) => list.any((e) => e.phase != ExamPhase.past),
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.academics)),
      body: SafeArea(
        child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('${l10n.academicYear}: ${student?.academicYear ?? ''}',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),

          // --- exam schedule ---
          exams.maybeWhen(
            data: (list) {
              final relevant = list
                  .where((e) => e.phase != ExamPhase.past)
                  .toList()
                ..sort((a, b) => (a.firstDate ?? DateTime(2100)).compareTo(b.firstDate ?? DateTime(2100)));
              if (relevant.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(title: l10n.examSchedule),
                  ...relevant.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _ExamCard(exam: e),
                      )),
                  const SizedBox(height: AppSpacing.sm),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),

          // --- formal exam results live on their own statement ---
          const ExamDashboardCards(),
          const SizedBox(height: AppSpacing.md),

          // --- report cards ---
          if (groups.isNotEmpty) SectionHeader(title: l10n.reportCards),
          if (groups.isEmpty && !hasExams)
            AppEmptyState(
              icon: Icons.school_outlined,
              title: l10n.noMarksTitle,
              body: l10n.noMarksBody,
            ),
          ...groups.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: MarkResultCard(
                title: e.value.first.examName,
                results: e.value,
                onSubjectTap: (subject) =>
                    AppRoutes.push(context, SubjectDetailScreen(subject: subject)),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  final ParentExam exam;
  const _ExamCard({required this.exam});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return PremiumCard(
      onTap: () => AppRoutes.push(context, ExamTimetableScreen(exam: exam)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(exam.name, style: theme.textTheme.titleMedium)),
              ExamPhaseBadge(phase: exam.phase),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${dateRange(context, exam.firstDate, exam.lastDate)} · ${l10n.exSubjectCount(exam.papers.length)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Text(exam.papers.map((p) => p.subject).join(' · '), style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
