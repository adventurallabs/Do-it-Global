import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'event_bloc.dart';

class ComposeEventScreen extends StatefulWidget {
  const ComposeEventScreen({super.key});

  @override
  State<ComposeEventScreen> createState() => _ComposeEventScreenState();
}

class _ComposeEventScreenState extends State<ComposeEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _feeController = TextEditingController();
  DateTime? _eventDate;
  DateTime? _lastPayDate;
  bool _feeNeeded = false;
  bool _schoolWide = true;
  final Set<String> _selectedClassroomIds = {};
  final Set<String> _expandedGrades = {};

  @override
  void initState() {
    super.initState();
    context.read<SchoolEventBloc>().add(LoadEventComposer());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compose event')),
      body: SafeArea(
        child: BlocConsumer<SchoolEventBloc, SchoolEventState>(
        listener: (context, state) {
          if (state is SchoolEventOrganized) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Event organised. ${state.familiesNotified} families were notified.',
                ),
              ),
            );
            Navigator.pop(context);
          }
          if (state is SchoolEventError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
            );
          }
        },
        builder: (context, state) {
          if (state is SchoolEventLoading || state is SchoolEventInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is EventComposerLoaded) {
            return _buildForm(state.classrooms);
          }
          return const Center(child: CircularProgressIndicator());
        },
        ),
      ),
    );
  }

  Widget _buildForm(List<Classroom> classrooms) {
    final groups = GradeCatalog.group(classrooms, includeEmpty: false);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          _header('Event details', Icons.event_note_rounded),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Event name',
              prefixIcon: Icon(Icons.title_rounded),
            ),
            validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _descriptionController,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Description',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_rounded),
            ),
            validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 14),
          _DateField(
            label: 'Event date',
            value: _eventDate,
            onTap: () => _pickDate(isPayDate: false),
          ),
          const SizedBox(height: 24),
          _header('Fee', Icons.currency_rupee_rounded),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fee payment needed', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Parents will be asked to pay a per-student amount'),
            value: _feeNeeded,
            activeThumbColor: AppColors.accent,
            onChanged: (val) => setState(() => _feeNeeded = val),
          ),
          if (_feeNeeded) ...[
            TextFormField(
              controller: _feeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Fee to be paid by individual (₹)',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              validator: (val) {
                if (!_feeNeeded) return null;
                final amount = double.tryParse(val ?? '');
                if (amount == null || amount <= 0) return 'Enter a valid fee';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _DateField(
              label: 'Last date to pay the fee',
              value: _lastPayDate,
              onTap: () => _pickDate(isPayDate: true),
            ),
          ],
          const SizedBox(height: 24),
          _header('Audience', Icons.groups_rounded),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Whole school'), icon: Icon(Icons.apartment_rounded)),
              ButtonSegment(value: false, label: Text('Classrooms'), icon: Icon(Icons.class_rounded)),
            ],
            selected: {_schoolWide},
            onSelectionChanged: (value) => setState(() => _schoolWide = value.first),
          ),
          if (!_schoolWide) ...[
            const SizedBox(height: 16),
            Text(
              '${_selectedClassroomIds.length} classroom(s) selected',
              style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13),
            ),
            const SizedBox(height: 8),
            ...groups.map((group) => _gradePicker(group)),
          ],
          const SizedBox(height: 28),
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: () => _submit(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Organise event',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 20),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface(context))),
      ],
    );
  }

  Widget _gradePicker(ClassroomGradeGroup group) {
    final allSelected = group.classrooms.every((c) => _selectedClassroomIds.contains(c.id));
    final expanded = _expandedGrades.contains(group.gradeKey);
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(16),
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          ListTile(
            title: Text(group.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              group.hasSections ? '${group.classrooms.length} sections' : 'No sections',
              style: const TextStyle(fontSize: 12),
            ),
            leading: Checkbox(
              value: allSelected,
              activeColor: AppColors.accent,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedClassroomIds.addAll(group.classrooms.map((c) => c.id));
                  } else {
                    _selectedClassroomIds.removeAll(group.classrooms.map((c) => c.id));
                  }
                });
              },
            ),
            trailing: group.hasSections
                ? IconButton(
                    icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                    onPressed: () {
                      setState(() {
                        if (expanded) {
                          _expandedGrades.remove(group.gradeKey);
                        } else {
                          _expandedGrades.add(group.gradeKey);
                        }
                      });
                    },
                  )
                : null,
          ),
          if (group.hasSections && expanded)
            ...group.classrooms.map((classroom) {
              final selected = _selectedClassroomIds.contains(classroom.id);
              return CheckboxListTile(
                dense: true,
                value: selected,
                activeColor: AppColors.accent,
                title: Text(classroom.displayName),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedClassroomIds.add(classroom.id);
                    } else {
                      _selectedClassroomIds.remove(classroom.id);
                    }
                  });
                },
              );
            }),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool isPayDate}) async {
    final now = DateTime.now();
    final initial = isPayDate ? (_lastPayDate ?? _eventDate ?? now) : (_eventDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      locale: const Locale('en', 'IN'),
      fieldHintText: 'dd/mm/yyyy',
      errorFormatText: 'Enter date as dd/mm/yyyy',
    );
    if (picked == null) return;
    setState(() {
      if (isPayDate) {
        _lastPayDate = picked;
      } else {
        _eventDate = picked;
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_eventDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please choose the event date')));
      return;
    }
    if (_feeNeeded && _lastPayDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please choose the last date to pay')));
      return;
    }
    if (!_schoolWide && _selectedClassroomIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one classroom')));
      return;
    }
    if (_feeNeeded && _lastPayDate != null && _lastPayDate!.isAfter(_eventDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Last pay date should be on or before the event date')),
      );
      return;
    }

    final event = SchoolEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      eventDate: _eventDate!,
      lastPayDate: _feeNeeded ? _lastPayDate : null,
      feeAmount: _feeNeeded ? double.parse(_feeController.text) : 0,
      audience: _schoolWide ? EventAudience.school : EventAudience.classrooms,
      classroomIds: _schoolWide ? const [] : _selectedClassroomIds.toList(),
      createdAt: DateTime.now(),
    );
    context.read<SchoolEventBloc>().add(OrganizeSchoolEvent(event));
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  const _DateField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final text = value == null ? 'Tap to choose' : '${value!.day} ${months[value!.month - 1]} ${value!.year}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(Icons.calendar_today_outlined),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: value == null ? AppColors.onSurfaceHint(context) : AppColors.onSurface(context),
            fontWeight: value == null ? FontWeight.w400 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
