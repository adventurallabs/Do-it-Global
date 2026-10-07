// Opens every screen, sheet and form offline at phone, tablet, laptop and desktop sizes. Fails on any
// build or layout exception (overflow, unbounded constraints, null errors) and on a page whose content
// collapsed to nothing (e.g. a bottom bar that took the whole height).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nuvara/models.dart';
import 'package:nuvara/router.dart';
import 'package:nuvara/screens/admin/fees.dart';
import 'package:nuvara/screens/admin/sessions.dart';
import 'package:nuvara/screens/admin/therapies.dart';
import 'package:nuvara/screens/admin/timetable.dart';
import 'package:nuvara/store.dart';
import 'package:nuvara/theme.dart';
import 'package:nuvara/widgets/account.dart';
import 'package:nuvara/util.dart';
import 'package:provider/provider.dart';

import 'fixtures.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  const sizes = [Size(320, 640), Size(360, 740), Size(412, 915), Size(768, 1024), Size(1024, 768), Size(1366, 768), Size(1920, 1080)];
  final monday = weekStart(todayISO());
  // Screens whose content is a small centred message rather than a full-height list.
  const centred = {'/admin/messages/c4'};

  Future<List<String>> visit(WidgetTester tester, AppStore store, List<String> paths, {Future<void> Function(BuildContext, String)? extra}) async {
    final failures = <String>[];
    final router = buildRouter(store);
    for (final size in sizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(ChangeNotifierProvider.value(value: store, child: MaterialApp.router(theme: buildTheme(), routerConfig: router)));
      for (final p in paths) {
        router.go(p);
        await tester.pumpAndSettle(const Duration(milliseconds: 50), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
        void collect(String where) {
          for (Object? e = tester.takeException(); e != null; e = tester.takeException()) {
            final msg = '$e';
            if (msg.contains('GoogleFonts') || msg.contains('google_fonts')) continue;
            failures.add('${size.width.toInt()}px $where\n$msg');
          }
        }

        collect(p);
        // The page's main scrolling area must have real height on every screen size.
        final tallest = find.byType(Scrollable).evaluate().map((e) => (e.renderObject as RenderBox?)?.size.height ?? 0).fold<double>(0, (a, h) => h > a ? h : a);
        if (tallest < size.height * 0.4 && !centred.contains(p)) failures.add('${size.width.toInt()}px $p: main content is only ${tallest.toInt()}px tall');
        if (extra != null) {
          final ctx = router.routerDelegate.navigatorKey.currentContext!;
          await extra(ctx, p);
          await tester.pumpAndSettle(const Duration(milliseconds: 50), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
          collect('$p (sheet)');
          // Close whatever sheet or dialog was opened.
          router.routerDelegate.navigatorKey.currentState!.popUntil((r) => r is! PopupRoute);
          await tester.pumpAndSettle(const Duration(milliseconds: 50), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
        }
      }
    }
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
    return failures;
  }

  testWidgets('admin screens render', (tester) async {
    final store = demoStore(Role.admin);
    final failures = await visit(tester, store, [
      '/admin',
      '/admin/timetable',
      '/admin/timetable/$monday',
      '/admin/timetable/$monday?view=day',
      '/admin/timetable/${addDays(monday, 7)}',
      '/admin/children',
      '/admin/children/new',
      '/admin/children/c1',
      '/admin/children/c1/edit',
      '/admin/therapists',
      '/admin/therapists/new',
      '/admin/therapists/t1',
      '/admin/therapists/t1/edit',
      '/admin/fees',
      '/admin/fees/c1',
      '/admin/fees/c4',
      '/admin/fees/upi',
      '/admin/fees/verify',
      '/admin/requests',
      '/admin/therapies',
      '/admin/reports',
      '/admin/messages',
      '/admin/messages/c1',
      '/admin/messages/c4',
      '/admin/messages/parents',
      '/admin/messages/therapists',
      '/admin/messages/therapists/t1',
      '/password',
    ]);
    expect(failures, isEmpty, reason: failures.join('\n\n'));
  });

  testWidgets('admin sheets and forms render', (tester) async {
    final store = demoStore(Role.admin);
    final today = todayISO();
    final sheets = <String, Future<void> Function(BuildContext)>{
      'slot sheet': (c) => showSlotSheet(c, 's0-a'),
      'empty slot sheet': (c) => showSlotSheet(c, 'empty'),
      'session sheet': (c) => showSessionSheet(c, 'x0-1'),
      'new session': (c) => showSessionForm(c, date: today, start: '09:30', end: '10:15'),
      'edit session': (c) => showSessionForm(c, date: monday, start: '09:30', end: '10:15', sessionId: 'x0-1'),
      'new slot': (c) => showSlotForm(c, monday: monday),
      'week picker': (c) => showWeekPicker(c, initial: today),
      'therapy sheet': (c) => showTherapySheet(c, therapy: store.therapies.first),
      'payment': (c) => showPaymentSheet(c, store.child('c1')!, store.bill('c1', addDays(monday, -7))!),
      'collect across weeks': (c) => showCollectSheet(c, store.child('c1')!),
      'upi sheet': (c) => showUpiSheet(c, account: store.upiAccounts.first),
      'account sheet': (c) => showAccountSheet(c),
    };
    final failures = <String>[];
    for (final e in sheets.entries) {
      final f = await visit(tester, store, ['/admin'], extra: (c, _) async {
        e.value(c);
      });
      failures.addAll(f.map((x) => '[${e.key}] $x'));
    }
    expect(failures, isEmpty, reason: failures.join('\n\n'));
  });

  testWidgets('therapist screens render', (tester) async {
    final store = demoStore(Role.therapist);
    final failures = await visit(tester, store, ['/therapist', '/therapist/week', '/therapist/children', '/therapist/children/c1', '/therapist/messages', '/therapist/sessions/x0-2', '/therapist/sessions/x${DateTime.now().weekday.clamp(1, 5) - 1}-2']);
    expect(failures, isEmpty, reason: failures.join('\n\n'));
  });

  testWidgets('parent screens render', (tester) async {
    final store = demoStore(Role.parent);
    final failures = await visit(tester, store, ['/parent', '/parent/schedule', '/parent/progress', '/parent/fees', '/parent/messages', '/parent/messages/c1', '/password']);
    expect(failures, isEmpty, reason: failures.join('\n\n'));
  });

  testWidgets('a link straight to a form can still go back (web refresh / deep link)', (tester) async {
    final store = demoStore(Role.admin);
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    final router = buildRouter(store);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: store, child: MaterialApp.router(theme: buildTheme(), routerConfig: router)));
    router.go('/admin/children/c1/edit');
    await tester.pumpAndSettle();
    expect(find.text('Edit child'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/admin/children/c1');
    router.pop();
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/admin/children');
    router.go('/admin/therapists/t1/edit');
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/admin/therapists/t1');
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  });

  testWidgets('signing in with the default password holds them on "set your own password"', (tester) async {
    final store = demoStore(Role.parent)..mustChangePassword = true;
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    final router = buildRouter(store);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: store, child: MaterialApp.router(theme: buildTheme(), routerConfig: router)));
    for (final p in ['/parent', '/parent/fees', '/parent/messages/c1']) {
      router.go(p);
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/password', reason: '$p is out of reach');
    }
    expect(find.text('Set your own password'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    store.mustChangePassword = false;
    await tester.pumpAndSettle();
    router.go('/password');
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/parent', reason: 'otherwise parents cannot change their password');
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  });

  testWidgets('session form blocks busy people', (tester) async {
    final store = demoStore(Role.admin);
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    final router = buildRouter(store);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: store, child: MaterialApp.router(theme: buildTheme(), routerConfig: router)));
    router.go('/admin');
    await tester.pumpAndSettle();
    final ctx = router.routerDelegate.navigatorKey.currentContext!;
    showSessionForm(ctx, date: monday, start: '09:45', end: '10:30');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select a therapist'));
    await tester.pumpAndSettle();
    // 09:45–10:30 overlaps both slots, so all three therapists are busy.
    expect(find.textContaining('Busy · In "Speech group"'), findsOneWidget);
    expect(find.textContaining('Busy · In "Behaviour"'), findsOneWidget);
    expect(find.textContaining('Busy · In "OT room"'), findsOneWidget);
    expect(find.text('0 of 3 available at this time'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  });
}
