import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'assessment/screen.dart';
import 'models.dart';
import 'screens/admin/child_form.dart';
import 'screens/admin/children.dart';
import 'screens/admin/fees.dart';
import 'screens/admin/home.dart';
import 'screens/admin/reports.dart';
import 'screens/admin/requests.dart';
import 'screens/admin/therapies.dart';
import 'screens/admin/therapists.dart';
import 'screens/admin/timetable.dart';
import 'screens/admin/week.dart';
import 'screens/login.dart';
import 'screens/messages.dart';
import 'screens/password.dart';
import 'screens/parent/parent.dart';
import 'screens/therapist/therapist.dart';
import 'store.dart';
import 'widgets/shell.dart';

/// One app, three role areas. Tabs live inside the role's [Shell]; detail screens and forms are nested
/// under their tab but open full screen on top of it. Because of the nesting, a link or a browser
/// refresh on any screen rebuilds the screens beneath it, so back always has somewhere to go.
/// What each role can read or change is enforced by the database.
GoRouter buildRouter(AppStore store) {
  final rootKey = GlobalKey<NavigatorState>();
  // Each tab is its own branch, so it keeps its search, filters and scroll position when you switch away.
  StatefulShellBranch tab(String path, Widget Function(GoRouterState) build, [List<RouteBase> screens = const []]) => StatefulShellBranch(
        routes: [GoRoute(path: path, pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(path), child: build(state)), routes: screens)],
      );
  GoRoute screen(String path, Widget Function(GoRouterState) build, [List<RouteBase> screens = const []]) =>
      GoRoute(path: path, parentNavigatorKey: rootKey, pageBuilder: (context, state) => MaterialPage(key: state.pageKey, child: build(state)), routes: screens);
  StatefulShellRoute area(Role role, List<StatefulShellBranch> tabs) => StatefulShellRoute(
        builder: (context, state, shell) => Shell(role: role, shell: shell),
        navigatorContainerBuilder: (context, shell, children) => TabStack(index: shell.currentIndex, children: children),
        branches: tabs,
      );
  String id(GoRouterState s) => s.pathParameters['id']!;

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/login',
    refreshListenable: Listenable.merge([store.auth, store.gate]),
    redirect: (context, state) {
      final role = store.role;
      final loc = state.matchedLocation;
      if (role == null) return loc == '/login' ? null : '/login';
      // Signed in with the default password: nothing else until they set their own.
      if (store.mustChangePassword) return loc == '/password' ? null : '/password';
      // Otherwise only admins change their password; the centre resets everyone else's.
      if (loc == '/password') return role == Role.admin ? null : role.home;
      if (loc == '/login' || !(loc == role.home || loc.startsWith('${role.home}/'))) return role.home;
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      screen('/password', (_) => const PasswordScreen()),
      area(Role.admin, [
        tab('/admin', (_) => const AdminHome(), [
          screen('therapists', (_) => const TherapistsTab(), [
            screen('new', (_) => const TherapistFormScreen()),
            screen(':id', (s) => TherapistDetailScreen(id(s)), [
              screen('edit', (s) => TherapistFormScreen(therapistId: id(s))),
            ]),
          ]),
          screen('therapies', (_) => const TherapiesScreen()),
          screen('requests', (s) => RequestsScreen(focus: s.uri.queryParameters['focus'])),
          screen('reports', (_) => const PendingReportsScreen()),
        ]),
        tab('/admin/timetable', (_) => const TimetablesTab(), [
          screen(':monday', (s) => WeekScreen(monday: s.pathParameters['monday']!, startInDayView: s.uri.queryParameters['view'] == 'day')),
        ]),
        tab('/admin/children', (_) => const ChildrenTab(), [
          screen('new', (_) => const ChildFormScreen(), [
            // The intake assessment of a child not created yet.
            screen('assessment/:aid', (s) => AssessmentScreen(s.pathParameters['aid']!)),
          ]),
          screen(':id', (s) => ChildDetailScreen(id(s)), [
            screen('edit', (s) => ChildFormScreen(childId: id(s))),
            screen('assessments/:aid', (s) => AssessmentScreen(s.pathParameters['aid']!)),
          ]),
        ]),
        tab('/admin/fees', (_) => const FeesTab(), [
          screen('upi', (_) => const UpiSettingsScreen()),
          screen('verify', (_) => const PaymentsReviewScreen()),
          screen(':id', (s) => FeeDetailScreen(id(s), week: s.uri.queryParameters['week'])),
        ]),
        tab('/admin/messages', (_) => const AdminInbox(), [
          screen('parents', (_) => const AdminPeople(therapists: false)),
          screen('therapists', (_) => const AdminPeople(therapists: true), [
            screen(':id', (s) => ChatScreen(Convo.therapist(id(s)))),
          ]),
          screen(':id', (s) => ChatScreen(Convo.family(id(s)))),
        ]),
      ]),
      area(Role.therapist, [
        tab('/therapist', (_) => const TherapistToday(), [
          screen('sessions/:id', (s) => TherapistSessionScreen(id(s))),
        ]),
        tab('/therapist/week', (_) => const TherapistWeek()),
        tab('/therapist/children', (_) => const TherapistChildren(), [
          screen(':id', (s) => TherapistChildDetail(id(s)), [
            screen('assessments/:aid', (s) => AssessmentScreen(s.pathParameters['aid']!)),
          ]),
        ]),
        tab('/therapist/messages', (_) => const TherapistMessages()),
      ]),
      area(Role.parent, [
        tab('/parent', (_) => const ParentHome()),
        tab('/parent/schedule', (_) => const ParentSchedule()),
        tab('/parent/progress', (_) => const ParentProgress()),
        tab('/parent/fees', (_) => const ParentFees()),
        tab('/parent/messages', (_) => const ParentMessages(), [
          screen(':id', (s) => ChatScreen(Convo.family(id(s)))),
        ]),
      ]),
    ],
  );
}
