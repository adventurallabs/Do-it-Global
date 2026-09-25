import 'package:flutter_test/flutter_test.dart';
import 'package:palliconnect/shared/models/library_loan.dart';

void main() {
  final now = DateTime(2026, 9, 24, 21, 30);

  LibraryLoan loan(DateTime due, {DateTime? returned}) => LibraryLoan(
        id: 'l',
        bookTitle: 'Wings of Fire',
        bookAuthor: 'Kalam',
        bookPublisher: 'UP',
        issuedAt: DateTime(2026, 9, 20),
        dueDate: due,
        returnedAt: returned,
      );

  test('same due-state rules as the school app', () {
    expect(loan(DateTime(2026, 9, 23)).dueState(now), LibraryDueState.overdue);
    expect(loan(DateTime(2026, 9, 24)).dueState(now), LibraryDueState.dueToday);
    expect(loan(DateTime(2026, 9, 26)).dueState(now), LibraryDueState.dueSoon);
    expect(loan(DateTime(2026, 9, 27)).dueState(now), LibraryDueState.onTime);
    expect(loan(DateTime(2026, 9, 1), returned: DateTime(2026, 9, 2)).needsAttention(now), isFalse);
  });

  test('fromJson reads the loan snapshot columns', () {
    final l = LibraryLoan.fromJson({
      'id': 'x',
      'book_title': 'Malgudi Days',
      'book_author': 'R.K. Narayan',
      'book_publisher': 'Indian Thought',
      'issued_at': '2026-09-24T04:00:00+00:00',
      'due_date': '2026-10-08',
      'returned_at': null,
    });
    expect(l.bookAuthor, 'R.K. Narayan');
    expect(l.dueDate, DateTime(2026, 10, 8));
    expect(l.isOpen, isTrue);
  });
}
