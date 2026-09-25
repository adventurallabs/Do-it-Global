import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:go_router/go_router.dart';
import '../directory_bloc.dart';
import '../student_detail_screen.dart';
import '../teacher_detail_screen.dart';
import 'export_sheet_action.dart';

/// Which archive this screen is showing. Graduating is a milestone and
/// leaving early is a problem; an admin looking for one should never have to
/// read past the other, so they are separate lists behind separate cards.
enum ArchiveKind {
  discontinued,
  graduated;

  String get title => switch (this) {
        ArchiveKind.discontinued => 'Discontinued',
        ArchiveKind.graduated => 'Graduated',
      };

  Set<StudentLifecycle> get studentLifecycles => switch (this) {
        ArchiveKind.discontinued => {
            StudentLifecycle.discontinued,
            StudentLifecycle.transferred,
          },
        ArchiveKind.graduated => {StudentLifecycle.graduated},
      };

  bool get hasStaff => this == ArchiveKind.discontinued;
}

/// Everyone who has left the school, with their retention countdown and the
/// download that outlives them.
class ArchiveScreen extends StatefulWidget {
  final ArchiveKind kind;

  const ArchiveScreen({super.key, required this.kind});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  List<Student> _students = const [];
  List<Teacher> _teachers = const [];
  Map<String, String> _classNames = const {};
  bool _loading = true;
  bool _hasError = false;

