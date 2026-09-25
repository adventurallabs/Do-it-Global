import 'package:core_models/core_models.dart';
import 'package:flutter_test/flutter_test.dart';

LibraryLoan _loan({required DateTime due, DateTime? returnedAt}) => LibraryLoan(
      id: 'l1',
      borrowerKind: LibraryBorrowerKind.student,
      borrowerName: 'Harish',
      className: 'LKG',
      section: 'A',
      rollNumber: '01',
      bookTitle: 'Wings of Fire',
      issuedAt: DateTime(2026, 9, 20, 10),
      dueDate: due,
      returnedAt: returnedAt,
    );

void main() {
  // A fixed "now" late in the day: due-state must go by calendar day, not
  // by 24-hour blocks from the current time.
  final now = DateTime(2026, 9, 24, 21, 30);

  group('LibraryLoan due state', () {
    test('overdue once the due date has passed', () {
      final l = _loan(due: DateTime(2026, 9, 23));
      expect(l.dueState(now), LoanDueState.overdue);
      expect(l.daysLeft(now), -1);
      expect(l.dueLabel(now), 'Overdue by 1 day');
      expect(l.needsAttention(now), isTrue);
    });

    test('due today', () {
      final l = _loan(due: DateTime(2026, 9, 24));
      expect(l.dueState(now), LoanDueState.dueToday);
      expect(l.needsAttention(now), isTrue);
    });

    test('due soon covers tomorrow and the day after', () {
      expect(_loan(due: DateTime(2026, 9, 25)).dueLabel(now), 'Due tomorrow');
      expect(_loan(due: DateTime(2026, 9, 26)).dueState(now), LoanDueState.dueSoon);
      expect(_loan(due: DateTime(2026, 9, 27)).dueState(now), LoanDueState.onTime);
      expect(_loan(due: DateTime(2026, 9, 27)).needsAttention(now), isFalse);
    });

    test('a returned loan never asks for attention, however late it was', () {
      final l = _loan(due: DateTime(2026, 9, 1), returnedAt: DateTime(2026, 9, 10));
      expect(l.isOpen, isFalse);
      expect(l.dueState(now), LoanDueState.returned);
      expect(l.needsAttention(now), isFalse);
    });
  });

  test('borrowerDetail reads as class, section and roll for a student', () {
    expect(_loan(due: DateTime(2026, 10, 1)).borrowerDetail, 'LKG A · Roll 01');
  });

  test('LibraryLoan.fromJson keeps the due date as a calendar date', () {
    final l = LibraryLoan.fromJson({
      'id': 'x',
      'borrower_kind': 'staff',
      'teacher_id': 't1',
      'borrower_name': 'Tony',
      'contact_number': '3000300030',
      'book_title': 'Malgudi Days',
      'issued_at': '2026-09-24T04:00:00+00:00',
      'due_date': '2026-10-08',
      'returned_at': null,
    });
    expect(l.borrowerKind, LibraryBorrowerKind.staff);
    expect(l.dueDate, DateTime(2026, 10, 8));
    expect(l.borrowerDetail, '3000300030');
    expect(l.isOpen, isTrue);
  });

  test('LibraryBook counts come straight from the stock view', () {
    final b = LibraryBook.fromJson({
      'id': 'b',
      'title': 'T',
      'total_copies': 10,
      'unassigned_copies': 4,
      'shelved_copies': 4,
      'issued_copies': 2,
      'issued_to_students': 1,
      'issued_to_staff': 1,
    });
    expect(b.inLibrary, 8);
    expect(b.totalCopies, b.inLibrary + b.issuedCopies);
  });

  test('LibraryRemoval parses the database plan', () {
    final r = LibraryRemoval.fromJson({
      'book_id': 'b',
      'title': 'Wings of Fire',
      'removed': 5,
      'from_unassigned': 4,
      'from_partitions': [
        {'rack_code': 'A1', 'shelf_no': 1, 'partition_no': 1, 'copies': 1},
      ],
      'copies_left': 5,
      'book_removed': false,
    });
    expect(r.fromPartitions.single.rackCode, 'A1');
    expect(r.fromUnassigned + r.fromPartitions.single.copies, r.removed);
    expect(r.bookRemoved, isFalse);
  });

  test('LibrarySlot equality is by rack, shelf and partition', () {
    const a = LibrarySlot(rackId: 'r', rackCode: 'A1', shelfNo: 2, partitionNo: 3);
    const b = LibrarySlot(rackId: 'r', rackCode: 'A1', shelfNo: 2, partitionNo: 3);
    expect(a, b);
    expect(a.label, 'A1 · Shelf 2 · P3');
  });

  test('StaffRole.librarian round-trips through JSON as "librarian"', () {
    final t = Teacher.fromJson({
      'id': 't',
      'name': 'Lib',
      'contact_number': '1',
      'qualification': '',
      'address': '',
      'salary': 0,
      'role': 'librarian',
    });
    expect(t.isLibrarian, isTrue);
    expect(t.isTeaching, isFalse);
    expect(t.toJson()['role'], 'librarian');
  });

  test('borrower status: a leaver holding a book is flagged, a returned one is not', () {
    Map<String, dynamic> row(String status, {String? returned}) => {
          'id': 'x',
          'borrower_kind': 'student',
          'borrower_name': 'Harish',
          'book_title': 'B',
          'issued_at': '2026-09-20T04:00:00+00:00',
          'due_date': '2026-10-08',
          'returned_at': returned,
          'borrower_status': status,
        };
    expect(LibraryLoan.fromJson(row('active')).borrowerGone, isFalse);
    expect(LibraryLoan.fromJson(row('left')).borrowerGone, isTrue);
    expect(LibraryLoan.fromJson(row('left')).borrowerStatusLabel, 'Left school');
    expect(LibraryLoan.fromJson(row('inactive')).borrowerStatusLabel, 'Account deactivated');
    expect(LibraryLoan.fromJson(row('left', returned: '2026-09-30T04:00:00+00:00')).borrowerGone, isFalse);
    // Older rows / unknown values read as active rather than crashing.
    expect(LibraryLoan.fromJson(row('something-new')).borrowerStatus, LibraryBorrowerStatus.active);
  });
}
