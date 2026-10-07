// Parent fixes from the QA pass (offline): series requests, saved logins, fees weeks, Home and Schedule details.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nuvara/models.dart';
import 'package:nuvara/router.dart';
import 'package:nuvara/screens/parent/kit.dart';
import 'package:nuvara/screens/splash.dart';
import 'package:nuvara/store.dart';
import 'package:nuvara/theme.dart';
import 'package:nuvara/util.dart';
import 'package:nuvara/widgets/bill.dart' show WeekBill;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthApiException, AuthRetryableFetchException, AuthSessionMissingException;

import 'fixtures.dart';

Map<String, dynamic> seat(String child, {bool confirmed = false}) =>
    {'child_id': child, 'attendance': null, 'note': '', 'absence_reason': null, 'absence_at': null, 'rating': null, 'rate': null, 'confirmed_at': confirmed ? DateTime.now().toUtc().toIso8601String() : null};

Slot slot(String id, String date, String start, String end, List<Map<String, dynamic>> sessions) =>
    Slot({'id': id, 'slot_date': date, 'start_time': '$start:00', 'end_time': '$end:00', 'sessions': sessions});

Map<String, dynamic> sess(String id, String name, String therapist, String therapy, List<Map<String, dynamic>> seats) =>
    {'id': id, 'name': name, 'therapist_id': therapist, 'therapy_id': therapy, 'session_children': seats};

