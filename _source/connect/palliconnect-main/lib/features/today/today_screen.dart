import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/auth/session_provider.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/features/feature_registry.dart';
import '../../core/localization/l10n_ext.dart';
import '../../core/navigation/app_routes.dart';
import '../../shared/models/homework.dart';
import '../../shared/widgets/announcement_card.dart';
import '../../shared/widgets/announcement_overlay.dart';
import '../../shared/widgets/attention_alert_card.dart';
import '../profile/complete_profile_screen.dart';
import '../../shared/widgets/fee_summary_card.dart';
import '../../shared/widgets/homework_card.dart';
import '../../shared/widgets/notification_bell.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/student_switcher.dart';
import '../exams/exam_dashboard_cards.dart';
import '../exams/exam_providers.dart';
import '../fees/fees_screen.dart';
import '../homework/homework_screen.dart';
import '../library/borrowed_books_card.dart';
import '../library/library_providers.dart';
import '../parent/parent_store.dart';
import '../progress/attendance_screen.dart';
import '../school_life/school_life_providers.dart';
import 'widgets/school_day_cards.dart';
import 'widgets/school_life_shortcuts.dart';
import 'widgets/today_periods_card.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  String _greeting(BuildContext context) {
    final hour = DateTime.now().hour;
    final l10n = context.l10n;
    if (hour < 12) return l10n.goodMorning;
    if (hour < 17) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final registry = ref.watch(featureRegistryProvider);
    final student = ref.watch(currentStudentProvider);
    final homework = ref.watch(studentHomeworkProvider);
    final attention = ref.watch(attentionItemsProvider);
    final announcements = ref.watch(studentAnnouncementsProvider);
    final fees = ref.watch(studentFeesProvider);
    final schoolDay = ref.watch(studentSchoolDayProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    final synced = ref.watch(sessionProvider).lastSyncedAt;
    final now = DateTime.now();
    final firstName = student?.firstName ?? '';

    final todayItems = homework
        .where(
          (h) =>
              h.urgencyOn(now) == HomeworkUrgency.dueToday ||
              h.urgencyOn(now) == HomeworkUrgency.overdue,
        )
        .toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () {
            ref.invalidate(classTimetableProvider);
            ref.invalidate(eventNoticesProvider);
            ref.invalidate(parentExamsProvider);
            ref.invalidate(parentExamMarksProvider);
            ref.invalidate(libraryLoansProvider);
            return ref.read(sessionProvider.notifier).refresh();
          },
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _greeting(context),
                          style: theme.textTheme.headlineMedium,
                        ),
                      ),
                      NotificationBell(count: unread),
                    ],
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                sliver: SliverToBoxAdapter(child: StudentSwitcherHeader()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    DateFormat(
                      'EEEE, MMMM d',
                      Localizations.localeOf(context).toString(),
                    ).format(now),
                    style: theme.textTheme.labelMedium?.copyWith(
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
              if (student != null)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: SchoolDayHeroCard(
                      title: l10n.schoolDayTitle(firstName),
                      subtitle: l10n.todayAtSchool,
                    ),
                  ),
                ),
              if (student != null)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(child: SchoolLifeShortcuts()),
                ),
              if (student != null)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(child: ExamDashboardCards()),
                ),
              // Only there once this child has borrowed a library book.
              if (student != null)
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  sliver: SliverToBoxAdapter(child: BorrowedBooksCard()),
                ),
              if (student != null && registry.isEnabled('timetable'))
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(child: TodayPeriodsCard()),
                ),
              if (registry.isEnabled('homework')) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: SectionHeader(
                      title: l10n.homeworkStatus,
                      actionLabel: l10n.seeAllHomework,
                      onAction: () =>
                          AppRoutes.push(context, const HomeworkScreen()),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  sliver: SliverList.separated(
                    itemCount: todayItems.isEmpty
                        ? 1
                        : todayItems.length.clamp(0, 3),
                    separatorBuilder: (_, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      if (todayItems.isEmpty) {
                        return PremiumCard(
                          child: Text(
                            l10n.noHomeworkTitle,
                            style: theme.textTheme.titleMedium,
                          ),
                        );
                      }
                      final item = todayItems[i];
                      return HomeworkCard(
                        item: item,
                        onToggle: () => ref
                            .read(parentStoreProvider.notifier)
                            .toggleHomework(item.id),
                        onOpen: () => AppRoutes.push(
                          context,
                          HomeworkScreen(highlightId: item.id),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (schoolDay != null) ...[
                if (schoolDay.learning.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.md,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: SchoolDaySectionCard(
                        title: l10n.todaysLearning,
                        subtitle: firstName.isEmpty
                            ? null
                            : l10n.whatStudentLearned(firstName),
                        accent: AppColors.leafGreen,
                        child: LearningList(items: schoolDay.learning),
                      ),
                    ),
                  ),
                if (schoolDay.teacherNote.trim().isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.md,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: SchoolDaySectionCard(
                        title: l10n.todaysHighlight,
                        subtitle: l10n.teachersNote,
                        accent: AppColors.heart,
                        child: Text(
                          schoolDay.teacherNote,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ),
                  ),
                if (schoolDay.growingIn.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.md,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: SchoolDaySectionCard(
                        title: l10n.growingIn,
                        subtitle: l10n.todaysGrowth,
                        accent: AppColors.skyBlue,
                        child: GrowthSignalsRow(signals: schoolDay.growingIn),
                      ),
                    ),
                  ),
              ],
              if (attention.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: SectionHeader(title: l10n.needsAttention),
                  ),
                ),
              if (attention.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  sliver: SliverList.separated(
                    itemCount: attention.length,
                    separatorBuilder: (_, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      final item = attention[i];
                      if (item.deepLink == 'fees' &&
                          !registry.isEnabled('fees')) {
                        return const SizedBox.shrink();
                      }
                      if (item.deepLink == 'homework' &&
                          !registry.isEnabled('homework')) {
                        return const SizedBox.shrink();
                      }

                      return AttentionAlertCard(
                        item: item,
                        onTap: () =>
                            _openLink(context, ref, item.deepLink, registry),
                      );
                    },
                  ),
                ),
              if (registry.isEnabled('fees') && fees != null && fees.hasDue)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: FeeSummaryCard(
                      account: fees,
                      onTap: () => AppRoutes.push(context, const FeesScreen()),
                    ),
                  ),
                ),
              if (registry.isEnabled('announcements') &&
                  announcements.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: SectionHeader(title: l10n.updates),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  sliver: SliverList.separated(
                    itemCount: announcements.length,
                    separatorBuilder: (_, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      final announcement = announcements[i];
                      return AnnouncementCard(
                        announcement: announcement,
                        onTap: () => AnnouncementDetailOverlay.show(
                          context,
                          announcement,
                        ),
                      );
                    },
                  ),
                ),
              ],
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    108,
                  ),
                  child: Text(
                    l10n.lastUpdated(
                      DateFormat.jm(
                        Localizations.localeOf(context).toString(),
                      ).format(synced),
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openLink(
    BuildContext context,
    WidgetRef ref,
    String link,
    FeatureRegistry registry,
  ) {
    if (link == 'profile-gaps') {
      // Always reachable: the school is waiting on these, and there is no
      // feature flag that should be able to hide that.
      CompleteProfileScreen.open(context);
    } else if (link.startsWith('homework') && registry.isEnabled('homework')) {
      AppRoutes.push(context, const HomeworkScreen());
    } else if (link == 'fees' && registry.isEnabled('fees')) {
      AppRoutes.push(context, const FeesScreen());
    } else if (link == 'attendance' && registry.isEnabled('attendance')) {
      AppRoutes.push(context, const AttendanceScreen());
    } else if (link.startsWith('announcement')) {
      final announcements = ref.read(studentAnnouncementsProvider);
      if (announcements.isEmpty) return;

      final parts = link.split(':');
      if (parts.length > 1) {
        final id = parts[1];
        try {
          final announcement = announcements.firstWhere((a) => a.id == id);
          AnnouncementDetailOverlay.show(context, announcement);
          return;
        } catch (_) {}
      }

      // Fallback: show the first announcement if ID is missing or not found
      AnnouncementDetailOverlay.show(context, announcements.first);
    }
  }
}
