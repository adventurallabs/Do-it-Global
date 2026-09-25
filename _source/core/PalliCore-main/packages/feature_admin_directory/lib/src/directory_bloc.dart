import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';

abstract class DirectoryEvent {}

class LoadDirectory extends DirectoryEvent {}

class SearchDirectory extends DirectoryEvent {
  final String query;
  SearchDirectory(this.query);
}

class SortDirectory extends DirectoryEvent {
  final String sortBy;
  SortDirectory(this.sortBy);
}

class FilterByClass extends DirectoryEvent {
  final String? classroomId;
  FilterByClass(this.classroomId);
}

class AddStudent extends DirectoryEvent {
  final Student student;
  AddStudent(this.student);
}

class UpdateStudent extends DirectoryEvent {
  final Student student;
  UpdateStudent(this.student);
}

class DeleteStudent extends DirectoryEvent {
  final String studentId;
  DeleteStudent(this.studentId);
}

class AddTeacher extends DirectoryEvent {
  final Teacher teacher;
  AddTeacher(this.teacher);
}

class UpdateTeacher extends DirectoryEvent {
  final Teacher teacher;
  UpdateTeacher(this.teacher);
}

class DeleteTeacher extends DirectoryEvent {
  final String teacherId;
  DeleteTeacher(this.teacherId);
}

abstract class DirectoryState {}

class DirectoryInitial extends DirectoryState {}

class DirectoryLoading extends DirectoryState {}

class DirectoryLoaded extends DirectoryState {
  final List<Student> students;
  final List<Teacher> teachers;
  final List<Classroom> classrooms;
  final List<Student> filteredStudents;
  final List<Teacher> filteredTeachers;
  final Map<String, Set<String>> teacherClassroomIds;
  final String? classFilter;

  DirectoryLoaded({
    required this.students,
    required this.teachers,
    required this.classrooms,
    required this.teacherClassroomIds,
    List<Student>? filteredStudents,
    List<Teacher>? filteredTeachers,
    this.classFilter,
  })  : filteredStudents = filteredStudents ?? students,
        filteredTeachers = filteredTeachers ?? teachers;

  String classroomName(String id) {
    if (id.isEmpty) return 'Unassigned';
    for (final classroom in classrooms) {
      if (classroom.id == id) return classroom.name;
    }
    return id;
  }
}

class DirectoryError extends DirectoryState {
  final String message;
  DirectoryError(this.message);
}

class DirectoryBloc extends Bloc<DirectoryEvent, DirectoryState> {
  final StudentRepository _studentRepository;
  final TeacherRepository _teacherRepository;
  final ClassroomRepository _classroomRepository;
  final TimetableRepository _timetableRepository;
  String _currentQuery = '';
  String _currentSort = 'name';
  String? _currentFilter;
  Map<String, Set<String>> _teacherClassroomIds = {};

  DirectoryBloc(
    this._studentRepository,
    this._teacherRepository,
    this._classroomRepository,
    this._timetableRepository,
  ) : super(DirectoryInitial()) {
    on<LoadDirectory>(_onLoad);
    on<SearchDirectory>(_onSearch);
    on<SortDirectory>(_onSort);
    on<FilterByClass>(_onFilter);
    on<AddStudent>(_onAddStudent);
    on<UpdateStudent>(_onUpdateStudent);
    on<DeleteStudent>(_onDeleteStudent);
    on<AddTeacher>(_onAddTeacher);
    on<UpdateTeacher>(_onUpdateTeacher);
    on<DeleteTeacher>(_onDeleteTeacher);
  }

  Future<void> _onLoad(LoadDirectory event, Emitter<DirectoryState> emit) async {
    emit(DirectoryLoading());
    try {
      final (students, teachers, classrooms, timetables) = await (
        _studentRepository.getAll(),
        _teacherRepository.getAll(),
        _classroomRepository.getAll(),
        _timetableRepository.getAll(),
      ).wait;
      _teacherClassroomIds = {};
      for (final teacher in teachers) {
        _teacherClassroomIds.putIfAbsent(teacher.id, () => <String>{});
        if (teacher.classroomId != null && teacher.classroomId!.isNotEmpty) {
          _teacherClassroomIds[teacher.id]!.add(teacher.classroomId!);
        }
      }
      for (final timetable in timetables) {
        for (final period in timetable.periods) {
          if (period.staffId == 'N/A' || period.staffId.isEmpty) continue;
          _teacherClassroomIds.putIfAbsent(period.staffId, () => <String>{});
          _teacherClassroomIds[period.staffId]!.add(timetable.classroomId);
        }
      }
      emit(_applyFilters(students, teachers, classrooms));
    } catch (e) {
      emit(DirectoryError(e.toString()));
    }
  }

