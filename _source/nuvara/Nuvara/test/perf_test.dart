// Smoothness check at centre scale: 150 children, 15 therapists, ~190 sessions a week, half a year of
// weekly bills, 2,000 payments, 1,500 messages and 300 progress reports. Every main screen is opened,
// flung through and refreshed while each frame's build + layout + paint time is measured.
//
// Times here come from the test runner (debug/JIT, no GPU), so they are several times slower than a
// release build on a phone. They are compared against generous limits to catch screens that do far too
// much work per frame; a release build is roughly 5–10× faster.
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

/// [demoStore] scaled up to a busy centre.
AppStore bigStore(Role role) {
  final store = demoStore(role);
  final therapies = store.therapies;
  final therapists = [
    for (var i = 1; i <= 15; i++)
      Therapist({
        'id': 't$i',
        'therapist_no': i,
        'name': 'Therapist Number$i',
        'profile_id': i == 1 ? 'u-therapist' : null,
        'active': true,
        'therapist_therapies': [{'therapy_id': therapies[i % 3].id}],
        'therapist_details': {'dob': '1990-05-01', 'phone': '984001${i.toString().padLeft(4, '0')}', 'emergency_phone': '', 'salary': 30000},
      }),
  ];
  final children = [
    for (var i = 1; i <= 150; i++)
      Child({
        'id': 'c$i',
        'child_no': i,
        'name': 'Child Name$i',
        'dob': '2019-0${1 + i % 9}-1${i % 9}',
        'father_name': 'Father $i',
        'mother_name': 'Mother $i',
        'phone': '98765${i.toString().padLeft(5, '0')}',
        'alt_phone': '',
        'active': true,
        'child_therapies': [{'therapy_id': therapies[i % 3].id, 'session_fee': null}, if (i.isEven) {'therapy_id': therapies[(i + 1) % 3].id, 'session_fee': null}],
      }),
  ];
  store.setCatalog(therapies, therapists, children);

  final monday = weekStart(todayISO());
  var n = 0;
  final slots = <Slot>[];
  for (var d = 0; d < 6; d++) {
    for (var h = 0; h < 8; h++) {
      final start = fromMin(9 * 60 + h * 50), end = fromMin(9 * 60 + h * 50 + 45);
      slots.add(Slot({
        'id': 's$d-$h',
        'slot_date': addDays(monday, d),
        'start_time': '$start:00',
        'end_time': '$end:00',
        'sessions': [
          for (var k = 0; k < 4; k++)
            {
              'id': 'x${n++}',
              'name': 'Group $k',
              'therapist_id': 't${1 + (h * 4 + k) % 15}',
              'therapy_id': therapies[k % 3].id,
              'session_children': [
                for (var c = 0; c < 4; c++)
                  {
                    'child_id': 'c${1 + (d * 37 + h * 16 + k * 4 + c) % 150}',
                    'attendance': d < 2 ? 'present' : null,
                    'note': d < 1 ? 'Settled in well.' : '',
                    'rating': d < 1 ? 7 : null,
                    'rate': d < 2 ? 3000 : null,
                  },
              ],
            },
        ],
      }));
    }
  }
  store.setWeek(monday, slots);
  store.weekIndex = {monday: (slots: slots.length, sessions: n)};

  Map<String, dynamic> line(String th, int alloc, int att) => {
        'therapy_id': th,
        'allocated': alloc,
        'attended': att,
        'absent': alloc - att,
        'unmarked': 0,
        'upcoming': 0,
        'amount': att * 3000.0,
        'rates': [if (att > 0) {'rate': 3000, 'count': att}],
      };
  final weeks = <FeeWeek>[];
  final payments = <Payment>[];
  for (var w = 0; w < 26; w++) {
    final m = addDays(monday, -7 * w);
    for (var i = 1; i <= 150; i++) {
      final paid = (i + w) % 4 != 0 ? 12000.0 : 0.0;
      weeks.add(FeeWeek({
        'child_id': 'c$i',
        'week_start': m,
        'allocated': 5,
        'attended': 4,
        'absent': 1,
        'unmarked': 0,
        'upcoming': w == 0 ? 2 : 0,
        'amount': 12000.0,
        'paid': paid,
        'verifying': 0.0,
        'lines': [line(therapies[i % 3].id, 5, 4)],
        'closed': w > 0,
      }));
      if (paid > 0 && payments.length < 2000) {
        payments.add(Payment({
          'id': 'p${payments.length}',
          'child_id': 'c$i',
          'week_start': m,
          'amount': paid,
          'method': 'Cash',
          'status': 'confirmed',
          'txn_ref': 'NVP${payments.length}',
          'verified_by': 'admin',
          'paid_on': m,
          'receipt_no': payments.length + 1,
          'created_at': DateTime.parse(m).toUtc().toIso8601String(),
          'note': '',
        }));
      }
    }
  }
  store.setFees(weeks, payments);

  final now = DateTime.now().toUtc();
  store.messages = [
    for (var i = 0; i < 1500; i++)
      Message({
        'id': 'm$i',
        if (i % 5 == 0) 'therapist_id': 't${1 + i % 15}' else 'child_id': 'c${1 + i % 150}',
        'sender_id': 'u',
        'from_admin': i.isEven,
        'body': 'Message number $i about the sessions this week.',
        'created_at': now.subtract(Duration(minutes: 1500 - i)).toIso8601String(),
        'read_at': i % 7 == 0 ? null : now.toIso8601String(),
      }),
  ];
  store.setProgress('c1', [
    for (var i = 300; i > 0; i--)
      ProgressPoint({
        'session_id': 'h$i',
        'day': addDays(todayISO(), -i ~/ 2),
        'start_time': i.isEven ? '09:30:00' : '11:00:00',
        'end_time': i.isEven ? '10:15:00' : '11:45:00',
        'session_name': 'Session',
        'therapy_id': therapies[i % 3].id,
        'therapist_id': 't1',
        'attendance': 'present',
        'rating': i % 11 == 0 ? null : (3 + (300 - i) ~/ 50).clamp(0, 10),
        'note': i % 3 == 0 ? 'Good focus today.' : '',
        'rated_at': null,
      }),
  ]);
  if (role == Role.parent) store.setCatalog(therapies, therapists, children.take(2).toList());
  return store;
}

