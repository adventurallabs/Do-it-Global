// Regression tests for the therapist QA fixes (THR-3, -7, -9 … -16). The store is offline, so every save fails
// and is reverted; that is what the optimistic-update tests rely on.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nuvara/actions.dart';
import 'package:nuvara/models.dart';
import 'package:nuvara/router.dart';
import 'package:nuvara/screens/therapist/parts.dart';
import 'package:nuvara/store.dart';
import 'package:nuvara/theme.dart';
import 'package:nuvara/util.dart';
import 'package:provider/provider.dart';

import 'fixtures.dart';

Map<String, dynamic> _seat(String child, {String? reason, String? attendance, int? rating}) => {
      'child_id': child,
      'attendance': attendance,
      'note': '',
      'absence_reason': reason,
      'absence_at': reason == null ? null : DateTime.now().toUtc().toIso8601String(),
      'rating': rating,
    };

/// A slot today starting [startOffset] minutes from now and lasting [length] minutes (null when it would leave today).
Slot? _slotToday(String id, int startOffset, int length, List<Map<String, dynamic>> sessions) {
  final now = toMin(nowHM());
  final start = now + startOffset, end = start + length;
  if (start < 0 || end >= 24 * 60) return null;
  return Slot({'id': id, 'slot_date': todayISO(), 'start_time': '${fromMin(start)}:00', 'end_time': '${fromMin(end)}:00', 'sessions': sessions});
}

