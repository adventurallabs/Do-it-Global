import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_admin_classroom/feature_admin_classroom.dart';
import 'package:feature_admin_timetable/feature_admin_timetable.dart';
import 'package:feature_admin_directory/feature_admin_directory.dart';
import 'package:feature_announcements/feature_announcements.dart';
import 'package:feature_bus_tracking/feature_bus_tracking.dart';
import 'package:feature_teacher_tools/feature_teacher_tools.dart';
import 'package:feature_admin_events/feature_admin_events.dart';
import 'package:feature_admin_fees/feature_admin_fees.dart';
import 'package:feature_admin_ops/feature_admin_ops.dart';
import 'package:feature_library/feature_library.dart';
import 'package:flutter/foundation.dart';
import 'admin_main_screen.dart';
import 'notification_center_screen.dart';
import 'premium_surface_gallery.dart';
import 'splash_screen.dart';
import 'teacher_main_screen.dart';
import 'package:core_models/core_models.dart';
import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart';

/// Entry screens (splash -> login -> home) replace each other, they don't
/// stack — so they fade through an opaque backdrop instead of sliding. The
/// old cross-fade drew a transparent page over the previous one, which is
/// what made a screen's layout appear on top of the last.
CustomTransitionPage<void> _fade(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 460),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: fadeThroughTransition,
  );
}

