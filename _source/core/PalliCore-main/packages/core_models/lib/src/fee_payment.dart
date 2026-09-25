import 'package:json_annotation/json_annotation.dart';

part 'fee_payment.g.dart';

enum FeeKind {
  @JsonValue('tuition')
  tuition,
  @JsonValue('transport')
  transport,
  @JsonValue('activity')
  activity,
  @JsonValue('admission')
  admission,
  @JsonValue('event')
  event,
}

enum FeeStatus {
  notPaid,
  partiallyPaid,
  fullyPaid,
}

enum FeePaymentMethod {
  @JsonValue('razorpay')
  razorpay,
  @JsonValue('cash')
  cash,
  @JsonValue('cheque')
  cheque,
  @JsonValue('bank_transfer')
  bankTransfer,
  @JsonValue('upi_manual')
  upiManual,
}

enum FeePaymentStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('success')
  success,
  @JsonValue('failed')
  failed,
  @JsonValue('refunded')
  refunded,
}

@JsonSerializable(fieldRename: FieldRename.snake)
class FeePayment {
  final String id;
  final String studentId;
  final double amount;
  final DateTime paidOn;
  @JsonKey(defaultValue: FeeKind.tuition, unknownEnumValue: FeeKind.tuition)
  final FeeKind kind;
  final String? eventId;
  final String note;
  @JsonKey(defaultValue: FeePaymentMethod.cash, unknownEnumValue: FeePaymentMethod.cash)
  final FeePaymentMethod method;
  @JsonKey(defaultValue: FeePaymentStatus.success, unknownEnumValue: FeePaymentStatus.success)
  final FeePaymentStatus status;
  final String? receiptNo;
  @JsonKey(defaultValue: '')
  final String recordedBy;

  FeePayment({
    required this.id,
    required this.studentId,
    required this.amount,
    required this.paidOn,
    required this.kind,
    this.eventId,
    this.note = '',
    this.method = FeePaymentMethod.cash,
    this.status = FeePaymentStatus.success,
    this.receiptNo,
    this.recordedBy = '',
  });

  bool get isOnline => method == FeePaymentMethod.razorpay;
  bool get isPending => status == FeePaymentStatus.pending;

  String get methodLabel {
    switch (method) {
      case FeePaymentMethod.razorpay:
        return 'Online';
      case FeePaymentMethod.cash:
        return 'Cash';
      case FeePaymentMethod.cheque:
        return 'Cheque';
      case FeePaymentMethod.bankTransfer:
        return 'Bank transfer';
      case FeePaymentMethod.upiManual:
        return 'UPI';
    }
  }

  factory FeePayment.fromJson(Map<String, dynamic> json) =>
      _$FeePaymentFromJson(json);
  Map<String, dynamic> toJson() => _$FeePaymentToJson(this);
}

class StudentFeeLedger {
  final String studentId;
  final double tuitionDue;
  final double tuitionPaid;
  final double eventDue;
  final double eventPaid;
  final List<FeePayment> payments;

  const StudentFeeLedger({
    required this.studentId,
    required this.tuitionDue,
    required this.tuitionPaid,
    required this.eventDue,
    required this.eventPaid,
    required this.payments,
  });

  double get tuitionBalance =>
      (tuitionDue - tuitionPaid).clamp(0, double.infinity);

  double get eventBalance =>
      (eventDue - eventPaid).clamp(0, double.infinity);

  double get totalDue => tuitionDue + eventDue;
  double get totalPaid => tuitionPaid + eventPaid;
  double get totalBalance => tuitionBalance + eventBalance;

  FeeStatus get status {
    if (totalDue <= 0) return FeeStatus.fullyPaid;
    if (totalPaid <= 0) return FeeStatus.notPaid;
    if (totalBalance <= 0.009) return FeeStatus.fullyPaid;
    return FeeStatus.partiallyPaid;
  }

  String get statusLabel {
    switch (status) {
      case FeeStatus.fullyPaid:
        return 'Fully paid';
      case FeeStatus.partiallyPaid:
        return 'Partially paid';
      case FeeStatus.notPaid:
        return 'Not paid';
    }
  }
}
