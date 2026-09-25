import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'fee_bloc.dart';
import 'fee_classroom_screen.dart';

class FeeSectionsScreen extends StatelessWidget {
  final String gradeKey;

  const FeeSectionsScreen({super.key, required this.gradeKey});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${GradeCatalog.label(gradeKey)} fees')),
      body: SafeArea(
        child: BlocBuilder<FeeBloc, FeeState>(
        builder: (context, state) {
          if (state is! FeesLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final rooms = state.classrooms
              .where((c) => c.resolvedGradeKey == gradeKey)
              .toList()
            ..sort((a, b) => a.resolvedSection.compareTo(b.resolvedSection));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final classroom = rooms[index];
              final students = state.studentsIn(classroom.id);
              final paid = students.where((s) => state.ledgerFor(s.id).status == FeeStatus.fullyPaid).length;
              return AnimatedListItem(
                index: index,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
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
                              color: AppColors.feeCard.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(
                                classroom.resolvedSection.isEmpty ? '—' : classroom.resolvedSection,
                                style: const TextStyle(
                                  color: AppColors.feeCard,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  classroom.displayName,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$paid/${students.length} fully paid',
                                  style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          StatusPill(
                            label: students.isEmpty ? 'No students' : _mixLabel(students, state),
                            color: _mixColor(context, students, state),
                          ),
                          Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceHint(context)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
        ),
      ),
    );
  }

  String _mixLabel(List<Student> students, FeesLoaded state) {
    if (students.every((s) => state.ledgerFor(s.id).status == FeeStatus.fullyPaid)) {
      return 'All paid';
    }
    if (students.every((s) => state.ledgerFor(s.id).status == FeeStatus.notPaid)) {
      return 'Unpaid';
    }
    return 'Mixed';
  }

  Color _mixColor(BuildContext context, List<Student> students, FeesLoaded state) {
    if (students.isEmpty) return AppColors.onSurfaceHint(context);
    if (students.every((s) => state.ledgerFor(s.id).status == FeeStatus.fullyPaid)) {
      return AppColors.success;
    }
    if (students.every((s) => state.ledgerFor(s.id).status == FeeStatus.notPaid)) {
      return AppColors.error;
    }
    return AppColors.warning;
  }
}
