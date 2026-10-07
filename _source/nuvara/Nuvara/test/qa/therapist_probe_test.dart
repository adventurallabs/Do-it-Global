// QA-Therapist probes. Each test documents one behaviour the therapist sees. They started as QA findings
// (THR-1, -2, -5, -6, -8); now fixed, they guard against regressions.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nuvara/models.dart';
import 'package:nuvara/router.dart';
import 'package:nuvara/screens/therapist/parts.dart';
import 'package:nuvara/store.dart';
import 'package:nuvara/theme.dart';
import 'package:nuvara/util.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient, AuthClientOptions;

import '../fixtures.dart';

Map<String, dynamic> _seat(String child, {String? reason, bool confirmed = false, String? attendance, int? rating}) => {
      'child_id': child,
      'attendance': attendance,
      'note': '',
      'absence_reason': reason,
      'absence_at': reason == null ? null : DateTime.now().toUtc().toIso8601String(),
      'rating': rating,
      'confirmed_at': confirmed ? DateTime.now().toUtc().toIso8601String() : null,
    };

/// A slot today starting [startOffset] minutes from now and lasting [length] minutes (null when it would cross midnight).
Slot? _slotToday(String id, int startOffset, int length, List<Map<String, dynamic>> sessions) {
  final now = toMin(nowHM());
  final start = now + startOffset, end = start + length;
  if (start < 0 || end >= 24 * 60) return null;
  return Slot({'id': id, 'slot_date': todayISO(), 'start_time': '${fromMin(start)}:00', 'end_time': '${fromMin(end)}:00', 'sessions': sessions});
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  final today = todayISO();
  final monday = weekStart(today);

  Future<GoRouterLike> open(WidgetTester tester, AppStore store, String path, {Size size = const Size(412, 915), double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    final router = buildRouter(store);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: store, child: MaterialApp.router(theme: buildTheme(), routerConfig: router)));
    router.go(path);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return GoRouterLike(router.go);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  }

  // ------------------------------------------------------------------ business rule
  group('RULE: an unconfirmed child can always be marked', () {
    testWidgets('live session: no answer, request pending, confirmed -> all markable', (tester) async {
      final store = demoStore(Role.therapist);
      final slot = _slotToday('live', -5, 45, [
        {
          'id': 'L1',
          'name': 'Live OT',
          'therapist_id': 't1',
          'therapy_id': 'th2',
          'session_children': [_seat('c1'), _seat('c4', confirmed: true), _seat('c3')],
        },
      ]);
      if (slot == null) return markTestSkipped('too close to midnight');
      store.weekSlots(monday)!.add(slot);
      // c1's family has a "request another slot" waiting for this very session.
      store.requests = [
        RescheduleRequest({
          'id': 'rq', 'child_id': 'c1', 'session_id': 'L1', 'scope': 'once', 'from_date': today, 'from_start': slot.start, 'from_end': slot.end,
          'session_name': 'Live OT', 'therapist_id': 't1', 'therapy_id': 'th2', 'preferred_date': today, 'preferred_start': '18:00:00', 'preferred_end': '18:45:00',
          'reason': 'Clash', 'status': 'pending', 'admin_note': '', 'moved': 0, 'created_at': DateTime.now().toUtc().toIso8601String(),
        }),
      ];
      final s = store.sessionById('L1')!;
      for (final id in s.childIds) {
        expect(s.canMarkSeat(id), isTrue, reason: '$id must be markable whatever the family answered');
      }
      await open(tester, store, '/therapist/sessions/L1', size: const Size(412, 2600));
      final toggles = tester.widgetList<AttendanceToggle>(find.byType(AttendanceToggle)).toList();
      expect(toggles, hasLength(3));
      expect(toggles.every((t) => t.enabled), isTrue);
      // No confusing "not confirmed" wording anywhere on the therapist's session screen.
      expect(find.textContaining(RegExp('confirm', caseSensitive: false)), findsNothing);
      expect(find.text('Mark all present'), findsOneWidget);
      // Tap Present on the first child (Aarav, c1 - the one with the pending request).
      await tester.tap(find.descendant(of: find.byType(AttendanceToggle).first, matching: find.text('Present')));
      // Optimistic: shows before the (offline, failing) save returns.
      expect(s.seat('c1')!.attendance, 'present');
      await tester.pump(const Duration(seconds: 2));
      await close(tester);
    });

    testWidgets('session starting in 10 minutes, nobody confirmed -> markable from the Today timeline', (tester) async {
      final store = demoStore(Role.therapist);
      final slot = _slotToday('soon', 10, 45, [
        {'id': 'S1', 'name': 'Soon OT', 'therapist_id': 't1', 'therapy_id': 'th2', 'session_children': [_seat('c1'), _seat('c4')]},
      ]);
      if (slot == null) return markTestSkipped('too close to midnight');
      store.weekSlots(monday)!.add(slot);
      final s = store.sessionById('S1')!;
      expect(s.unconfirmed('c1'), isTrue);
      expect(s.canMarkSeat('c1'), isTrue);
      await open(tester, store, '/therapist');
      expect(find.text('Soon OT'), findsOneWidget);
      expect(find.text('Mark all present'), findsWidgets);
      await close(tester);
    });
  });

  // ------------------------------------------------------------------ Sunday
  group('Sunday', () {
    testWidgets('a Sunday session shows in Today and Week when today is Sunday', (tester) async {
      if (weekdayOf(today) != 0) return markTestSkipped('only meaningful on a Sunday');
      final store = demoStore(Role.therapist);
      final slot = _slotToday('sun', 60, 45, [
        {'id': 'SUN', 'name': 'Sunday OT', 'therapist_id': 't1', 'therapy_id': 'th2', 'session_children': [_seat('c4')]},
      ]);
      if (slot == null) return markTestSkipped('too late in the day');
      store.weekSlots(monday)!.add(slot);
      store.setWeek(addDays(monday, 7), []);
      final go = await open(tester, store, '/therapist', size: const Size(412, 4000));
      expect(find.text('Sunday OT'), findsOneWidget);
      go('/therapist/week');
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Sunday,'), findsOneWidget);
      await close(tester);
    });

    testWidgets('Sunday with nothing left: Today points at Monday (next week)', (tester) async {
      if (weekdayOf(today) != 0) return markTestSkipped('only meaningful on a Sunday');
      final store = demoStore(Role.therapist);
      final next = addDays(monday, 7);
      store.setWeek(next, [
        Slot({'id': 'mon', 'slot_date': next, 'start_time': '09:30:00', 'end_time': '10:15:00', 'sessions': [
          {'id': 'MON', 'name': 'Monday OT', 'therapist_id': 't1', 'therapy_id': 'th2', 'session_children': [_seat('c4')]},
        ]}),
      ]);
      await open(tester, store, '/therapist');
      expect(find.textContaining('Next up: Monday OT, Tomorrow'), findsOneWidget);
      await close(tester);
    });

    testWidgets('Children tab: on Sunday the child\'s next session (Monday) is shown', (tester) async {
      if (weekdayOf(today) != 0) return markTestSkipped('only meaningful on a Sunday');
      final store = demoStore(Role.therapist);
      final next = addDays(monday, 7);
      store.setWeek(next, [
        Slot({'id': 'mon', 'slot_date': next, 'start_time': '09:30:00', 'end_time': '10:15:00', 'sessions': [
          {'id': 'MON', 'name': 'Monday OT', 'therapist_id': 't1', 'therapy_id': 'th2', 'session_children': [_seat('c4')]},
        ]}),
      ]);
      await open(tester, store, '/therapist/children');
      // Kavin (c4) is in Monday's session, which on a Sunday is tomorrow (THR-6).
      expect(find.textContaining('Next tomorrow 9:30 AM'), findsOneWidget, reason: 'Children tab looks into next week too');
      await close(tester);
    });
  });

  // ------------------------------------------------------------------ messages
  testWidgets('a message arriving while the Messages tab is hidden stays unread', (tester) async {
    final store = demoStore(Role.therapist);
    final go = await open(tester, store, '/therapist/messages');
    go('/therapist');
    await tester.pump(const Duration(seconds: 1));
    store.messages.add(Message({
      'id': 'new1',
      'therapist_id': 't1',
      'sender_id': 'u-admin',
      'from_admin': true,
      'body': 'Please cover the 4 pm group today.',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'read_at': null,
    }));
    store.touch();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(store.unreadMessages, 1, reason: 'THR-1: the offstage ChatView must not mark the thread read');
    expect(find.text('New from the centre'), findsOneWidget);
    // Back on Messages, it is on screen, so now it is read.
    go('/therapist/messages');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(store.unreadMessages, 0);
    await close(tester);
  });

  // ------------------------------------------------------------------ final marks
  testWidgets('finished session: one-child mark and "Mark all present" both ask first', (tester) async {
    final store = demoStore(Role.therapist);
    final slot = _slotToday('done', -60, 30, [
      {'id': 'D1', 'name': 'Done OT', 'therapist_id': 't1', 'therapy_id': 'th2', 'session_children': [_seat('c1'), _seat('c4')]},
    ]);
    if (slot == null) return markTestSkipped('too early in the day');
    store.weekSlots(monday)!.add(slot);
    await open(tester, store, '/therapist/sessions/D1');
    await tester.tap(find.descendant(of: find.byType(AttendanceToggle).first, matching: find.text('Present')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsOneWidget, reason: 'single mark after the end is confirmed');
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Mark all present'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsOneWidget, reason: 'THR-2: bulk final marking is confirmed');
    expect(find.text('Mark 2 present?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(unmarked(store.sessionById('D1')!), hasLength(2), reason: 'cancel marks nobody');
    await tester.pump(const Duration(seconds: 2));
    await close(tester);
  });

  // ------------------------------------------------------------------ loading / error
  testWidgets('Today without the current week loaded: an error with "Try again", not an endless spinner', (tester) async {
    final base = demoStore(Role.therapist);
    final store = AppStore(client: SupabaseClient('http://localhost:54321', 'test-key', authOptions: const AuthClientOptions(autoRefreshToken: false)))..realtime = false;
    store.role = Role.therapist;
    store.ready = true;
    store.userName = 'Lakshmi';
    store.setCatalog(base.therapies, base.therapists, base.children);
    store.therapistId = 't1';
    await open(tester, store, '/therapist');
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(CircularProgressIndicator), findsNothing, reason: 'THR-5: no endless spinner on Today when the week failed to load');
    expect(find.text('Try again'), findsOneWidget);
    await close(tester);
  });

  // ------------------------------------------------------------------ layout at small widths + large text
  testWidgets('therapist screens at 320px with 1.3x text and long content do not overflow', (tester) async {
    final store = demoStore(Role.therapist);
    final slot = _slotToday('big', -5, 45, [
      {
        'id': 'B1',
        'name': 'Sensory integration and fine motor small group',
        'therapist_id': 't1',
        'therapy_id': 'th2',
        'session_children': [_seat('c1', reason: 'Has a fever since last night and the doctor asked for rest'), _seat('c4', attendance: 'present', rating: 7), _seat('c3')],
      },
    ]);
    if (slot == null) return markTestSkipped('too close to midnight');
    store.weekSlots(monday)!.add(slot);
    final failures = <String>[];
    for (final size in const [Size(320, 640), Size(360, 740)]) {
      for (final p in ['/therapist', '/therapist/week', '/therapist/children', '/therapist/children/c1', '/therapist/sessions/B1', '/therapist/messages']) {
        await open(tester, store, p, size: size, textScale: 1.3);
        for (Object? e = tester.takeException(); e != null; e = tester.takeException()) {
          final msg = '$e';
          if (msg.contains('GoogleFonts') || msg.contains('google_fonts')) continue;
          failures.add('${size.width.toInt()}px $p: ${msg.split('\n').take(3).join(' ')}');
        }
      }
    }
    await close(tester);
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  testWidgets('0-10 rating scale stays on one row from 320px up', (tester) async {
    final store = demoStore(Role.therapist);
    final slot = _slotToday('r', -5, 45, [
      {'id': 'R1', 'name': 'Rate OT', 'therapist_id': 't1', 'therapy_id': 'th2', 'session_children': [_seat('c4', attendance: 'present')]},
    ]);
    if (slot == null) return markTestSkipped('too close to midnight');
    store.weekSlots(monday)!.add(slot);
    final rows = <double, String>{};
    for (final w in const [320.0, 360.0, 393.0, 412.0]) {
      await open(tester, store, '/therapist/sessions/R1', size: Size(w, 1600));
      final zero = tester.getCenter(_rate(0)).dy;
      final ten = tester.getCenter(_rate(10)).dy;
      final chip = tester.getSize(_rate(5));
      rows[w] = 'same row: ${zero == ten}, chip ${chip.width.toStringAsFixed(0)}x${chip.height.toStringAsFixed(0)}px';
      expect(zero, ten, reason: 'THR-8: "10" wraps to a second row at ${w}px');
      expect(chip.height, greaterThanOrEqualTo(40), reason: 'THR-8: rating cells are big enough to tap at ${w}px');
    }
    await close(tester);
    // ignore: avoid_print
    print('rating scale: $rows');
  });
}

Finder _rate(int i) => find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Rate $i out of 10');

class GoRouterLike {
  final void Function(String) go;
  GoRouterLike(this.go);
  void call(String p) => go(p);
}
