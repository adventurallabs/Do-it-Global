/// A library book the child has (or had) out. Mirrors `library_loans`; the
/// book's name, author and publisher are kept on the loan itself, which is
/// the only library table a parent can read.
enum LibraryDueState { returned, onTime, dueSoon, dueToday, overdue }

/// Days before the due date that a loan starts asking for attention. Same
/// value the school app and the daily reminder use.
const int kLibraryDueSoonDays = 2;

class LibraryLoan {
  const LibraryLoan({
    required this.id,
    required this.bookTitle,
    required this.bookAuthor,
    required this.bookPublisher,
    required this.issuedAt,
    required this.dueDate,
    this.returnedAt,
  });

  final String id;
  final String bookTitle;
  final String bookAuthor;
  final String bookPublisher;
  final DateTime issuedAt;

  /// A calendar date — no time of day.
  final DateTime dueDate;
  final DateTime? returnedAt;

  bool get isOpen => returnedAt == null;

  /// Whole days until due; negative once overdue.
  int daysLeft([DateTime? now]) {
    final n = now ?? DateTime.now();
    return DateTime(dueDate.year, dueDate.month, dueDate.day)
        .difference(DateTime(n.year, n.month, n.day))
        .inDays;
  }

  LibraryDueState dueState([DateTime? now]) {
    if (!isOpen) return LibraryDueState.returned;
    final d = daysLeft(now);
    if (d < 0) return LibraryDueState.overdue;
    if (d == 0) return LibraryDueState.dueToday;
    if (d <= kLibraryDueSoonDays) return LibraryDueState.dueSoon;
    return LibraryDueState.onTime;
  }

  bool needsAttention([DateTime? now]) {
    final s = dueState(now);
    return s == LibraryDueState.dueSoon ||
        s == LibraryDueState.dueToday ||
        s == LibraryDueState.overdue;
  }

  factory LibraryLoan.fromJson(Map<String, dynamic> j) {
    final due = DateTime.tryParse('${j['due_date'] ?? ''}') ?? DateTime.now();
    return LibraryLoan(
      id: '${j['id']}',
      bookTitle: '${j['book_title'] ?? ''}',
      bookAuthor: '${j['book_author'] ?? ''}',
      bookPublisher: '${j['book_publisher'] ?? ''}',
      issuedAt: DateTime.tryParse('${j['issued_at'] ?? ''}')?.toLocal() ?? DateTime.now(),
      dueDate: DateTime(due.year, due.month, due.day),
      returnedAt: j['returned_at'] == null ? null : DateTime.tryParse('${j['returned_at']}')?.toLocal(),
    );
  }
}