Map<String, dynamic> _session(String id, List<Map<String, dynamic>> seats) => {'id': id, 'name': 'OT $id', 'therapist_id': 't1', 'therapy_id': 'th2', 'session_children': seats};

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  final monday = weekStart(todayISO());

  Future<void Function(String)> open(WidgetTester tester, AppStore store, String path, {Size size = const Size(412, 1600)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    final router = buildRouter(store);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: store, child: MaterialApp.router(theme: buildTheme(), routerConfig: router)));
    router.go(path);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return router.go;
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  }

  /// Waits for an offline save to fail; returns 'ok' or 'failed'.
  Future<String> settle(WidgetTester tester, Future<void> f) async {
    String? r;
    f.then((_) => r = 'ok', onError: (_) => r = 'failed');
    for (var i = 0; i < 50 && r == null; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return r ?? 'pending';
  }

  testWidgets('THR-3: marking a rated child absent drops the rating at once, and brings it back if the save fails', (tester) async {
    final store = demoStore(Role.therapist);
    final slot = _slotToday('a', -5, 45, [_session('A1', [_seat('c4', attendance: 'present', rating: 7)])]);
    if (slot == null) return markTestSkipped('too close to midnight');
    store.weekSlots(monday)!.add(slot);
    final s = store.sessionById('A1')!;
    final f = store.markAttendance(s, ['c4'], 'absent');
    expect(s.seat('c4')!.attendance, 'absent');
    expect(s.seat('c4')!.rating, isNull, reason: 'the server drops it too');
    expect(await settle(tester, f), 'failed');
    expect(s.seat('c4')!.attendance, 'present');
    expect(s.seat('c4')!.rating, 7);
  });

  testWidgets('THR-3: late keeps the rating', (tester) async {
    final store = demoStore(Role.therapist);
    final slot = _slotToday('a', -5, 45, [_session('A2', [_seat('c4', attendance: 'present', rating: 6)])]);
    if (slot == null) return markTestSkipped('too close to midnight');
    store.weekSlots(monday)!.add(slot);
    final s = store.sessionById('A2')!;
    final f = store.markAttendance(s, ['c4'], 'late');
    expect(s.seat('c4')!.rating, 6);
    await settle(tester, f);
  });

  testWidgets('THR-3: the toggle asks before removing a report', (tester) async {
    final store = demoStore(Role.therapist);
    final slot = _slotToday('a', -5, 45, [_session('A3', [_seat('c4', attendance: 'present', rating: 7)])]);
    if (slot == null) return markTestSkipped('too close to midnight');
    store.weekSlots(monday)!.add(slot);
    await open(tester, store, '/therapist/sessions/A3');
    await tester.tap(find.descendant(of: find.byType(AttendanceToggle), matching: find.text('Absent')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('This removes the 7/10 report for this session.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(store.sessionById('A3')!.seat('c4')!.attendance, 'present');
    expect(store.sessionById('A3')!.seat('c4')!.rating, 7);
    await close(tester);
  });

  testWidgets('THR-7: quick rating taps that all fail end on the last saved rating', (tester) async {
    final store = demoStore(Role.therapist);
    final slot = _slotToday('r', -5, 45, [_session('R7', [_seat('c4', attendance: 'present', rating: 3)])]);
    if (slot == null) return markTestSkipped('too close to midnight');
    store.weekSlots(monday)!.add(slot);
    final s = store.sessionById('R7')!;
    final a = store.rateSession(s, 'c4', 5);
    final b = store.rateSession(s, 'c4', 8);
    expect(s.seat('c4')!.rating, 8, reason: 'the latest tap shows');
    expect(await settle(tester, Future.wait([a.catchError((_) {}), b])), 'failed');
    expect(s.seat('c4')!.rating, 3, reason: 'back to what the server has, not to the first tap');
  });

  testWidgets('THR-9/REG-17: Undo is offered only once a clear is saved', (tester) async {
    final store = demoStore(Role.therapist);
    final slot = _slotToday('u', -5, 45, [_session('U1', [_seat('c4', attendance: 'present', rating: 6), _seat('c1', attendance: 'late')])]);
    if (slot == null) return markTestSkipped('too close to midnight');
    store.weekSlots(monday)!.add(slot);
    // Offline, the save fails at once: the error shows and no Undo is offered for a clear that never happened.
    final shown = <SnackBar>[];
    tester.view.physicalSize = const Size(412, 1600);
    tester.view.devicePixelRatio = 1;
    final router = buildRouter(store);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp.router(theme: buildTheme(), routerConfig: router, builder: (_, child) => _Messenger(shown, child: child!)),
    ));
    router.go('/therapist/sessions/U1');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    String? text(SnackBar b) => b.content is Text ? (b.content as Text).data : null;
    // Re-tapping the chosen rating clears it.
    await tester.tap(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Rate 6 out of 10' && w.properties.selected == true));
    await tester.pump();
    expect(shown.map(text), isNot(contains('Rating 6/10 removed')));
    expect(shown.where((b) => b.action?.label == 'Undo'), isEmpty);
    expect(shown, isNotEmpty, reason: 'the failed save is reported');
    // Re-tapping "Late" on Aarav (c1, no rating) clears it straight away (no question); offline, no Undo either.
    final before = shown.length;
    await tester.tap(find.descendant(of: find.byType(AttendanceToggle), matching: find.text('Late')).first);
    await tester.pump();
    expect(shown.where((b) => text(b)?.endsWith('attendance cleared') ?? false), isEmpty);
    expect(shown.length, greaterThan(before), reason: 'the failed save is reported');
    await close(tester);
  });

  testWidgets('THR-10/15: Today explains a closed toggle and who will be marked absent', (tester) async {
    final store = demoStore(Role.therapist);
    final later = _slotToday('l', 90, 30, [_session('L10', [_seat('c4')])]);
    final live = _slotToday('n', -5, 45, [_session('N15', [_seat('c1', reason: 'Fever'), _seat('c3')])]);
    if (later == null || live == null) return markTestSkipped('too close to midnight');
    store.weekSlots(monday)!.addAll([live, later]);
    await open(tester, store, '/therapist', size: const Size(412, 4000));
    expect(find.textContaining('Attendance opens at ${attendanceOpensLabel(store.sessionById('L10')!)}'), findsOneWidget);
    expect(find.text(noticeAbsentHint), findsOneWidget);
    await close(tester);
  });

  testWidgets('THR-11: Today and Week count "to mark" the same way', (tester) async {
    final store = demoStore(Role.therapist);
    final live = _slotToday('n', -5, 45, [_session('N11', [_seat('c1'), _seat('c3')])]);
    final later = _slotToday('l', 90, 30, [_session('L11', [_seat('c4')])]);
    if (live == null || later == null) return markTestSkipped('too close to midnight');
    store.weekSlots(monday)!.addAll([live, later]);
    final s = [store.sessionById('N11')!, store.sessionById('L11')!];
    expect(toMarkCount(s), 2, reason: 'running counts, later does not');
  });

  testWidgets('THR-13: the description waits for the session to start', (tester) async {
    final store = demoStore(Role.therapist);
    final slot = _slotToday('f', 120, 30, [_session('F13', [_seat('c4')])]);
    if (slot == null) return markTestSkipped('too close to midnight');
    store.weekSlots(monday)!.add(slot);
    await open(tester, store, '/therapist/sessions/F13');
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isFalse);
    expect(find.text('You can write this once the session starts'), findsOneWidget);
    await close(tester);
  });

  testWidgets('THR-14: one "Locked" line per finished session, not per child', (tester) async {
    final store = demoStore(Role.therapist);
    final slot = _slotToday('d', -90, 30, [_session('D14', [_seat('c4', attendance: 'present', rating: 5), _seat('c1', attendance: 'absent'), _seat('c3', attendance: 'late', rating: 6)])]);
    if (slot == null) return markTestSkipped('too early in the day');
    store.weekSlots(monday)!.add(slot);
    await open(tester, store, '/therapist/sessions/D14', size: const Size(412, 3000));
    expect(find.text('Locked: the session is over'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await open(tester, store, '/therapist', size: const Size(412, 3000));
    // One per finished session with marks on today's timeline (the fixtures add their own).
    final done = mySessions(store, monday).where((x) => x.date == todayISO() && x.phase == 'done' && x.markedCount > 0).length;
    expect(find.text('Locked: the session is over'), findsNWidgets(done));
    await close(tester);
  });

  testWidgets('THR-16: attendance toggles are 44px+ tall and fit 320px', (tester) async {
    final store = demoStore(Role.therapist);
    final slot = _slotToday('t', -5, 45, [_session('T16', [_seat('c1', reason: 'Fever'), _seat('c4')])]);
    if (slot == null) return markTestSkipped('too close to midnight');
    store.weekSlots(monday)!.add(slot);
    await open(tester, store, '/therapist', size: const Size(320, 3000));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AttendanceToggle).first).height, greaterThanOrEqualTo(44));
    await close(tester);
  });

  testWidgets('THR-6: a child\'s next session in next week shows its day and date', (tester) async {
    final store = demoStore(Role.therapist);
    final next = addDays(monday, 7);
    final day = addDays(next, 2);
    store.setWeek(monday, []);
    store.setWeek(next, [
      Slot({'id': 'w', 'slot_date': day, 'start_time': '09:30:00', 'end_time': '10:15:00', 'sessions': [_session('W6', [_seat('c4')])]}),
    ]);
    await open(tester, store, '/therapist/children');
    expect(find.textContaining('Next ${fmtDate(day, 'EEE, d MMM')} 9:30 AM'), findsOneWidget);
    await close(tester);
  });
}

/// A ScaffoldMessenger that remembers every SnackBar it was asked to show.
class _Messenger extends ScaffoldMessenger {
  final List<SnackBar> shown;
  const _Messenger(this.shown, {required super.child});

  @override
  ScaffoldMessengerState createState() => _MessengerState();
}

class _MessengerState extends ScaffoldMessengerState {
  @override
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(SnackBar snackBar, {AnimationStyle? snackBarAnimationStyle}) {
    (widget as _Messenger).shown.add(snackBar);
    return super.showSnackBar(snackBar, snackBarAnimationStyle: snackBarAnimationStyle);
  }
}
