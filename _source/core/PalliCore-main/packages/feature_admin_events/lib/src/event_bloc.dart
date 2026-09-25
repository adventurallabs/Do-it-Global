import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';

abstract class SchoolEventEvent {}

class LoadSchoolEvents extends SchoolEventEvent {}

class LoadEventComposer extends SchoolEventEvent {}

class OrganizeSchoolEvent extends SchoolEventEvent {
  final SchoolEvent event;
  OrganizeSchoolEvent(this.event);
}

class DeleteSchoolEvent extends SchoolEventEvent {
  final String id;
  DeleteSchoolEvent(this.id);
}

abstract class SchoolEventState {}

class SchoolEventInitial extends SchoolEventState {}

class SchoolEventLoading extends SchoolEventState {}

class SchoolEventsLoaded extends SchoolEventState {
  final List<SchoolEvent> events;
  final Map<String, int> noticeCounts;
  SchoolEventsLoaded(this.events, {this.noticeCounts = const {}});
}

class EventComposerLoaded extends SchoolEventState {
  final List<Classroom> classrooms;
  EventComposerLoaded(this.classrooms);
}

class SchoolEventOrganized extends SchoolEventState {
  final SchoolEvent event;
  final int familiesNotified;
  SchoolEventOrganized(this.event, this.familiesNotified);
}

class SchoolEventError extends SchoolEventState {
  final String message;
  SchoolEventError(this.message);
}

class SchoolEventBloc extends Bloc<SchoolEventEvent, SchoolEventState> {
  final SchoolEventRepository _events;
  final ClassroomRepository _classrooms;
  final StudentRepository _students;
  final ParentNoticeRepository _notices;
  final AnnouncementRepository _announcements;

  SchoolEventBloc(
    this._events,
    this._classrooms,
    this._students,
    this._notices,
    this._announcements,
  ) : super(SchoolEventInitial()) {
    on<LoadSchoolEvents>((event, emit) async {
      emit(SchoolEventLoading());
      try {
        emit(await _loaded());
      } catch (e) {
        emit(SchoolEventError(e.toString()));
      }
    });

    on<LoadEventComposer>((event, emit) async {
      emit(SchoolEventLoading());
      try {
        final classrooms = await _classrooms.getAll();
        emit(EventComposerLoaded(classrooms));
      } catch (e) {
        emit(SchoolEventError(e.toString()));
      }
    });

    on<OrganizeSchoolEvent>((event, emit) async {
      try {
        await _events.upsert(event.event);
        final (students, classrooms) = await (
          _students.getAll(),
          _classrooms.getAll(),
        ).wait;
        final targets = _targetStudents(event.event, students);
        final notices = <ParentNotice>[];
        final now = DateTime.now();
        for (final student in targets) {
          notices.add(
            ParentNotice(
              id: '${event.event.id}-${student.id}',
              eventId: event.event.id,
              studentId: student.id,
              studentName: student.name,
              guardianName: student.fatherName.isNotEmpty ? student.fatherName : student.motherName,
              contactNumber: student.contactNumber,
              title: event.event.name,
              body: _noticeBody(event.event, student),
              createdAt: now,
            ),
          );
        }
        await _notices.upsertAll(notices);
        await _announcements.upsert(
          Announcement(
            id: 'ann-${event.event.id}',
            title: event.event.name,
            content: _announcementBody(event.event, classrooms),
            target: event.event.isSchoolWide
                ? AnnouncementTarget.overall
                : AnnouncementTarget.students,
            createdAt: now,
            expiresAt: event.event.eventDate.add(const Duration(days: 1)),
          ),
        );
        emit(SchoolEventOrganized(event.event, notices.length));
      } catch (e) {
        emit(SchoolEventError(e.toString()));
      }
    });

    on<DeleteSchoolEvent>((event, emit) async {
      try {
        await _events.delete(event.id);
        emit(await _loaded());
      } catch (e) {
        emit(SchoolEventError(e.toString()));
      }
    });
  }

  Future<SchoolEventsLoaded> _loaded() async {
    final events = await _events.getAll();
    events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final notices = await _notices.getAll();
    final counts = <String, int>{};
    for (final notice in notices) {
      counts[notice.eventId] = (counts[notice.eventId] ?? 0) + 1;
    }
    return SchoolEventsLoaded(events, noticeCounts: counts);
  }

  List<Student> _targetStudents(SchoolEvent event, List<Student> students) {
    if (event.isSchoolWide) {
      return students.where((s) => s.classroomId.isNotEmpty).toList();
    }
    final ids = event.classroomIds.toSet();
    return students.where((s) => ids.contains(s.classroomId)).toList();
  }

  String _noticeBody(SchoolEvent event, Student student) {
    final buffer = StringBuffer();
    buffer.writeln('Dear ${student.fatherName.isNotEmpty ? student.fatherName : 'Parent'},');
    buffer.writeln();
    buffer.writeln(event.description);
    buffer.writeln();
    buffer.writeln('Event date: ${_prettyDate(event.eventDate)}');
    if (event.requiresFee) {
      buffer.writeln('Fee for ${student.name}: ₹${event.feeAmount.toStringAsFixed(0)}');
      if (event.lastPayDate != null) {
        buffer.writeln('Please pay by ${_prettyDate(event.lastPayDate!)}.');
      }
    }
    return buffer.toString().trim();
  }

  String _announcementBody(SchoolEvent event, List<Classroom> classrooms) {
    final buffer = StringBuffer(event.description);
    buffer.writeln();
    buffer.writeln();
    buffer.writeln('Date: ${_prettyDate(event.eventDate)}');
    if (event.requiresFee) {
      buffer.writeln('Individual fee: ₹${event.feeAmount.toStringAsFixed(0)}');
      if (event.lastPayDate != null) {
        buffer.writeln('Last date to pay: ${_prettyDate(event.lastPayDate!)}');
      }
    }
    if (!event.isSchoolWide) {
      final names = classrooms
          .where((c) => event.classroomIds.contains(c.id))
          .map((c) => c.displayName)
          .join(', ');
      buffer.writeln('For: $names');
    } else {
      buffer.writeln('For: Entire school');
    }
    return buffer.toString().trim();
  }

  String _prettyDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
