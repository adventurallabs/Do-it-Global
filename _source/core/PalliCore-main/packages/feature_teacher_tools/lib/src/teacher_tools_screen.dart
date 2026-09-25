import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'teacher_tools_bloc.dart';
import 'marks/marks_board_screen.dart';
import 'progress/class_progress_screen.dart';
import 'class_workspace_screen.dart';
import 'my_classroom_screen.dart';
import 'teacher_leave_screen.dart';
import 'cover_requests_screen.dart';
import 'homework/homework_board_screen.dart';

class TeacherToolsScreen extends StatefulWidget {
  final String teacherId;

  const TeacherToolsScreen({super.key, required this.teacherId});

  @override
  State<TeacherToolsScreen> createState() => _TeacherToolsScreenState();
}

class _TeacherToolsScreenState extends State<TeacherToolsScreen> {
  int _tab = 0;
  bool _autoAdjusted = false;

  @override
  void initState() {
    super.initState();
    context.read<TeacherToolsBloc>().add(LoadTeacherTools(widget.teacherId));
  }

  @override
  void didUpdateWidget(TeacherToolsScreen old) {
    super.didUpdateWidget(old);
    // Same screen, different teacher — a second sign-in on the same phone can
    // reuse this State, and `initState` only ever fires once.
    if (old.teacherId != widget.teacherId) {
      _autoAdjusted = false;
      context.read<TeacherToolsBloc>().add(LoadTeacherTools(widget.teacherId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocListener<TeacherToolsBloc, TeacherToolsState>(
          listener: (context, state) {
            // Non-class-teachers would otherwise land on the "My class" empty
            // state by default — send them to "Teaching" instead, once.
            if (!_autoAdjusted && state is TeacherToolsLoaded) {
              _autoAdjusted = true;
              if (state.myClassroom == null && _tab == 0) setState(() => _tab = 1);
            }
          },
          child: Column(
          children: [
            SoftPageHeader(
              title: 'Classes',
              subtitle: 'Homework, teaching and classroom',
              actions: [
                SoftIconButton(
                  icon: Icons.swap_horiz_rounded,
                  tooltip: 'Cover requests',
                  elevated: false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CoverRequestsScreen(teacherId: widget.teacherId),
                      ),
                    );
                  },
                ),
                SoftIconButton(
                  icon: Icons.event_busy_outlined,
                  tooltip: 'Apply for leave',
                  elevated: false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TeacherLeaveScreen(teacherId: widget.teacherId),
                      ),
                    );
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: SoftSegmentedControl(
                labels: const ['My class', 'Teaching', 'Homework'],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            Expanded(
              child: FadeTabStack(
                index: _tab,
                children: [
                  MyClassroomScreen(teacherId: widget.teacherId),
                  _ClassesTab(teacherId: widget.teacherId),
                  _HomeworkTab(teacherId: widget.teacherId),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _HomeworkTab extends StatelessWidget {
  final String teacherId;
  const _HomeworkTab({required this.teacherId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TeacherToolsBloc, TeacherToolsState>(
      builder: (context, state) {
        if (state is TeacherToolsError) {
          return Center(child: Text(state.message, style: const TextStyle(color: AppColors.error)));
        }
        // Still the previous teacher's state until the reload lands.
        if (state is! TeacherToolsLoaded || state.teacherId != teacherId) {
          return const Center(child: CircularProgressIndicator());
        }
        return HomeworkBoardScreen(
          teacherId: teacherId,
          classrooms: state.taughtClassrooms,
          subjectsByClassroom: state.subjectsByClassroom,
          assignedCount: state.homework.length,
        );
      },
    );
  }
}

class _ClassesTab extends StatelessWidget {
  final String teacherId;
  const _ClassesTab({required this.teacherId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TeacherToolsBloc, TeacherToolsState>(
      builder: (context, state) {
        if (state is TeacherToolsError) {
          return Center(child: Text(state.message, style: const TextStyle(color: AppColors.error)));
        }
        // Still the previous teacher's state until the reload lands.
        if (state is! TeacherToolsLoaded || state.teacherId != teacherId) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.taughtClassrooms.isEmpty) {
          return const EmptyState(
            icon: Icons.class_outlined,
            title: 'No classes assigned',
            subtitle: 'You will see classrooms once the admin places you on a timetable.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          itemCount: state.taughtClassrooms.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final classroom = state.taughtClassrooms[index];
            final scope = state.scopeFor(classroom);
            return _TaughtClassCard(
              teacherId: teacherId,
              classroom: classroom,
              scope: scope,
              onOpen: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<TeacherToolsBloc>(),
                    child: ClassWorkspaceScreen(
                      teacherId: teacherId,
                      classroom: classroom,
                      scope: scope,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// One class this teacher takes. The old card was a bare row whose subtitle
/// happened to mention marks — teachers read it as a label, not a way in.
/// Each thing they can do here is now its own labelled button.
class _TaughtClassCard extends StatelessWidget {
  final String teacherId;
  final Classroom classroom;
  final TeachingScope scope;
  final VoidCallback onOpen;

  const _TaughtClassCard({
    required this.teacherId,
    required this.classroom,
    required this.scope,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final subjects = scope.subjects;
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.class_outlined, color: AppColors.classroomCard, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(classroom.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                      subjects.isEmpty
                          ? 'Your homeroom'
                          : 'You teach ${subjects.join(', ')}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (scope.isClassTeacher)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AdminLook.gold.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('CLASS TEACHER',
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: AdminLook.gold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ClassAction(
                  icon: Icons.grading_rounded,
                  label: scope.canEnterMarks ? 'Marks' : 'Marks · n/a',
                  color: AppColors.accent,
                  onTap: scope.canEnterMarks
                      ? () => MarksBoardScreen.open(
                            context,
                            teacherId: teacherId,
                            classroom: classroom,
                            scope: scope,
                          )
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ClassAction(
                  icon: Icons.groups_outlined,
                  label: 'Students',
                  color: AppColors.classroomCard,
                  onTap: onOpen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ClassAction(
                  icon: Icons.star_rounded,
                  label: 'Stars',
                  color: AdminLook.gold,
                  onTap: () => ClassProgressScreen.open(
                    context,
                    classroom: classroom,
                    teacherId: teacherId,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClassAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ClassAction({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final tint = enabled ? color : AppColors.onSurfaceHint(context);
    return Material(
      color: tint.withValues(alpha: enabled ? 0.12 : 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: tint),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: tint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
