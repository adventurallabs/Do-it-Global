// Confirming planned sessions and asking for another slot (offline), plus Android back on the tabs.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nuvara/models.dart';
import 'package:nuvara/router.dart';
import 'package:nuvara/screens/parent/kit.dart';
import 'package:nuvara/store.dart';
import 'package:nuvara/theme.dart';
import 'package:nuvara/util.dart';
import 'package:provider/provider.dart';

import 'fixtures.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> settle(WidgetTester t) => t.pumpAndSettle(const Duration(milliseconds: 50), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));

  /// Aarav has one OT session tomorrow that the family hasn't answered yet.
  AppStore storeWithPlan({bool confirmed = false}) {
    final store = demoStore(Role.parent);
    confirmLoadedSeats(store);
    final tomorrow = addDays(todayISO(), 1);
    final monday = weekStart(tomorrow);
    // The plan is Aarav's next session whatever time the test runs: the demo sessions up to tomorrow are dropped.
    final current = weekStart(todayISO());
    if (current != monday) store.setWeek(current, [...?store.weekSlots(current)?.where((s) => s.date.compareTo(tomorrow) > 0)]);
    store.setWeek(monday, [
      ...?store.weekSlots(monday)?.where((s) => s.date.compareTo(tomorrow) > 0),
      Slot({
        'id': 'plan',
        'slot_date': tomorrow,
        'start_time': '10:00:00',
        'end_time': '10:45:00',
        'sessions': [
          {
            'id': 'plan-ot',
            'name': 'OT room',
            'therapist_id': 't1',
            'therapy_id': 'th2',
            'session_children': [
              {'child_id': 'c1', 'attendance': null, 'note': '', 'absence_reason': null, 'absence_at': null, 'rating': null, 'rate': null, 'confirmed_at': confirmed ? DateTime.now().toUtc().toIso8601String() : null},
            ],
          },
        ],
      }),
    ]);
    // Home looks at this week and next; keep both offline.
    final thisWeek = weekStart(todayISO());
    for (final m in [thisWeek, addDays(thisWeek, 7)]) {
      if (store.weekSlots(m) == null) store.setWeek(m, []);
    }
    store.requests = [];
    return store;
  }

  Future<GoRouter> open(WidgetTester tester, AppStore store, String path) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    final router = buildRouter(store);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: store, child: MaterialApp.router(theme: buildTheme(), routerConfig: router)));
    router.go(path);
    await settle(tester);
    return router;
  }

  tearDown(() => selectedChildId.value = null);

  testWidgets('an unanswered session asks the family to confirm it, and counts on the Schedule tab', (tester) async {
    final store = storeWithPlan();
    expect(store.awaitingConfirmation('c1', weekStart(addDays(todayISO(), 1))).map((s) => s.id), ['plan-ot']);
    expect(store.toConfirm, greaterThanOrEqualTo(1));
    selectedChildId.value = 'c1';
    await open(tester, store, '/parent');
    expect(find.text("Confirm Aarav's slots"), findsOneWidget);
    expect(find.text('Confirm'), findsWidgets);
    expect(find.text('Request another slot'), findsWidgets);
    // Home and Schedule lay out cleanly from a small phone to a desktop.
    for (final size in const [Size(360, 740), Size(1100, 800)]) {
      tester.view.physicalSize = size;
      final router = buildRouter(store);
      await tester.pumpWidget(ChangeNotifierProvider.value(value: store, child: MaterialApp.router(theme: buildTheme(), routerConfig: router)));
      for (final p in ['/parent', '/parent/schedule']) {
        router.go(p);
        await settle(tester);
        expect(tester.takeException(), isNull, reason: '${size.width} $p');
      }
    }
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  });

  testWidgets('a confirmed session no longer asks', (tester) async {
    final store = storeWithPlan(confirmed: true);
    expect(store.awaitingConfirmation('c1', weekStart(addDays(todayISO(), 1))), isEmpty);
    selectedChildId.value = 'c1';
    await open(tester, store, '/parent');
    expect(find.text("Confirm Aarav's slots"), findsNothing);
    expect(find.text('Confirmed'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  });

  testWidgets('a change request waiting counts as answered', (tester) async {
    final store = storeWithPlan();
    final tomorrow = addDays(todayISO(), 1);
    store.requests = [
      RescheduleRequest({
        'id': 'r9', 'child_id': 'c1', 'session_id': 'plan-ot', 'scope': 'once', 'from_date': tomorrow, 'from_start': '10:00:00', 'from_end': '10:45:00',
        'session_name': 'OT room', 'therapist_id': 't1', 'therapy_id': 'th2', 'preferred_date': tomorrow, 'preferred_start': '16:00:00', 'preferred_end': '16:45:00',
        'reason': '', 'status': 'pending', 'admin_note': '', 'moved': 0, 'created_at': DateTime.now().toUtc().toIso8601String(),
      }),
    ];
    expect(store.awaitingConfirmation('c1', weekStart(tomorrow)), isEmpty);
    expect(store.requests.single.picked, isFalse);
    expect(store.requests.single.expired, isFalse);
  });

  testWidgets('"Request another slot" opens the request sheet and still lets them suggest a time offline', (tester) async {
    final store = storeWithPlan();
    selectedChildId.value = 'c1';
    await open(tester, store, '/parent');
    await tester.tap(find.text('Request another slot').first);
    await tester.pump();
    // Let the (failing) request for the other sessions finish in real time.
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
    await settle(tester);
    expect(find.text('For this day'), findsOneWidget);
    expect(find.text('Regularly'), findsOneWidget);
    // The list of other sessions can't load offline; the family can still suggest a time.
    expect(find.text('From'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  });

  testWidgets('Android back on another tab goes to the first tab instead of leaving the app', (tester) async {
    final store = storeWithPlan();
    final r = await open(tester, store, '/parent/fees');
    expect(r.routerDelegate.currentConfiguration.uri.toString(), '/parent/fees');
    final handled = await tester.binding.handlePopRoute();
    await settle(tester);
    expect(handled, isTrue);
    expect(r.routerDelegate.currentConfiguration.uri.toString(), '/parent');
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  });
}