final router = GoRouter(
  initialLocation: '/splash',
  refreshListenable: Listenable.merge([authStateNotifier, splashMinDurationNotifier]),
  routes: [
    GoRoute(
      path: '/splash',
      pageBuilder: (context, state) => _fade(state, const SplashScreen()),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => _fade(state, const LoginScreen()),
    ),
    GoRoute(
      path: '/force-password-change',
      pageBuilder: (context, state) => _fade(state, const ForcePasswordChangeScreen()),
    ),
    // Admin Routes
    ShellRoute(
      builder: (context, state, child) => child,
      routes: [
        GoRoute(
          path: '/admin',
          pageBuilder: (context, state) => _fade(state, const AdminMainScreen()),
          routes: [
        GoRoute(
          path: 'classrooms',
          builder: (context, state) => const ClassroomDashboard(),
        ),
        GoRoute(
          path: 'timetable/:classroomId',
          builder: (context, state) => TimetableDashboard(classroomId: state.pathParameters['classroomId']!),
        ),
        GoRoute(
          path: 'directory',
          builder: (context, state) => DirectoryScreen(
            initialTab: state.uri.queryParameters['tab'] ?? 'students',
          ),
        ),
        GoRoute(
          path: 'announcements',
          builder: (context, state) => const AnnouncementScreen(),
        ),
        GoRoute(
          path: 'bus-tracking',
          builder: (context, state) => const BusTrackingScreen(),
        ),
        GoRoute(
          path: 'events',
          builder: (context, state) => const EventListScreen(),
        ),
        GoRoute(
          path: 'fees',
          builder: (context, state) => const FeeDashboard(),
        ),
        GoRoute(
          path: 'attendance',
          builder: (context, state) => const AttendanceOverviewScreen(),
        ),
        GoRoute(
          path: 'leave',
          builder: (context, state) => const LeaveDeskScreen(),
        ),
        GoRoute(
          path: 'academics',
          builder: (context, state) => const AcademicsScreen(),
        ),
        GoRoute(
          path: 'discontinued',
          builder: (context, state) => const ArchiveScreen(kind: ArchiveKind.discontinued),
        ),
        GoRoute(
          path: 'graduated',
          builder: (context, state) => const ArchiveScreen(kind: ArchiveKind.graduated),
        ),
        GoRoute(
          path: 'exams',
          builder: (context, state) => const ExamsScreen(),
        ),
        GoRoute(
          path: 'results',
          builder: (context, state) => const ExamsScreen(mode: ExamsMode.results),
        ),
        GoRoute(
          path: 'admissions',
          builder: (context, state) => const AdmissionsScreen(),
        ),
        GoRoute(
          path: 'student-leave',
          builder: (context, state) {
            final s = authStateNotifier.value;
            return StudentLeaveDeskScreen(
              reviewerId: s is LoginSuccess ? s.user.id : '',
            );
          },
        ),
        GoRoute(
          path: 'notifications',
          builder: (context, state) {
            final s = authStateNotifier.value;
            return NotificationCenterScreen(
              role: NotificationRecipientRole.admin,
              recipientId: s is LoginSuccess ? s.user.id : '',
            );
          },
        ),
        GoRoute(
          path: 'surface-preview',
          builder: (context, state) => const PremiumSurfaceGallery(),
        ),
          ],
        ),
      ],
    ),
    // Librarian — its own screens push with Navigator from here.
    GoRoute(
      path: '/library',
      pageBuilder: (context, state) => _fade(state, const LibraryHomeScreen()),
    ),
    // Teacher Routes
    GoRoute(
      path: '/teacher',
      pageBuilder: (context, state) => _fade(state, const TeacherMainScreen()),
      routes: [
        GoRoute(
          path: 'tools',
          builder: (context, state) {
            final state = authStateNotifier.value;
            final teacherId = state is LoginSuccess ? state.user.id : '';
            return TeacherToolsScreen(teacherId: teacherId);
          },
        ),
        GoRoute(
          path: 'messages',
          builder: (context, state) {
            final s = authStateNotifier.value;
            return TeacherMessagesScreen(teacherId: s is LoginSuccess ? s.user.id : '');
          },
        ),
        GoRoute(
          path: 'student-leave',
          builder: (context, state) {
            final s = authStateNotifier.value;
            return StudentLeaveDeskScreen(
              reviewerId: s is LoginSuccess ? s.user.id : '',
            );
          },
        ),
        GoRoute(
          path: 'notifications',
          builder: (context, state) {
            final s = authStateNotifier.value;
            return NotificationCenterScreen(
              role: NotificationRecipientRole.teacher,
              recipientId: s is LoginSuccess ? s.user.id : '',
            );
          },
        ),
        GoRoute(
          path: 'cover-requests',
          builder: (context, state) {
            final s = authStateNotifier.value;
            return CoverRequestsScreen(teacherId: s is LoginSuccess ? s.user.id : '');
          },
        ),
        GoRoute(
          path: 'exams',
          builder: (context, state) {
            final s = authStateNotifier.value;
            return TeacherExamsScreen(teacherId: s is LoginSuccess ? s.user.id : '');
          },
        ),
        GoRoute(
          path: 'results',
          builder: (context, state) {
            final s = authStateNotifier.value;
            return TeacherResultsScreen(teacherId: s is LoginSuccess ? s.user.id : '');
          },
        ),
      ],
    ),
  ],
  redirect: (context, state) {
    final loginState = authStateNotifier.value;
    final splashing = state.matchedLocation == '/splash';
    final loggingIn = state.matchedLocation == '/login';
    final changingPassword = state.matchedLocation == '/force-password-change';

    // Hold the splash route until both the session check has come back and
    // the brand moment has had its minimum time on screen — whichever is
    // later — so a returning signed-in user never sees a flash of /login.
    final stillResolving = loginState is LoginSessionUnresolved || !splashMinDurationNotifier.value;
    if (stillResolving) {
      return splashing ? null : '/splash';
    }
    // Auth state is resolved — fall through to pick the right destination;
    // this also carries a still-mounted /splash away to /login or /admin|/teacher.

    if (loginState is! LoginSuccess) {
      return loggingIn ? null : '/login';
    }

    // Locked to the force-password-change screen until it's done — enforced
    // again server-side by RLS, this is just so the UI doesn't dead-end.
    if (loginState.user.mustChangePassword) {
      return changingPassword ? null : '/force-password-change';
    }
    final home = _homeFor(loginState.user.role);
    if (changingPassword || loggingIn || splashing) return home;

    // Each role has exactly one area of the app. The librarian signs in
    // like a teacher but only ever sees the library, and nobody else can
    // open it (the database refuses them anyway).
    final location = state.matchedLocation;
    final area = location.startsWith('/admin')
        ? '/admin'
        : location.startsWith('/teacher')
            ? '/teacher'
            : location.startsWith('/library')
                ? '/library'
                : null;
    if (area != null && area != home) return home;

    return null;
  },
);

String _homeFor(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return '/admin';
    case UserRole.teacher:
      return '/teacher';
    case UserRole.librarian:
      return '/library';
  }
}
