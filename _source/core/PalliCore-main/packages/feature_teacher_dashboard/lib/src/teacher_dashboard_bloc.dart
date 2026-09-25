import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:intl/intl.dart';

class ScheduledPeriod {
  final Period period;
  final String timetableId;
  final String classroomId;
  final String classroomName;

  const ScheduledPeriod({
    required this.period,
    required this.timetableId,
    required this.classroomId,
    required this.classroomName,
  });
}

abstract class TeacherDashboardEvent {}

class LoadTeacherDashboard extends TeacherDashboardEvent {
  final String teacherId;
  LoadTeacherDashboard(this.teacherId);
}

/// Sign-out. The bloc is created once for the whole app, so without this the
/// next person to sign in on this phone inherits the last one's dashboard.
class ClearTeacherDashboard extends TeacherDashboardEvent {}

class StartClass extends TeacherDashboardEvent {
  final Period period;
  final String teacherId;
  StartClass(this.period, this.teacherId);
}

class RequestReassignment extends TeacherDashboardEvent {
  final ScheduledPeriod item;
  final String fromTeacherId;
  final String toTeacherId;
  RequestReassignment(this.item, this.fromTeacherId, this.toTeacherId);
}

abstract class TeacherDashboardState {}

class TeacherDashboardInitial extends TeacherDashboardState {}

class TeacherDashboardLoading extends TeacherDashboardState {}

class TeacherDashboardLoaded extends TeacherDashboardState {
  final List<ScheduledPeriod> todayPeriods;
  final Map<String, ClassLog?> classLogs;
  final Map<String, PeriodReassignment> pendingOutgoing;
  final String teacherId;
  final int todayAttended;
  /// Periods whose time is past — not a judgement about whether the class
  /// was taught, which the app cannot know.
  final int todayEnded;
  final int reassignedToday;
  final Classroom? myClassroom;
  final bool homeroomMarkedToday;

  TeacherDashboardLoaded({
    required this.todayPeriods,
    required this.classLogs,
    required this.pendingOutgoing,
    required this.teacherId,
    required this.todayAttended,
    required this.todayEnded,
    required this.reassignedToday,
    this.myClassroom,
    this.homeroomMarkedToday = false,
  });

  int get todayAssigned => todayPeriods.length;
}

class TeacherDashboardError extends TeacherDashboardState {
  final String message;
  TeacherDashboardError(this.message);
}

class TeacherDashboardBloc extends Bloc<TeacherDashboardEvent, TeacherDashboardState> {
  final TimetableRepository _timetableRepository;
  final ClassLogRepository _classLogRepository;
  final ClassroomRepository _classroomRepository;
  final PeriodReassignmentRepository _reassignmentRepository;
  final AttendanceRepository _attendanceRepository;

  TeacherDashboardBloc(
    this._timetableRepository,
    this._classLogRepository,
    this._classroomRepository,
    this._reassignmentRepository,
    this._attendanceRepository,
  ) : super(TeacherDashboardInitial()) {
    on<LoadTeacherDashboard>(_onLoadTeacherDashboard);
    on<ClearTeacherDashboard>((_, emit) => emit(TeacherDashboardInitial()));
    on<StartClass>(_onStartClass);
    on<RequestReassignment>(_onRequestReassignment);
  }

