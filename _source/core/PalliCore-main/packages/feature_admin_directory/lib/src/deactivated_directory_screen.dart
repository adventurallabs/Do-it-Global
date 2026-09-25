import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart';
import 'directory_bloc.dart';
import 'student_detail_screen.dart';
import 'teacher_detail_screen.dart';

/// Deactivated teachers/students — excluded from the normal directory and its
/// counts, but their history stays fully accessible here. From this screen an
/// admin can restore access (Reactivate) or purge the record entirely
/// (Delete Permanently — the login and every trace of it, irreversible).
class DeactivatedDirectoryScreen extends StatefulWidget {
  const DeactivatedDirectoryScreen({super.key});

  @override
  State<DeactivatedDirectoryScreen> createState() => _DeactivatedDirectoryScreenState();
}

class _DeactivatedDirectoryScreenState extends State<DeactivatedDirectoryScreen> {
  late Future<List<Student>> _students;
  late Future<List<Teacher>> _teachers;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _students = context.read<StudentRepository>().getInactive();
    _teachers = context.read<TeacherRepository>().getInactive();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await Future.wait([_students, _teachers]);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Deactivated'),
          bottom: const TabBar(tabs: [Tab(text: 'Students'), Tab(text: 'Staff')]),
        ),
        body: SafeArea(
          child: TabBarView(
          children: [
            _DeactivatedStudentList(future: _students, onChanged: _refresh),
            _DeactivatedTeacherList(future: _teachers, onChanged: _refresh),
          ],
          ),
        ),
      ),
    );
  }
}

class _DeactivatedStudentList extends StatelessWidget {
  final Future<List<Student>> future;
  final Future<void> Function() onChanged;
  const _DeactivatedStudentList({required this.future, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Student>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.cloud_off_rounded,
            title: "Couldn't load deactivated students",
            subtitle: 'Check your connection and try again.',
            actionLabel: 'Retry',
            onAction: onChanged,
          );
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final students = snapshot.data!;
        if (students.isEmpty) {
          return const EmptyState(
            icon: Icons.person_off_outlined,
            title: 'No deactivated students',
          );
        }
        return RefreshIndicator(
          onRefresh: onChanged,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              return _DeactivatedCard(
                name: student.name,
                subtitle: student.deactivatedAt != null
                    ? 'Deactivated ${_formatDate(student.deactivatedAt!)}'
                    : 'Deactivated',
                icon: Icons.person_rounded,
                color: AppColors.studentCard,
                onView: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StudentDetailScreen(student: student)),
                ),
                onReactivate: () async {
                  await context.read<StudentRepository>().setActive(student.id, true);
                  if (context.mounted) {
                    context.read<DirectoryBloc>().add(LoadDirectory());
                    await onChanged();
                  }
                },
                onDeleteForever: () => showDialog(
                  context: context,
                  builder: (_) => VerificationDialog(
                    title: 'Delete ${student.name} permanently',
                    content: 'This permanently erases the student record, their parent login, '
                        'attendance, marks, fees, messages — everything. This cannot be undone.',
                    confirmWord: 'PERMANENTLY DELETE',
                    actionLabel: 'Delete forever',
                    onConfirm: () async {
                      await context.read<StudentRepository>().deletePermanently(student.id);
                      await onChanged();
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _DeactivatedTeacherList extends StatelessWidget {
  final Future<List<Teacher>> future;
  final Future<void> Function() onChanged;
  const _DeactivatedTeacherList({required this.future, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Teacher>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.cloud_off_rounded,
            title: "Couldn't load deactivated staff",
            subtitle: 'Check your connection and try again.',
            actionLabel: 'Retry',
            onAction: onChanged,
          );
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final teachers = snapshot.data!;
        if (teachers.isEmpty) {
          return const EmptyState(
            icon: Icons.person_off_outlined,
            title: 'No deactivated staff',
          );
        }
        return RefreshIndicator(
          onRefresh: onChanged,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: teachers.length,
            itemBuilder: (context, index) {
              final teacher = teachers[index];
              return _DeactivatedCard(
                name: teacher.name,
                subtitle: teacher.deactivatedAt != null
                    ? 'Deactivated ${_formatDate(teacher.deactivatedAt!)}'
                    : 'Deactivated',
                icon: Icons.badge_rounded,
                color: AppColors.teacherCard,
                onView: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TeacherDetailScreen(teacher: teacher)),
                ),
                onReactivate: () async {
                  await context.read<TeacherRepository>().setActive(teacher.id, true);
                  if (context.mounted) {
                    context.read<DirectoryBloc>().add(LoadDirectory());
                    await onChanged();
                  }
                },
                onDeleteForever: () => showDialog(
                  context: context,
                  builder: (_) => VerificationDialog(
                    title: 'Delete ${teacher.name} permanently',
                    content: 'This permanently erases the staff record and their login. '
                        'This cannot be undone.',
                    confirmWord: 'PERMANENTLY DELETE',
                    actionLabel: 'Delete forever',
                    onConfirm: () async {
                      await context.read<TeacherRepository>().deletePermanently(teacher.id);
                      await onChanged();
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _DeactivatedCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onView;
  final Future<void> Function() onReactivate;
  final VoidCallback onDeleteForever;

  const _DeactivatedCard({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onView,
    required this.onReactivate,
    required this.onDeleteForever,
  });

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(16),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onView,
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(name, style: TextStyle(color: AppColors.onSurface(context), fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(subtitle, style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.settings_backup_restore_rounded, color: AppColors.success),
              tooltip: 'Reactivate',
              onPressed: onReactivate,
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
              tooltip: 'Delete permanently',
              onPressed: onDeleteForever,
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }
}

String _formatDate(DateTime dt) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}
