import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_models/core_models.dart';
import 'classroom_bloc.dart';
import 'classroom_detail_screen.dart';
import 'grade_sections_screen.dart';
import 'classroom_navigation.dart';
import 'package:go_router/go_router.dart';

class ClassroomDashboard extends StatefulWidget {
  const ClassroomDashboard({super.key});

  @override
  State<ClassroomDashboard> createState() => _ClassroomDashboardState();
}

class _ClassroomDashboardState extends State<ClassroomDashboard> {
  ClassroomsLoaded? _cached;

  @override
  void initState() {
    super.initState();
    context.read<ClassroomBloc>().add(LoadClassrooms());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Classes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<ClassroomBloc, ClassroomState>(
        builder: (context, state) {
          if (state is ClassroomsLoaded) {
            _cached = state;
          }
          final loaded = state is ClassroomsLoaded ? state : _cached;
          if (state is ClassroomLoading && loaded == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (loaded != null && state is! ClassroomError) {
            final groups = GradeCatalog.group(loaded.classrooms);
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              addAutomaticKeepAlives: false,
              itemCount: groups.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: EdgeInsets.fromLTRB(4, 0, 4, 16),
                    child: Text(
                      'Organised from LKG to 12th. Open a class to see its sections, or go straight in when there are none.',
                      style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13, height: 1.4),
                    ),
                  );
                }
                final group = groups[index - 1];
                final studentCount = group.classrooms.fold<int>(
                  0,
                  (sum, room) => sum + (loaded.studentCounts[room.id] ?? 0),
                );
                final subtitle = !group.exists
                    ? 'Tap to create this class'
                    : group.hasSections
                        ? '${group.classrooms.length} sections · $studentCount students'
                        : '$studentCount students · Tap to open';
                return AnimatedListItem(
                  index: index,
                  child: GradeOverviewCard(
                    title: group.title,
                    subtitle: subtitle,
                    exists: group.exists,
                    hasSections: group.hasSections,
                    onTap: () => _openGroup(context, group),
                  ),
                );
              },
            );
          }
          if (state is ClassroomError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: AppColors.error, size: 48),
                  SizedBox(height: 12),
                  Text(state.message, style: TextStyle(color: AppColors.onSurfaceMuted(context))),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<ClassroomBloc>().add(LoadClassrooms()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          return const SizedBox();
        },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openClassroomForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openGroup(BuildContext context, ClassroomGradeGroup group) {
    if (!group.exists) {
      openClassroomForm(context, initialGradeKey: group.gradeKey);
      return;
    }
    if (group.hasSections) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: context.read<ClassroomBloc>(),
            child: GradeSectionsScreen(gradeKey: group.gradeKey),
          ),
        ),
      );
      return;
    }
    final classroom = group.singleClassroom;
    if (classroom == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<ClassroomBloc>(),
          child: ClassroomDetailScreen(classroomId: classroom.id),
        ),
      ),
    );
  }
}
