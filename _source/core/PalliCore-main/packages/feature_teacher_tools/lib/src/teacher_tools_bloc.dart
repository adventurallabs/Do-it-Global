import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';

abstract class TeacherToolsEvent {}

class LoadTeacherTools extends TeacherToolsEvent {
  final String teacherId;
  LoadTeacherTools(this.teacherId);
}

/// Sign-out. The bloc is created once for the whole app, so without this the
/// next person to sign in on this phone inherits the last one's classes,
/// homeroom roster and homework.
class ClearTeacherTools extends TeacherToolsEvent {}

/// Re-reads this teacher's homework into state after a screen has written
/// one. The write itself lives in the screens so they can report a failure to
/// the teacher instead of the bloc swallowing it.
class RefreshTeacherHomework extends TeacherToolsEvent {
  final String teacherId;
  RefreshTeacherHomework(this.teacherId);
}

class SearchStudents extends TeacherToolsEvent {
  final String query;
  final String classroomId;
  SearchStudents(this.query, this.classroomId);
}

class AddClassroomStudent extends TeacherToolsEvent {
  final Student student;
  AddClassroomStudent(this.student);
}

class UpdateClassroomStudent extends TeacherToolsEvent {
  final Student student;
  UpdateClassroomStudent(this.student);
}

class DeleteClassroomStudent extends TeacherToolsEvent {
  final String studentId;
  final String classroomId;
  DeleteClassroomStudent(this.studentId, this.classroomId);
}

class UnassignClassroomStudent extends TeacherToolsEvent {
  final String studentId;
  final String classroomId;
  UnassignClassroomStudent(this.studentId, this.classroomId);
}

class AssignExistingStudents extends TeacherToolsEvent {
  final String classroomId;
  final List<String> studentIds;
  final double? fees;
  AssignExistingStudents(this.classroomId, this.studentIds, {this.fees});
}

class LoadAvailableStudents extends TeacherToolsEvent {
  final String classroomId;
  LoadAvailableStudents(this.classroomId);
}

abstract class TeacherToolsState {}

class TeacherToolsInitial extends TeacherToolsState {}

class TeacherToolsLoading extends TeacherToolsState {}

class TeacherToolsLoaded extends TeacherToolsState {
  final String teacherId;
  final List<Classroom> taughtClassrooms;
  final Classroom? myClassroom;
  final List<Student> currentClassroomStudents;
  final List<Student> searchResults;
  final List<Student> availableStudents;
  final Map<String, List<String>> subjectsByClassroom;
  /// What this teacher may do in each classroom — the subjects whose marks
  /// are theirs, and whether roll call is theirs to take. Screens ask this
  /// instead of re-deriving permission from the timetable themselves.
  final Map<String, TeachingScope> scopes;
  final Timetable? myTimetable;
  final List<Homework> homework;

  TeacherToolsLoaded({
    required this.teacherId,
    required this.taughtClassrooms,
    this.myClassroom,
    this.currentClassroomStudents = const [],
    this.searchResults = const [],
    this.availableStudents = const [],
    this.subjectsByClassroom = const {},
    this.scopes = const {},
    this.myTimetable,
    this.homework = const [],
  });

  /// Never null: a classroom with no standing yields an empty scope rather
  /// than forcing every caller to guard.
  TeachingScope scopeFor(Classroom classroom) =>
      scopes[classroom.id] ?? TeachingScope.none(teacherId, classroom);

  TeacherToolsLoaded copyWith({
    List<Classroom>? taughtClassrooms,
    Classroom? myClassroom,
    List<Student>? currentClassroomStudents,
    List<Student>? searchResults,
    List<Student>? availableStudents,
    Map<String, List<String>>? subjectsByClassroom,
    Map<String, TeachingScope>? scopes,
    Timetable? myTimetable,
    List<Homework>? homework,
    bool clearMyClassroom = false,
  }) {
    return TeacherToolsLoaded(
      teacherId: teacherId,
      taughtClassrooms: taughtClassrooms ?? this.taughtClassrooms,
      myClassroom: clearMyClassroom ? null : (myClassroom ?? this.myClassroom),
      currentClassroomStudents: currentClassroomStudents ?? this.currentClassroomStudents,
      searchResults: searchResults ?? this.searchResults,
      availableStudents: availableStudents ?? this.availableStudents,
      subjectsByClassroom: subjectsByClassroom ?? this.subjectsByClassroom,
      scopes: scopes ?? this.scopes,
      myTimetable: myTimetable ?? this.myTimetable,
      homework: homework ?? this.homework,
    );
  }
}

