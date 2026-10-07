import 'package:nuvara/models.dart';
import 'package:nuvara/store.dart';
import 'package:nuvara/util.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient, AuthClientOptions;

/// An offline store filled through the same JSON parsing the app uses for Supabase rows.
AppStore demoStore(Role role) {
  final store = AppStore(client: SupabaseClient('http://localhost:54321', 'test-key', authOptions: const AuthClientOptions(autoRefreshToken: false)))..realtime = false
    ..persist = false;
  store.role = role;
  store.ready = true;
  store.userName = 'Lakshmi Narayanan';

  final therapies = [
    Therapy({'id': 'th1', 'name': 'Speech Therapy', 'base_fee': 3000}),
    Therapy({'id': 'th2', 'name': 'Occupational Therapy', 'base_fee': 3500}),
    Therapy({'id': 'th3', 'name': 'Behaviour Therapy', 'base_fee': 4000}),
  ];
  final therapists = [
    for (final (i, n, ts) in [(1, 'Priya Raman', ['th2']), (2, 'Rahul Menon', ['th1']), (3, 'Divya Nair', ['th3', 'th1'])])
      Therapist({
        'id': 't$i',
        'therapist_no': i,
        'name': n,
        'profile_id': i == 1 ? 'u-therapist' : null,
        'active': true,
        'therapist_therapies': [for (final t in ts) {'therapy_id': t}],
        'therapist_details': {'dob': '1990-05-0$i', 'phone': '98400 1000$i', 'emergency_phone': '', 'salary': 30000 + i * 1000},
      }),
  ];
  final children = [
    for (final (i, n, ts, fee) in <(int, String, List<String>, num?)>[
      (1, 'Aarav Sharma', ['th1', 'th2'], null),
      (2, 'Anaya Sharma', ['th1'], 2500),
      (3, 'Diya Patel', ['th3'], null),
      (4, 'Kavin Raj', ['th2', 'th3'], null),
    ])
      Child({
        'id': 'c$i',
        'child_no': i,
        'name': n,
        'dob': '2020-0$i-14',
        'father_name': 'Father $i',
        'mother_name': 'Mother $i',
        'phone': '98765 4321$i',
        'alt_phone': '',
        'active': true,
        // Anaya pays her own fee for speech therapy.
        'child_therapies': [for (final t in ts) {'therapy_id': t, 'session_fee': t == 'th1' ? fee : null}],
      }),
  ];
  store.setCatalog(therapies, therapists, children);

  final monday = weekStart(todayISO());
  Map<String, dynamic> session(String id, String name, String t, String therapy, List<String> kids) =>
      {
        'id': id,
        'name': name,
        'therapist_id': t,
        'therapy_id': therapy,
        'session_children': [
          for (final k in kids)
            {
              'child_id': k,
              'attendance': k == 'c1' ? 'present' : null,
              'note': k == 'c1' ? 'Worked well and stayed focused.' : '',
              'absence_reason': k == 'c2' ? "Doctor's appointment" : null,
              'absence_at': k == 'c2' ? DateTime.now().toUtc().toIso8601String() : null,
              'rating': k == 'c1' ? 8 : null,
              'rate': k == 'c1' ? 3000 : null,
            },
        ],
      };
  final slots = <Slot>[];
  for (var d = 0; d < 5; d++) {
    final date = addDays(monday, d);
    slots.add(Slot({
      'id': 's$d-a',
      'slot_date': date,
      'start_time': '09:30:00',
      'end_time': '10:15:00',
      'sessions': [session('x$d-1', 'Speech group', 't2', 'th1', ['c1', 'c2']), session('x$d-2', 'OT room', 't1', 'th2', ['c4'])],
    }));
    slots.add(Slot({
      'id': 's$d-b',
      'slot_date': date,
      'start_time': '10:15:00',
      'end_time': '11:00:00',
      'sessions': [session('y$d-1', 'Behaviour', 't3', 'th3', ['c3'])],
    }));
  }
  slots.add(Slot({'id': 'empty', 'slot_date': addDays(monday, 1), 'start_time': '11:15:00', 'end_time': '12:00:00', 'sessions': []}));
  store.setWeek(monday, slots);
  store.setWeek(addDays(monday, -7), []);
  store.weekIndex = {monday: (slots: slots.length, sessions: 15)};

  final last = addDays(monday, -7);
  Map<String, dynamic> line(String therapy, int allocated, int attended, double rate) => {
        'therapy_id': therapy,
        'allocated': allocated,
        'attended': attended,
        'absent': allocated - attended,
        'unmarked': 0,
        'upcoming': 0,
        'amount': attended * rate,
        'rates': [if (attended > 0) {'rate': rate, 'count': attended}],
      };
  Map<String, dynamic> week(String child, String m, List<Map<String, dynamic>> lines, {double paid = 0, double verifying = 0, bool closed = true}) => {
        'child_id': child,
        'week_start': m,
        'allocated': lines.fold<int>(0, (a, l) => a + (l['allocated'] as int)),
        'attended': lines.fold<int>(0, (a, l) => a + (l['attended'] as int)),
        'absent': lines.fold<int>(0, (a, l) => a + (l['absent'] as int)),
        'unmarked': 0,
        'upcoming': closed ? 0 : 3,
        'amount': lines.fold<double>(0, (a, l) => a + (l['amount'] as double)),
        'paid': paid,
        'verifying': verifying,
        'lines': lines,
        'closed': closed,
      };
  store.setFees([
    // Aarav: 10 speech sessions allotted last week, 9 attended; OT 5 of 5. Partly paid.
    FeeWeek(week('c1', last, [line('th1', 10, 9, 3000), line('th2', 5, 5, 3500)], paid: 20000)),
    FeeWeek(week('c2', last, [line('th1', 5, 5, 2500)], verifying: 12500)),
    FeeWeek(week('c3', last, [line('th3', 5, 4, 4000)])),
    FeeWeek(week('c4', last, [line('th2', 5, 5, 3500), line('th3', 5, 5, 4000)], paid: 37500)),
    FeeWeek(week('c1', monday, [line('th1', 10, 2, 3000), line('th2', 5, 1, 3500)], closed: false)),
  ], [
    Payment({'id': 'p1', 'child_id': 'c1', 'week_start': last, 'amount': 20000, 'method': 'UPI', 'status': 'confirmed', 'txn_ref': 'NVTEST1', 'payee_vpa': 'centre@okaxis', 'payee_name': 'Nuvara', 'utr': '412345678901', 'verified_by': 'upi_app', 'paid_on': todayISO(), 'receipt_no': 1, 'created_at': DateTime.now().toUtc().toIso8601String(), 'note': ''}),
    Payment({'id': 'p2', 'child_id': 'c2', 'week_start': last, 'amount': 12500, 'method': 'UPI', 'status': 'verifying', 'txn_ref': 'NVTEST2', 'payee_vpa': 'centre@okaxis', 'payee_name': 'Nuvara', 'utr': '412345678902', 'created_at': DateTime.now().toUtc().toIso8601String(), 'note': ''}),
    Payment({'id': 'p3', 'child_id': 'c4', 'week_start': last, 'amount': 37500, 'method': 'Cash', 'status': 'confirmed', 'txn_ref': 'NVTEST3', 'verified_by': 'admin', 'paid_on': todayISO(), 'receipt_no': 2, 'created_at': DateTime.now().toUtc().toIso8601String(), 'note': 'Receipt 12'}),
  ]);
  store.upiAccounts = [UpiAccount({'id': 'u1', 'vpa': 'centre@okaxis', 'payee_name': 'Nuvara', 'label': 'HDFC', 'active': true, 'archived': false})];
  store.requests = [
    RescheduleRequest({
      'id': 'r1', 'child_id': 'c1', 'session_id': 'x4-1', 'scope': 'series', 'from_date': addDays(monday, 4), 'from_start': '09:30:00', 'from_end': '10:15:00',
      'session_name': 'Speech group', 'therapist_id': 't2', 'therapy_id': 'th1', 'preferred_date': null, 'preferred_start': '16:00:00', 'preferred_end': '16:45:00',
      'reason': 'School timing changed', 'status': 'pending', 'admin_note': '', 'moved': 0, 'created_at': DateTime.now().toUtc().toIso8601String(),
    }),
  ];
  for (final c in children) {
    store.setProgress(c.id, [
      for (final ct in c.therapies)
        for (var w = 8; w >= 0; w--)
          ProgressPoint({
            'session_id': 'h${c.id}${ct.therapyId}$w',
            'day': addDays(monday, -7 * w),
            'start_time': '09:30:00',
            'end_time': '10:15:00',
            'session_name': 'Session',
            'therapy_id': ct.therapyId,
            'therapist_id': 't1',
            'attendance': 'present',
            'rating': (3 + (8 - w) ~/ 2).clamp(0, 10),
            'note': w == 0 ? 'Settled quickly and finished every activity.' : '',
            'rated_at': null,
          }),
      // Attended yesterday, report not written yet.
      if (c.id == 'c1')
        ProgressPoint({
          'session_id': 'pending-c1',
          'day': addDays(todayISO(), -1),
          'start_time': '11:00:00',
          'end_time': '11:45:00',
          'session_name': 'Speech',
          'therapy_id': c.therapies.first.therapyId,
          'therapist_id': 't1',
          'attendance': 'present',
          'rating': null,
          'note': '',
          'rated_at': null,
        }),
    ]..sort((a, b) => a.date.compareTo(b.date)));
  }
  store.pendingReports = [
    PendingReport({
      'session_id': 'x0-1',
      'child_id': 'c1',
      'day': addDays(todayISO(), -1),
      'start_time': '11:00:00',
      'end_time': '11:45:00',
      'session_name': 'Speech',
      'therapy_id': 'th1',
      'therapist_id': 't1',
    }),
  ];
  store.parentLogins = {'c1', 'c2', 'c3'};
  final now = DateTime.now().toUtc();
  store.messages = [
    for (final (i, child, admin, body, read) in [
      (0, 'c1', false, 'Hello, Aarav has a mild cold today. Is it okay if he comes for speech?', true),
      (1, 'c1', true, 'Thanks for letting us know! Yes, he can come — we will keep the session gentle.', true),
      (2, 'c1', false, 'Thank you so much 🙏', false),
      (3, 'c3', false, 'Can we move Diya to the 10:15 slot from next week?', false),
    ])
      Message({
        'id': 'm$i',
        'child_id': child,
        'sender_id': admin ? 'u-admin' : 'u-parent',
        'from_admin': admin,
        'body': body,
        'created_at': now.subtract(Duration(minutes: 90 - i * 20)).toIso8601String(),
        'read_at': read ? now.toIso8601String() : null,
      }),
    // The centre and a therapist.
    Message({
      'id': 'mt1',
      'therapist_id': 't1',
      'sender_id': 'u-therapist',
      'from_admin': false,
      'body': 'Can I swap my Friday 4 pm session?',
      'created_at': now.subtract(const Duration(minutes: 5)).toIso8601String(),
      'read_at': null,
    }),
  ];
  if (role == Role.therapist) store.therapistId = 't1';
  return store;
}

/// Marks every seat in the loaded weeks as confirmed by the family. The demo week runs Monday to Friday, so on a
/// weekday its later sessions would otherwise still be waiting for an answer; tests about confirming add their
/// own unanswered sessions on top.
void confirmLoadedSeats(AppStore store) {
  final now = DateTime.now();
  for (final m in [for (var w = -1; w <= 2; w++) addDays(weekStart(todayISO()), 7 * w)]) {
    for (final s in store.sessionsInWeek(m)) {
      for (final seat in s.seats.values) {
        seat.confirmedAt ??= now;
      }
    }
  }
}
