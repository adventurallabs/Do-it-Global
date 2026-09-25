import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:feature_admin_fees/feature_admin_fees.dart';

class DashboardAttention {
  final String label;
  final String route;
  DashboardAttention(this.label, this.route);
}

class DashboardSnapshot {
  final int studentCount;

  /// Today's roll call, coverage included. The home screen used to get a bare
  /// percentage that silently ignored every child nobody had marked.
  final DailyAttendance attendance;
  final DailyStaffAttendance staffAttendance;

  final double pendingFees;
  final int pendingFeeStudents;
  final int staleBuses;
  final List<DashboardAttention> attention;

  DashboardSnapshot({
    required this.studentCount,
    required this.attendance,
    required this.staffAttendance,
    required this.pendingFees,
    required this.pendingFeeStudents,
    required this.staleBuses,
    required this.attention,
  });

  int get staffPresent => staffAttendance.present;
  int get staffTotal => staffAttendance.expected;
  int get studentsPresent => attendance.present;
  int get studentsAbsent => attendance.absent;
  int get unmarkedStudents => attendance.unmarked;
}

abstract class DashboardEvent {}

class LoadDashboard extends DashboardEvent {}

abstract class DashboardState {}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final DashboardSnapshot snapshot;
  DashboardLoaded(this.snapshot);
}

class DashboardError extends DashboardState {
  final String message;
  DashboardError(this.message);
}

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final StudentRepository _students;
  final TeacherRepository _staff;
  final AttendanceRepository _attendance;
  /// Needed to name the classes whose roll is still outstanding.
  final ClassroomRepository _classrooms;
  final StaffAttendanceRepository _staffAttendance;
  final FeePaymentRepository _payments;
  final SchoolEventRepository _events;
  final BusRepository _buses;
  final LeaveRequestRepository _leaves;

  DashboardBloc(
    this._students,
    this._staff,
    this._attendance,
    this._classrooms,
    this._staffAttendance,
    this._payments,
    this._events,
    this._buses,
    this._leaves,
  ) : super(DashboardInitial()) {
    on<LoadDashboard>((event, emit) async {
      emit(DashboardLoading());
      try {
        emit(DashboardLoaded(await _snapshot()));
      } catch (e) {
        emit(DashboardError(e.toString()));
      }
    });
  }

  Future<DashboardSnapshot> _snapshot() async {
    final today = DateTime.now();
    // Eight independent reads for one home-screen snapshot — the admin's
    // very first screen after login — firing them together instead of one
    // after another turns 8 round trips into 1.
    final loaded = await Future.wait<dynamic>([
      _students.getAll(),
      _staff.getAll(),
      _attendance.getByDate(today),
      _classrooms.getAll(),
      _staffAttendance.getByDate(today),
      _events.getAll(),
      _payments.getAll(),
      _buses.getAll(),
      _leaves.getAll(),
    ]);
    final allStudents = loaded[0] as List<Student>;
    // Everyone on the roll. Filtering out the class-less here used to make the
    // headline count quietly smaller than the school actually is; they are a
    // problem to fix, not children to omit.
    final students =
        allStudents.where((s) => s.lifecycle == StudentLifecycle.enrolled).toList();
    final staff = loaded[1] as List<Teacher>;
    final teaching = staff.where((t) => t.isTeaching).toList();
    final studentAtt = loaded[2] as List<Attendance>;
    final classrooms = loaded[3] as List<Classroom>;
    final staffAtt = loaded[4] as List<StaffAttendance>;
    final events = loaded[5] as List<SchoolEvent>;
    final payments = loaded[6] as List<FeePayment>;
    final buses = loaded[7] as List<Bus>;
    final leaves = loaded[8] as List<LeaveRequest>;

    // One rule, one place — see DailyAttendance. It counts only homeroom rows,
    // keeps unmarked children visible, and reports which classes are still
    // outstanding.
    final day = DailyAttendance.forDay(
      students: allStudents,
      classrooms: classrooms,
      rows: studentAtt,
    );
    final staffDay = DailyStaffAttendance.forDay(
      staffIds: [for (final t in teaching) t.id],
      statusById: {for (final row in staffAtt) row.staffId: row.status},
    );
    final absent = day.absent;
    final staffAbsent = staffDay.absent;

    var pendingFees = 0.0;
    var pendingFeeStudents = 0;
    // Grouped once rather than re-scanned per student. This loop used to walk
    // every payment in the school for every child in it, so the cost grew with
    // the two together — and it ran on the UI isolate each time the admin
    // opened their home screen.
    final paymentsOf = <String, List<FeePayment>>{};
    for (final p in payments) {
      paymentsOf.putIfAbsent(p.studentId, () => []).add(p);
    }
    for (final student in students) {
      final studentPayments = paymentsOf[student.id] ?? const <FeePayment>[];
      final ledger = FeeBloc.buildLedger(student: student, payments: studentPayments, events: events);
      if (ledger.status != FeeStatus.fullyPaid) {
        pendingFeeStudents++;
        pendingFees += ledger.totalBalance;
      }
    }

    var staleBuses = 0;
    for (final bus in buses) {
      final updated = bus.lastUpdate;
      if (updated == null || today.difference(updated).inMinutes > 45) {
        staleBuses++;
      }
    }

    final pendingLeaves = leaves.where((l) => l.status == LeaveStatus.pending).length;

    final attention = <DashboardAttention>[
      // An uncalled roll is the thing the admin can actually act on, so it
      // leads — a rate is no use if half the school is missing from it.
      if (day.attentionLabel case final label?) DashboardAttention(label, '/admin/attendance'),
      // A child in no class is in nobody's register, so nothing else on this
      // screen would ever mention them.
      if (day.unplacedLabel case final label?) DashboardAttention(label, '/admin/classrooms'),
      if (staffAbsent > 0) DashboardAttention('$staffAbsent teachers absent', '/admin/attendance'),
      if (absent > 0) DashboardAttention('$absent students absent', '/admin/attendance'),
      if (pendingFeeStudents > 0) DashboardAttention('$pendingFeeStudents pending fee payments', '/admin/fees'),
      if (staleBuses > 0) DashboardAttention('$staleBuses buses haven\'t updated location', '/admin/bus-tracking'),
      if (pendingLeaves > 0) DashboardAttention('$pendingLeaves leave request${pendingLeaves == 1 ? '' : 's'} waiting', '/admin/leave'),
    ];

    return DashboardSnapshot(
      studentCount: students.length,
      attendance: day,
      staffAttendance: staffDay,
      pendingFees: pendingFees,
      pendingFeeStudents: pendingFeeStudents,
      staleBuses: staleBuses,
      attention: attention,
    );
  }
}
