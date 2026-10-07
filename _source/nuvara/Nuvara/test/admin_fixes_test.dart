// Admin fixes from the QA round (ADM-1 … ADM-19): store helpers and the screens that use them.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nuvara/models.dart';
import 'package:nuvara/router.dart';
import 'package:nuvara/screens/admin/children.dart' show nextSevenDays;
import 'package:nuvara/screens/admin/sessions.dart' show deleteImpact, repeatDates, repeatTitle, skippedRepeatDates;
import 'package:nuvara/store.dart';
import 'package:nuvara/theme.dart';
import 'package:nuvara/util.dart';
import 'package:provider/provider.dart';

import 'fixtures.dart';

RescheduleRequest req(String id, String from, {String start = '09:30:00', String status = 'pending', DateTime? created, DateTime? resolved, String child = 'c3', String therapist = 't3', String? session}) =>
    RescheduleRequest({
      'id': id, 'child_id': child, 'session_id': session ?? 'zz-$id', 'scope': 'once', 'from_date': from, 'from_start': start, 'from_end': '23:59:00',
      'session_name': 'Behaviour $id', 'therapist_id': therapist, 'therapy_id': 'th3', 'preferred_date': from, 'preferred_start': '16:00:00', 'preferred_end': '16:45:00',
      'reason': '', 'status': status, 'admin_note': '', 'moved': 0, 'created_at': (created ?? DateTime.now()).toUtc().toIso8601String(),
      'resolved_at': resolved?.toUtc().toIso8601String(),
    });

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  final today = todayISO();
  final monday = weekStart(today);

  Future<void> open(WidgetTester tester, AppStore store, String path, {Size size = const Size(412, 915)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    final router = buildRouter(store);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: store, child: MaterialApp.router(theme: buildTheme(), routerConfig: router)));
    router.go(path);
    await tester.pumpAndSettle(const Duration(milliseconds: 50), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
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

  group('store', () {
    test('ADM-1/2 actionable requests: live only, soonest session first; expired ones apart', () {
      final store = demoStore(Role.admin);
      final now = DateTime.now();
      store.requests = [
        req('late', addDays(today, 6), created: now),
        req('soon', addDays(today, 1), created: now.subtract(const Duration(hours: 5))),
        req('past', addDays(today, -2)),
        req('done', addDays(today, 1), status: 'approved'),
        req('mid', addDays(today, 3), created: now.subtract(const Duration(hours: 1))),
      ];
      expect([for (final r in store.actionableRequests) r.id], ['soon', 'mid', 'late']);
      expect([for (final r in store.expiredRequests) r.id], ['past']);
      expect(store.pendingRequests, hasLength(4), reason: 'pending still includes the expired one (it can be closed)');
    });

    test('ADM-4 upcoming sessions only count sessions that have not started', () {
      final store = demoStore(Role.admin);
      final now = '$today ${nowHM()}';
      final up = store.upcomingSessions((s) => s.therapistId == 't3');
      expect(up.every((s) => '${s.date} ${s.start}'.compareTo(now) > 0 && s.therapistId == 't3'), isTrue);
      for (var i = 1; i < up.length; i++) {
        expect('${up[i - 1].date} ${up[i - 1].start}'.compareTo('${up[i].date} ${up[i].start}') <= 0, isTrue);
      }
    });

    test('ADM-6 delete impact mentions waiting requests and attended places', () {
      final store = demoStore(Role.admin);
      final s = store.sessionById('x4-1')!; // Aarav (present) and Anaya; Aarav's family asked to move it (r1).
      final text = deleteImpact(store, [s]);
      expect(text, contains('A family is waiting for an answer'));
      expect(text, contains('1 attended place'));
      expect(deleteImpact(store, [store.sessionById('y0-1')!]), isEmpty);
    });

    test('ADM-11 repeat title and days', () {
      final past = addDays(monday, -7);
      expect(repeatTitle(past), 'Repeat all week (Mon – Sun)');
      expect(repeatDates(addDays(past, 6)), hasLength(7));
      final sunday = addDays(monday, 6);
      // Only Sunday is left when today is Sunday (the switch is hidden then); otherwise earlier days are skipped.
      if (today == sunday) {
        expect(repeatDates(today), [today]);
      } else if (today != monday) {
        expect(skippedRepeatDates(today), isNotEmpty);
        expect(repeatTitle(today), 'Repeat on the rest of this week');
      }
    });

    test('ADM-19 next 7 days spans into next week', () {
      final store = demoStore(Role.admin);
      final next = addDays(monday, 7);
      store.setWeek(next, [
        Slot({'id': 'n1', 'slot_date': next, 'start_time': '09:30:00', 'end_time': '10:15:00', 'sessions': [
          {'id': 'nx', 'name': 'Next Monday', 'therapist_id': 't3', 'therapy_id': 'th3', 'session_children': [{'child_id': 'c3'}]},
        ]}),
        Slot({'id': 'n2', 'slot_date': addDays(next, 6), 'start_time': '09:30:00', 'end_time': '10:15:00', 'sessions': [
          {'id': 'ny', 'name': 'Next Sunday', 'therapist_id': 't3', 'therapy_id': 'th3', 'session_children': [{'child_id': 'c3'}]},
        ]}),
      ]);
      final days = nextSevenDays([...store.sessionsOfChild('c3', monday), ...store.sessionsOfChild('c3', next)]);
      expect(days.every((s) => s.date.compareTo(today) >= 0 && s.date.compareTo(addDays(today, 6)) <= 0), isTrue);
      expect(days.any((s) => s.name == 'Next Monday'), isTrue, reason: 'next Monday is always within 7 days');
      expect(days.any((s) => s.name == 'Next Sunday'), isFalse);
    });
  });

  group('screens', () {
    testWidgets('ADM-2/16 requests screen: session passed section, answered newest first', (tester) async {
      final store = demoStore(Role.admin);
      final now = DateTime.now();
      store.requests = [
        req('live', addDays(today, 2)),
        req('gone', addDays(today, -1)),
        req('a-old', addDays(today, -5), status: 'rejected', created: now.subtract(const Duration(days: 9)), resolved: now.subtract(const Duration(days: 8))),
        req('a-new', addDays(today, -6), status: 'approved', created: now.subtract(const Duration(days: 10)), resolved: now.subtract(const Duration(hours: 1))),
      ];
      await open(tester, store, '/admin/requests');
      drain(tester);
      expect(find.text('Waiting for you'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Session passed', skipOffstage: false).first, 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Close request'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Answered'), 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      final newer = find.textContaining('Behaviour a-new', skipOffstage: false), older = find.textContaining('Behaviour a-old', skipOffstage: false);
      expect(newer, findsOneWidget);
      expect(older, findsOneWidget);
      expect(tester.getTopLeft(newer).dy, lessThan(tester.getTopLeft(older).dy), reason: 'answered most recently comes first, though asked earlier');
      await close(tester);
    });

    testWidgets('ADM-5 home flags past sessions without attendance', (tester) async {
      final store = demoStore(Role.admin);
      final last = addDays(monday, -7);
      store.setFees([
        ...store.feeWeeks.where((w) => w.monday != last || w.childId != 'c3'),
        FeeWeek({'child_id': 'c3', 'week_start': last, 'allocated': 5, 'attended': 1, 'absent': 0, 'unmarked': 4, 'upcoming': 0, 'amount': 4000, 'paid': 0, 'verifying': 0, 'lines': [], 'closed': false}),
      ], store.payments);
      await open(tester, store, '/admin');
      drain(tester);
      expect(find.textContaining('past session'), findsOneWidget);
      expect(find.textContaining('still need attendance'), findsOneWidget);
      expect(find.textContaining('the week of ${fmtDate(last, 'd MMM')}'), findsOneWidget);
      await close(tester);
    });

    testWidgets('ADM-12 arrange sheet: inactive therapist is not preselected and is named', (tester) async {
      final store = demoStore(Role.admin);
      store.setCatalog(store.therapies, [
        for (final t in store.therapists)
          t.id == 't3'
              ? Therapist({'id': 't3', 'therapist_no': 3, 'name': t.name, 'active': false, 'therapist_therapies': [{'therapy_id': 'th3'}, {'therapy_id': 'th1'}], 'therapist_details': null})
              : t,
      ], store.children);
      store.requests = [req('sugg', addDays(today, 2))];
      await open(tester, store, '/admin/requests');
      drain(tester);
      await tester.tap(find.text('Arrange slot'));
      await tester.pumpAndSettle();
      drain(tester);
      expect(find.text('Divya is inactive, so choose another therapist.'), findsOneWidget);
      expect(find.text('Choose a therapist.'), findsOneWidget, reason: 'nobody is preselected');
      await close(tester);
    });

    testWidgets('ADM-13 admin chat with a family without a parent login', (tester) async {
      final store = demoStore(Role.admin);
      await open(tester, store, '/admin/messages/c4');
      drain(tester);
      expect(find.text("No parent login yet — the family can't see messages"), findsOneWidget);
      await tester.tap(find.text('Set up'));
      await tester.pumpAndSettle();
      expect(find.text('Parent login'), findsOneWidget, reason: "opens the child's profile");
      await close(tester);
      final withLogin = demoStore(Role.admin);
      await open(tester, withLogin, '/admin/messages/c1');
      expect(find.textContaining('No parent login yet'), findsNothing);
      await close(tester);
    });

    testWidgets('ADM-15 a UPI payment started minutes ago is "In progress", not reviewable', (tester) async {
      final store = demoStore(Role.admin);
      store.setFees(store.feeWeeks, [
        Payment({'id': 'p9', 'child_id': 'c1', 'week_start': monday, 'amount': 9500, 'method': 'UPI', 'status': 'initiated', 'txn_ref': 'NVTEST9', 'created_at': DateTime.now().toUtc().toIso8601String(), 'note': ''}),
        ...store.payments,
      ]);
      await open(tester, store, '/admin/fees/c1');
      drain(tester);
      await tester.scrollUntilVisible(find.text('In progress'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('Not received'), findsNothing);
      await close(tester);
    });

    testWidgets('ADM-3/18 deactivating a child offers to take them out of upcoming sessions', (tester) async {
      final store = demoStore(Role.admin);
      await open(tester, store, '/admin/children/c3');
      drain(tester);
      await tester.scrollUntilVisible(find.text('Next 7 days'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Next 7 days'), findsOneWidget);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as inactive'));
      await tester.pumpAndSettle();
      expect(find.text('Mark Diya as inactive?'), findsOneWidget);
      expect(find.textContaining("isn't billed"), findsNothing);
      if (store.upcomingSessions((s) => s.childIds.contains('c3')).isNotEmpty) {
        expect(find.textContaining('upcoming session'), findsOneWidget);
        expect(find.text('Remove from sessions & mark inactive'), findsOneWidget);
      } else {
        expect(find.textContaining('Fees already owed stay due'), findsOneWidget);
      }
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await close(tester);
    });
  });
}
