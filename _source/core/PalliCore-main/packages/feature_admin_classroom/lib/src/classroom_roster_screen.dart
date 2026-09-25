import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'classroom_bloc.dart';

class ClassroomRosterScreen extends StatefulWidget {
  final String classroomId;

  const ClassroomRosterScreen({super.key, required this.classroomId});

  @override
  State<ClassroomRosterScreen> createState() => _ClassroomRosterScreenState();
}

class _ClassroomRosterScreenState extends State<ClassroomRosterScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ClassroomBloc>().add(LoadClassroomRoster(widget.classroomId));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          context.read<ClassroomBloc>().add(LoadClassrooms());
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Manage students')),
        body: SafeArea(
          child: BlocBuilder<ClassroomBloc, ClassroomState>(
          builder: (context, state) {
            if (state is ClassroomError) {
              return Center(child: Text(state.message, style: const TextStyle(color: AppColors.error)));
            }
            if (state is! ClassroomRosterLoaded || state.classroom.id != widget.classroomId) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                Text(
                  state.classroom.displayName,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  '${state.enrolled.length} enrolled · Add unassigned students or remove them from this class (records stay in the school).',
                  style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13, height: 1.4),
                ),
                SizedBox(height: 20),
                _SectionLabel(title: 'In this classroom'),
                SizedBox(height: 8),
                if (state.enrolled.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No students yet.', style: TextStyle(color: AppColors.onSurfaceHint(context))),
                  )
                else
                  ...state.enrolled.map(
                    (student) => _StudentTile(
                      student: student,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Move to another section',
                            icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.accent),
                            onPressed: () => _openMoveSheet(context, student, state.classroom),
                          ),
                          IconButton(
                            tooltip: 'Remove from class',
                            icon: const Icon(Icons.person_remove_rounded, color: AppColors.error),
                            onPressed: () => _confirmRemove(context, student),
                          ),
                        ],
                      ),
                    ),
                  ),
                SizedBox(height: 24),
                _SectionLabel(title: 'Unassigned students'),
                SizedBox(height: 8),
                if (state.available.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No unassigned students. Approve admissions or create students first.',
                      style: TextStyle(color: AppColors.onSurfaceHint(context)),
                    ),
                  )
                else
                  ...state.available.map(
                    (student) => _StudentTile(
                      student: student,
                      trailing: IconButton(
                        tooltip: 'Add to class',
                        icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.success),
                        onPressed: () {
                          context.read<ClassroomBloc>().add(
                                AssignStudentsToClass(widget.classroomId, [student.id]),
                              );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${student.name} added to class')),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            );
          },
          ),
        ),
        floatingActionButton: BlocBuilder<ClassroomBloc, ClassroomState>(
          builder: (context, state) {
            if (state is! ClassroomRosterLoaded || state.available.isEmpty) {
              return const SizedBox.shrink();
            }
            return FloatingActionButton.extended(
              onPressed: () => _openBulkAdd(context, state.available),
              icon: const Icon(Icons.group_add_rounded),
              label: const Text('Add several'),
              shape: const StadiumBorder(),
            );
          },
        ),
      ),
    );
  }

  void _confirmRemove(BuildContext context, Student student) {
    showDialog<void>(
      context: context,
      builder: (_) => VerificationDialog(
        title: 'Remove from class',
        content:
            '${student.name} will be unassigned from this classroom. Their student record will not be deleted.',
        onConfirm: () {
          context.read<ClassroomBloc>().add(RemoveStudentFromClass(student.id));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${student.name} removed from class')),
          );
        },
      ),
    );
  }

  Future<void> _openMoveSheet(BuildContext context, Student student, Classroom current) async {
    final all = await context.read<ClassroomRepository>().getAll();
    final sections = all
        .where((c) => c.id != current.id && c.resolvedGradeKey == current.resolvedGradeKey)
        .toList()
      ..sort((a, b) => a.resolvedSection.compareTo(b.resolvedSection));
    if (!context.mounted) return;
    if (sections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No other section in ${current.gradeLabel} to move to')),
      );
      return;
    }
    final target = await showModalBottomSheet<Classroom>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'Move ${student.name} to another section',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              ...sections.map((c) => ListTile(
                    title: Text(c.displayName),
                    onTap: () => Navigator.pop(sheetContext, c),
                  )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (target == null || !context.mounted) return;
    await context.read<StudentRepository>().updateClassroom(student.id, target.id, fees: target.baseFees);
    if (!context.mounted) return;
    context.read<ClassroomBloc>().add(LoadClassroomRoster(widget.classroomId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${student.name} moved to ${target.displayName}')),
    );
  }

  void _openBulkAdd(BuildContext context, List<Student> available) {
    final selected = <String>{};
    var query = '';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = query.trim().isEmpty
                ? available
                : available.where((s) {
                    final q = query.trim().toLowerCase();
                    return s.name.toLowerCase().contains(q) || s.rollNumber.toLowerCase().contains(q);
                  }).toList();
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Add students',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      autofocus: false,
                      onChanged: (val) => setModalState(() => query = val),
                      decoration: const InputDecoration(
                        hintText: 'Search by name or roll number',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                      ),
                      child: filtered.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: Text('No students found')),
                            )
                          : ListView(
                        shrinkWrap: true,
                        children: filtered
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
                              context.read<ClassroomBloc>().add(
                                    AssignStudentsToClass(widget.classroomId, selected.toList()),
                                  );
                              Navigator.pop(sheetContext);
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(content: Text('${selected.length} student(s) added')),
                              );
                            },
                      child: Text('Add ${selected.isEmpty ? '' : '(${selected.length})'}'.trim()),
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
}

class _SectionLabel extends StatelessWidget {
  final String title;
  _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: AppColors.onSurface(context),
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  final Student student;
  final Widget trailing;

  const _StudentTile({required this.student, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(14),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Roll ${student.rollNumber}'),
        trailing: trailing,
      ),
    );
  }
}
