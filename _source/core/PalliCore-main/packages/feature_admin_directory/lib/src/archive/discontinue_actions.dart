import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import '../directory_bloc.dart';
import 'exit_explainer.dart';

/// Marking somebody as having left the school.
///
/// Both flows are here rather than inside a screen because the same action is
/// reachable from the directory, from a detail page and from the end-of-year
/// screen, and all three must archive the record identically — one wrong
/// path and a leaver quietly stays on the roll with no retention clock.
class DiscontinueActions {
  DiscontinueActions._();

  /// Discontinues a staff member. Before the archive write it deals with
  /// everything they were holding: the classes they run and the periods they
  /// teach, which would otherwise be left pointing at somebody who no longer
  /// exists. Returns true when the record was archived.
  static Future<bool> staff(
    BuildContext context,
    Teacher teacher, {
    VoidCallback? onDone,
  }) async {
    final teacherRepo = context.read<TeacherRepository>();
    final classroomRepo = context.read<ClassroomRepository>();
    final timetableRepo = context.read<TimetableRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final directory = context.read<DirectoryBloc>();
    final library = context.read<LibraryRepository>();

    HandoverImpact impact;
    try {
      impact = await StaffHandover.impactOf(
        teacher.id,
        classrooms: classroomRepo,
        timetables: timetableRepo,
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text("Couldn't check this teacher's classes — check your connection."),
      ));
      return false;
    }
    final booksOut = await libraryBooksStillOut(library, teacherId: teacher.id);
    if (!context.mounted) return false;

    // Say up front what will be left without a teacher, so the admin is not
    // told after the fact that a class has nobody.
    final consequences = <String>[
      ?booksOut,
      if (impact.homerooms.isNotEmpty)
        '${impact.homerooms.map((c) => c.displayName).join(', ')} '
            '${impact.homerooms.length == 1 ? 'is' : 'are'} left without a class teacher — '
            'the class keeps its students, marks and progress, and the next teacher '
            'you name inherits all of it.',
      if (impact.periods.isNotEmpty)
        '${impact.periods.length} timetable '
            '${impact.periods.length == 1 ? 'period' : 'periods'} '
            '${impact.periods.length == 1 ? 'becomes' : 'become'} unassigned. '
            'Assign them from each class\'s timetable.',
    ];

    var note = '';
    final confirmed = await ExitExplainer.confirm(
      context,
      subjectName: teacher.name,
      isStaff: true,
      reason: ExitReason.discontinued,
      onNote: (value) => note = value,
      extraConsequences: consequences,
    );
    if (!confirmed || !context.mounted) return false;

    try {
      // Free the class and the timetable first. If the archive write then
      // fails, the worst case is a teacher still on staff whose periods are
      // unassigned — recoverable. The reverse would leave classes pointing
      // at somebody the app has archived.
      for (final room in impact.homerooms) {
        await StaffHandover.setClassTeacher(
          room,
          null,
          classrooms: classroomRepo,
          teachers: teacherRepo,
        );
      }
      if (impact.periods.isNotEmpty) {
        await StaffHandover.reassignPeriods(
          timetables: timetableRepo,
          fromTeacherId: teacher.id,
          toTeacherId: null,
        );
      }
      await teacherRepo.recordExit(teacher, note: note);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text("Couldn't discontinue — check your connection and try again."),
      ));
      return false;
    }

    directory.add(LoadDirectory());
    onDone?.call();
    messenger.showSnackBar(SnackBar(
      content: Text('${teacher.name} moved to Discontinued. '
          'Download their record within 30 days.'),
      duration: const Duration(seconds: 5),
    ));
    return true;
  }

  /// Marks a child as having left. [lifecycle] must be one that has left —
  /// transferred, discontinued or graduated.
  static Future<bool> student(
    BuildContext context,
    Student student, {
    required StudentLifecycle lifecycle,
    VoidCallback? onDone,
    bool announce = true,
  }) async {
    assert(lifecycle.hasLeft, 'Use this only for a lifecycle that has left');
    final repo = context.read<StudentRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final directory = context.read<DirectoryBloc>();
    final booksOut = await libraryBooksStillOut(context.read<LibraryRepository>(), studentIds: [student.id]);
    if (!context.mounted) return false;

    var note = '';
    final confirmed = await ExitExplainer.confirm(
      context,
      subjectName: student.name,
      isStaff: false,
      reason: lifecycle.exitReason!,
      onNote: (value) => note = value,
      extraConsequences: [?booksOut],
    );
    if (!confirmed || !context.mounted) return false;

    try {
      await repo.recordExit(student, lifecycle: lifecycle, note: note);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text("Couldn't update this student — check your connection and try again."),
      ));
      return false;
    }

    directory.add(LoadDirectory());
    onDone?.call();
    if (announce) {
      messenger.showSnackBar(SnackBar(
        content: Text('${student.name} moved to '
            '${lifecycle == StudentLifecycle.graduated ? 'Graduated' : 'Discontinued'}. '
            'Download their record within 30 days.'),
        duration: const Duration(seconds: 5),
      ));
    }
    return true;
  }
}