  bool get _hasStaff => widget.kind.hasStaff;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _hasError = false;
      });
    }
    try {
      final (students, teachers, classrooms) = await (
        context.read<StudentRepository>().getArchived(reasons: widget.kind.studentLifecycles),
        _hasStaff
            ? context.read<TeacherRepository>().getArchived()
            : Future<List<Teacher>>.value(const []),
        context.read<ClassroomRepository>().getAll(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _students = students;
        _teachers = teachers;
        _classNames = {for (final c in classrooms) c.id: c.displayName};
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[
      const Tab(text: 'Students'),
      if (_hasStaff) const Tab(text: 'Staff'),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.kind.title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/admin'),
          ),
          bottom: tabs.length > 1 ? TabBar(tabs: tabs) : null,
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _hasError
                  ? EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: "Couldn't load the archive",
                      subtitle: 'Check your connection and try again.',
                      actionLabel: 'Retry',
                      onAction: _load,
                    )
                  : TabBarView(
                      children: [
                        _studentTab(),
                        if (_hasStaff) _staffTab(),
                      ],
                    ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Students
  // ---------------------------------------------------------------------------

  Widget _studentTab() {
    if (_students.isEmpty) {
      return EmptyState(
        icon: widget.kind == ArchiveKind.graduated
            ? Icons.workspace_premium_outlined
            : Icons.person_off_outlined,
        title: widget.kind == ArchiveKind.graduated
            ? 'No graduated students'
            : 'No discontinued or transferred students',
        subtitle: widget.kind == ArchiveKind.graduated
            ? 'Students you graduate from the Academic year screen appear here.'
            : 'Students you transfer out or discontinue appear here for 30 days.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _retentionNote(_students.length, 'student'),
          const SizedBox(height: 12),
          _bulkExportButton(
            label: 'Download all ${_students.length} students',
            baseName: '${widget.kind.title.toLowerCase()}-students',
            sheets: () => LeaverExport.students(_students, classNames: _classNames),
          ),
          const SizedBox(height: 16),
          for (final student in _students)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ArchiveCard(
                name: student.name,
                meta: [
                  if (student.admissionNo.isNotEmpty) 'Reg ${student.admissionNo}',
                  student.lifecycle.label,
                ].join(' · '),
                note: student.exitNote,
                exit: student.exit,
                icon: Icons.person_rounded,
                color: AppColors.studentCard,
                onView: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StudentDetailScreen(student: student)),
                ),
                onExport: () => _exportStudent(student),
                onRestore: () => _restoreStudent(student),
                onDeleteNow: () => _deleteStudentNow(student),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _exportStudent(Student student) async {
    final marksRepo = context.read<MarkRepository>();
    final attendanceRepo = context.read<AttendanceRepository>();
    List<Mark> marks = const [];
    List<Attendance> attendance = const [];
    try {
      marks = await marksRepo.getForStudents([student.id]);
      attendance = await attendanceRepo.getForStudent(student.id);
    } catch (_) {
      // A profile-only export still beats no export at all — say so rather
      // than failing the whole download.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Couldn't load marks and attendance — exporting the profile only."),
        ));
      }
    }
    if (!mounted) return;
    await ExportSheetAction.run(
      context,
      title: 'Download ${student.name}',
      baseName: student.name,
      sheets: LeaverExport.studentFile(
        student,
        className: _classNames[student.classroomId] ?? '',
        marks: marks,
        attendance: attendance,
      ),
    );
  }

  Future<void> _restoreStudent(Student student) async {
    final ok = await _confirmRestore(student.name, isStaff: false);
    if (ok != true || !mounted) return;
    final repo = context.read<StudentRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final bloc = context.read<DirectoryBloc>();
    try {
      await repo.undoExit(student);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text("Couldn't restore — check your connection and try again."),
      ));
      return;
    }
    bloc.add(LoadDirectory());
    messenger.showSnackBar(SnackBar(
      content: Text('${student.name} is back on the roll. Assign them to a class next.'),
    ));
    await _load();
  }

  Future<void> _deleteStudentNow(Student student) {
    return showDialog<void>(
      context: context,
      builder: (_) => VerificationDialog(
        title: 'Erase ${student.name} now',
        content: "This won't wait for the 30 days. It permanently erases the student "
            'record, their parent login, attendance, marks, fees and messages. '
            'Download their file first if you still need it.',
        confirmWord: 'PERMANENTLY DELETE',
        actionLabel: 'Erase forever',
        onConfirm: () async {
          await context.read<StudentRepository>().deletePermanently(student.id);
          await _load();
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Staff
  // ---------------------------------------------------------------------------

  Widget _staffTab() {
    if (_teachers.isEmpty) {
      return const EmptyState(
        icon: Icons.badge_outlined,
        title: 'No discontinued staff',
        subtitle: 'Staff you discontinue appear here for 30 days, with their record '
            'available to download.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _retentionNote(_teachers.length, 'staff member'),
          const SizedBox(height: 12),
          _bulkExportButton(
            label: 'Download all ${_teachers.length} staff',
            baseName: 'discontinued-staff',
            sheets: () => LeaverExport.staff(_teachers),
          ),
          const SizedBox(height: 16),
          for (final teacher in _teachers)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ArchiveCard(
                name: teacher.name,
                meta: [
                  teacher.roleLabel,
                  if (teacher.subjects.isNotEmpty) teacher.subjects.join(', '),
                ].join(' · '),
                note: teacher.exitNote,
                exit: teacher.exit,
                icon: Icons.badge_rounded,
                color: AppColors.teacherCard,
                onView: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TeacherDetailScreen(teacher: teacher)),
                ),
                onExport: () => ExportSheetAction.run(
                  context,
                  title: 'Download ${teacher.name}',
                  baseName: teacher.name,
                  sheets: LeaverExport.staffFile(teacher),
                ),
                onRestore: () => _restoreTeacher(teacher),
                onDeleteNow: () => _deleteTeacherNow(teacher),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _restoreTeacher(Teacher teacher) async {
    final ok = await _confirmRestore(teacher.name, isStaff: true);
    if (ok != true || !mounted) return;
    final repo = context.read<TeacherRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final bloc = context.read<DirectoryBloc>();
    try {
      await repo.undoExit(teacher);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text("Couldn't restore — check your connection and try again."),
      ));
      return;
    }
    bloc.add(LoadDirectory());
    messenger.showSnackBar(SnackBar(
      content: Text('${teacher.name} is back on staff. Their classes and timetable '
          'periods were not restored — assign those again.'),
    ));
    await _load();
  }

  Future<void> _deleteTeacherNow(Teacher teacher) {
    return showDialog<void>(
      context: context,
      builder: (_) => VerificationDialog(
        title: 'Erase ${teacher.name} now',
        content: "This won't wait for the 30 days. It permanently erases the staff "
            'record and their login. Download their file first if you still need it.',
        confirmWord: 'PERMANENTLY DELETE',
        actionLabel: 'Erase forever',
        onConfirm: () async {
          await context.read<TeacherRepository>().deletePermanently(teacher.id);
          await _load();
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared
  // ---------------------------------------------------------------------------

  Future<bool?> _confirmRestore(String name, {required bool isStaff}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Bring $name back?'),
        content: Text(
          isStaff
              ? 'Their login is switched back on and the 30-day countdown stops. '
                  'Their old class and timetable periods are not restored — assign '
                  'those yourself.'
              : 'They go back on the roll as enrolled and the 30-day countdown stops. '
                  'They are not put back in a class — assign them yourself.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bring back'),
          ),
        ],
      ),
    );
  }

  Widget _retentionNote(int count, String noun) {
    return SoftSurface(
      depth: SoftDepth.none,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.schedule_rounded, size: 18, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count ${count == 1 ? noun : '${noun}s'} here. Every record is erased for '
              'good 30 days after they left — download what you need before then. '
              'The download is the only copy that survives.',
              style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.onSurfaceMuted(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulkExportButton({
    required String label,
    required String baseName,
    required List<ExportSheet> Function() sheets,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        onPressed: () => ExportSheetAction.run(
          context,
          title: label,
          baseName: baseName,
          sheets: sheets(),
        ),
        icon: const Icon(Icons.download_rounded, size: 18),
        label: Text(label),
      ),
    );
  }
}

/// One leaver: who they were, when they left, how long is left, and every
/// action that still applies to them.
class _ArchiveCard extends StatelessWidget {
  final String name;
  final String meta;
  final String note;
  final ExitRecord? exit;
  final IconData icon;
  final Color color;
  final VoidCallback onView;
  final VoidCallback onExport;
  final VoidCallback onRestore;
  final VoidCallback onDeleteNow;

  const _ArchiveCard({
    required this.name,
    required this.meta,
    required this.note,
    required this.exit,
    required this.icon,
    required this.color,
    required this.onView,
    required this.onExport,
    required this.onRestore,
    required this.onDeleteNow,
  });

  @override
  Widget build(BuildContext context) {
    final record = exit;
    final urgent = record?.isUrgent() ?? false;
    final countdownColor = record == null
        ? AppColors.onSurfaceHint(context)
        : urgent
            ? AppColors.error
            : AppColors.warning;

    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      onTap: onView,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                    const SizedBox(height: 2),
                    Text(meta,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted(context))),
                    if (record != null) ...[
                      const SizedBox(height: 2),
                      Text('Left ${_shortDate(record.at)}',
                          style: TextStyle(fontSize: 12, color: AppColors.onSurfaceHint(context))),
                    ],
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('"$note"',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: AppColors.onSurfaceMuted(context))),
                    ],
                  ],
                ),
              ),
              if (record != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: countdownColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    record.countdownLabel(),
                    style: TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w800, color: countdownColor),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.download_rounded, size: 17),
                label: const Text('Download'),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
              TextButton.icon(
                onPressed: onRestore,
                icon: const Icon(Icons.settings_backup_restore_rounded, size: 17),
                label: const Text('Bring back'),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.success, visualDensity: VisualDensity.compact),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Erase now',
                onPressed: onDeleteNow,
                icon: const Icon(Icons.delete_forever_rounded, size: 20, color: AppColors.error),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _shortDate(DateTime dt) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}
