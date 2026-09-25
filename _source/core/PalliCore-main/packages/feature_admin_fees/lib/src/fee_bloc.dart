import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';

abstract class FeeEvent {}

class LoadFees extends FeeEvent {}

class RecordFeePayment extends FeeEvent {
  final FeePayment payment;
  RecordFeePayment(this.payment);
}

abstract class FeeState {}

class FeeInitial extends FeeState {}

class FeeLoading extends FeeState {}

class FeesLoaded extends FeeState {
  final List<Classroom> classrooms;
  final List<Student> students;
  final List<SchoolEvent> events;
  final List<FeePayment> payments;
  final Map<String, StudentFeeLedger> ledgers;

  FeesLoaded({
    required this.classrooms,
    required this.students,
    required this.events,
    required this.payments,
    required this.ledgers,
  });

  StudentFeeLedger ledgerFor(String studentId) {
    return ledgers[studentId] ??
        StudentFeeLedger(
          studentId: studentId,
          tuitionDue: 0,
          tuitionPaid: 0,
          eventDue: 0,
          eventPaid: 0,
          payments: const [],
        );
  }

  Classroom? classroomById(String id) {
    for (final room in classrooms) {
      if (room.id == id) return room;
    }
    return null;
  }

  Student? studentById(String id) {
    for (final student in students) {
      if (student.id == id) return student;
    }
    return null;
  }

  List<Student> studentsIn(String classroomId) {
    return students.where((s) => s.classroomId == classroomId).toList()
      ..sort((a, b) => a.rollNumber.compareTo(b.rollNumber));
  }
}

class FeeError extends FeeState {
  final String message;
  FeeError(this.message);
}

class FeeBloc extends Bloc<FeeEvent, FeeState> {
  final ClassroomRepository _classrooms;
  final StudentRepository _students;
  final FeePaymentRepository _payments;
  final SchoolEventRepository _events;

  FeeBloc(this._classrooms, this._students, this._payments, this._events)
      : super(FeeInitial()) {
    on<LoadFees>((event, emit) async {
      emit(FeeLoading());
      try {
        emit(await _loaded());
      } catch (e) {
        emit(FeeError(e.toString()));
      }
    });

    on<RecordFeePayment>((event, emit) async {
      try {
        await _payments.upsert(event.payment);
        emit(await _loaded());
      } catch (e) {
        emit(FeeError(e.toString()));
      }
    });
  }

  Future<FeesLoaded> _loaded() async {
    final loaded = await Future.wait<dynamic>([
      _classrooms.getAll(),
      _students.getAll(),
      _payments.getAll(),
      _events.getAll(),
    ]);
    final classrooms = loaded[0] as List<Classroom>;
    final students = loaded[1] as List<Student>;
    final payments = loaded[2] as List<FeePayment>;
    final events = loaded[3] as List<SchoolEvent>;
    final byStudent = <String, List<FeePayment>>{};
    for (final payment in payments) {
      byStudent.putIfAbsent(payment.studentId, () => []).add(payment);
    }
    final ledgers = <String, StudentFeeLedger>{};
    for (final student in students) {
      ledgers[student.id] = buildLedger(
        student: student,
        payments: byStudent[student.id] ?? const [],
        events: events,
      );
    }
    return FeesLoaded(
      classrooms: classrooms,
      students: students,
      events: events,
      payments: payments,
      ledgers: ledgers,
    );
  }

  static StudentFeeLedger buildLedger({
    required Student student,
    required List<FeePayment> payments,
    required List<SchoolEvent> events,
  }) {
    final settled =
        payments.where((p) => p.status == FeePaymentStatus.success);
    final tuitionPaid = settled
        .where((p) => p.kind != FeeKind.event)
        .fold<double>(0, (sum, p) => sum + p.amount);
    final eventPaid = settled
        .where((p) => p.kind == FeeKind.event)
        .fold<double>(0, (sum, p) => sum + p.amount);
    final eventDue = events.where((event) {
      if (!event.requiresFee) return false;
      if (student.classroomId.isEmpty) return false;
      if (event.isSchoolWide) return true;
      return event.classroomIds.contains(student.classroomId);
    }).fold<double>(0, (sum, event) => sum + event.feeAmount);

    final ordered = [...payments]..sort((a, b) => b.paidOn.compareTo(a.paidOn));
    return StudentFeeLedger(
      studentId: student.id,
      tuitionDue: student.fees,
      tuitionPaid: tuitionPaid,
      eventDue: eventDue,
      eventPaid: eventPaid,
      payments: ordered,
    );
  }
}
