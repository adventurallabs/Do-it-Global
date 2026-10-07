// The offline snapshot: what's saved, how it's trimmed and expired, how a saved snapshot fills the store,
// and the banner that says the app is showing saved data.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nuvara/models.dart';
import 'package:nuvara/offline.dart';
import 'package:nuvara/store.dart';
import 'package:nuvara/theme.dart';
import 'package:nuvara/util.dart';
import 'package:nuvara/widgets/offline_banner.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthClientOptions, AuthRetryableFetchException, PostgrestException, SupabaseClient;

AppStore emptyStore() =>
    AppStore(client: SupabaseClient('http://localhost:54321', 'test-key', authOptions: const AuthClientOptions(autoRefreshToken: false)))
      ..realtime = false
      ..persist = false;

Json message(String id, String child, int minute) =>
    {'id': id, 'child_id': child, 'therapist_id': null, 'body': 'Hello $id', 'sender_id': 'u1', 'from_admin': true, 'created_at': DateTime.utc(2026, 10, 1, 9, minute).toIso8601String(), 'read_at': null};

/// A parent's snapshot as the app would save it, with one session this week, one bill and a message.
Json parentSnapshot({DateTime? savedAt}) {
  final monday = weekStart(todayISO());
  return {
    'v': OfflineCache.version,
    'user_id': 'u-parent',
    'saved_at': (savedAt ?? DateTime.now()).toUtc().toIso8601String(),
    'profile': {'id': 'u-parent', 'full_name': 'Meena Sharma', 'child_id': 'c1', 'role': 'PARENT', 'must_change_password': false},
    'therapies': [
      {'id': 'th1', 'name': 'Speech Therapy', 'base_fee': 3000},
    ],
    'therapists': [
      {'id': 't1', 'therapist_no': 1, 'name': 'Rahul Menon', 'profile_id': null, 'active': true, 'therapist_therapies': [{'therapy_id': 'th1'}], 'therapist_details': null},
    ],
    'children': [
      {'id': 'c1', 'child_no': 1, 'name': 'Aarav Sharma', 'dob': '2020-01-14', 'father_name': 'Ravi', 'mother_name': 'Meena', 'phone': '9876543210', 'alt_phone': '', 'active': true, 'child_therapies': [{'therapy_id': 'th1', 'session_fee': null}]},
    ],
    'weeks': {
      monday: [
        {
          'id': 's1',
          'slot_date': addDays(monday, 6),
          'start_time': '09:30:00',
          'end_time': '10:15:00',
          'sessions': [
            {'id': 'x1', 'name': 'Speech group', 'therapist_id': 't1', 'therapy_id': 'th1', 'session_children': [{'child_id': 'c1', 'attendance': null, 'note': '', 'absence_reason': null, 'absence_at': null, 'rating': null, 'rate': null, 'confirmed_at': null}]},
          ],
        },
      ],
    },
    'fees': [
      {'child_id': 'c1', 'week_start': addDays(monday, -7), 'allocated': 1, 'attended': 1, 'absent': 0, 'unmarked': 0, 'upcoming': 0, 'amount': 3000, 'paid': 0, 'verifying': 0, 'lines': [], 'closed': true},
    ],
    'payments': [],
    'messages': [message('m1', 'c1', 1)],
    'requests': [],
    'reports': [],
    'upi': [],
    'week_index': {},
    'progress': {},
  };
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('snapshot file', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('nuvara_offline_');
      OfflineCache.folderOverride = dir;
    });
    tearDown(() async {
      OfflineCache.folderOverride = null;
      await dir.delete(recursive: true);
    });

    test('round-trips, and is removed on sign-out', () async {
      await OfflineCache.write('u-parent', parentSnapshot());
      expect((await OfflineCache.read('u-parent'))?['profile']['full_name'], 'Meena Sharma');
      await OfflineCache.remove('u-parent');
      expect(await OfflineCache.read('u-parent'), isNull);
    });

    test('older than 14 days, another login or another version is ignored and deleted', () async {
      await OfflineCache.write('u-parent', parentSnapshot(savedAt: DateTime.now().subtract(const Duration(days: 15))));
      expect(await OfflineCache.read('u-parent'), isNull);
      await OfflineCache.write('u-parent', {...parentSnapshot(), 'v': OfflineCache.version + 1});
      expect(await OfflineCache.read('u-parent'), isNull);
      await OfflineCache.write('u-other', {...parentSnapshot(), 'user_id': 'u-parent'});
      expect(await OfflineCache.read('u-other'), isNull, reason: "a file never opens for a login it wasn't saved for");
    });

    test('a damaged file is dropped instead of half-loaded', () async {
      await File('${dir.path}/nuvara_offline/u-parent.json').create(recursive: true).then((f) => f.writeAsString('{"v": 1, "user_'));
      expect(await OfflineCache.read('u-parent'), isNull);
      expect(File('${dir.path}/nuvara_offline/u-parent.json').existsSync(), isFalse);
    });

    test('clear removes every login', () async {
      await OfflineCache.write('a', {...parentSnapshot(), 'user_id': 'a'});
      await OfflineCache.write('b', {...parentSnapshot(), 'user_id': 'b'});
      await OfflineCache.clear();
      expect(await OfflineCache.read('a'), isNull);
      expect(await OfflineCache.read('b'), isNull);
    });
  });

  group('size', () {
    test('keeps the newest messages of each conversation', () {
      final rows = [for (var i = 0; i < 10; i++) message('a$i', 'c1', i), for (var i = 0; i < 3; i++) message('b$i', 'c2', i)];
      final kept = OfflineCache.lastPerThread(rows, 4);
      expect(kept.map((m) => m['id']), ['a6', 'a7', 'a8', 'a9', 'b0', 'b1', 'b2']);
    });

    test('a big snapshot is trimmed to fit, keeping what is owed', () {
      final big = parentSnapshot();
      big['messages'] = [for (var i = 0; i < 6000; i++) message('m$i', 'c${i % 3}', i % 60)];
      final text = OfflineCache.encode(big);
      expect(text, isNotNull);
      expect(utf8.encode(text!).length, lessThanOrEqualTo(OfflineCache.maxBytes));
      final back = jsonDecode(text) as Json;
      expect((back['fees'] as List), hasLength(1), reason: 'an unpaid bill is never trimmed away');
      expect((back['messages'] as List).length, lessThanOrEqualTo(45));
    });
  });

  group('store', () {
    test('a saved snapshot fills every screen and is marked offline', () {
      final store = emptyStore()..applySnapshot(parentSnapshot(savedAt: DateTime(2026, 10, 4, 10, 42)));
      expect(store.role, Role.parent);
      expect(store.offline, isTrue);
      expect(store.ready, isTrue);
      expect(store.userName, 'Meena Sharma');
      expect(store.child('c1')?.first, 'Aarav');
      expect(store.slotsOn(addDays(weekStart(todayISO()), 6)), hasLength(1), reason: 'Sunday sessions come back too');
      expect(store.feeWeeks.single.due, 3000);
      expect(store.messages.single.body, 'Hello m1');
      expect(store.dataAsOf, DateTime(2026, 10, 4, 10, 42));
    });

    test('what is saved again after reopening is the same data', () {
      final store = emptyStore()..applySnapshot(parentSnapshot());
      final again = jsonDecode(jsonEncode(store.snapshot())) as Json;
      expect(again['children'], parentSnapshot()['children']);
      expect((again['weeks'] as Map).keys, [weekStart(todayISO())]);
      expect(again['messages'], hasLength(1));
    });
  });

  test('only failures to reach the server count as offline', () {
    expect(isNetworkError(const SocketException('Failed host lookup')), isTrue);
    expect(isNetworkError(AuthRetryableFetchException()), isTrue);
    expect(isNetworkError(Exception('ClientException with SocketException: Connection refused')), isTrue);
    expect(isNetworkError(const PostgrestException(message: 'This session no longer exists.')), isFalse);
    expect(isNetworkError(Exception('Fill in the highlighted fields.')), isFalse);
  });

  testWidgets('the banner says the data is saved, offers Retry, and says when it is back online', (t) async {
    final store = emptyStore()..applySnapshot(parentSnapshot(savedAt: DateTime.now()));
    await t.pumpWidget(ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp(theme: buildTheme(), home: const OfflineFrame(child: Scaffold(body: Text('Home')))),
    ));
    expect(find.textContaining("You're offline · showing data from"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);

    store.offline = false;
    store.touch();
    await t.pump();
    expect(find.text('Back online · up to date'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    await t.pumpAndSettle();
    expect(find.text('Back online · up to date'), findsNothing);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('signed out, no banner even when offline', (t) async {
    final store = emptyStore()..offline = true;
    await t.pumpWidget(ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp(theme: buildTheme(), home: const OfflineFrame(child: Scaffold(body: Text('Login')))),
    ));
    expect(find.textContaining("You're offline"), findsNothing);
  });
}
