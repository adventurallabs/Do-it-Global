import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import 'directory_bloc.dart';
import 'person_documents_section.dart';
import 'student_form_screen.dart';

/// How complete a child's file is, what travel is arranged, and the papers
/// on record — the three things that used to be invisible until someone went
/// looking for them.
class StudentFileSection extends StatefulWidget {
  final Student student;
  const StudentFileSection({super.key, required this.student});

  @override
  State<StudentFileSection> createState() => _StudentFileSectionState();
}

class _StudentFileSectionState extends State<StudentFileSection> {
  StudentTransport? _transport;
  List<Bus> _buses = const [];
  int _documentCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final media = context.read<PersonMediaRepository>();
      final buses = context.read<BusRepository>();
      final transport = await media.transport(widget.student.id);
      if (!mounted) return;
      final docs = await media.documents(
        ownerType: DocumentOwner.student,
        ownerId: widget.student.id,
      );
      if (!mounted) return;
      final busList = await buses.getAll();
      if (!mounted) return;
      setState(() {
        _transport = transport;
        _documentCount = docs.length;
        _buses = busList;
        _loading = false;
      });
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
          child: StudentFormScreen(student: widget.student),
        ),
      ),
    );
  }

  String _busLabel(String? busId) {
    if (busId == null) return 'Not assigned';
    final bus = _buses.where((b) => b.id == busId).firstOrNull;
    return bus == null ? 'Not assigned' : 'Bus ${bus.busNumber}';
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

    final gaps = StudentProfileGaps.of(
      widget.student,
      hasTransportDetails: _transport?.isComplete ?? false,
      documentCount: _documentCount,
    );
    final mute = AppColors.onSurfaceMuted(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileGapsCard(
          gaps: gaps.gaps,
          completeMessage: 'This file is complete.',
          onAction: gaps.isComplete ? null : _edit,
          actionLabel: 'Fill these in',
        ),
        if (widget.student.needsTransport == true) ...[
          const SizedBox(height: 14),
          SoftSurface(
            depth: SoftDepth.one,
            borderRadius: BorderRadius.circular(18),
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.directions_bus_outlined,
                        size: 18, color: AppColors.accent),
                    const SizedBox(width: 9),
                    const Expanded(
                      child: Text('Travels by school bus',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                    ),
                    if (_transport?.isComplete != true)
                      const ProfileGapsBadge(count: 1),
                  ],
                ),
                const SizedBox(height: 8),
                _line('Bus', _busLabel(_transport?.busId), mute),
                _line('Pickup', _blankOr(_transport?.pickupLocation), mute),
                _line('Drop', _blankOr(_transport?.dropLocation), mute),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Text('DOCUMENTS',
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: mute)),
        const SizedBox(height: 10),
        PersonDocumentsSection(
          ownerType: DocumentOwner.student,
          ownerId: widget.student.id,
          kinds: DocumentKind.forStudents,
          onChanged: _load,
        ),
      ],
    );
  }

  static String _blankOr(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Not recorded' : value.trim();

  Widget _line(String label, String value, Color mute) {
    final missing = value == 'Not recorded' || value == 'Not assigned';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(label, style: TextStyle(fontSize: 12, color: mute)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: missing ? FontWeight.w500 : FontWeight.w700,
                fontStyle: missing ? FontStyle.italic : FontStyle.normal,
                color: missing ? AppColors.warning : AppColors.onSurface(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