class TeacherToolsError extends TeacherToolsState {
  final String message;
  TeacherToolsError(this.message);
}

class TeacherToolsBloc extends Bloc<TeacherToolsEvent, TeacherToolsState> {
  final ClassroomRepository _classroomRepository;
  final TimetableRepository _timetableRepository;
  final StudentRepository _studentRepository;
  final HomeworkRepository _homeworkRepository;

  TeacherToolsBloc(
    this._classroomRepository,
    this._timetableRepository,
    this._studentRepository,
    this._homeworkRepository,
  ) : super(TeacherToolsInitial()) {
    on<LoadTeacherTools>(_onLoadTeacherTools);
    on<ClearTeacherTools>((_, emit) => emit(TeacherToolsInitial()));
    on<RefreshTeacherHomework>(_onRefreshHomework);
    on<SearchStudents>(_onSearchStudents);
    on<AddClassroomStudent>(_onAddStudent);
    on<UpdateClassroomStudent>(_onUpdateStudent);
    on<DeleteClassroomStudent>(_onDeleteStudent);
    on<UnassignClassroomStudent>(_onUnassignStudent);
    on<AssignExistingStudents>(_onAssignExisting);
    on<LoadAvailableStudents>(_onLoadAvailable);
  }

  Future<void> _onLoadTeacherTools(
    LoadTeacherTools event,
    Emitter<TeacherToolsState> emit,
  ) async {
    emit(TeacherToolsLoading());
    try {
      emit(await _buildState(event.teacherId));
    } catch (e) {
      emit(TeacherToolsError(e.toString()));
    }
  }

  Future<TeacherToolsLoaded> _buildState(String teacherId, {TeacherToolsLoaded? previous}) async {
    final loaded = await Future.wait<dynamic>([
      _classroomRepository.getAll(),
      _timetableRepository.getAll(),
      // Server-side filter: this used to pull every homework row in the school
      // and narrow it in Dart.
      _homeworkRepository.getByTeacher(teacherId),
    ]);
    final allClassrooms = loaded[0] as List<Classroom>;
    final allTimetables = loaded[1] as List<Timetable>;
    final homework = loaded[2] as List<Homework>;

    // One rule, one place: TeachingScope decides which subjects are this
    // teacher's and where they may take roll call — and `asDatabaseSees`
    // decides it per classroom, the way the database's teacher_teaches()
    // does. The old school-wide "did anything activate?" fallback could
    // disagree with the database in both directions, so a teacher was
    // offered mark sheets that were then refused on save.
    final scopes = TeachingScope.asDatabaseSees(
      teacherId: teacherId,
      classrooms: allClassrooms,
      timetables: allTimetables,
    );
    final subjectsByClassroom = {
      for (final scope in scopes.values)
        if (scope.subjects.isNotEmpty) scope.classroomId: scope.subjects,
    };
    final taughtClassroomIds = scopes.keys.toSet();

    // Sorted so the homework board, the class list and the assign chips all
    // present the teacher's classes in the same order every time.
    final taughtClassrooms = allClassrooms
        .where((c) => taughtClassroomIds.contains(c.id) || c.classTeacherId == teacherId)
        .toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    final myClassroom = allClassrooms.where((c) => c.classTeacherId == teacherId).firstOrNull;
    Timetable? myTimetable;
    if (myClassroom != null) {
      myTimetable = await _timetableRepository.getActiveForClass(myClassroom.id);
    }

    var students = previous?.currentClassroomStudents ?? <Student>[];
    var search = previous?.searchResults ?? <Student>[];
    var available = previous?.availableStudents ?? <Student>[];
    if (myClassroom != null && students.isEmpty) {
      final fetched = await Future.wait([
        _studentRepository.getByClassroom(myClassroom.id),
        _studentRepository.getAvailableStudents(myClassroom.id),
      ]);
      students = fetched[0];
      search = students;
      available = fetched[1].where((s) => s.classroomId.isEmpty).toList();
    }

    return TeacherToolsLoaded(
      teacherId: teacherId,
      taughtClassrooms: taughtClassrooms,
      myClassroom: myClassroom,
      currentClassroomStudents: students,
      searchResults: search,
      availableStudents: available,
      subjectsByClassroom: subjectsByClassroom,
      scopes: scopes,
      myTimetable: myTimetable,
      homework: homework,
    );
  }

