// QA-Regression probes (offline). Each test demonstrates one finding from the regression pass; a failing
// expectation here points at a bug (the reason says which REG id).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nuvara/models.dart';
import 'package:nuvara/router.dart';
import 'package:nuvara/screens/admin/sessions.dart' show rollOf;
import 'package:nuvara/screens/parent/kit.dart';
import 'package:nuvara/store.dart';
import 'package:nuvara/theme.dart';
import 'package:nuvara/util.dart';
import 'package:provider/provider.dart';

import '../fixtures.dart';

Map<String, dynamic> seat(String child, {bool confirmed = false}) =>
    {'child_id': child, 'attendance': null, 'note': '', 'absence_reason': null, 'absence_at': null, 'rating': null, 'rate': null, 'confirmed_at': confirmed ? DateTime.now().toUtc().toIso8601String() : null};

Slot slot(String id, String date, String start, String end, List<Map<String, dynamic>> sessions) =>
    Slot({'id': id, 'slot_date': date, 'start_time': '$start:00', 'end_time': '$end:00', 'sessions': sessions});

Map<String, dynamic> sess(String id, String name, String therapist, String therapy, List<Map<String, dynamic>> seats) =>
    {'id': id, 'name': name, 'therapist_id': therapist, 'therapy_id': therapy, 'session_children': seats};

