import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:go_router/go_router.dart';
import 'classroom_bloc.dart';
import 'classroom_navigation.dart';

class ClassroomDetailScreen extends StatefulWidget {
  final String classroomId;

  const ClassroomDetailScreen({super.key, required this.classroomId});

  @override
  State<ClassroomDetailScreen> createState() => _ClassroomDetailScreenState();
}

class _ClassroomDetailScreenState extends State<ClassroomDetailScreen> {
  ClassroomsLoaded? _cached;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ClassroomBloc, ClassroomState>(
      listener: (context, state) {
        if (state is ClassroomsLoaded &&
            state.classrooms.every((c) => c.id != widget.classroomId)) {
          Navigator.pop(context);
        }
      },
      builder: (context, state) {
        if (state is ClassroomsLoaded) _cached = state;
        final loaded = state is ClassroomsLoaded ? state : _cached;
        if (loaded == null) {
          if (state is ClassroomError) {
            return Scaffold(
              body: EmptyState(
                icon: Icons.cloud_off_rounded,
                title: "Couldn't load this classroom",
                subtitle: 'Check your connection and try again.',
                actionLabel: 'Retry',
                onAction: () => context.read<ClassroomBloc>().add(LoadClassrooms()),
              ),
            );
          }
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        Classroom? classroom;
        for (final room in loaded.classrooms) {
          if (room.id == widget.classroomId) classroom = room;
        }
        if (classroom == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final teacher = loaded.teachers[classroom.classTeacherId];
        final count = loaded.studentCounts[classroom.id] ?? 0;
        return Scaffold(
          appBar: AppBar(title: Text(classroom.displayName)),
          body: SafeArea(
            child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(20),
      child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.classroomCard.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.class_rounded, color: AppColors.classroomCard),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                classroom.displayName,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              StatusPill(
                                label: classroom.hasSectionLabel ? 'Section ${classroom.resolvedSection}' : 'No sections',
                                color: classroom.hasSectionLabel ? AppColors.accent : AppColors.success,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _MetaRow(label: 'Class teacher', value: teacher?.name ?? 'Not assigned'),
                    _MetaRow(label: 'Students', value: '$count'),
                    _MetaRow(label: 'Annual fees', value: '₹${classroom.baseFees.toStringAsFixed(0)}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _ActionTile(
                icon: Icons.calendar_month_rounded,
                color: AppColors.accent,
                title: 'Timetable',
                subtitle: 'Periods and weekly plan',
                onTap: () => context.go('/admin/timetable/${classroom!.id}'),
              ),
              _ActionTile(
                icon: Icons.groups_rounded,
                color: AppColors.success,
                title: 'Manage students',
                subtitle: 'Add or remove students from this class',
                onTap: () => openClassroomRoster(context, classroom!.id),
              ),
              _ActionTile(
                icon: Icons.published_with_changes_rounded,
                color: AdminLook.gold,
                title: teacher == null ? 'Assign a class teacher' : 'Change class teacher',
                subtitle: teacher == null
                    ? 'This class has nobody taking roll call'
                    : 'Hand this class to another teacher',
                onTap: () => _changeClassTeacher(context, classroom!, teacher),
              ),
              _ActionTile(
                icon: Icons.edit_rounded,
                color: AppColors.warning,
                title: 'Edit classroom',
                subtitle: 'Grade, section and fees',
                onTap: () => openClassroomForm(context, classroomId: classroom!.id),
              ),
              _ActionTile(
                icon: Icons.delete_rounded,
                color: AppColors.error,
                title: 'Delete classroom',
                subtitle: 'Students will be unassigned',
                onTap: () => _confirmDelete(context, classroom!),
              ),
            ],
            ),
          ),
        );
      },
    );
  }

  /// A class teacher leaving mid-year does not mean the class goes with
  /// them. Everything the class owns — students, marks, attendance, progress
  /// — hangs off the classroom, so the successor inherits it by being named.
  /// The only thing that needs deciding is the timetable, because periods
  /// name a person.
  Future<void> _changeClassTeacher(
    BuildContext context,
    Classroom classroom,
    Teacher? outgoing,
  ) async {
    final classrooms = context.read<ClassroomRepository>();
    final teacherRepo = context.read<TeacherRepository>();
    final timetables = context.read<TimetableRepository>();
    final bloc = context.read<ClassroomBloc>();
    final messenger = ScaffoldMessenger.of(context);

    List<Teacher> staff;
    List<Classroom> allRooms;
    HandoverImpact impact;
    try {
      final (fetchedStaff, fetchedRooms) = await (teacherRepo.getAll(), classrooms.getAll()).wait;
      staff = fetchedStaff.where((t) => t.isTeaching && t.id != outgoing?.id).toList();
      allRooms = fetchedRooms;
      impact = outgoing == null
          ? const HandoverImpact()
          : await StaffHandover.impactOf(
              outgoing.id,
              classrooms: classrooms,
              timetables: timetables,
            );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text("Couldn't load staff — check your connection and try again."),
      ));
      return;
    }
    if (!context.mounted) return;

    // One teacher runs one homeroom, so anyone already holding another class
    // is shown with that class named rather than silently offered.
    final unavailable = {
      for (final room in allRooms)
        if (room.id != classroom.id && room.classTeacherId.isNotEmpty)
          room.classTeacherId: TeacherUnavailable(
            'Class teacher of ${room.displayName}',
            detail: 'Free them from that class first, or pick someone else',
          ),
    };

    final choice = await showClassHandoverSheet(
      context: context,
      className: classroom.displayName,
      candidates: staff,
      outgoing: outgoing,
      periodsInClass: impact.periodsIn(classroom.id),
      unavailable: unavailable,
      allowNoTeacher: outgoing != null,
      clashesFor: outgoing == null
          ? null
          : (candidate) async {
              final clashes = await StaffHandover.clashesForTakeover(
                timetables: timetables,
                classrooms: classrooms,
                fromTeacherId: outgoing.id,
                toTeacherId: candidate.id,
                onlyClassroomIds: {classroom.id},
              );
              return [for (final (incoming, _) in clashes) incoming];
            },
    );
    if (choice == null) return;

    try {
      await StaffHandover.setClassTeacher(
        classroom,
        choice.newClassTeacher?.id,
        classrooms: classrooms,
        teachers: teacherRepo,
      );
      var moved = 0;
      if (choice.movePeriods && outgoing != null) {
        moved = await StaffHandover.reassignPeriods(
          timetables: timetables,
          fromTeacherId: outgoing.id,
          toTeacherId: choice.newClassTeacher?.id,
          onlyClassroomIds: {classroom.id},
        );
      }
      bloc.add(LoadClassrooms());
      messenger.showSnackBar(SnackBar(
        content: Text(_handoverMessage(classroom, choice.newClassTeacher, moved)),
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text("Couldn't hand over the class — check your connection and try again."),
      ));
    }
  }

  String _handoverMessage(Classroom classroom, Teacher? incoming, int movedPeriods) {
    if (incoming == null) {
      return '${classroom.displayName} has no class teacher. Assign one before roll call.';
    }
    final base = '${incoming.name} now runs ${classroom.displayName} '
        'with all its students, marks and progress';
    if (movedPeriods == 0) return '$base.';
    return '$base, plus $movedPeriods ${movedPeriods == 1 ? 'period' : 'periods'}.';
  }

  void _confirmDelete(BuildContext context, Classroom classroom) {
    showDialog(
      context: context,
      builder: (_) => VerificationDialog(
        title: 'Delete Classroom',
        content:
            'This will permanently remove "${classroom.displayName}" and all associated data. This action cannot be undone.',
        onConfirm: () {
          context.read<ClassroomBloc>().add(DeleteClassroom(classroom.id));
        },
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: AppColors.onSurface(context), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.onSurface(context))),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.onSurfaceHint(context))),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceHint(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
