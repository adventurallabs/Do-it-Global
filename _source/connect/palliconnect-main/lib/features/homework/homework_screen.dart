import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/localization/l10n_ext.dart';
import '../../core/navigation/app_routes.dart';
import '../../shared/models/homework.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/homework_card.dart';
import '../../shared/widgets/homework_status.dart';
import '../parent/parent_store.dart';
import 'homework_detail_screen.dart';

enum HomeworkFilter { pending, review, completed }

class HomeworkScreen extends ConsumerStatefulWidget {
  const HomeworkScreen({super.key, this.highlightId});

  final String? highlightId;

  @override
  ConsumerState<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends ConsumerState<HomeworkScreen> {
  HomeworkFilter _filter = HomeworkFilter.pending;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final all = ref.watch(studentHomeworkProvider);
    
    final visible = all.where((h) {
      switch (_filter) {
        case HomeworkFilter.pending:
          return h.status == HomeworkStatus.pending || h.status == HomeworkStatus.underReview;
        case HomeworkFilter.review:
          return h.status == HomeworkStatus.underReview;
        case HomeworkFilter.completed:
          return h.status == HomeworkStatus.completed;
      }
    }).toList();

    final done = all.where((h) => h.status == HomeworkStatus.completed).length;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homework)),
      body: SafeArea(
        child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (all.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: HomeworkProgressBar(
                done: done,
                total: all.length,
                label: l10n.homeworkProgress(done, all.length),
              ),
            ),
          SegmentedButton<HomeworkFilter>(
            segments: [
              ButtonSegment(value: HomeworkFilter.pending, label: Text(l10n.filterPending)),
              ButtonSegment(value: HomeworkFilter.review, label: Text(l10n.underReview)),
              ButtonSegment(value: HomeworkFilter.completed, label: Text(l10n.filterCompleted)),
            ],
            selected: {_filter},
            onSelectionChanged: (s) => setState(() => _filter = s.first),
          ),
          const SizedBox(height: AppSpacing.lg),
          
          if (visible.isEmpty)
            _buildEmptyState(context, _filter)
          else
            ..._grouped(context, visible).expand((section) {
              return [
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm, top: AppSpacing.sm),
                  child: Text(section.$1, style: theme.textTheme.titleLarge),
                ),
                ...section.$2.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: HomeworkCard(
                      item: item,
                      onOpen: () => AppRoutes.push(context, HomeworkDetailScreen(item: item)),
                      onToggle: () =>
                          ref.read(parentStoreProvider.notifier).toggleHomework(item.id),
                    ),
                  ),
                ),
              ];
            }),
        ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, HomeworkFilter filter) {
    final l10n = context.l10n;
    return switch (filter) {
      HomeworkFilter.pending => AppEmptyState(
          icon: Icons.celebration_outlined,
          title: l10n.noPendingHomework,
          body: l10n.noHomeworkBody,
        ),
      HomeworkFilter.review => AppEmptyState(
          icon: Icons.access_time_outlined,
          title: l10n.noReviewHomework,
          body: 'Check back later for teacher approval.',
        ),
      HomeworkFilter.completed => AppEmptyState(
          icon: Icons.task_alt_outlined,
          title: l10n.noCompletedHomework,
          body: 'Stay consistent!',
        ),
    };
  }

  List<(String, List<HomeworkItem>)> _grouped(BuildContext context, List<HomeworkItem> items) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final overdue = items.where((h) => h.status != HomeworkStatus.completed && h.urgencyOn(now) == HomeworkUrgency.overdue).toList();
    final today = items.where((h) => h.status != HomeworkStatus.completed && h.urgencyOn(now) == HomeworkUrgency.dueToday).toList();
    final upcoming = items.where((h) => h.status != HomeworkStatus.completed && h.urgencyOn(now) == HomeworkUrgency.upcoming).toList();
    final done = items.where((h) => h.status == HomeworkStatus.completed).toList();
    
    return [
      if (overdue.isNotEmpty) (l10n.overdue, overdue),
      if (today.isNotEmpty) (l10n.dueToday, today),
      if (upcoming.isNotEmpty) (l10n.upcoming, upcoming),
      if (done.isNotEmpty) (l10n.completed, done),
    ];
  }
}