  Future<void> _onRefreshHomework(
    RefreshTeacherHomework event,
    Emitter<TeacherToolsState> emit,
  ) async {
    final current = state;
    if (current is! TeacherToolsLoaded) return;
    try {
      emit(current.copyWith(
        homework: await _homeworkRepository.getByTeacher(event.teacherId),
      ));
    } catch (_) {
      // Stale counts are better than tearing down a working screen.
    }
  }

  Future<void> _onSearchStudents(
    SearchStudents event,
    Emitter<TeacherToolsState> emit,
  ) async {
    final currentState = state;
    if (currentState is TeacherToolsLoaded) {
      try {
        final students = await _studentRepository.getByClassroom(event.classroomId);
        final filtered = students.where((s) =>
            s.name.toLowerCase().contains(event.query.toLowerCase()) ||
            s.rollNumber.contains(event.query)).toList();
        // `currentClassroomStudents` is the class teacher's OWN roster ("My
        // class"). Searching another (subject) class must not overwrite it,
        // or "My class" ends up listing some other section's students.
        final isMyClass = event.classroomId == currentState.myClassroom?.id;
        emit(currentState.copyWith(
          searchResults: filtered,
          currentClassroomStudents: isMyClass ? students : null,
        ));
      } catch (e) {
        emit(TeacherToolsError(e.toString()));
      }
    }
  }

  Future<void> _onAddStudent(AddClassroomStudent event, Emitter<TeacherToolsState> emit) async {
    try {
      await _studentRepository.upsert(event.student);
      add(SearchStudents('', event.student.classroomId));
    } catch (e) {
      emit(TeacherToolsError(e.toString()));
    }
  }

  Future<void> _onUpdateStudent(UpdateClassroomStudent event, Emitter<TeacherToolsState> emit) async {
    try {
      await _studentRepository.upsert(event.student);
      add(SearchStudents('', event.student.classroomId));
    } catch (e) {
      emit(TeacherToolsError(e.toString()));
    }
  }

  Future<void> _onDeleteStudent(DeleteClassroomStudent event, Emitter<TeacherToolsState> emit) async {
    try {
      await _studentRepository.updateClassroom(event.studentId, null);
      add(SearchStudents('', event.classroomId));
      add(LoadAvailableStudents(event.classroomId));
    } catch (e) {
      emit(TeacherToolsError(e.toString()));
    }
  }

  Future<void> _onUnassignStudent(UnassignClassroomStudent event, Emitter<TeacherToolsState> emit) async {
    try {
      await _studentRepository.updateClassroom(event.studentId, null);
      add(SearchStudents('', event.classroomId));
      add(LoadAvailableStudents(event.classroomId));
    } catch (e) {
      emit(TeacherToolsError(e.toString()));
    }
  }

  Future<void> _onAssignExisting(AssignExistingStudents event, Emitter<TeacherToolsState> emit) async {
    try {
      await Future.wait(event.studentIds.map(
        (id) => _studentRepository.updateClassroom(id, event.classroomId, fees: event.fees),
      ));
      add(SearchStudents('', event.classroomId));
      add(LoadAvailableStudents(event.classroomId));
    } catch (e) {
      emit(TeacherToolsError(e.toString()));
    }
  }

  Future<void> _onLoadAvailable(LoadAvailableStudents event, Emitter<TeacherToolsState> emit) async {
    final currentState = state;
    if (currentState is! TeacherToolsLoaded) return;
    try {
      final available = (await _studentRepository.getAvailableStudents(event.classroomId))
          .where((s) => s.classroomId.isEmpty)
          .toList();
      emit(currentState.copyWith(availableStudents: available));
    } catch (e) {
      emit(TeacherToolsError(e.toString()));
    }
  }
}