  void _onSearch(SearchDirectory event, Emitter<DirectoryState> emit) {
    _currentQuery = event.query;
    if (state is DirectoryLoaded) {
      final s = state as DirectoryLoaded;
      emit(_applyFilters(s.students, s.teachers, s.classrooms));
    }
  }

  void _onSort(SortDirectory event, Emitter<DirectoryState> emit) {
    _currentSort = event.sortBy;
    if (state is DirectoryLoaded) {
      final s = state as DirectoryLoaded;
      emit(_applyFilters(s.students, s.teachers, s.classrooms));
    }
  }

  void _onFilter(FilterByClass event, Emitter<DirectoryState> emit) {
    _currentFilter = event.classroomId;
    if (state is DirectoryLoaded) {
      final s = state as DirectoryLoaded;
      emit(_applyFilters(s.students, s.teachers, s.classrooms));
    }
  }

  DirectoryLoaded _applyFilters(List<Student> allStudents, List<Teacher> allTeachers, List<Classroom> classrooms) {
    var students = List<Student>.from(allStudents);
    var teachers = List<Teacher>.from(allTeachers);

    if (_currentQuery.isNotEmpty) {
      final q = _currentQuery.toLowerCase();
      students = students.where((s) => s.name.toLowerCase().contains(q) || s.rollNumber.contains(q)).toList();
      teachers = teachers.where((t) =>
          t.name.toLowerCase().contains(q) ||
          t.qualification.toLowerCase().contains(q) ||
          t.contactNumber.contains(q) ||
          t.subjects.any((subject) => subject.toLowerCase().contains(q))).toList();
    }

    if (_currentFilter != null) {
      students = students.where((s) => s.classroomId == _currentFilter).toList();
      teachers = teachers.where((t) => (_teacherClassroomIds[t.id] ?? {}).contains(_currentFilter)).toList();
    }

    if (_currentSort == 'name') {
      students.sort((a, b) => a.name.compareTo(b.name));
      teachers.sort((a, b) => a.name.compareTo(b.name));
    } else if (_currentSort == 'class') {
      students.sort((a, b) => a.classroomId.compareTo(b.classroomId));
      teachers.sort((a, b) => (a.classroomId ?? '').compareTo(b.classroomId ?? ''));
    }

    return DirectoryLoaded(
      students: allStudents,
      teachers: allTeachers,
      classrooms: classrooms,
      teacherClassroomIds: _teacherClassroomIds,
      filteredStudents: students,
      filteredTeachers: teachers,
      classFilter: _currentFilter,
    );
  }

  Future<void> _onAddStudent(AddStudent event, Emitter<DirectoryState> emit) async {
    try {
      await _studentRepository.upsert(event.student);
      add(LoadDirectory());
    } catch (e) {
      emit(DirectoryError(e.toString()));
    }
  }

  Future<void> _onUpdateStudent(UpdateStudent event, Emitter<DirectoryState> emit) async {
    try {
      await _studentRepository.upsert(event.student);
      add(LoadDirectory());
    } catch (e) {
      emit(DirectoryError(e.toString()));
    }
  }

  Future<void> _onDeleteStudent(DeleteStudent event, Emitter<DirectoryState> emit) async {
    try {
      // Soft — revokes the linked parent login and drops them from active
      // lists/counts. Permanent purge only happens from the Deactivated section.
      await _studentRepository.setActive(event.studentId, false);
      add(LoadDirectory());
    } catch (e) {
      emit(DirectoryError(e.toString()));
    }
  }

  Future<void> _onAddTeacher(AddTeacher event, Emitter<DirectoryState> emit) async {
    try {
      await _teacherRepository.upsert(event.teacher);
      add(LoadDirectory());
    } catch (e) {
      emit(DirectoryError(e.toString()));
    }
  }

  Future<void> _onUpdateTeacher(UpdateTeacher event, Emitter<DirectoryState> emit) async {
    try {
      await _teacherRepository.upsert(event.teacher);
      add(LoadDirectory());
    } catch (e) {
      emit(DirectoryError(e.toString()));
    }
  }

  Future<void> _onDeleteTeacher(DeleteTeacher event, Emitter<DirectoryState> emit) async {
    try {
      // Soft — revokes their session immediately and drops them from active
      // lists/counts. Permanent purge only happens from the Deactivated section.
      await _teacherRepository.setActive(event.teacherId, false);
      add(LoadDirectory());
    } catch (e) {
      emit(DirectoryError(e.toString()));
    }
  }
}
