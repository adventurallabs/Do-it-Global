// QA-Parent probes (offline). Each test demonstrates one finding; failures here are expected to point at bugs.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nuvara/models.dart';
import 'package:nuvara/router.dart';
import 'package:nuvara/screens/parent/kit.dart';
import 'package:nuvara/screens/parent/pay.dart' show resolveUnfinished;
import 'package:nuvara/store.dart';
import 'package:nuvara/theme.dart';
import 'package:nuvara/util.dart';
import 'package:nuvara/widgets/ui.dart';
import 'package:provider/provider.dart';

import '../fixtures.dart';

Map<String, dynamic> seat(String child, {bool confirmed = false}) =>
    {'child_id': child, 'attendance': null, 'note': '', 'absence_reason': null, 'absence_at': null, 'rating': null, 'rate': null, 'confirmed_at': confirmed ? DateTime.now().toUtc().toIso8601String() : null};

Slot slot(String id, String date, String start, String end, List<Map<String, dynamic>> sessions) =>
    Slot({'id': id, 'slot_date': date, 'start_time': '$start:00', 'end_time': '$end:00', 'sessions': sessions});

Map<String, dynamic> sess(String id, String name, String therapist, String therapy, List<Map<String, dynamic>> seats) =>
    {'id': id, 'name': name, 'therapist_id': therapist, 'therapy_id': therapy, 'session_children': seats};

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  Future<void> settle(WidgetTester t) => t.pumpAndSettle(const Duration(milliseconds: 50), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
  List<String> drain(WidgetTester t, String where) => [
        for (Object? e = t.takeException(); e != null; e = t.takeException())
          if (!'$e'.contains('GoogleFonts') && !'$e'.contains('google_fonts')) '$where\n$e',
      ];

  final thisWeek = weekStart(todayISO());
  final nextWeek = addDays(thisWeek, 7);

  /// Aarav (c1) only: next week Speech on Monday and Wednesday at 09:30 with Rahul (same series), both unanswered.
  AppStore planStore() {
    final store = demoStore(Role.parent);
    confirmLoadedSeats(store);
    store.setWeek(nextWeek, [
      slot('n-mon', nextWeek, '09:30', '10:15', [sess('n1', 'Speech group', 't2', 'th1', [seat('c1')])]),
      slot('n-wed', addDays(nextWeek, 2), '09:30', '10:15', [sess('n3', 'Speech group', 't2', 'th1', [seat('c1')])]),
    ]);
    store.requests = [];
    return store;
  }

  Future<GoRouter> open(WidgetTester tester, AppStore store, String path, {Size size = const Size(412, 915), double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    final router = buildRouter(store);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: store, child: MaterialApp.router(theme: buildTheme(), routerConfig: router)));
    router.go(path);
    await settle(tester);
    return router;
  }

  tearDown(() {
    selectedChildId.value = null;
    scheduleWeek.value = null;
  });

  // PAR-2 (fixed): a "Regularly" change request answers the later sessions of the series too.
  testWidgets('series request: later sessions in the series no longer count as "to confirm"', (tester) async {
    final store = planStore();
    store.requests = [
      RescheduleRequest({
        'id': 'rs', 'child_id': 'c1', 'session_id': 'n1', 'scope': 'series', 'from_date': nextWeek, 'from_start': '09:30:00', 'from_end': '10:15:00',
        'session_name': 'Speech group', 'therapist_id': 't2', 'therapy_id': 'th1', 'preferred_date': null, 'preferred_start': '16:00:00', 'preferred_end': '16:45:00',
        'reason': '', 'status': 'pending', 'admin_note': '', 'moved': 0, 'created_at': DateTime.now().toUtc().toIso8601String(),
      }),
    ];
    final open = store.awaitingConfirmation('c1', nextWeek).map((s) => s.id).toList();
    // n3 (Wednesday, same therapist/time, later date) will be moved by resolve_reschedule's series loop.
    expect(open, isEmpty, reason: 'series siblings counted as awaiting confirmation');
    expect(store.requestCovering('c1', store.sessionById('n3')!)?.id, 'rs');
  });

  // PAR-6 (fixed): next week's planned bill has its own "Next week" section, not "Earlier weeks".
  testWidgets("next week's bill shows under 'Next week', not 'Earlier weeks'", (tester) async {
    final store = planStore();
    store.setFees([
      ...store.feeWeeks,
      FeeWeek({
        'child_id': 'c1', 'week_start': nextWeek, 'allocated': 2, 'attended': 0, 'absent': 0, 'unmarked': 0, 'upcoming': 2, 'amount': 0, 'paid': 0, 'verifying': 0,
        'lines': [
          {'therapy_id': 'th1', 'allocated': 2, 'attended': 0, 'absent': 0, 'unmarked': 0, 'upcoming': 2, 'amount': 0, 'rates': []},
        ],
        'closed': false,
      }),
    ], store.payments);
    selectedChildId.value = 'c1';
    await open(tester, store, '/parent/fees');
    final range = 'Next week · ${fmtDate(nextWeek, 'd MMM')} – ${fmtDate(addDays(nextWeek, 6), 'd MMM')}';
    await tester.scrollUntilVisible(find.text(range), 200, scrollable: find.byType(Scrollable).first);
    await settle(tester);
    final section = find.text('Next week');
    expect(section, findsOneWidget);
    expect(tester.getTopLeft(find.text(range)).dy, greaterThan(tester.getTopLeft(section).dy));
    final earlier = find.text('Earlier weeks');
    if (earlier.evaluate().isNotEmpty) {
      expect(tester.getTopLeft(find.text(range)).dy, lessThan(tester.getTopLeft(earlier).dy), reason: 'a future week is filed under "Earlier weeks"');
    }
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  });

  // PAR: errors from actions inside a bottom sheet go to the page's ScaffoldMessenger, under the sheet.
  testWidgets('a failing action in a sheet shows its error snackbar behind the sheet', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        bottomNavigationBar: const SizedBox(height: 80),
        body: Builder(builder: (c) {
          ctx = c;
          return const SizedBox.expand();
        }),
      ),
    ));
    showSheet(ctx,
        builder: (_) => SheetBody(
              title: 'Request another slot',
              footer: [
                btn('Cancel', onPressed: () {}),
                ActionButton('Send request', onPressed: () async => throw Exception('You have already asked to change this session.')),
              ],
              child: const SizedBox(height: 300),
            ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();
    final snack = find.byType(SnackBar);
    expect(snack, findsOneWidget);
    final sheet = tester.getRect(find.byType(BottomSheet));
    final bar = tester.getRect(snack);
    expect(sheet.overlaps(bar), isFalse, reason: 'snackbar $bar is drawn under the bottom sheet $sheet');
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  });

  bool truncated(WidgetTester tester, Finder f) {
    final p = tester.renderObject<RenderParagraph>(find.descendant(of: f, matching: find.byType(RichText)).first);
    return p.didExceedMaxLines;
  }

  // PAR: on the dark hero the two buttons sit side by side from 320px of hero width; labels get cut.
  for (final (size, scale) in [(const Size(412, 915), 1.0), (const Size(412, 915), 1.3), (const Size(393, 851), 1.0)]) {
    testWidgets('hero "Request another slot" label fits at ${size.width} x$scale', (tester) async {
      final store = planStore();
      // Make the next session tomorrow's unanswered one.
      final tomorrow = addDays(todayISO(), 1);
      // Nothing before it, whatever time the test runs: the demo week's sessions up to tomorrow are dropped.
      final thisWeek = weekStart(todayISO());
      store.setWeek(thisWeek, [...?store.weekSlots(thisWeek)?.where((s) => s.date.compareTo(tomorrow) > 0)]);
      store.setWeek(weekStart(tomorrow), [
        ...?store.weekSlots(weekStart(tomorrow))?.where((s) => s.date.compareTo(tomorrow) > 0),
        slot('tmr', tomorrow, '07:00', '07:45', [sess('tmr1', 'OT room', 't1', 'th2', [seat('c1')])]),
      ]);
      selectedChildId.value = 'c1';
      await open(tester, store, '/parent', size: size, textScale: scale);
      final label = find.text('Request another slot').first;
      expect(label, findsOneWidget);
      expect(truncated(tester, label), isFalse, reason: '"Request another slot" is ellipsized on the hero');
      await tester.pumpWidget(const SizedBox());
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.view.reset();
    });
  }

  // PAR: "No, I didn't pay" in the unfinished-payment sheet gets the narrow (flex 1) slot.
  for (final size in const [Size(320, 640), Size(360, 740)]) {
    testWidgets('unfinished payment footer labels fit at ${size.width}', (tester) async {
      final store = demoStore(Role.parent);
      store.setFees(store.feeWeeks, [
        ...store.payments,
        Payment({'id': 'pi', 'child_id': 'c1', 'week_start': addDays(thisWeek, -7), 'amount': 7000, 'method': 'UPI', 'status': 'initiated', 'txn_ref': 'NVX', 'payee_vpa': 'centre@okaxis', 'payee_name': 'Nuvara', 'created_at': DateTime.now().toUtc().toIso8601String(), 'note': ''}),
      ]);
      final router = await open(tester, store, '/parent/fees', size: size);
      resolveUnfinished(router.routerDelegate.navigatorKey.currentContext!, 'pi');
      await settle(tester);
      final no = find.text("No, I didn't pay");
      expect(no, findsOneWidget);
      expect(truncated(tester, no), isFalse, reason: '"No, I didn\'t pay" is cut off at ${size.width}px');
      await tester.pumpWidget(const SizedBox());
      tester.view.reset();
    });
  }

  // PAR: Home's "Today" rows open Schedule on whatever week it was last left on.
  testWidgets("tapping a Today row opens Schedule on this week", (tester) async {
    final store = planStore();
    final today = todayISO();
    store.setWeek(thisWeek, [
      ...?store.weekSlots(thisWeek)?.where((s) => s.date != today),
      slot('tdy', today, '00:00', '00:30', [sess('tdy1', 'OT room', 't1', 'th2', [seat('c1', confirmed: true)])]),
    ]);
    selectedChildId.value = 'c1';
    final router = await open(tester, store, '/parent/schedule');
    await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
    await settle(tester);
    expect(find.text('Next week'), findsWidgets);
    router.go('/parent');
    await settle(tester);
    await tester.scrollUntilVisible(find.text('OT room').last, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('OT room').last);
    await settle(tester);
    expect(find.text('This week'), findsOneWidget, reason: "Schedule still shows next week after tapping today's session");
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  });

  // Layout sweep: every parent tab at 320px and with large text.
  testWidgets('parent tabs at 320px and 1.3x text', (tester) async {
    final store = planStore();
    final failures = <String>[];
    for (final (size, scale) in [(const Size(320, 568), 1.0), (const Size(360, 740), 1.3), (const Size(320, 568), 1.3)]) {
      for (final c in ['c1', 'c2']) {
        selectedChildId.value = c;
        for (final p in ['/parent', '/parent/schedule', '/parent/progress', '/parent/fees', '/parent/messages']) {
          final r = await open(tester, store, p, size: size, textScale: scale);
          failures.addAll(drain(tester, '${size.width} x$scale $c $p'));
          if (p == '/parent/schedule') {
            r.go('/parent/schedule');
            scheduleWeek.value = nextWeek;
            await settle(tester);
            failures.addAll(drain(tester, '${size.width} x$scale $c next week'));
          }
        }
      }
    }
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
    expect(failures, isEmpty, reason: failures.join('\n\n'));
  });

  // Badge equals what's findable: one child, this + next week, Sunday included.
  test('badge counts this week and next for every active child', () {
    final store = planStore();
    final perChild = {for (final c in store.activeChildren) c.id: toConfirmSoon(store, c.id)};
    expect(store.toConfirm, perChild.values.fold<int>(0, (a, b) => a + b));
    expect(perChild['c1'], 2);
  });
}
