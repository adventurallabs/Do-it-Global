import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/session_provider.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/localization/l10n_ext.dart';
import '../../core/navigation/app_routes.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/notification_item.dart';
import '../diary/diary_screen.dart';
import '../exams/exams_screen.dart';
import '../exams/results_screen.dart';
import '../fees/fees_screen.dart';
import '../library/borrowed_books_screen.dart';
import '../homework/homework_screen.dart';
import '../messages/message_screen.dart';
import '../messages/message_store.dart';
import '../parent/parent_store.dart';
import '../progress/academics_screen.dart';
import '../progress/attendance_screen.dart';
import '../progress/activities_screen.dart';
import '../progress/growth_screen.dart';
import '../progress/stars_screen.dart';
import '../school_life/events_screen.dart';
import '../../shared/widgets/announcement_overlay.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final items = ref.watch(studentNotificationsProvider);
    final student = ref.watch(currentStudentProvider);
    final theme = Theme.of(context);

    if (items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.notifications)),
        body: AppEmptyState(
          icon: Icons.notifications_none_rounded,
          title: l10n.noNotificationsTitle,
          body: l10n.noNotificationsBody,
        ),
      );
    }

    final groups = <String, List<int>>{};
    for (var i = 0; i < items.length; i++) {
      final label = notificationSectionLabel(context, items[i].createdAt);
      groups.putIfAbsent(label, () => []).add(i);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notifications)),
      body: SafeArea(
        child: ListView(
        children: [
          for (final entry in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
              child: Text(entry.key, style: theme.textTheme.titleLarge),
            ),
            ...entry.value.map(
              (i) => NotificationItemCard(
                item: items[i],
                onTap: () {
                  if (!items[i].read && student != null) {
                    ref.read(parentStoreProvider.notifier)
                        .markNotificationRead(student.id, items[i].id);
                  }
                  _open(context, ref, items[i].deepLink);
                },
              ),
            ),
          ],
        ],
        ),
      ),
    );
  }

  void _open(BuildContext context, WidgetRef ref, String link) {
    if (link.startsWith('homework')) {
      AppRoutes.push(context, const HomeworkScreen());
    } else if (link == 'fees') {
      AppRoutes.push(context, const FeesScreen());
    } else if (link.startsWith('exam:')) {
      // exam:<examId>:<grade>
      final parts = link.split(':');
      AppRoutes.push(context, ExamsScreen(openExamId: parts.length > 1 ? parts[1] : null));
    } else if (link.startsWith('result:')) {
      AppRoutes.push(context, ResultsScreen(openExamId: link.substring('result:'.length)));
    } else if (link == 'marks') {
      AppRoutes.push(context, const AcademicsScreen());
    } else if (link == 'attendance') {
      AppRoutes.push(context, const AttendanceScreen());
    } else if (link.startsWith('activity')) {
      AppRoutes.push(context, const ActivitiesScreen());
    } else if (link == 'stars') {
      AppRoutes.push(context, const StarsScreen());
    } else if (link == 'growth') {
      AppRoutes.push(context, const GrowthScreen());
    } else if (link.startsWith('event')) {
      AppRoutes.push(context, const EventsScreen());
    } else if (link.startsWith('thread') || link.startsWith('leave')) {
      ref.read(messageProvider.notifier).markRead();
      AppRoutes.push(context, MessageScreen(onBack: () => Navigator.pop(context)));
    } else if (link.startsWith('library')) {
      // library:<loanId>
      final id = link.contains(':') ? link.split(':')[1] : null;
      AppRoutes.push(context, BorrowedBooksScreen(highlightLoanId: id));
    } else if (link == 'diary') {
      AppRoutes.push(context, const DiaryScreen());
    } else if (link == 'today') {
      // handled by the bottom nav; nothing to push
    } else if (link.startsWith('announcement')) {
      final announcements = ref.read(studentAnnouncementsProvider);
      if (announcements.isEmpty) return;
      final id = link.contains(':') ? link.split(':')[1] : '';
      final match = announcements.where((a) => a.id == id);
      AnnouncementDetailOverlay.show(
          context, match.isNotEmpty ? match.first : announcements.first);
    }
  }
}
