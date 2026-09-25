import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import 'directory_bloc.dart';
import 'person_documents_section.dart';
import 'teacher_form_screen.dart';

/// How complete a staff file is, and the papers on it.
///
/// Everything here is the office's to fill in — a teacher does not chase
/// their own record — so the card says "still needed" rather than asking.
class TeacherFileSection extends StatefulWidget {
  final Teacher teacher;
  const TeacherFileSection({super.key, required this.teacher});

  @override
  State<TeacherFileSection> createState() => _TeacherFileSectionState();
}

class _TeacherFileSectionState extends State<TeacherFileSection> {
  int _documentCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final docs = await context.read<PersonMediaRepository>().documents(
            ownerType: DocumentOwner.teacher,
            ownerId: widget.teacher.id,
          );
      if (mounted) {
        setState(() {
          _documentCount = docs.length;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _edit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<DirectoryBloc>(),
          child: TeacherFormScreen(teacher: widget.teacher),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    final gaps = TeacherProfileGaps.of(widget.teacher, documentCount: _documentCount);
    final mute = AppColors.onSurfaceMuted(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileGapsCard(
          gaps: gaps.gaps,
          completeMessage: 'This staff file is complete.',
          onAction: gaps.isComplete ? null : _edit,
        ),
        const SizedBox(height: 14),
        Text('DOCUMENTS',
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: mute)),
        const SizedBox(height: 10),
        PersonDocumentsSection(
          ownerType: DocumentOwner.teacher,
          ownerId: widget.teacher.id,
          kinds: DocumentKind.forTeachers,
          onChanged: _load,
        ),
      ],
    );
  }
}