typedef Frames = ({double open, double worst, double avg, double refresh});

Future<Frames> measure(WidgetTester t, Role role, String path) async {
  final store = bigStore(role);
  final router = buildRouter(store);
  await t.pumpWidget(ChangeNotifierProvider.value(value: store, child: MaterialApp.router(theme: buildTheme(), routerConfig: router)));
  await t.pump(const Duration(milliseconds: 50));

  // Open once to warm up (the test runner compiles code on first use, which a release build never does),
  // go back, then time a second open.
  router.go(path);
  for (var i = 0; i < 20; i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
  router.go(role.home);
  for (var i = 0; i < 20; i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
  final sw = Stopwatch()..start();
  router.go(path);
  await t.pump();
  await t.pump(const Duration(milliseconds: 16));
  final open = sw.elapsedMicroseconds / 1000;

  // Let the opening animations finish, then fling through the page frame by frame.
  for (var i = 0; i < 40; i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
  final times = <double>[];
  final scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isNotEmpty) {
    for (var fling = 0; fling < 3; fling++) {
      await t.fling(scrollable.first, const Offset(0, -900), 2500, warnIfMissed: false);
      for (var i = 0; i < 30; i++) {
        sw
          ..reset()
          ..start();
        await t.pump(const Duration(milliseconds: 16));
        times.add(sw.elapsedMicroseconds / 1000);
      }
    }
  }
  // A data refresh (what a realtime update does): every screen watching the store rebuilds. The first one
  // also compiles code in the test runner, so the steady state is the median of three.
  final refreshes = <double>[];
  for (var i = 0; i < 3; i++) {
    sw
      ..reset()
      ..start();
    store.touch();
    await t.pump();
    refreshes.add(sw.elapsedMicroseconds / 1000);
  }
  refreshes.sort();
  final refresh = refreshes[1];
  for (Object? e = t.takeException(); e != null; e = t.takeException()) {
    if (!'$e'.contains('GoogleFonts') && !'$e'.contains('google_fonts')) fail('$path: $e');
  }
  await t.pumpWidget(const SizedBox());
  final sorted = [...times]..sort();
  return (
    open: open,
    worst: sorted.isEmpty ? 0.0 : sorted.last,
    avg: times.isEmpty ? 0.0 : times.reduce((a, b) => a + b) / times.length,
    refresh: refresh,
  );
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  final monday = weekStart(todayISO());
  final screens = <(Role, String)>[
    (Role.admin, '/admin'),
    (Role.admin, '/admin/timetable/$monday'),
    (Role.admin, '/admin/children'),
    (Role.admin, '/admin/children/c1'),
    (Role.admin, '/admin/fees'),
    (Role.admin, '/admin/fees/c1'),
    (Role.admin, '/admin/messages'),
    (Role.admin, '/admin/messages/parents'),
    (Role.admin, '/admin/messages/c1'),
    (Role.admin, '/admin/reports'),
    (Role.therapist, '/therapist'),
    (Role.therapist, '/therapist/week'),
    (Role.parent, '/parent'),
    (Role.parent, '/parent/progress'),
    (Role.parent, '/parent/fees'),
  ];
  final report = <String>[];
  for (final (role, path) in screens) {
    testWidgets('smooth at centre scale: $path', (t) async {
      t.view.physicalSize = const Size(1170, 2532);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final f = await measure(t, role, path);
      report.add('${path.padRight(36)} open ${f.open.toStringAsFixed(0).padLeft(4)} ms · scroll avg ${f.avg.toStringAsFixed(1).padLeft(5)} ms, worst ${f.worst.toStringAsFixed(0).padLeft(4)} ms · refresh ${f.refresh.toStringAsFixed(0).padLeft(4)} ms');
      // Generous limits for debug/JIT test timing (see the note at the top).
      expect(f.open, lessThan(1500), reason: '$path took too long to open');
      expect(f.avg, lessThan(60), reason: '$path scrolls slowly');
      expect(f.refresh, lessThan(800), reason: '$path rebuilds slowly on a data refresh');
    });
  }
  tearDownAll(() {
    // ignore: avoid_print
    print('\n${report.join('\n')}');
  });
}
