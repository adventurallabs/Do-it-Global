// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fee_payment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FeePayment _$FeePaymentFromJson(Map<String, dynamic> json) => FeePayment(
  id: json['id'] as String,
  studentId: json['student_id'] as String,
  amount: (json['amount'] as num).toDouble(),
  paidOn: DateTime.parse(json['paid_on'] as String),
  kind:
      $enumDecodeNullable(
        _$FeeKindEnumMap,
        json['kind'],
        unknownValue: FeeKind.tuition,
      ) ??
      FeeKind.tuition,
  eventId: json['event_id'] as String?,
  note: json['note'] as String? ?? '',
  method:
      $enumDecodeNullable(
        _$FeePaymentMethodEnumMap,
        json['method'],
        unknownValue: FeePaymentMethod.cash,
      ) ??
      FeePaymentMethod.cash,
  status:
      $enumDecodeNullable(
        _$FeePaymentStatusEnumMap,
        json['status'],
        unknownValue: FeePaymentStatus.success,
      ) ??
      FeePaymentStatus.success,
  receiptNo: json['receipt_no'] as String?,
  recordedBy: json['recorded_by'] as String? ?? '',
);

Map<String, dynamic> _$FeePaymentToJson(FeePayment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'student_id': instance.studentId,
      'amount': instance.amount,
      'paid_on': instance.paidOn.toIso8601String(),
      'kind': _$FeeKindEnumMap[instance.kind]!,
      'event_id': instance.eventId,
      'note': instance.note,
      'method': _$FeePaymentMethodEnumMap[instance.method]!,
      'status': _$FeePaymentStatusEnumMap[instance.status]!,
      'receipt_no': instance.receiptNo,
      'recorded_by': instance.recordedBy,
    };

const _$FeeKindEnumMap = {
  FeeKind.tuition: 'tuition',
  FeeKind.transport: 'transport',
  FeeKind.activity: 'activity',
  FeeKind.admission: 'admission',
  FeeKind.event: 'event',
};

const _$FeePaymentMethodEnumMap = {
  FeePaymentMethod.razorpay: 'razorpay',
  FeePaymentMethod.cash: 'cash',
  FeePaymentMethod.cheque: 'cheque',
  FeePaymentMethod.bankTransfer: 'bank_transfer',
  FeePaymentMethod.upiManual: 'upi_manual',
};

const _$FeePaymentStatusEnumMap = {
  FeePaymentStatus.pending: 'pending',
  FeePaymentStatus.success: 'success',
  FeePaymentStatus.failed: 'failed',
  FeePaymentStatus.refunded: 'refunded',
};
