import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';

abstract class ClassroomEvent {}
class LoadClassrooms extends ClassroomEvent {}
class LoadClassroomFormDependencies extends ClassroomEvent {
  final String? classroomId;
  LoadClassroomFormDependencies({this.classroomId});
}
class CreateClassroom extends ClassroomEvent {
  final Classroom classroom;
  final List<String> studentIds;
  CreateClassroom(this.classroom, this.studentIds);
}
class UpdateClassroom extends ClassroomEvent {
  final Classroom classroom;
  final List<String> studentIds;
  final bool replaceStudents;
  UpdateClassroom(this.classroom, this.studentIds, {this.replaceStudents = false});
}

class AssignStudentsToClass extends ClassroomEvent {
  final String classroomId;
  final List<String> studentIds;
  AssignStudentsToClass(this.classroomId, this.studentIds);
}

class RemoveStudentFromClass extends ClassroomEvent {
  final String studentId;
  RemoveStudentFromClass(this.studentId);
}

class LoadClassroomRoster extends ClassroomEvent {
  final String classroomId;
  LoadClassroomRoster(this.classroomId);
}

class DeleteClassroom extends ClassroomEvent {
  final String id;
  DeleteClassroom(this.id);
}

abstract class ClassroomState {}
class ClassroomInitial extends ClassroomState {}
class ClassroomLoading extends ClassroomState {}
class ClassroomsLoaded extends ClassroomState {
  final List<Classroom> classrooms;
  final Map<String, Teacher> teachers;
  final Map<String, int> studentCounts;
  ClassroomsLoaded(this.classrooms, {this.teachers = const {}, this.studentCounts = const {}});
}
class ClassroomFormDependenciesLoaded extends ClassroomState {
  final List<Teacher> teachers;
  final List<Student> availableStudents;
  final Classroom? classroom;
  ClassroomFormDependenciesLoaded({
    required this.teachers,
    required this.availableStudents,
    this.classroom,
  });
}
class ClassroomError extends ClassroomState {
  final String message;
  ClassroomError(this.message);
}

class ClassroomRosterLoaded extends ClassroomState {
  final Classroom classroom;
  final List<Student> enrolled;
  final List<Student> available;
  ClassroomRosterLoaded({
    required this.classroom,
    required this.enrolled,
    required this.available,
  });
}

class ClassroomBloc extends Bloc<ClassroomEvent, ClassroomState> {
  final ClassroomRepository _repository;
  final TeacherRepository _teacherRepository;
  final StudentRepository _studentRepository;

