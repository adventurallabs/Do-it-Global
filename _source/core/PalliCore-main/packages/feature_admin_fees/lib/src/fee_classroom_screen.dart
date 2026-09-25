import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'fee_bloc.dart';
import 'fee_status_style.dart';
import 'student_fee_detail_screen.dart';

class FeeClassroomScreen extends StatelessWidget {
  final String classroomId;

  const FeeClassroomScreen({super.key, required this.classroomId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FeeBloc, FeeState>(
      builder: (context, state) {
        if (state is FeeError) {
          return Scaffold(
            body: EmptyState(
              icon: Icons.cloud_off_rounded,
              title: "Couldn't load fees",
              subtitle: 'Check your connection and try again.',
              actionLabel: 'Retry',
              onAction: () => context.read<FeeBloc>().add(LoadFees()),
            ),
          );
        }
        if (state is! FeesLoaded) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final classroom = state.classroomById(classroomId);
        if (classroom == null) {
          return const Scaffold(body: Center(child: Text('Classroom not found')));
        }
        final students = state.studentsIn(classroomId);
        return Scaffold(
          appBar: AppBar(title: Text('${classroom.displayName} fees')),
          body: SafeArea(
            child: students.isEmpty
              ? const EmptyState(
                  icon: Icons.payments_outlined,
                  title: 'No students',
                  subtitle: 'Assign students to this classroom to track fees',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: students.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                        child: Text(
                          classroom.hasSectionLabel
                              ? 'Section ${classroom.resolvedSection} · tap a student for the full ledger'
                              : 'No sections · tap a student for the full ledger',
                          style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13),
                        ),
                      );
                    }
                    final student = students[index - 1];
                    final ledger = state.ledgerFor(student.id);
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
                                  child: StudentFeeDetailScreen(studentId: student.id),
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(16),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: feeStatusColor(ledger.status).withValues(alpha: 0.15),
                                  child: Text(
                                    student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      color: feeStatusColor(ledger.status),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        student.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.onSurface(context),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Roll ${student.rollNumber} · Paid ₹${ledger.totalPaid.toStringAsFixed(0)} of ₹${ledger.totalDue.toStringAsFixed(0)}',
                                        style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                StatusPill(
                                  label: ledger.statusLabel,
                                  color: feeStatusColor(ledger.status),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
          ),
        );
      },
    );
  }
}
