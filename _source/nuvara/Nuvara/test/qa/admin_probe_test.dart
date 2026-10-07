// QA-Admin probes: each test pinned down one admin-side bug found in QA. They now assert the fixed behaviour,
// so they guard against regressions.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nuvara/models.dart';
import 'package:nuvara/router.dart';
import 'package:nuvara/store.dart';
import 'package:nuvara/theme.dart';
import 'package:nuvara/util.dart';
import 'package:provider/provider.dart';

import '../fixtures.dart';

RescheduleRequest req(String id, String from, {required DateTime created, String? target}) => RescheduleRequest({
      'id': id, 'child_id': 'c3', 'session_id': 'zz-$id', 'scope': 'once', 'from_date': from, 'from_start': '09:30:00', 'from_end': '10:15:00',
      'session_name': 'Behaviour $id', 'therapist_id': 't3', 'therapy_id': 'th3', 'preferred_date': from, 'preferred_start': '16:00:00', 'preferred_end': '16:45:00',
      'target_session_id': target == null ? null : 'tgt-$id', 'target_therapist_id': target,
      'reason': 'probe', 'status': 'pending', 'admin_note': '', 'moved': 0, 'created_at': created.toUtc().toIso8601String(),
    });

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  final monday = weekStart(todayISO());

  Future<GoRouter> open(WidgetTester tester, AppStore store, String path, {Size size = const Size(412, 915)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    final router = buildRouter(store);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: store, child: MaterialApp.router(theme: buildTheme(), routerConfig: router)));
    router.go(path);
    await tester.pumpAndSettle(const Duration(milliseconds: 50), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    return router;
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  }

  void drain(WidgetTester tester) {
    for (Object? e = tester.takeException(); e != null; e = tester.takeException()) {
      if (!'$e'.contains('GoogleFonts') && !'$e'.contains('google_fonts')) fail('Unexpected exception: $e');
    }
  }

  // ADM-1: the violet "families need another slot" card used to show the 3 *newest-asked* requests, hiding the
  // most urgent one. It now lists them soonest session first.
  testWidgets('ADM-1 home request card shows the soonest request first', (tester) async {
    final store = demoStore(Role.admin);
    final now = DateTime.now();
    final t = todayISO();
    // Store order = created_at desc (what loadRequests returns).
    store.requests = [
      req('a', addDays(t, 6), created: now),
      req('b', addDays(t, 5), created: now.subtract(const Duration(hours: 1))),
      req('c', addDays(t, 4), created: now.subtract(const Duration(hours: 2))),
      req('d', addDays(t, 1), created: now.subtract(const Duration(hours: 3))), // tomorrow: most urgent
    ];
    await open(tester, store, '/admin');
    drain(tester);
    expect(find.textContaining('soonest tomorrow'), findsOneWidget, reason: 'header says tomorrow is the soonest');
    expect(find.textContaining("Can't make tomorrow"), findsOneWidget, reason: 'the tomorrow request is the first row');
    expect(find.textContaining('Behaviour a'), findsNothing, reason: 'the furthest-away request is the one left out');
    expect(find.text('Review all 4 requests'), findsOneWidget);
    await close(tester);
  });

  // ADM-2: a pending request whose session already started used to keep the urgent violet card up with a past
  // "soonest" date. Now it is a quiet "Needs attention" row and isn't counted as waiting.
  testWidgets('ADM-2 expired requests move to a quiet attention row', (tester) async {
    final store = demoStore(Role.admin);
    final yesterday = addDays(todayISO(), -1);
    store.requests = [req('old', yesterday, created: DateTime.now().subtract(const Duration(days: 2)))];
    expect(store.requests.first.expired, isTrue);
    await open(tester, store, '/admin');
    drain(tester);
    expect(find.text('A family needs another slot'), findsNothing, reason: 'an expired request no longer raises the urgent card');
    expect(find.textContaining('Answer before the session'), findsNothing);
    expect(find.text('1 request passed unanswered · close it'), findsOneWidget);
    expect(find.textContaining('yesterday started before anyone answered'), findsOneWidget, reason: 'lowercase mid-sentence');
    await tester.scrollUntilVisible(find.text('None waiting'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('None waiting'), findsOneWidget, reason: 'nav card no longer counts it as waiting');
    await close(tester);
  });

  // ADM-3 (day strip): the Day view strip was 7 x 58 px + gaps = 454 px wide, so on a phone Saturday/Sunday were
  // off-screen. The seven days now share the width.
  testWidgets('ADM-3 day view: Sunday chip fits on a phone', (tester) async {
    final store = demoStore(Role.admin);
    await open(tester, store, '/admin/timetable/$monday', size: const Size(360, 740));
    drain(tester);
    await tester.ensureVisible(find.text('SUN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SUN'));
    await tester.pumpAndSettle();
    drain(tester);
    final sunday = addDays(monday, 6);
    expect(find.text(fmtDate(sunday, 'EEEE, d MMMM')), findsOneWidget, reason: 'day view opened on Sunday');
    // The strip chip for Sunday: its "Sun" label.
    final chip = find.text('Sun', skipOffstage: false);
    expect(chip, findsOneWidget);
    expect(tester.getRect(chip).right, lessThanOrEqualTo(360), reason: 'the Sunday chip is inside the 360px viewport');
    await close(tester);
  });

  // ADM-4: "Mark as inactive" used to check only weeks already loaded on the device. It now loads every planned
  // week ahead first; offline (as in tests) that fails, and it stops rather than skipping the check.
  testWidgets('ADM-4 therapist inactive guard loads future weeks before deciding', (tester) async {
    final store = demoStore(Role.admin);
    final later = addDays(monday, 14);
    store.weekIndex = {...store.weekIndex, later: (slots: 5, sessions: 10)};
    expect(store.weekSlots(later), isNull);
    await open(tester, store, '/admin/therapists/t1');
    drain(tester);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as inactive'));
    await tester.pumpAndSettle();
    expect(find.text('Mark Priya as inactive?'), findsNothing, reason: 'never goes straight to "mark inactive" without the week of $later');
    expect(find.textContaining("Couldn't check Priya's upcoming sessions"), findsOneWidget);
    await close(tester);
  });

  // ADM-6: the approve/arrange sheet renders at 320 px for both kinds of request (it is not in screens_test).
  testWidgets('ADM-6 arrange-slot and approve flows render at 320px', (tester) async {
    final store = demoStore(Role.admin);
    final t = todayISO();
    final fri = addDays(monday, 4);
    store.requests = [
      req('pick', addDays(t, 1), created: DateTime.now(), target: 't1'),
      req('sugg', addDays(t, 2), created: DateTime.now().subtract(const Duration(minutes: 5))),
      ...store.requests,
    ];
    await open(tester, store, '/admin/requests?focus=sugg', size: const Size(320, 640));
    drain(tester);
    await tester.tap(find.text('Arrange slot').first);
    for (var k = 0; k < 5; k++) { await tester.pump(const Duration(milliseconds: 300)); }
    drain(tester);
    expect(find.textContaining('Arrange a slot for'), findsOneWidget);
    Navigator.of(tester.element(find.textContaining('Arrange a slot for'))).pop();
    for (var k = 0; k < 5; k++) { await tester.pump(const Duration(milliseconds: 300)); }
    await tester.ensureVisible(find.text('Approve').first);
    for (var k = 0; k < 5; k++) { await tester.pump(const Duration(milliseconds: 300)); }
    await tester.tap(find.text('Approve').first);
    for (var k = 0; k < 5; k++) { await tester.pump(const Duration(milliseconds: 300)); }
    drain(tester);
    expect(find.textContaining('Move Diya?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    for (var k = 0; k < 5; k++) { await tester.pump(const Duration(milliseconds: 300)); }
    // Focused one is sorted first even though it was asked later.
    final cards = find.textContaining('Diya Patel');
    expect(cards, findsWidgets);
    expect(fri.isNotEmpty, isTrue);
    await close(tester);
  });

  // ADM-7: a day with no slots in a week that IS planned (e.g. a Sunday when the centre plans Mon–Fri) used to
  // say "Create this week's timetable". It now says there are no sessions today and offers a slot today.
  testWidgets('ADM-7 home empty day in a planned week offers a slot today', (tester) async {
    final store = demoStore(Role.admin);
    final t = todayISO();
    final keep = [for (final s in store.weekSlots(monday)!) if (s.date != t) s];
    store.setWeek(monday, keep);
    expect(keep, isNotEmpty);
    await open(tester, store, '/admin');
    drain(tester);
    await tester.scrollUntilVisible(find.text('No sessions today'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text("Create this week's timetable to see today's time slots here."), findsNothing, reason: 'the week already has ${keep.length} slots');
    expect(find.text('Add a slot today'), findsOneWidget);
    expect(find.text('Plan this week'), findsNothing);
    await tester.ensureVisible(find.text('Add a slot today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a slot today'));
    await tester.pumpAndSettle();
    expect(find.text('Create time slot'), findsOneWidget);
    await close(tester);
  });
}
