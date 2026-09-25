import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'teacher_tools_bloc.dart';
import 'homework/homework_progress.dart';
import 'progress/class_progress_screen.dart';
import 'progress/progress_widgets.dart';
import 'progress/student_progress_screen.dart';
import 'marks/marks_board_screen.dart';

class ClassWorkspaceScreen extends StatefulWidget {
  final String teacherId;
  final Classroom classroom;

  /// What this teacher may do here — which subjects are theirs, and whether
  /// roll call is. Passed in rather than re-derived so every screen agrees.
  final TeachingScope scope;

  const ClassWorkspaceScreen({
    super.key,
    required this.teacherId,
    required this.classroom,
    required this.scope,
  });

  List<String> get subjects => scope.subjects;

  @override
  State<ClassWorkspaceScreen> createState() => _ClassWorkspaceScreenState();
}

class _ClassWorkspaceScreenState extends State<ClassWorkspaceScreen> {
  final _searchC = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<TeacherToolsBloc>().add(SearchStudents('', widget.classroom.id));
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.classroom.displayName),
        actions: [
          IconButton(
            tooltip: 'Stars & progress',
            icon: const Icon(Icons.star_rounded, color: AdminLook.gold),
            onPressed: () => ClassProgressScreen.open(
              context,
              classroom: widget.classroom,
              teacherId: widget.teacherId,
            ),
          ),
          if (widget.scope.canEnterMarks)
            IconButton(
              tooltip: 'Marks',
              icon: const Icon(Icons.grading_rounded),
              onPressed: _openMarks,
            ),
        ],
      ),
      body: SafeArea(child: _studentsTab()),
      floatingActionButton: widget.scope.canEnterMarks
          ? FloatingActionButton.extended(
              onPressed: _openMarks,
              icon: const Icon(Icons.grading_rounded),
              label: const Text('Marks'),
              shape: const StadiumBorder(),
            )
          : null,
    );
  }

  /// Marks always open on the board, never straight into a blank entry form:
  /// a teacher's first question is "what did I already record?".
  void _openMarks() => MarksBoardScreen.open(
        context,
        teacherId: widget.teacherId,
        classroom: widget.classroom,
        scope: widget.scope,
      );

  Widget _studentsTab() {
    return BlocBuilder<TeacherToolsBloc, TeacherToolsState>(
      builder: (context, state) {
        if (state is TeacherToolsError) {
          return Center(child: Text(state.message, style: const TextStyle(color: AppColors.error)));
        }
        if (state is! TeacherToolsLoaded) return const Center(child: CircularProgressIndicator());
        // The search list is shared bloc state — until this class's search
        // lands it may still hold another section's students.
        final results =
            state.searchResults.where((s) => s.classroomId == widget.classroom.id).toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchC,
                onChanged: (val) => context.read<TeacherToolsBloc>().add(SearchStudents(val, widget.classroom.id)),
                decoration: const InputDecoration(hintText: 'Search by name or roll number', prefixIcon: Icon(Icons.search)),
              ),
            ),
            if (results.isEmpty)
              Expanded(
                child: EmptyState(
                  icon: Icons.person_search_rounded,
                  title: _searchC.text.isEmpty ? 'No students in this class yet' : 'No match',
                  subtitle: _searchC.text.isEmpty ? null : 'Try a different name or roll number.',
                ),
              )
            else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final student = results[index];
                  return SoftSurface(
                    depth: SoftDepth.one,
                    borderRadius: BorderRadius.circular(14),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.only(left: 12, right: 4),
                      leading: StudentInitials(name: student.name),
                      title: Text(student.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Roll ${student.rollNumber} · tap for progress'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentProgressScreen(
                            student: student,
                            teacherId: widget.teacherId,
                            classroomId: widget.classroom.id,
                          ),
                        ),
                      ),
                      trailing: widget.scope.teachesHere
                          ? IconButton(
                              icon: const Icon(Icons.assignment_outlined, color: AppColors.accent),
                              tooltip: 'Assign individual work',
                              onPressed: () => _assignWork(student),
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Work for a single student. Its own small flow rather than the full
  /// assign screen — the class and the student are already decided, and the
  /// only thing a teacher wants to type is the work itself.
  Future<void> _assignWork(Student student) async {
    // Work goes out under a subject this teacher actually takes here. The old
    // fallback to the whole catalogue let a science teacher send "English"
    // homework, which then sat in another teacher's column.
    final subjects = widget.scope.subjects;
    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.scope.marksBlockedReason('') ??
            "You don't teach a subject in this class."),
      ));
      return;
    }
    final result = await showDialog<_IndividualWork>(
      context: context,
      builder: (_) => _AssignWorkDialog(student: student, subjects: subjects),
    );
    if (result == null || !mounted) return;

    final hw = Homework(
      id: HomeworkRepository.newId(),
      classroomId: widget.classroom.id,
      subject: result.subject,
      title: result.title,
      description: 'Individual work',
      dueDate: DateTime(
          result.dueDate.year, result.dueDate.month, result.dueDate.day, 23, 59),
      createdBy: widget.teacherId,
      studentId: student.id,
    );

    final bloc = context.read<TeacherToolsBloc>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<HomeworkRepository>().save(hw);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text("Couldn't send the work — check your connection and try again."),
      ));
      return;
    }
    bloc.add(RefreshTeacherHomework(widget.teacherId));
    messenger.showSnackBar(SnackBar(
      content: Text('${result.subject} work sent to ${student.name} · ${dueLabel(hw.dueDate).toLowerCase()}'),
    ));
  }
}

class _IndividualWork {
  final String title;
  final String subject;
  final DateTime dueDate;
  const _IndividualWork(this.title, this.subject, this.dueDate);
}

class _AssignWorkDialog extends StatefulWidget {
  final Student student;
  final List<String> subjects;
  const _AssignWorkDialog({required this.student, required this.subjects});

  @override
  State<_AssignWorkDialog> createState() => _AssignWorkDialogState();
}

class _AssignWorkDialogState extends State<_AssignWorkDialog> {
  final _workC = TextEditingController();
  late String _subject = widget.subjects.first;
  DateTime _due = DateTime.now().add(const Duration(days: 2));

  @override
  void dispose() {
    _workC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Work for ${widget.student.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Always shown, even for a single subject: the teacher should be
            // able to see which subject this lands under before sending it.
            DropdownButtonFormField<String>(
              initialValue: _subject,
              items: widget.subjects
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) => setState(() => _subject = val ?? _subject),
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _workC,
              maxLines: 3,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Imposition or assignment',
                hintText: 'e.g. Rewrite the spelling list five times',
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Due', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.onSurfaceMuted(context))),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                _dueChip('Tomorrow', 1),
                _dueChip('In 2 days', 2),
                _dueChip('Next week', 7),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _workC.text.trim().isEmpty
              ? null
              : () => Navigator.pop(
                  context, _IndividualWork(_workC.text.trim(), _subject, _due)),
          child: const Text('Assign'),
        ),
      ],
    );
  }

  Widget _dueChip(String label, int days) {
    final now = DateTime.now();
    final target = DateTime(now.year, now.month, now.day).add(Duration(days: days));
    return ChoiceChip(
      label: Text(label),
      selected: daysUntilDue(_due) == days,
      onSelected: (_) => setState(() => _due = target),
    );
  }
}
