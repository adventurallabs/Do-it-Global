import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:go_router/go_router.dart';
import 'fee_bloc.dart';
import 'fee_classroom_screen.dart';
import 'fee_sections_screen.dart';

class FeeDashboard extends StatefulWidget {
  const FeeDashboard({super.key});

  @override
  State<FeeDashboard> createState() => _FeeDashboardState();
}

class _FeeDashboardState extends State<FeeDashboard> {
  @override
  void initState() {
    super.initState();
    context.read<FeeBloc>().add(LoadFees());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fee management'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<FeeBloc, FeeState>(
        builder: (context, state) {
          if (state is FeeLoading || state is FeeInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is FeeError) {
            return Center(child: Text(state.message, style: const TextStyle(color: AppColors.error)));
          }
          if (state is FeesLoaded) {
            final groups = GradeCatalog.group(state.classrooms);
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: groups.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                    child: Text(
                      'Open a class to review student fee status. Classes with sections open first into their sections.',
                      style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13, height: 1.4),
                    ),
                  );
                }
                final group = groups[index - 1];
                final students = group.classrooms
                    .expand((room) => state.studentsIn(room.id))
                    .toList();
                final paid = students.where((s) => state.ledgerFor(s.id).status == FeeStatus.fullyPaid).length;
                final subtitle = !group.exists
                    ? 'No classroom yet'
                    : group.hasSections
                        ? '${group.classrooms.length} sections · $paid/${students.length} fully paid'
                        : '$paid/${students.length} fully paid';
                return AnimatedListItem(
                  index: index,
                  child: GradeOverviewCard(
                    title: group.title,
                    subtitle: subtitle,
                    exists: group.exists,
                    hasSections: group.hasSections,
                    onTap: () {
                      if (!group.exists) return;
                      if (group.hasSections) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: context.read<FeeBloc>(),
                              child: FeeSectionsScreen(gradeKey: group.gradeKey),
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
                            value: context.read<FeeBloc>(),
                            child: FeeClassroomScreen(classroomId: classroom.id),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          }
          return const SizedBox();
        },
        ),
      ),
    );
  }
}
