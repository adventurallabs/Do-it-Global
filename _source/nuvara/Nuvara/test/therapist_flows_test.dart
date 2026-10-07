import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nuvara/models.dart';
import 'package:nuvara/router.dart';
import 'package:nuvara/store.dart';
import 'package:nuvara/theme.dart';
import 'package:nuvara/util.dart';
import 'package:provider/provider.dart';

import 'fixtures.dart';

Map<String, dynamic> _seat(String child, {String? reason}) => {'child_id': child, 'attendance': null, 'note': '', 'absence_reason': reason, 'absence_at': reason == null ? null : DateTime.now().toUtc().toIso8601String()};

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  final monday = weekStart(todayISO());

  Future<void> open(WidgetTester tester, AppStore store, String path) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    final router = buildRouter(store);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: store, child: MaterialApp.router(theme: buildTheme(), routerConfig: router)));
    router.go(path);
    await tester.pumpAndSettle();
  }

  testWidgets('mark all present marks children with an absence notice absent', (tester) async {
    final store = demoStore(Role.therapist);
    // A session today that has already finished (00:00–00:01), with one child whose parent sent a notice.
    store.weekSlots(monday)!.add(Slot({
      'id': 'z',
      'slot_date': todayISO(),
      'start_time': '00:00:00',
      'end_time': '00:01:00',
      'sessions': [
        {'id': 'z1', 'name': 'Early bird', 'therapist_id': 't1', 'session_children': [_seat('c2', reason: 'Fever'), _seat('c4')]},
      ],
    }));
    await open(tester, store, '/therapist/sessions/z1');
    expect(find.textContaining('Fever'), findsOneWidget);
    final s = store.sessionById('z1')!;
    await tester.tap(find.text('Mark all present'));
    await tester.pumpAndSettle();
    // The session is over, so the marks are final: it asks first.
    expect(find.text('Mark 1 present and 1 absent (parent notice)?'), findsOneWidget);
    await tester.tap(find.text('Save'));
    // The change is optimistic: it shows before the (offline, failing) save returns.
    expect(s.seat('c4')!.attendance, 'present');
    expect(s.seat('c2')!.attendance, 'absent');
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  });

  testWidgets('attendance is locked for future sessions', (tester) async {
    final store = demoStore(Role.therapist);
    final next = addDays(monday, 7);
    store.setWeek(next, [
      Slot({
        'id': 'n',
        'slot_date': addDays(next, 1),
        'start_time': '09:30:00',
        'end_time': '10:15:00',
        'sessions': [
          {'id': 'f1', 'name': 'OT room', 'therapist_id': 't1', 'session_children': [_seat('c4')]},
        ],
      }),
    ]);
    await open(tester, store, '/therapist/sessions/f1');
    expect(find.textContaining('Attendance opens at'), findsOneWidget);
    expect(find.text('Mark all present'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  });
}
