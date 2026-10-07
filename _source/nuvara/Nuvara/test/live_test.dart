// Signs in as each test account against the live Supabase project and checks what each role can
// see and do. Read-only: the only writes attempted are ones the database must reject.
// Needs .env: flutter test --tags live --dart-define-from-file=.env
@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuvara/actions.dart';
import 'package:nuvara/config.dart';
import 'package:nuvara/models.dart';
import 'package:nuvara/store.dart';
import 'package:nuvara/util.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthClientOptions, AuthException, SupabaseClient, UserAttributes;

import 'live_helpers.dart';

void main() {
  if (missingConfig != null || testPassword.isEmpty) {
    test('live suite', () {}, skip: 'Needs SUPABASE_* and TEST_PASSWORD: run with --dart-define-from-file=.env');
    return;
  }
  final stores = <Role, AppStore>{};

  setUpAll(() async {
    HttpOverrides.global = null;
    for (final role in Role.values) {
      final store = AppStore(client: SupabaseClient(supabaseUrl, supabaseKey, authOptions: const AuthClientOptions(autoRefreshToken: false)))..realtime = false;
      await store.signInAs(role);
      stores[role] = store;
    }
  });

  tearDownAll(() async {
    for (final s in stores.values) {
      await s.db.auth.signOut();
      await s.db.dispose();
    }
  });

  final monday = weekStart(todayISO());

  test('wrong password gives a friendly message', () async {
    final s = AppStore(client: SupabaseClient(supabaseUrl, supabaseKey, authOptions: const AuthClientOptions(autoRefreshToken: false)))..realtime = false;
    await s.signIn(Role.admin, 'admin@nuvara.test', 'not-the-password');
    expect(s.error, contains("don't match"));
    expect(s.role, isNull);
    await s.db.dispose();
  });

  test('parents only see sessions their child is in', () {
    final p = stores[Role.parent]!;
    final mine = {for (final c in p.children) c.id};
    expect(p.sessionsInWeek(monday).every((x) => x.childIds.any(mine.contains)), isTrue);
  });

  test('every role signs in and loads', () {
    for (final r in Role.values) {
      expect(stores[r]!.error, isNull, reason: r.name);
      expect(stores[r]!.role, r);
      expect(stores[r]!.weekSlots(monday), isNotNull);
    }
  });

  test('everything loads oldest/lowest first', () {
    final s = stores[Role.admin]!;
    final nos = s.children.map((c) => c.no).toList();
    expect(nos, [...nos]..sort());
    final names = s.therapies.map((t) => t.name).toList();
    expect(names, [...names]..sort());
    final slots = s.weekSlots(monday)!;
    expect([for (final x in slots) '${x.date} ${x.start}'], [for (final x in slots) '${x.date} ${x.start}']..sort());
    final weeks = s.feeWeeks.map((w) => w.monday).toList();
    expect(weeks, [...weeks]..sort((a, b) => b.compareTo(a)), reason: 'bills newest week first');
  });

  test('admin sees the whole centre, with private details', () {
    final s = stores[Role.admin]!;
    expect(s.children.length, greaterThanOrEqualTo(5));
    expect(s.therapists.every((t) => t.details != null), isTrue);
    expect(s.therapies, isNotEmpty);
    expect(s.feeWeeks.where((w) => w.monday == monday), isNotEmpty, reason: 'this week has bills from the timetable');
    expect(s.weekIndex[monday]?.slots, greaterThan(0));
  });

  test('therapist sees only their children and not other salaries', () async {
    final s = stores[Role.therapist]!;
    expect(s.therapistId, isNotNull);
    final mine = s.sessionsOfTherapist(s.therapistId!, monday).expand((x) => x.childIds).toSet();
    expect(s.children.map((c) => c.id).toSet(), mine);
    expect(s.therapists.where((t) => t.id != s.therapistId).every((t) => t.details == null), isTrue);
    expect(s.feeWeeks, isEmpty);
    await expectLater(s.loadFees(), throwsA(isA<Exception>()), reason: 'fees are for the centre and families only');
  });

  test('parent sees only their own children and fees', () {
    final s = stores[Role.parent]!;
    expect(s.children.map((c) => c.name).toSet(), {'Aarav Sharma', 'Anaya Sharma'});
    expect(s.feeWeeks.map((w) => w.childId).toSet().difference(s.children.map((c) => c.id).toSet()), isEmpty);
    expect(s.payments.map((p) => p.childId).toSet().difference(s.children.map((c) => c.id).toSet()), isEmpty);
    expect(s.therapists.every((t) => t.details == null), isTrue);
  });

  test('database rejects double-booking and overpayment', () async {
    final s = stores[Role.admin]!;
    final slot = s.weekSlots(monday)!.firstWhere((x) => x.sessions.isNotEmpty);
    final busy = slot.sessions.first;
    final freeChild = s.children.firstWhere((c) => s.childClash(c.id, slot.date, slot.start, slot.end) == null);
    await expectLater(
      s.createSessions(dates: [slot.date], start: slot.start, end: slot.end, name: 'Clash', therapistId: busy.therapistId, therapyId: busy.therapyId, childIds: [freeChild.id]),
      throwsA(predicate((e) => '$e'.contains('is already in'))),
    );
    final kid = s.children.first;
    await expectLater(
      s.recordPayment(childId: kid.id, monday: monday, amount: 9999999, method: 'Cash', note: '', paidOn: todayISO()),
      throwsA(predicate((e) => '$e'.contains('is due'))),
    );
  });

  test('non-admins cannot write', () async {
    for (final r in [Role.therapist, Role.parent]) {
      final s = stores[r]!;
      await expectLater(s.createSlots([todayISO()], '06:00', '06:30'), throwsA(predicate((e) => '$e'.contains('Only the centre admin'))), reason: r.name);
      final rows = await s.db.from('therapies').update({'base_fee': 1}).neq('id', '00000000-0000-0000-0000-000000000000').select();
      expect(rows, isEmpty, reason: '${r.name} update must match no rows');
    }
  });

  group('session record permissions', () {
    Session pick(AppStore s, bool Function(Session) where) => s.sessionsInWeek(monday).firstWhere(where);

    test('therapist marks attendance on their own session and can undo it', () async {
      final t = stores[Role.therapist]!;
      final s = pick(t, (x) => x.therapistId == t.therapistId && x.attendanceOpen);
      final kid = s.childIds.first;
      final before = s.seat(kid)!.attendance;
      await t.markAttendance(s, [kid], 'late');
      await t.loadWeek(monday, force: true);
      expect(t.sessionById(s.id)!.seat(kid)!.attendance, 'late');
      await t.markAttendance(t.sessionById(s.id)!, [kid], before);
    });

    test('attendance is refused for future sessions and for other therapists', () async {
      final t = stores[Role.therapist]!;
      final future = t.sessionsInWeek(monday).where((x) => x.therapistId == t.therapistId && !x.attendanceOpen).firstOrNull;
      if (future != null) {
        await expectLater(t.markAttendance(future, [future.childIds.first], 'present'), throwsA(predicate((e) => '$e'.contains('opens 15 minutes'))));
      }
      final admin = stores[Role.admin]!;
      final other = pick(admin, (x) => x.therapistId != t.therapistId && x.attendanceOpen);
      await expectLater(t.markAttendance(t.sessionById(other.id)!, [other.childIds.first], 'present'), throwsA(predicate((e) => '$e'.contains('Only this session'))));
      final p = stores[Role.parent]!;
      final mine = pick(p, (x) => x.childIds.isNotEmpty && x.attendanceOpen);
      await expectLater(p.markAttendance(mine, [mine.childIds.first], 'present'), throwsA(isA<Exception>()));
    });

    test('parent reports and withdraws an absence only for their own child', () async {
      final p = stores[Role.parent]!;
      final s = p.sessionsInWeek(monday).where((x) => x.childIds.isNotEmpty && x.phase == 'upcoming' && !x.seat(x.childIds.first)!.noticed).firstOrNull;
      if (s != null) {
        final kid = s.childIds.first;
        await p.reportAbsence(s, kid, 'Unwell');
        expect(p.sessionById(s.id)!.seat(kid)!.absenceReason, 'Unwell');
        await p.reportAbsence(p.sessionById(s.id)!, kid, null);
        expect(p.sessionById(s.id)!.seat(kid)!.noticed, isFalse);
      }
      final admin = stores[Role.admin]!;
      final diya = admin.children.firstWhere((c) => c.name == 'Diya Patel');
      final hers = pick(admin, (x) => x.childIds.contains(diya.id));
      await expectLater(p.reportAbsence(hers, diya.id, 'x'), throwsA(predicate((e) => '$e'.contains('your own child'))));
    });

    test("only the session's therapist rates it; parents and admins cannot", () async {
      final t = stores[Role.therapist]!;
      final s = t.sessionsInWeek(monday).where((x) => x.therapistId == t.therapistId && x.ratingOpen && x.seats.values.any((y) => y.attended)).firstOrNull;
      if (s != null) {
        final kid = s.seats.values.firstWhere((y) => y.attended).childId;
        final before = s.seat(kid)!.rating;
        await t.rateSession(s, kid, 7);
        await t.loadWeek(monday, force: true);
        expect(t.sessionById(s.id)!.seat(kid)!.rating, 7);
        await t.rateSession(t.sessionById(s.id)!, kid, before);
      }
      final admin = stores[Role.admin]!;
      final any = admin.sessionsInWeek(monday).firstWhere((x) => x.childIds.isNotEmpty);
      await expectLater(admin.rateSession(any, any.childIds.first, 5), throwsA(predicate((e) => '$e'.contains('Only this session'))));
      final p = stores[Role.parent]!;
      final mine = p.sessionsInWeek(monday).firstWhere((x) => x.childIds.isNotEmpty);
      await expectLater(p.rateSession(mine, mine.childIds.first, 5), throwsA(predicate((e) => '$e'.contains('Only this session'))));
    });
  });

  group('logins', () {
    AppStore fresh() => AppStore(client: SupabaseClient(supabaseUrl, supabaseKey, authOptions: const AuthClientOptions(autoRefreshToken: false)))..realtime = false;

    test('admin sign-up only works for approved emails', () async {
      final s = fresh();
      await expectLater(s.signUpAdmin(name: 'Stranger', email: 'stranger@example.com', password: 'Password123'), throwsA(predicate((e) => '$e'.contains('not approved'))));
      await expectLater(s.signUpAdmin(name: 'Again', email: 'admin@nuvara.test', password: 'Password123'), throwsA(predicate((e) => '$e'.contains('already exists'))));
      await s.db.dispose();
    });

    test('identifier formats map to the right login', () {
      expect(loginEmail(Role.therapist, '+91 98400 11001'), 't9840011001@therapist.nuvara.app');
      expect(loginEmail(Role.parent, 'c001'), 'child-1@parent.nuvara.app');
      expect(loginEmail(Role.parent, '12'), 'child-12@parent.nuvara.app');
      expect(loginEmail(Role.parent, 'X1'), isNull);
      expect(defaultPassword('santhosh', '2000-01-01'), 'S01012000');
    });

    test('default password must be replaced once; after that only the admin reset changes it', () async {
      final admin = stores[Role.admin]!;
      final rahul = admin.therapists.firstWhere((t) => t.name == 'Rahul Menon');
      final phone = rahul.details!.phone;
      final starting = defaultPassword(rahul.name, rahul.details!.dob);
      await admin.resetTherapistPassword(rahul.id);
      expect(admin.onDefaultPassword(rahul.profileId), isTrue, reason: 'the profile shows the default is in use');

      final s = fresh();
      await s.signIn(Role.therapist, phone, starting);
      expect(s.error, isNull);
      expect(s.mustChangePassword, isTrue, reason: 'signed in with the default password');
      await expectLater(s.setPassword(starting), throwsA(predicate((e) => '$e'.contains('different'))), reason: 'keeping the default is not allowed');
      final own = 'Own${DateTime.now().millisecondsSinceEpoch % 100000}x';
      await s.setPassword(own);
      expect(s.mustChangePassword, isFalse);
      // That was the one change allowed; another, through the app or straight to the auth API, is refused.
      await expectLater(s.setPassword('Again12345x'), throwsA(predicate((e) => '$e'.contains('managed by the centre'))));
      await expectLater(s.db.auth.updateUser(UserAttributes(password: 'Again12345x')), throwsA(isA<AuthException>()));
      await s.signOut();

      await s.signIn(Role.therapist, phone, starting);
      expect(s.error, contains("don't match"), reason: 'the default stops working once replaced');
      await s.signIn(Role.therapist, phone, own);
      expect(s.error, isNull);
      expect(s.mustChangePassword, isFalse);
      await s.signOut();

      await admin.resetTherapistPassword(rahul.id);
      await s.signIn(Role.therapist, phone, starting);
      expect(s.error, isNull, reason: 'the reset brings the default back');
      expect(s.mustChangePassword, isTrue, reason: 'and they must replace it again');
      await s.signOut();
      await s.db.dispose();
    });

    test('parent signs in with the child ID', () {
      final p = stores[Role.parent]!;
      expect(p.role, Role.parent);
      expect(p.children.any((c) => c.code == 'C001'), isTrue);
    });
  });

  group('messages', () {
    test('parent and admin talk; read receipts; therapists and other families see nothing', () async {
      final p = stores[Role.parent]!, admin = stores[Role.admin]!, t = stores[Role.therapist]!;
      final kid = p.children.firstWhere((c) => c.code == 'C001');
      final text = 'Live test ${DateTime.now().microsecondsSinceEpoch}';
      await p.sendMessage(Convo.family(kid.id), text);
      await admin.loadMessages();
      final got = admin.messages.firstWhere((m) => m.body == text);
      expect(got.fromAdmin, isFalse);
      expect(admin.unreadIn(Convo.family(kid.id)), greaterThan(0));
      await admin.markThreadRead(Convo.family(kid.id));
      await p.loadMessages();
      expect(p.messages.firstWhere((m) => m.id == got.id).readAt, isNotNull, reason: 'the parent sees it was read');

      await admin.sendMessage(Convo.family(kid.id), 'Reply $text');
      await p.loadMessages();
      expect(p.thread(Convo.family(kid.id)).last.fromAdmin, isTrue);

      final seen = await t.db.from('messages').select('id');
      expect(seen, isEmpty, reason: 'therapists have no access to messages');
      final diya = admin.children.firstWhere((c) => c.name == 'Diya Patel');
      await expectLater(p.sendMessage(Convo.family(diya.id), 'not mine'), throwsA(isA<Exception>()));
      await expectLater(p.db.from('messages').insert({'child_id': kid.id, 'body': 'pretend admin', 'from_admin': true, 'sender_id': p.userId}), throwsA(anything));

      await admin.db.from('messages').delete().like('body', '%$text%');
    });
  });
}