RescheduleRequest req(String id, String child, String session, String date, String start, String end, {String status = 'pending', String scope = 'once'}) => RescheduleRequest({
      'id': id, 'child_id': child, 'session_id': session, 'scope': scope, 'from_date': date, 'from_start': '$start:00', 'from_end': '$end:00',
      'session_name': 'Speech group', 'therapist_id': 't2', 'therapy_id': 'th1', 'preferred_date': date, 'preferred_start': '16:00:00', 'preferred_end': '16:45:00',
      'reason': '', 'status': status, 'admin_note': status == 'rejected' ? 'Sorry, no therapist is free then.' : '', 'moved': 0,
      'created_at': DateTime.now().toUtc().toIso8601String(), 'resolved_at': status == 'pending' ? null : DateTime.now().toUtc().toIso8601String(),
    });

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  Future<void> settle(WidgetTester t) => t.pumpAndSettle(const Duration(milliseconds: 50), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));

  final thisWeek = weekStart(todayISO());
  final nextWeek = addDays(thisWeek, 7);

  Future<GoRouter> open(WidgetTester tester, AppStore store, String path) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
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

  // REG-1: a request the centre turned down still reads "the centre will arrange it", and the planned session
  // (which stays) is struck through as if it were gone.
  testWidgets('REG-1 rejected request card wording on parent Schedule', (tester) async {
    final store = demoStore(Role.parent);
    store.setWeek(nextWeek, [slot('n-mon', nextWeek, '09:30', '10:15', [sess('n1', 'Speech group', 't2', 'th1', [seat('c1')])])]);
    store.requests = [req('r1', 'c1', 'n1', nextWeek, '09:30', '10:15', status: 'rejected')];
    await open(tester, store, '/parent/schedule');
    expect(find.text('Not possible'), findsWidgets);
    expect(find.text('You suggested this time; the centre will arrange it.'), findsNothing,
        reason: 'REG-1: rejected request still promises the centre will arrange the suggested time');
  });

  // REG-3: the admin slot/session chip "N to confirm" counts seats whose family already asked for another slot.
  test('REG-3 rollOf counts seats with a pending request as "to confirm"', () {
    final store = demoStore(Role.admin);
    store.setWeek(nextWeek, [slot('n-mon', nextWeek, '09:30', '10:15', [sess('n1', 'Speech group', 't2', 'th1', [seat('c1'), seat('c3')])])]);
    store.requests = [req('r1', 'c1', 'n1', nextWeek, '09:30', '10:15')];
    final s = store.sessionById('n1')!;
    final open = [for (final id in s.childIds) if (s.unconfirmed(id) && store.requestCovering(id, s) == null) id];
    expect(open.length, 1);
    expect(rollOf([s], store).unconfirmed, open.length, reason: 'REG-3: slot chip says "2 to confirm" but only one family has not answered (the other asked for another slot)');
  });

  // REG-4: viewing two weeks ahead, the "next week needs your confirmation" card points forward although next week is behind.
  testWidgets('REG-4 confirm-elsewhere card direction from week +2', (tester) async {
    final store = demoStore(Role.parent);
    store.setWeek(nextWeek, [slot('n-mon', nextWeek, '09:30', '10:15', [sess('n1', 'Speech group', 't2', 'th1', [seat('c1')])])]);
    store.setWeek(addDays(nextWeek, 7), []);
    store.requests = [];
    scheduleWeek.value = addDays(nextWeek, 7);
    await open(tester, store, '/parent/schedule');
    expect(find.textContaining('next week need'), findsOneWidget);
    expect(find.text('Tap to go to next week'), findsNothing, reason: 'REG-4: the card says "go to next week" with a forward arrow while next week is the previous page');
    expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing, reason: 'REG-4: forward arrow points the wrong way');
  });

  // REG-5: the violet admin card counts requests but says "families".
  testWidgets('REG-5 admin home requests card counts families', (tester) async {
    final store = demoStore(Role.admin);
    store.setWeek(nextWeek, [
      slot('n-mon', nextWeek, '09:30', '10:15', [sess('n1', 'Speech group', 't2', 'th1', [seat('c1')])]),
      slot('n-tue', addDays(nextWeek, 1), '09:30', '10:15', [sess('n2', 'Speech group', 't2', 'th1', [seat('c1')])]),
    ]);
    store.requests = [req('r1', 'c1', 'n1', nextWeek, '09:30', '10:15'), req('r2', 'c1', 'n2', addDays(nextWeek, 1), '09:30', '10:15')];
    await open(tester, store, '/admin');
    expect(find.text('2 families need another slot'), findsNothing, reason: 'REG-5: one family with two requests is shown as "2 families"');
  });

  // REG-2: today's row on parent Home doesn't say a change was requested (Schedule and the hero do).
  testWidgets('REG-2 parent Home "Today" row with a pending request', (tester) async {
    final now = toMin(nowHM());
    if (now > 22 * 60) return; // needs a session later today
    final start = fromMin(now + 60 > 23 * 60 ? 23 * 60 : now + 60), end = fromMin(toMin(start) + 30);
    final store = demoStore(Role.parent);
    final today = todayISO();
    store.setWeek(thisWeek, [slot('t-1', today, start, end, [sess('tt', 'Speech group', 't2', 'th1', [seat('c1')])])]);
    store.requests = [req('r1', 'c1', 'tt', today, start, end)];
    await open(tester, store, '/parent');
    // The hero and the row both show this session; the hero says "Change requested".
    expect(find.textContaining('Change requested'), findsWidgets);
    expect(find.text('Coming up'), findsNothing, reason: 'REG-2: Today row shows "Coming up" while the hero says "Change requested"');
  });
  // REG-6: a child marked inactive while still owing disappears from the parent's app when a sibling is still
  // enrolled, so the family can't see or pay those fees (the admin's dialog says "Fees already owed stay due").
  testWidgets('REG-6 parent can still reach an inactive sibling who owes fees', (tester) async {
    final store = demoStore(Role.parent);
    final kids = [
      for (final c in store.children)
        c.id == 'c3'
            ? Child({'id': 'c3', 'child_no': 3, 'name': 'Diya Patel', 'dob': '2020-03-14', 'father_name': 'F', 'mother_name': 'M', 'phone': '98765 43213', 'alt_phone': '', 'active': false,
                'child_therapies': [{'therapy_id': 'th3', 'session_fee': null}]})
            : c,
    ];
    store.setCatalog(store.therapies, store.therapists, kids);
    expect(store.dueTotal('c3'), greaterThan(0));
    await open(tester, store, '/parent/fees');
    expect(find.text('Diya'), findsWidgets, reason: 'REG-6: Diya (inactive, owes ${store.dueTotal('c3')}) is not reachable on parent Fees');
  });
}
