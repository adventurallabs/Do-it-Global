import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_teacher_attendance/feature_teacher_attendance.dart';
import 'teacher_tools_bloc.dart';
import 'class_update_screen.dart';
import 'progress/class_progress_screen.dart';
import 'progress/progress_widgets.dart';
import 'progress/student_progress_screen.dart';
import 'marks/marks_board_screen.dart';

class MyClassroomScreen extends StatelessWidget {
  final String teacherId;
  const MyClassroomScreen({super.key, required this.teacherId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TeacherToolsBloc, TeacherToolsState>(
      builder: (context, state) {
        if (state is TeacherToolsError) return Center(child: Text(state.message));
        // A sign-out leaves the bloc loaded with the last teacher. Showing
        // their homeroom to whoever signs in next is the worst version of
        // that bug — roll call and marks for a class that isn't theirs.
        if (state is! TeacherToolsLoaded || state.teacherId != teacherId) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.myClassroom == null) {
          return const EmptyState(
            icon: Icons.school_outlined,
            title: 'Not a class teacher',
            subtitle: 'This section appears when the admin assigns you as a class teacher.',
          );
        }
        final classroom = state.myClassroom!;
        final bloc = context.read<TeacherToolsBloc>();
        final scope = state.scopeFor(classroom);
        void push(Widget page) =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => page));

        final actions = <_ActionCard>[
          // Roll call is the class teacher's, and this screen only ever
          // renders for their own homeroom — see TeachingScope.
          _ActionCard(
            icon: Icons.checklist_rounded,
            label: 'Attendance',
            color: AppColors.success,
            // Its own full Scaffold, pushed as a dedicated route —
            // attendance-taking needs the whole screen.
            onTap: () => push(Scaffold(
              appBar: AppBar(title: Text('Attendance · ${classroom.name}')),
              body: SafeArea(
                child: ClassDailyAttendanceScreen(
                  classroomId: classroom.id,
                  classroomName: classroom.name,
                  teacherId: teacherId,
                ),
              ),
            )),
          ),
          _ActionCard(
            icon: Icons.grading_rounded,
            label: 'Marks',
            color: AppColors.accent,
            enabled: scope.canEnterMarks,
            disabledHint: scope.marksBlockedReason('') ??
                "You don't teach a subject in this class.",
            onTap: () => MarksBoardScreen.open(
              context,
              teacherId: teacherId,
              classroom: classroom,
              scope: scope,
            ),
          ),
          _ActionCard(
            icon: Icons.star_rounded,
            label: 'Stars & progress',
            color: AdminLook.gold,
            onTap: () => ClassProgressScreen.open(context, classroom: classroom, teacherId: teacherId),
          ),
          _ActionCard(
            icon: Icons.today_rounded,
            label: "Today's update",
            color: AppColors.eventCard,
            onTap: () => push(ClassUpdateScreen(
              classroomId: classroom.id,
              classroomName: classroom.name,
              teacherId: teacherId,
            )),
          ),
          _ActionCard(
            icon: Icons.calendar_view_week_rounded,
            label: 'Timetable',
            color: AppColors.examCard,
            onTap: () => push(Scaffold(
              appBar: AppBar(title: Text('Timetable · ${classroom.name}')),
              body: SafeArea(child: _TimetablePane(timetable: state.myTimetable)),
            )),
          ),
          _ActionCard(
            icon: Icons.edit_note_rounded,
            label: 'Diary note',
            color: AppColors.feeCard,
            onTap: () => _postDiaryNote(context, classroom.id, teacherId),
          ),
        ];

        return RefreshIndicator(
          onRefresh: () async {
            bloc.add(SearchStudents('', classroom.id));
            bloc.add(LoadAvailableStudents(classroom.id));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 96),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Text(
                  classroom.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AdminLook.inkOf(context),
                  ),
                ),
              ),
              for (var row = 0; row < actions.length; row += 3) ...[
                if (row > 0) const SizedBox(height: 10),
                Row(
                  children: [
                    for (var i = row; i < row + 3; i++) ...[
                      if (i > row) const SizedBox(width: 10),
                      Expanded(child: actions[i]),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 22),
              _StudentsPane(teacherId: teacherId, classroom: classroom),
            ],
          ),
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;
  /// Shown when a disabled tile is tapped — a greyed tile with no explanation
  /// reads as a bug.
  final String? disabledHint;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.enabled = true,
    this.disabledHint,
  });

  @override
  Widget build(BuildContext context) {
    final tint = enabled ? color : AppColors.onSurfaceHint(context);
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: SoftSurface(
        depth: SoftDepth.one,
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
        onTap: enabled
            ? onTap
            : () => ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(disabledHint ?? 'Not available for this class.'),
                behavior: SnackBarBehavior.floating,
              )),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(enabled ? icon : Icons.lock_outline_rounded, color: tint, size: 21),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                color: enabled ? AdminLook.inkOf(context) : tint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _postDiaryNote(
    BuildContext context, String classroomId, String teacherId) async {
  final repo = context.read<DiaryNoteRepository>();
  final messenger = ScaffoldMessenger.of(context);
  final note = await showModalBottomSheet<DiaryNote>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _DiaryNoteSheet(classroomId: classroomId, teacherId: teacherId),
  );
  if (note == null) return;
  try {
    await repo.upsert(note);
    messenger.showSnackBar(const SnackBar(content: Text('Posted to the class diary')));
  } catch (_) {
    messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't post — check the connection and try again.")));
  }
}

