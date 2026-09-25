import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'classroom_bloc.dart';
import 'classroom_form.dart';
import 'classroom_roster_screen.dart';

void openClassroomForm(
  BuildContext context, {
  String? classroomId,
  String? initialGradeKey,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: context.read<ClassroomBloc>(),
        child: ClassroomForm(
          classroomId: classroomId,
          initialGradeKey: initialGradeKey,
        ),
      ),
    ),
  ).then((_) {
    if (context.mounted) {
      context.read<ClassroomBloc>().add(LoadClassrooms());
    }
  });
}

void openClassroomRoster(BuildContext context, String classroomId) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: context.read<ClassroomBloc>(),
        child: ClassroomRosterScreen(classroomId: classroomId),
      ),
    ),
  ).then((_) {
    if (context.mounted) {
      context.read<ClassroomBloc>().add(LoadClassrooms());
    }
  });
}
