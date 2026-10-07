import 'package:flutter_test/flutter_test.dart';
import 'package:nuvara/models.dart';
import 'package:nuvara/widgets/progress.dart' show ProgressSummary;
import 'package:nuvara/payments/upi.dart';
import 'package:nuvara/screens/admin/sessions.dart' show repeatDates, skippedRepeatDates;
import 'package:nuvara/util.dart';

import 'fixtures.dart';

void main() {
  final monday = weekStart(todayISO());
  final store = demoStore(Role.admin);

  group('scheduling conflicts', () {
    test('a therapist is busy in an overlapping slot only', () {
      expect(store.therapistClash('t2', monday, '09:30', '10:15')?.name, 'Speech group');
      expect(store.therapistClash('t2', monday, '10:00', '10:30'), isNotNull, reason: 'partial overlap');
      expect(store.therapistClash('t2', monday, '10:15', '11:00'), isNull, reason: 'back-to-back is fine');
      expect(store.therapistClash('t2', monday, '08:45', '09:30'), isNull);
      expect(store.therapistClash('t3', monday, '09:30', '10:15'), isNull);
    });

    test('editing a session does not clash with itself', () {
      expect(store.therapistClash('t2', monday, '09:30', '10:15', exceptSession: 'x0-1'), isNull);
      expect(store.childClash('c1', monday, '09:30', '10:15', exceptSession: 'x0-1'), isNull);
    });

    test('a child is busy when already seated at that time', () {
      expect(store.childClash('c4', monday, '09:00', '09:45')?.name, 'OT room');
      expect(store.childClash('c3', monday, '09:30', '10:15'), isNull);
      expect(store.childClash('c3', monday, '10:30', '11:30')?.name, 'Behaviour');
    });

    test('other days are independent', () {
      expect(store.therapistClash('t2', addDays(monday, 5), '09:30', '10:15'), isNull, reason: 'nothing on Saturday');
    });

    test('repeat covers Mon–Sun and skips past days this week', () {
      final next = addDays(monday, 7), last = addDays(monday, -7);
      expect(repeatDates(addDays(next, 2)), weekDates(next), reason: 'Sunday included');
      expect(repeatDates(addDays(next, 6)), weekDates(next));
      expect(repeatDates(addDays(last, 2)), weekDates(last), reason: 'back-filling a past week keeps every day');
      final today = todayISO();
      expect(repeatDates(today), contains(today));
      expect(repeatDates(today).every((d) => d.compareTo(today) >= 0), isTrue);
      expect(skippedRepeatDates(today), weekDates(monday).where((d) => d.compareTo(today) < 0).toList());
    });
  });

  group('weekly fees', () {
    final last = addDays(monday, -7);
    test('a week is billed per attended session at the child\'s rate', () {
      final w = store.bill('c1', last)!;
      expect(w.allocated, 15);
      expect(w.attended, 14);
      expect(w.amount, 9 * 3000 + 5 * 3500);
      expect(w.lines.firstWhere((l) => l.therapyId == 'th1').rates.single, (rate: 3000.0, count: 9));
    });

    test('status follows payments and verification', () {
      expect(store.bill('c1', last)!.state, FeeState.partial);
      expect(store.bill('c1', last)!.due, 44500 - 20000);
      expect(store.bill('c2', last)!.state, FeeState.verifying, reason: 'a verifying payment covers the week but is not paid yet');
      expect(store.bill('c2', last)!.due, 0);
      expect(store.bill('c3', last)!.state, FeeState.due);
      expect(store.bill('c4', last)!.state, FeeState.paid);
      // The current week can be paid at any time for the sessions attended so far.
      expect(store.bill('c1', monday)!.state, FeeState.due);
      expect(store.bill('c1', monday)!.payable, isTrue);
      expect(store.bill('c1', monday)!.due, 2 * 3000 + 3500);
    });

    test('what is owed covers every unpaid week, this week included, oldest first', () {
      expect(store.dueBills('c1').map((w) => w.monday), [last, monday]);
      expect(store.dueTotal('c1'), (44500 - 20000) + 2 * 3000 + 3500);
      expect(store.owing.first.child.id, 'c1', reason: 'most owed first');
      expect(store.owing.map((o) => o.child.id), isNot(contains('c4')));
    });

    test('a child\'s own fee replaces the therapy\'s base fee', () {
      expect(store.rateOf('c2', 'th1'), 2500);
      expect(store.rateOf('c1', 'th1'), 3000);
      expect(store.dueTotal('c3'), 16000);
      expect(store.dueBills('c4'), isEmpty);
    });

    test('payments: receipts only for confirmed ones', () {
      expect(store.payments.firstWhere((p) => p.id == 'p1').receiptCode, 'NV-000001');
      expect(store.payments.firstWhere((p) => p.id == 'p2').confirmed, isFalse);
      expect(store.paymentsToVerify.map((p) => p.id), ['p2']);
    });
  });

  group('attendance and ratings', () {
    Session at(String date, String start, String end, {String? mark}) => Slot({
          'id': 'z',
          'slot_date': date,
          'start_time': '$start:00',
          'end_time': '$end:00',
          'sessions': [
            {'id': 'zs', 'name': 'Z', 'therapist_id': 't1', 'therapy_id': 'th1', 'session_children': [{'child_id': 'k', 'attendance': mark}]},
          ],
        }).sessions.first;
    final yesterday = addDays(todayISO(), -1), tomorrow = addDays(todayISO(), 1);

    test('after the end only an unmarked child can be marked, once', () {
      expect(at(yesterday, '09:00', '09:45').canMarkSeat('k'), isTrue);
      expect(at(yesterday, '09:00', '09:45', mark: 'present').canMarkSeat('k'), isFalse);
      expect(at(tomorrow, '09:00', '09:45').canMarkSeat('k'), isFalse, reason: 'opens 15 minutes before the start');
    });

    test('a finished session is completed only once everyone is marked', () {
      expect(at(yesterday, '09:00', '09:45').completed, isFalse);
      expect(at(yesterday, '09:00', '09:45', mark: 'absent').completed, isTrue);
    });

    test('ratings open at the start and stay open until the report is given', () {
      expect(at(tomorrow, '09:00', '09:45').ratingOpen, isFalse);
      expect(at(addDays(todayISO(), -3), '09:00', '09:45').ratingOpen, isTrue, reason: 'a late report is still better than none');
    });

    test('an attended session without a rating is a pending report', () {
      final s = at(addDays(todayISO(), -1), '09:00', '09:45');
      final id = s.childIds.first;
      s.seat(id)!
        ..attendance = 'present'
        ..rating = null;
      expect(s.seat(id)!.reportPending, isTrue);
      expect(s.pendingReports, contains(id));
      s.seat(id)!.rating = 7;
      expect(s.pendingReports, isNot(contains(id)));
      s.seat(id)!.attendance = 'absent';
      s.seat(id)!.rating = null;
      expect(s.seat(id)!.reportPending, isFalse, reason: 'nothing to report for an absent child');
    });

    test('progress is summarised per day and over the latest reports', () {
      final days = store.dailyRatings('c1');
      expect(days.map((d) => d.date).toSet().length, days.length, reason: 'one point per day');
      final s = ProgressSummary.of(store.progressOf('c1')!);
      expect(s.level, isNotNull);
      expect(s.reported, store.progressOf('c1')!.where((p) => p.rating != null).length);
      expect(ratingBand(8), 'Doing well');
      expect(ratingBand(5), 'Developing');
      expect(ratingBand(2), 'Needs support');
    });

    test('rating trend compares recent sessions with the ones before', () {
      expect(store.ratingTrend('c1', 'th1'), greaterThan(0));
      expect(store.ratings('c1', 'th1').length, 9);
    });
  });

  group('payments and logins', () {
    test('UPI IDs and references are validated like the database does', () {
      expect(validVpa('centre@okaxis'), isTrue);
      expect(validVpa('new.life-01@ybl'), isTrue);
      for (final bad in ['centre', '@okaxis', 'a@1bank', 'with space@ok']) {
        expect(validVpa(bad), isFalse, reason: bad);
      }
      expect(validUtr('4123 4567 8901'), isTrue);
      expect(cleanUtr('4123-4567 8901'), '412345678901');
      expect(validUtr('12345'), isFalse);
    });

    test('merchant UPI link carries our reference as tr', () {
      final link = Upi.link((id: 'p', txnRef: 'NVABC123', amount: 500, vpa: 'nuvara@hdfcbank', name: 'Nuvara', kind: UpiKind.merchant, mc: '8099'), 'Fee C001 wk 28 Sep');
      expect(link.queryParameters['tr'], 'NVABC123');
      expect(link.queryParameters['mc'], '8099');
      expect(link.queryParameters['am'], '500.00');
      final noMc = Upi.link((id: 'p', txnRef: 'NVABC123', amount: 500, vpa: 'nuvara@hdfcbank', name: 'Nuvara', kind: UpiKind.merchant, mc: null), 'x');
      expect(noMc.queryParameters.containsKey('mc'), isFalse);
      expect(noMc.queryParameters['tr'], 'NVABC123');
    });

    test('personal UPI link carries the server\'s amount, payee and reference', () {
      final link = Upi.link((id: 'p', txnRef: 'NVABC123', amount: 1234.5, vpa: 'centre@okaxis', name: 'Nuvara', kind: UpiKind.personal, mc: '8099'), 'Fee C001 wk 28 Sep');
      expect(link.scheme, 'upi');
      expect(link.queryParameters['pa'], 'centre@okaxis');
      expect(link.queryParameters['am'], '1234.50');
      expect(link.queryParameters['cu'], 'INR');
      expect(link.queryParameters['tn'], startsWith('NVABC123 '));
      expect(link.queryParameters['tn']!.length, lessThanOrEqualTo(50));
      // A personal UPI ID can't take merchant fields: apps reject the request ("request type not supported").
      expect(link.queryParameters.containsKey('tr'), isFalse);
      expect(link.queryParameters.containsKey('mc'), isFalse);
      // Literal '@' and %20 spaces: some UPI apps don't decode '%40' or '+'.
      expect(link.toString(), contains('pa=centre@okaxis'));
      expect(link.toString(), isNot(contains('+')));
    });

    test('child IDs normalise for the account list', () {
      expect(normaliseChildCode('c2'), 'C002');
      expect(normaliseChildCode('007'), 'C007');
    });
  });

  group('formatting', () {
    test('IDs and search', () {
      expect(childCode(7), 'C007');
      expect(therapistCode(12), 'T012');
      final c = store.child('c4')!;
      for (final q in ['4', '004', 'C004', 'c4', 'kavin', 'RAJ']) {
        expect(c.matches(q), isTrue, reason: q);
      }
      for (final q in ['5', 'T004', 'diya']) {
        expect(c.matches(q), isFalse, reason: q);
      }
    });

    test('age reads as years and months', () {
      final n = DateTime.now();
      String back(int months) => iso(DateTime(n.year, n.month - months, n.day));
      expect(ageLong(back(51)), '4 years, 3 months old');
      expect(ageLong(back(24)), '2 years old');
      expect(ageLong(back(1)), '1 month old');
      expect(ageLong(back(0)), '0 months old');
    });

    test('week helpers', () {
      expect(weekStart('2026-10-04'), '2026-09-28'); // Sunday belongs to the week before
      expect(weekLabel('2026-09-28'), '28 Sep – 4 Oct 2026');
      expect(addMonths('2026-12', 1), '2027-01');
      expect(overlaps('10:00', '10:45', '10:45', '11:30'), isFalse);
    });
  });
}