  ClassroomBloc(this._repository, this._teacherRepository, this._studentRepository) : super(ClassroomInitial()) {
    on<LoadClassrooms>((event, emit) async {
      emit(ClassroomLoading());
      try {
        emit(await _loaded());
      } catch (e) {
        emit(ClassroomError(e.toString()));
      }
    });

    on<LoadClassroomFormDependencies>((event, emit) async {
      try {
        final results = await Future.wait<dynamic>([
          _teacherRepository.getAll(),
          _studentRepository.getAvailableStudents(event.classroomId ?? 'none'),
          if (event.classroomId != null) _repository.getById(event.classroomId!),
        ]);
        final teachers = results[0] as List<Teacher>;
        final availableStudents = results[1] as List<Student>;
        final classroom = event.classroomId != null ? results[2] as Classroom? : null;
        emit(ClassroomFormDependenciesLoaded(
          teachers: teachers,
          availableStudents: availableStudents,
          classroom: classroom,
        ));
      } catch (e) {
        emit(ClassroomError(e.toString()));
      }
    });

    on<CreateClassroom>((event, emit) async {
      try {
        await _repository.upsert(event.classroom);
        await _syncTeacher(event.classroom);
        // Each id is a different student row, so these writes don't
        // conflict with each other — fire them together.
        await Future.wait(event.studentIds.map((id) => _studentRepository.updateClassroom(
              id,
              event.classroom.id,
              fees: event.classroom.baseFees,
            )));
        emit(await _loaded());
      } catch (e) {
        emit(ClassroomError(e.toString()));
      }
    });

    on<UpdateClassroom>((event, emit) async {
      try {
        await _repository.upsert(event.classroom);
        await _syncTeacher(event.classroom);
        if (event.studentIds.isNotEmpty || event.replaceStudents) {
          final currentStudents = await _studentRepository.getByClassroom(event.classroom.id);
          final removed = currentStudents.where((s) => !event.studentIds.contains(s.id));
          await Future.wait(removed.map((s) => _studentRepository.updateClassroom(s.id, null)));
          await Future.wait(event.studentIds.map((id) => _studentRepository.updateClassroom(
                id,
                event.classroom.id,
                fees: event.classroom.baseFees,
              )));
        }
        emit(await _loaded());
      } catch (e) {
        emit(ClassroomError(e.toString()));
      }
    });

    on<LoadClassroomRoster>((event, emit) async {
      try {
        final classroom = await _repository.getById(event.classroomId);
        if (classroom == null) {
          emit(ClassroomError('Classroom not found'));
          return;
        }
        final enrolled = await _studentRepository.getByClassroom(event.classroomId);
        final available = await _studentRepository.getAvailableStudents(event.classroomId);
        final unassigned = available.where((s) => s.classroomId.isEmpty).toList();
        emit(ClassroomRosterLoaded(
          classroom: classroom,
          enrolled: enrolled,
          available: unassigned,
        ));
      } catch (e) {
        emit(ClassroomError(e.toString()));
      }
    });

    on<AssignStudentsToClass>((event, emit) async {
      try {
        final classroom = await _repository.getById(event.classroomId);
        await Future.wait(event.studentIds.map((id) => _studentRepository.updateClassroom(
              id,
              event.classroomId,
              fees: classroom?.baseFees,
            )));
        final enrolled = await _studentRepository.getByClassroom(event.classroomId);
        final available = await _studentRepository.getAvailableStudents(event.classroomId);
        if (classroom != null) {
          emit(ClassroomRosterLoaded(
            classroom: classroom,
            enrolled: enrolled,
            available: available.where((s) => s.classroomId.isEmpty).toList(),
          ));
        } else {
          emit(await _loaded());
        }
      } catch (e) {
        emit(ClassroomError(e.toString()));
      }
    });

    on<RemoveStudentFromClass>((event, emit) async {
      try {
        String? classroomId;
        if (state is ClassroomRosterLoaded) {
          classroomId = (state as ClassroomRosterLoaded).classroom.id;
        }
        await _studentRepository.updateClassroom(event.studentId, null);
        if (classroomId != null) {
          final classroom = await _repository.getById(classroomId);
          if (classroom != null) {
            final enrolled = await _studentRepository.getByClassroom(classroomId);
            final available = await _studentRepository.getAvailableStudents(classroomId);
            emit(ClassroomRosterLoaded(
              classroom: classroom,
              enrolled: enrolled,
              available: available.where((s) => s.classroomId.isEmpty).toList(),
            ));
            return;
          }
        }
        emit(await _loaded());
      } catch (e) {
        emit(ClassroomError(e.toString()));
      }
    });

    on<DeleteClassroom>((event, emit) async {
      try {
        final currentStudents = await _studentRepository.getByClassroom(event.id);
        await Future.wait(currentStudents.map((s) => _studentRepository.updateClassroom(s.id, null)));
        final classroom = await _repository.getById(event.id);
        if (classroom != null) {
          final teacher = await _teacherRepository.getById(classroom.classTeacherId);
          if (teacher != null && teacher.classroomId == event.id) {
            await _teacherRepository.upsert(teacher.copyWith(clearClassroom: true));
          }
        }
        await _repository.delete(event.id);
        emit(await _loaded());
      } catch (e) {
        emit(ClassroomError(e.toString()));
      }
    });
  }

  Future<ClassroomsLoaded> _loaded() async {
    final results = await Future.wait<dynamic>([
      _repository.getAll(),
      _teacherRepository.getAll(),
      _studentRepository.getAll(),
    ]);
    final classrooms = results[0] as List<Classroom>;
    final teachers = results[1] as List<Teacher>;
    final students = results[2] as List<Student>;
    final teacherMap = {for (final t in teachers) t.id: t};
    final counts = <String, int>{};
    for (final student in students) {
      if (student.classroomId.isEmpty) continue;
      counts[student.classroomId] = (counts[student.classroomId] ?? 0) + 1;
    }
    return ClassroomsLoaded(classrooms, teachers: teacherMap, studentCounts: counts);
  }

  Future<void> _syncTeacher(Classroom classroom) async {
    final teachers = await _teacherRepository.getAll();
    final updates = <Future<void>>[];
    for (final teacher in teachers) {
      if (teacher.id == classroom.classTeacherId) {
        updates.add(_teacherRepository.upsert(teacher.copyWith(classroomId: classroom.id)));
      } else if (teacher.classroomId == classroom.id) {
        updates.add(_teacherRepository.upsert(teacher.copyWith(clearClassroom: true)));
      }
    }
    await Future.wait(updates);
  }
}