  Future<void> _onLoadTeacherDashboard(
    LoadTeacherDashboard event,
    Emitter<TeacherDashboardState> emit,
  ) async {
    // Keep the current schedule visible during pull-to-refresh.
    if (state is! TeacherDashboardLoaded) {
      emit(TeacherDashboardLoading());
    }
    try {
      final now = DateTime.now();
      final today = DateFormat('EEEE').format(now);

      // Four independent reads — firing them together instead of one after
      // another (and, for class logs, instead of re-fetching the whole
      // table once per period below) turns what used to be N+3 sequential
      // round trips into one.
      final loaded = await Future.wait([
        _timetableRepository.getAll(),
        _classroomRepository.getAll(),
        _classLogRepository.getForDay(now),
        _reassignmentRepository.sentToday(event.teacherId, now),
      ]);
      final allTimetables = loaded[0] as List<Timetable>;
      final classrooms = loaded[1] as List<Classroom>;
      final allClassLogs = loaded[2] as List<ClassLog>;
      final sentToday = loaded[3] as List<PeriodReassignment>;
      final classNames = {for (final c in classrooms) c.id: c.name};

      final todayPeriods = <ScheduledPeriod>[];

      for (final timetable in allTimetables) {
        if (!timetable.isActive) continue;
        final classroomName = classNames[timetable.classroomId] ?? 'Classroom';
        final tempSlots = <String>{};
        for (final p in timetable.periods) {
          if (p.isTemporary && _sameDay(p.date, now) && p.dayOfWeek == today) {
            tempSlots.add(p.startTime);
          }
        }

        for (final p in timetable.periods) {
          if (_isRelevantToday(p, event.teacherId, today, now, tempSlots)) {
            todayPeriods.add(ScheduledPeriod(
              period: p,
              timetableId: timetable.id,
              classroomId: timetable.classroomId,
              classroomName: classroomName,
            ));
          }
        }
      }

      todayPeriods.sort((a, b) => a.period.startTime.compareTo(b.period.startTime));

      final classLogs = <String, ClassLog?>{};
      var todayAttended = 0;
      var todayEnded = 0;
      for (final item in todayPeriods) {
        final log = _classLogFor(allClassLogs, item.period.id, now);
        classLogs[item.period.id] = log;
        if (log?.status == 'started') {
          todayAttended++;
        } else if (_periodEnded(item.period, now)) {
          todayEnded++;
        }
      }

      final pendingOutgoing = <String, PeriodReassignment>{
        for (final r in sentToday)
          if (r.status == PeriodReassignmentStatus.pending) r.periodId: r,
      };

      final myClassroom = classrooms.where((c) => c.classTeacherId == event.teacherId).firstOrNull;
      var homeroomMarkedToday = false;
      if (myClassroom != null) {
        final homeroom = await _attendanceRepository.getHomeroomForClassroom(myClassroom.id, now);
        homeroomMarkedToday = homeroom.isNotEmpty;
      }

      emit(TeacherDashboardLoaded(
        todayPeriods: todayPeriods,
        classLogs: classLogs,
        pendingOutgoing: pendingOutgoing,
        teacherId: event.teacherId,
        todayAttended: todayAttended,
        todayEnded: todayEnded,
        reassignedToday: sentToday.length,
        myClassroom: myClassroom,
        homeroomMarkedToday: homeroomMarkedToday,
      ));
    } catch (e) {
      emit(TeacherDashboardError(e.toString()));
    }
  }

  bool _isRelevantToday(Period p, String teacherId, String today, DateTime now, Set<String> tempSlots) {
    if (p.staffId != teacherId) return false;
    if (p.isTemporary) {
      return _sameDay(p.date, now);
    }
    if (p.dayOfWeek != today) return false;
    return !tempSlots.contains(p.startTime);
  }

  bool _periodEnded(Period p, DateTime date) {
    final parts = p.startTime.split(':');
    final end = DateTime(date.year, date.month, date.day, int.parse(parts[0]), int.parse(parts[1]))
        .add(Duration(minutes: p.durationMinutes));
    return DateTime.now().isAfter(end);
  }

  bool _sameDay(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  ClassLog? _classLogFor(List<ClassLog> logs, String periodId, DateTime date) {
    for (final log in logs) {
      if (log.periodId == periodId && _sameDay(log.startTime, date)) return log;
    }
    return null;
  }

  Future<void> _onStartClass(
    StartClass event,
    Emitter<TeacherDashboardState> emit,
  ) async {
    final currentState = state;
    if (currentState is TeacherDashboardLoaded) {
      try {
        final newLog = ClassLog(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          periodId: event.period.id,
          staffId: event.teacherId,
          startTime: DateTime.now(),
          status: 'started',
        );
        await _classLogRepository.upsert(newLog);

        final updatedLogs = Map<String, ClassLog?>.from(currentState.classLogs);
        updatedLogs[event.period.id] = newLog;

        emit(TeacherDashboardLoaded(
          todayPeriods: currentState.todayPeriods,
          classLogs: updatedLogs,
          pendingOutgoing: currentState.pendingOutgoing,
          teacherId: currentState.teacherId,
          todayAttended: currentState.todayAttended + 1,
          todayEnded: currentState.todayEnded,
          reassignedToday: currentState.reassignedToday,
          myClassroom: currentState.myClassroom,
          homeroomMarkedToday: currentState.homeroomMarkedToday,
        ));
      } catch (e) {
        emit(TeacherDashboardError(e.toString()));
      }
    }
  }

  Future<void> _onRequestReassignment(
    RequestReassignment event,
    Emitter<TeacherDashboardState> emit,
  ) async {
    try {
      final now = DateTime.now();
      final request = PeriodReassignment(
        id: 'reassign_${DateTime.now().microsecondsSinceEpoch}',
        timetableId: event.item.timetableId,
        periodId: event.item.period.id,
        classroomId: event.item.classroomId,
        dayOfWeek: event.item.period.dayOfWeek,
        periodDate: DateTime(now.year, now.month, now.day),
        periodName: event.item.period.name,
        startTime: event.item.period.startTime,
        durationMinutes: event.item.period.durationMinutes,
        fromStaffId: event.fromTeacherId,
        toStaffId: event.toTeacherId,
        createdAt: now,
      );
      await _reassignmentRepository.upsert(request);
      add(LoadTeacherDashboard(event.fromTeacherId));
    } catch (e) {
      emit(TeacherDashboardError(e.toString()));
    }
  }
}
