enum PaymentStatus { paid, pending, processing, failed }

class FeeCategory {
  final String nameKey;
  final int total;
  final int paid;

  const FeeCategory({
    required this.nameKey,
    required this.total,
    required this.paid,
  });

  int get remaining => total - paid;
}

class PaymentRecord {
  final DateTime date;
  final int amount;
  final PaymentStatus status;
  final String receiptId;

  const PaymentRecord({
    required this.date,
    required this.amount,
    required this.status,
    required this.receiptId,
  });
}

class FeeAccount {
  final String studentId;
  final String academicYear;
  final List<FeeCategory> categories;
  final List<PaymentRecord> history;
  final DateTime? nextDueDate;

  const FeeAccount({
    required this.studentId,
    required this.academicYear,
    required this.categories,
    required this.history,
    this.nextDueDate,
  });

  int get total => categories.fold(0, (s, c) => s + c.total);
  int get paid => categories.fold(0, (s, c) => s + c.paid);
  int get remaining => total - paid;
  bool get hasDue => remaining > 0 && nextDueDate != null;
}