RescheduleRequest request(String id, String session, String date, {String scope = 'series', String start = '09:30', String end = '10:15', String therapist = 't2', String therapy = 'th1'}) => RescheduleRequest({
      'id': id, 'child_id': 'c1', 'session_id': session, 'scope': scope, 'from_date': date, 'from_start': '$start:00', 'from_end': '$end:00',
      'session_name': 'Speech group', 'therapist_id': therapist, 'therapy_id': therapy, 'preferred_date': null, 'preferred_start': '16:00:00', 'preferred_end': '16:45:00',
      'reason': '', 'status': 'pending', 'admin_note': '', 'moved': 0, 'created_at': DateTime.now().toUtc().toIso8601String(),
    });

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  Future<void> settle(WidgetTester t) => t.pumpAndSettle(const Duration(milliseconds: 50), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));

  final thisWeek = weekStart(todayISO());
  final nextWeek = addDays(thisWeek, 7);

  /// Aarav (c1): next week Speech with Rahul at 09:30 on Monday, Wednesday and Friday, plus OT at 09:30 on Wednesday.
  AppStore planStore() {
    final store = demoStore(Role.parent);
    store.setWeek(nextWeek, [
      slot('n-mon', nextWeek, '09:30', '10:15', [sess('n1', 'Speech group', 't2', 'th1', [seat('c1')])]),
      slot('n-wed', addDays(nextWeek, 2), '09:30', '10:15', [sess('n3', 'Speech group', 't2', 'th1', [seat('c1')])]),
      slot('n-wed2', addDays(nextWeek, 2), '11:00', '11:45', [sess('n4', 'OT room', 't1', 'th2', [seat('c1')])]),
      slot('n-sun', addDays(nextWeek, 6), '09:30', '10:15', [sess('n7', 'Speech group', 't2', 'th1', [seat('c1')])]),
    ]);
    store.requests = [];
    return store;
  }

  Future<GoRouter> open(WidgetTester tester, AppStore store, String path, {Size size = const Size(412, 915)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    final router = buildRouter(store);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: store, child: MaterialApp.router(theme: buildTheme(), routerConfig: router)));
    router.go(path);
    await settle(tester);
    return router;
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  }

  tearDown(() {
    selectedChildId.value = null;
    scheduleWeek.value = null;
  });

  group('PAR-2 series requests', () {
    test('a "Regularly" request covers later sessions of the same series only', () {
      final store = planStore()..requests = [request('rs', 'n1', nextWeek)];
      final covered = {for (final s in store.sessionsOfChild('c1', nextWeek)) s.id: store.requestCovering('c1', s)?.id};
      // n1 is the request's own session; n3 and n7 (Sunday) are later, same therapist/therapy/time; n4 is another series.
      expect(covered, {'n1': 'rs', 'n3': 'rs', 'n4': null, 'n7': 'rs'});
      expect(store.awaitingConfirmation('c1', nextWeek).map((s) => s.id), ['n4']);
    });

    test('a "For this day" request covers only its own session', () {
      final store = planStore()..requests = [request('ro', 'n1', nextWeek, scope: 'once')];
      expect(store.awaitingConfirmation('c1', nextWeek).map((s) => s.id), ['n3', 'n4', 'n7']);
    });

    test('a series request covers nothing before its own session', () {
      final store = planStore()..requests = [request('rs', 'n3', addDays(nextWeek, 2))];
      expect(store.awaitingConfirmation('c1', nextWeek).map((s) => s.id), ['n1', 'n4']);
    });

    test('the badge drops the covered sessions', () {
      final store = planStore();
      final before = store.toConfirm;
      store.requests = [request('rs', 'n1', nextWeek)];
      expect(store.toConfirm, before - 3);
    });

    testWidgets('Schedule shows "Change requested" instead of Confirm on a covered session', (tester) async {
      final store = planStore()..requests = [request('rs', 'n1', nextWeek)];
      selectedChildId.value = 'c1';
      scheduleWeek.value = nextWeek;
      await open(tester, store, '/parent/schedule', size: const Size(412, 4000));
      // One Confirm row left: the OT session on Wednesday.
      final tiles = find.byType(SlotActions);
      var confirm = 0, requested = 0;
      for (final e in tiles.evaluate()) {
        final w = e.widget as SlotActions;
        if (find.descendant(of: find.byWidget(w), matching: find.text('Change requested')).evaluate().isNotEmpty) requested++;
        if (find.descendant(of: find.byWidget(w), matching: find.text('Confirm')).evaluate().isNotEmpty) confirm++;
      }
      expect(requested, 3);
      expect(confirm, 1);
      await close(tester);
    });
  });

  group('PAR-4 saved logins', () {
    test('only an auth rejection counts as a dead login', () {
      expect(loginRejected(const AuthApiException('Invalid Refresh Token: Refresh Token Not Found', statusCode: '400', code: 'refresh_token_not_found')), isTrue);
      expect(loginRejected(AuthSessionMissingException()), isTrue);
      expect(loginRejected(AuthRetryableFetchException(message: 'SocketException: Failed host lookup')), isFalse);
      expect(loginRejected(const AuthApiException('Bad gateway', statusCode: '502')), isFalse);
      expect(loginRejected(Exception('TimeoutException after 0:00:10')), isFalse);
    });
  });

  testWidgets('PAR-6 next week\'s bill says nothing is due yet', (tester) async {
    final store = planStore();
    store.setFees([
      ...store.feeWeeks.where((w) => !(w.childId == 'c1' && w.monday == nextWeek)),
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
    final title = find.textContaining('Next week · ');
    await tester.scrollUntilVisible(title, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(title);
    await settle(tester);
    final bill = find.ancestor(of: title, matching: find.byType(WeekBill));
    expect(find.descendant(of: bill, matching: find.textContaining('later this week')), findsNothing);
    expect(find.descendant(of: bill, matching: find.textContaining("Nothing to pay yet: next week's sessions")), findsOneWidget);
    await close(tester);
  });

  testWidgets('PAR-9 Schedule points to another child with sessions to confirm', (tester) async {
    final store = planStore();
    store.setWeek(nextWeek, [
      ...store.weekSlots(nextWeek)!,
      slot('n-anaya', addDays(nextWeek, 3), '15:00', '15:45', [sess('na', 'Speech group', 't3', 'th1', [seat('c2')])]),
    ]);
    selectedChildId.value = 'c1';
    await open(tester, store, '/parent/schedule');
    final banner = find.textContaining('Anaya has ');
    expect(banner, findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Show').first);
    await settle(tester);
    expect(selectedChildId.value, isNot('c1'));
    expect(find.bySemanticsLabel(RegExp('sessions to confirm')), findsWidgets);
    await close(tester);
  });

  testWidgets('PAR-14 Home shows one "no sessions today" card', (tester) async {
    final store = planStore();
    final today = todayISO();
    store.setWeek(thisWeek, [...?store.weekSlots(thisWeek)?.where((s) => s.date != today)]);
    selectedChildId.value = 'c1';
    await open(tester, store, '/parent');
    await tester.scrollUntilVisible(find.textContaining('No sessions for Aarav today'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text("Today's progress"), findsNothing);
    expect(find.text('No sessions today.'), findsNothing);
    await close(tester);
  });

  testWidgets('PAR-16 a placeholder "Parent of …" name is not used as a greeting', (tester) async {
    final store = planStore()..userName = 'Parent of Aarav';
    await open(tester, store, '/parent');
    expect(find.text('there'), findsOneWidget);
    expect(find.text('Parent'), findsNothing);
    await close(tester);
  });

  testWidgets('PAR-18 "Back to this week" is a 40px button', (tester) async {
    final store = planStore();
    selectedChildId.value = 'c1';
    scheduleWeek.value = nextWeek;
    await open(tester, store, '/parent/schedule');
    final back = find.widgetWithText(TextButton, 'Back to this week');
    expect(back, findsOneWidget);
    expect(tester.getSize(back).height, greaterThanOrEqualTo(40));
    await tester.tap(back);
    await settle(tester);
    expect(find.text('This week'), findsOneWidget);
    await close(tester);
  });

  testWidgets('PAR-17 offline "Use another login" asks first', (tester) async {
    var signedOut = 0;
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: SplashScreen(offline: true, onRetry: () {}, onSignOut: () => signedOut++)));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Sign in again'), findsNothing);
    await tester.tap(find.text('Use another login'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('only the centre can reset'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(signedOut, 0);
    await tester.tap(find.text('Use another login'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(FilledButton, 'Use another login'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(signedOut, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
