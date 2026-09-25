import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart';
import 'classroom_bloc.dart';

class ClassroomForm extends StatefulWidget {
  final String? classroomId;
  final String? initialGradeKey;
  const ClassroomForm({super.key, this.classroomId, this.initialGradeKey});

  @override
  State<ClassroomForm> createState() => _ClassroomFormState();
}

class _ClassroomFormState extends State<ClassroomForm> {
  final _feesController = TextEditingController(text: '0');
  String? _selectedTeacherId;
  String _selectedGradeKey = '1';
  String _selectedSection = '';
  List<Teacher> _teachers = [];
  /// Every classroom except the one being edited — used to keep one teacher
  /// from being class teacher of two classes at once.
  List<Classroom> _otherClassrooms = const [];
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.classroomId != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialGradeKey != null && widget.initialGradeKey!.isNotEmpty) {
      _selectedGradeKey = widget.initialGradeKey!;
    }
    context.read<ClassroomBloc>().add(LoadClassroomFormDependencies(classroomId: widget.classroomId));
    _loadOtherClassrooms();
  }

  Future<void> _loadOtherClassrooms() async {
    try {
      final rooms = await context.read<ClassroomRepository>().getAll();
      if (!mounted) return;
      setState(() => _otherClassrooms = rooms.where((c) => c.id != widget.classroomId).toList());
    } catch (_) {
      // Offline: the picker just can't dim anyone; the save check still runs.
    }
  }

  @override
  void dispose() {
    _feesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Classroom' : 'Create Classroom'),
      ),
      body: SafeArea(
        child: BlocConsumer<ClassroomBloc, ClassroomState>(
        listener: (context, state) {
          if (state is ClassroomFormDependenciesLoaded) {
            _teachers = state.teachers.where((t) => t.isTeaching).toList();
            if (state.classroom != null) {
              final room = state.classroom!;
              _feesController.text = room.baseFees.toStringAsFixed(0);
              _selectedTeacherId = room.classTeacherId;
              _selectedGradeKey = room.resolvedGradeKey;
              _selectedSection = room.resolvedSection;
            }
            setState(() {});
          }
          if (state is ClassroomsLoaded && _saving) {
            _saving = false;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_isEditing ? 'Classroom updated' : 'Classroom created')),
            );
          }
          if (state is ClassroomError) {
            setState(() {
              _saving = false;
              _error = state.message;
            });
          }
        },
        builder: (context, state) {
          if (state is ClassroomLoading || (state is ClassroomInitial && _teachers.isEmpty)) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_teachers.isEmpty && state is! ClassroomFormDependenciesLoaded && state is! ClassroomsLoaded) {
            if (state is ClassroomError) {
              return Center(child: Text(state.message, style: const TextStyle(color: AppColors.error)));
            }
            return const Center(child: CircularProgressIndicator());
          }
          return _buildForm();
        },
        ),
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionHeader(title: 'Classroom Details', icon: Icons.class_rounded),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: GradeCatalog.orderedKeys.contains(_selectedGradeKey) ? _selectedGradeKey : '1',
          isExpanded: true,
          items: GradeCatalog.orderedKeys
              .map((key) => DropdownMenuItem(value: key, child: Text(GradeCatalog.label(key))))
              .toList(),
          onChanged: (val) {
            if (val == null) return;
            setState(() => _selectedGradeKey = val);
          },
          decoration: const InputDecoration(
            labelText: 'Class',
            prefixIcon: Icon(Icons.school_outlined),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _selectedSection,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: '', child: Text('No section')),
            DropdownMenuItem(value: 'A', child: Text('Section A')),
            DropdownMenuItem(value: 'B', child: Text('Section B')),
            DropdownMenuItem(value: 'C', child: Text('Section C')),
            DropdownMenuItem(value: 'D', child: Text('Section D')),
            DropdownMenuItem(value: 'E', child: Text('Section E')),
            DropdownMenuItem(value: 'F', child: Text('Section F')),
            DropdownMenuItem(value: 'G', child: Text('Section G')),
          ],
          onChanged: (val) => setState(() => _selectedSection = val ?? ''),
          decoration: const InputDecoration(
            labelText: 'Section (optional)',
            prefixIcon: Icon(Icons.layers_outlined),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Will appear as ${GradeCatalog.composeName(_selectedGradeKey, _selectedSection)}',
          style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 12),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _feesController,
          decoration: const InputDecoration(
            labelText: 'Base Fees (₹)',
            hintText: 'Optional — default 0',
            prefixIcon: Icon(Icons.currency_rupee),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 24),
        _SectionHeader(title: 'Class Teacher', icon: Icons.person_rounded),
        const SizedBox(height: 4),
        Text(
          'Required. Students can be added later by you or the class teacher.',
          style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13),
        ),
        const SizedBox(height: 12),
        _classTeacherField(),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.error)),
        ],
        const SizedBox(height: 28),
        Container(
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ElevatedButton(
            onPressed: _saving ? null : _onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              _saving
                  ? 'Saving…'
                  : (_isEditing ? 'Update Classroom' : 'Create Classroom'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  /// A class teacher runs one homeroom — roll call, the daily diary and the
  /// parent's "my child's teacher" all assume exactly one. Teachers who
  /// already hold another classroom are shown with that classroom named, but
  /// can't be picked twice.
  Map<String, TeacherUnavailable> _alreadyClassTeacher() {
    return {
      for (final room in _otherClassrooms)
        if (room.classTeacherId.isNotEmpty && room.classTeacherId != _selectedTeacherId)
          room.classTeacherId: TeacherUnavailable(
            'Class teacher of ${room.displayName}',
            detail: 'Free them from that class first, or pick someone else',
          ),
    };
  }

  Widget _classTeacherField() {
    final selected = _selectedTeacherId == null
        ? null
        : _teachers.where((t) => t.id == _selectedTeacherId).firstOrNull;
    return InkWell(
      onTap: () async {
        final picked = await showTeacherPicker(
          context: context,
          teachers: _teachers,
          title: 'Choose class teacher',
          subtitle: 'Takes roll call and the daily diary for this class',
          unavailable: _alreadyClassTeacher(),
          selectedId: _selectedTeacherId,
        );
        if (picked != null) setState(() => _selectedTeacherId = picked.id);
      },
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Class teacher',
          prefixIcon: Icon(Icons.person_rounded),
        ),
        child: selected == null
            ? Text('Tap to choose', style: TextStyle(color: AppColors.onSurfaceHint(context)))
            : Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.accentAlt.withValues(alpha: 0.15),
                    child: Text(
                      selected.name.isNotEmpty ? selected.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.accentAlt, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(selected.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (selected.subjects.isNotEmpty)
                          Text(
                            selected.subjects.join(', '),
                            style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _onSave() {
    final teacherId = _selectedTeacherId;
    if (teacherId == null || teacherId.isEmpty) {
      setState(() => _error = 'Please select a class teacher.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a class teacher')),
      );
      return;
    }
    final heldElsewhere = _otherClassrooms.where((c) => c.classTeacherId == teacherId).firstOrNull;
    if (heldElsewhere != null) {
      final name = _teachers.where((t) => t.id == teacherId).firstOrNull?.name ?? 'That teacher';
      setState(() => _error =
          '$name is already the class teacher of ${heldElsewhere.displayName}. '
          'One teacher can only run one homeroom — pick someone else.');
      return;
    }
    final fees = double.tryParse(_feesController.text.trim()) ?? 0;
    setState(() {
      _saving = true;
      _error = null;
    });
    final classroom = Classroom(
      id: widget.classroomId ?? 'c_${DateTime.now().millisecondsSinceEpoch}',
      name: GradeCatalog.composeName(_selectedGradeKey, _selectedSection),
      classTeacherId: teacherId,
      baseFees: fees,
      gradeKey: _selectedGradeKey,
      section: _selectedSection.trim().toUpperCase(),
    );
    if (_isEditing) {
      // Details only — roster is managed separately so students are not wiped.
      context.read<ClassroomBloc>().add(UpdateClassroom(classroom, const []));
    } else {
      context.read<ClassroomBloc>().add(CreateClassroom(classroom, const []));
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: AppColors.onSurface(context),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