class _DiaryNoteSheet extends StatefulWidget {
  final String classroomId;
  final String teacherId;
  const _DiaryNoteSheet({required this.classroomId, required this.teacherId});

  @override
  State<_DiaryNoteSheet> createState() => _DiaryNoteSheetState();
}

class _DiaryNoteSheetState extends State<_DiaryNoteSheet> {
  final _titleC = TextEditingController();
  final _bodyC = TextEditingController();
  var _kind = DiaryNoteKind.notice;

  static const _kinds = [
    (DiaryNoteKind.notice, 'Notice', Icons.campaign_rounded),
    (DiaryNoteKind.reminder, 'Reminder', Icons.alarm_rounded),
    (DiaryNoteKind.teacherNote, 'Note', Icons.sticky_note_2_rounded),
  ];

  @override
  void dispose() {
    _titleC.dispose();
    _bodyC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canPost = _bodyC.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Post to class diary',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: AdminLook.inkOf(context))),
            const SizedBox(height: 4),
            Text('Every parent in this class sees it in their Diary.',
                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceMuted(context))),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (kind, label, icon) in _kinds)
                  ChoiceChip(
                    avatar: Icon(icon, size: 18),
                    label: Text(label),
                    selected: _kind == kind,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _kind = kind),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _titleC,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Title (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyC,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'e.g. Bring your art kit tomorrow',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 18),
            SoftPrimaryButton(
              label: 'Post',
              icon: Icons.send_rounded,
              onPressed: !canPost
                  ? null
                  : () {
                      final now = DateTime.now();
                      Navigator.pop(
                        context,
                        DiaryNote(
                          id: 'dn-${now.millisecondsSinceEpoch}',
                          classroomId: widget.classroomId,
                          noteDate: now,
                          kind: _kind,
                          title: _titleC.text.trim(),
                          body: _bodyC.text.trim(),
                          createdBy: widget.teacherId,
                        ),
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentsPane extends StatefulWidget {
  final String teacherId;
  final Classroom classroom;
  const _StudentsPane({required this.teacherId, required this.classroom});

  @override
  State<_StudentsPane> createState() => _StudentsPaneState();
}

class _StudentsPaneState extends State<_StudentsPane> {
  @override
  void initState() {
    super.initState();
    context.read<TeacherToolsBloc>().add(LoadAvailableStudents(widget.classroom.id));
    context.read<TeacherToolsBloc>().add(SearchStudents('', widget.classroom.id));
  }

  Classroom get classroom => widget.classroom;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TeacherToolsBloc, TeacherToolsState>(
      builder: (context, state) {
        if (state is! TeacherToolsLoaded || state.teacherId != widget.teacherId) {
          return const SizedBox.shrink();
        }
        final students = state.currentClassroomStudents;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    students.isEmpty ? 'Students' : 'Students · ${students.length}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AdminLook.inkOf(context),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openAddMenu(context, state),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (students.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: EmptyState(
                  icon: Icons.groups_outlined,
                  title: 'No students yet',
                  subtitle: 'Tap Add to create a student or assign an unassigned one to this class.',
                ),
              )
            else
              SoftSurface(
                depth: SoftDepth.one,
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (var index = 0; index < students.length; index++) ...[
                      if (index > 0) const Divider(height: 1, indent: 64, endIndent: 12),
                      _studentTile(context, state, students[index]),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _studentTile(BuildContext context, TeacherToolsLoaded state, Student student) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 12, right: 0),
      leading: StudentInitials(name: student.name),
      title: Text(student.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('Roll ${student.rollNumber} · tap for progress'),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StudentProgressScreen(
            student: student,
            teacherId: widget.teacherId,
            classroomId: classroom.id,
            classmates: state.currentClassroomStudents,
          ),
        ),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'More',
        icon: const Icon(Icons.more_vert_rounded),
        onSelected: (v) {
          if (v == 'edit') {
            _openForm(context, student: student);
          } else if (v == 'remove') {
            showDialog<void>(
              context: context,
              builder: (_) => VerificationDialog(
                title: 'Remove from class',
                content:
                    '${student.name} will be unassigned from ${classroom.name}. Their record stays in the school.',
                onConfirm: () => context.read<TeacherToolsBloc>().add(
                      UnassignClassroomStudent(student.id, classroom.id),
                    ),
              ),
            );
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'edit',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_rounded),
              title: Text('Edit details'),
            ),
          ),
          PopupMenuItem(
            value: 'remove',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.person_remove_rounded, color: AppColors.error),
              title: Text('Remove from class'),
            ),
          ),
        ],
      ),
    );
  }

  void _openAddMenu(BuildContext context, TeacherToolsLoaded state) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_rounded),
                title: const Text('Create new student'),
                subtitle: Text('Adds them straight into this class'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openForm(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_add_rounded),
                title: const Text('Assign existing student'),
                subtitle: Text(
                  state.availableStudents.isEmpty
                      ? 'No unassigned students available'
                      : '${state.availableStudents.length} unassigned',
                ),
                enabled: state.availableStudents.isNotEmpty,
                onTap: state.availableStudents.isEmpty
                    ? null
                    : () {
                        Navigator.pop(sheetContext);
                        _openAssignSheet(context, state.availableStudents);
                      },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _openAssignSheet(BuildContext parentContext, List<Student> available) {
    final selected = <String>{};
    showModalBottomSheet<void>(
      context: parentContext,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Assign students',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(modalContext).size.height * 0.5,
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: available
                            .map(
                              (student) => CheckboxListTile(
                                value: selected.contains(student.id),
                                onChanged: (val) {
                                  setModalState(() {
                                    if (val == true) {
                                      selected.add(student.id);
                                    } else {
                                      selected.remove(student.id);
                                    }
                                  });
                                },
                                title: Text(student.name),
                                subtitle: Text('Roll ${student.rollNumber}'),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: selected.isEmpty
                          ? null
                          : () {
                              parentContext.read<TeacherToolsBloc>().add(
                                    AssignExistingStudents(
                                      classroom.id,
                                      selected.toList(),
                                      fees: classroom.baseFees,
                                    ),
                                  );
                              Navigator.pop(sheetContext);
                              ScaffoldMessenger.of(parentContext).showSnackBar(
                                SnackBar(content: Text('${selected.length} student(s) assigned')),
                              );
                            },
                      child: const Text('Assign to class'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openForm(BuildContext context, {Student? student}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<TeacherToolsBloc>(),
          child: _ClassTeacherStudentForm(classroom: classroom, student: student),
        ),
      ),
    );
  }
}

class _TimetablePane extends StatefulWidget {
  final Timetable? timetable;
  const _TimetablePane({required this.timetable});

  @override
  State<_TimetablePane> createState() => _TimetablePaneState();
}

class _TimetablePaneState extends State<_TimetablePane> {
  Map<String, String> _staffNames = const {};

  @override
  void initState() {
    super.initState();
    _loadNames();
  }

  Future<void> _loadNames() async {
    try {
      final teachers = await context.read<TeacherRepository>().getAll();
      if (!mounted) return;
      setState(() => _staffNames = {for (final t in teachers) t.id: t.name});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final timetable = widget.timetable;
    if (timetable == null) {
      return const EmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'No active timetable',
        subtitle: 'The admin has not activated a timetable for this class yet.',
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DayScheduleView(periods: timetable.periods, staffNames: _staffNames),
    );
  }
}

class _ClassTeacherStudentForm extends StatefulWidget {
  final Classroom classroom;
  final Student? student;
  const _ClassTeacherStudentForm({required this.classroom, this.student});

  @override
  State<_ClassTeacherStudentForm> createState() => _ClassTeacherStudentFormState();
}

class _ClassTeacherStudentFormState extends State<_ClassTeacherStudentForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameC;
  late final TextEditingController _rollC;
  late final TextEditingController _fatherC;
  late final TextEditingController _motherC;
  late final TextEditingController _contactC;
  late final TextEditingController _secC;
  late final TextEditingController _addressC;
  late final TextEditingController _photoC;
  late final TextEditingController _admissionNoC;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _nameC = TextEditingController(text: s?.name ?? '');
    _rollC = TextEditingController(text: s?.rollNumber ?? '');
    _fatherC = TextEditingController(text: s?.fatherName ?? '');
    _motherC = TextEditingController(text: s?.motherName ?? '');
    _contactC = TextEditingController(text: s?.contactNumber ?? '');
    _secC = TextEditingController(text: s?.secondaryContactNumber ?? '');
    _addressC = TextEditingController(text: s?.address ?? '');
    _photoC = TextEditingController(text: s?.photoUrl ?? '');
    _admissionNoC = TextEditingController(text: s?.admissionNo ?? '');
  }

  @override
  void dispose() {
    for (final c in [_nameC, _rollC, _fatherC, _motherC, _contactC, _secC, _addressC, _photoC, _admissionNoC]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.student == null ? 'Add student' : 'Edit student')),
      body: SafeArea(
        child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _field(_nameC, 'Name', Icons.person_outline),
            _field(_admissionNoC, 'Register / Admission Number', Icons.badge_outlined),
            _field(_rollC, 'Roll number', Icons.tag),
            _field(_photoC, 'Photo URL (optional)', Icons.image_outlined, requiredField: false),
            _field(_fatherC, "Father's name", Icons.person),
            _field(_motherC, "Mother's name", Icons.person_outline),
            _field(_contactC, 'Contact', Icons.phone_outlined, keyboard: TextInputType.phone),
            _field(_secC, 'Secondary contact', Icons.phone, requiredField: false, keyboard: TextInputType.phone),
            _field(_addressC, 'Address', Icons.location_on_outlined, maxLines: 2),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                final student = Student(
                  id: widget.student?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  name: _nameC.text.trim(),
                  rollNumber: _rollC.text.trim(),
                  photoUrl: _photoC.text.trim().isEmpty ? null : _photoC.text.trim(),
                  fatherName: _fatherC.text.trim(),
                  motherName: _motherC.text.trim(),
                  contactNumber: _contactC.text.trim(),
                  secondaryContactNumber: _secC.text.trim().isEmpty ? null : _secC.text.trim(),
                  address: _addressC.text.trim(),
                  classroomId: widget.classroom.id,
                  fees: widget.student?.fees ?? widget.classroom.baseFees,
                  admissionNo: _admissionNoC.text.trim(),
                  isActive: widget.student?.isActive ?? true,
                  deactivatedAt: widget.student?.deactivatedAt,
                );
                final bloc = context.read<TeacherToolsBloc>();
                if (widget.student == null) {
                  bloc.add(AddClassroomStudent(student));
                } else {
                  bloc.add(UpdateClassroomStudent(student));
                }
                Navigator.pop(context);
              },
              child: Text(widget.student == null ? 'Create student' : 'Save changes'),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, {bool requiredField = true, TextInputType? keyboard, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        validator: requiredField ? (val) => val == null || val.trim().isEmpty ? 'Required' : null : null,
      ),
    );
  }
}
