import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'classroom_bloc.dart';
import 'classroom_navigation.dart';
import 'classroom_detail_screen.dart';

class GradeSectionsScreen extends StatefulWidget {
  final String gradeKey;

  const GradeSectionsScreen({super.key, required this.gradeKey});

  @override
  State<GradeSectionsScreen> createState() => _GradeSectionsScreenState();
}

class _GradeSectionsScreenState extends State<GradeSectionsScreen> {
  ClassroomsLoaded? _cached;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(GradeCatalog.label(widget.gradeKey))),
      body: SafeArea(
        child: BlocBuilder<ClassroomBloc, ClassroomState>(
        builder: (context, state) {
          if (state is ClassroomsLoaded) _cached = state;
          final loaded = state is ClassroomsLoaded ? state : _cached;
          if (loaded == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final rooms = loaded.classrooms
              .where((c) => c.resolvedGradeKey == widget.gradeKey)
              .toList()
            ..sort((a, b) => a.resolvedSection.compareTo(b.resolvedSection));
          if (rooms.isEmpty) {
            return EmptyState(
              icon: Icons.layers_outlined,
              title: 'No sections yet',
              subtitle: 'Create a section for ${GradeCatalog.label(widget.gradeKey)}',
              actionLabel: 'Add section',
              onAction: () => openClassroomForm(context, initialGradeKey: widget.gradeKey),
            );
          }
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 88),
            itemCount: rooms.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Text(
                    'Choose a section to open that classroom.',
                    style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13),
                  ),
                );
              }
              final classroom = rooms[index - 1];
              final teacher = loaded.teachers[classroom.classTeacherId];
              final count = loaded.studentCounts[classroom.id] ?? 0;
              return AnimatedListItem(
                index: index,
                child: _SectionCard(
                  classroom: classroom,
                  teacherName: teacher?.name ?? 'No class teacher',
                  studentCount: count,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: context.read<ClassroomBloc>(),
                          child: ClassroomDetailScreen(classroomId: classroom.id),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openClassroomForm(context, initialGradeKey: widget.gradeKey),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Classroom classroom;
  final String teacherName;
  final int studentCount;
  final VoidCallback onTap;

  const _SectionCard({
    required this.classroom,
    required this.teacherName,
    required this.studentCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.classroomCard.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    classroom.resolvedSection.isEmpty ? '—' : classroom.resolvedSection,
                    style: const TextStyle(
                      color: AppColors.classroomCard,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classroom.displayName,
                      style: TextStyle(
                        color: AppColors.onSurface(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      teacherName,
                      style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '$studentCount students · ₹${classroom.baseFees.toStringAsFixed(0)} / year',
                      style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceHint(context)),
            ],
          ),
        ),
      ),
    );
  }
}
