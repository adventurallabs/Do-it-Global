import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:go_router/go_router.dart';
import 'ops_format.dart';

class AdmissionsScreen extends StatefulWidget {
  const AdmissionsScreen({super.key});

  @override
  State<AdmissionsScreen> createState() => _AdmissionsScreenState();
}

class _AdmissionsScreenState extends State<AdmissionsScreen> {
  List<Admission> _items = [];
  bool _loading = true;
  bool _hasError = false;

  static const _order = [
    AdmissionStage.enquiry,
    AdmissionStage.application,
    AdmissionStage.documents,
    AdmissionStage.verification,
    AdmissionStage.approved,
    AdmissionStage.rejected,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final items = await context.read<AdmissionRepository>().getAll();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admissions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/admin'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createEnquiry,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('New enquiry'),
        shape: const StadiumBorder(),
      ),
      body: SafeArea(
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
          ? EmptyState(
              icon: Icons.cloud_off_rounded,
              title: "Couldn't load admissions",
              subtitle: 'Check your connection and try again.',
              actionLabel: 'Retry',
              onAction: _load,
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(item.studentName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          ),
                          StatusPill(label: item.stage.name, color: _color(item.stage)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${item.parentName} · ${item.contactNumber}', style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13)),
                      Text('${GradeCatalog.label(item.appliedGradeKey)} · ${prettyDate(item.createdAt)}', style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 12)),
                      if (item.notes.isNotEmpty) Text(item.notes, style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 12)),
                      if (item.stage != AdmissionStage.approved && item.stage != AdmissionStage.rejected) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            TextButton(onPressed: () => _setStage(item, AdmissionStage.rejected), child: const Text('Reject')),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: () => _advance(item),
                              child: Text(item.stage == AdmissionStage.verification ? 'Approve & create student' : 'Next stage'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
      ),
    );
  }

  Color _color(AdmissionStage stage) {
    switch (stage) {
      case AdmissionStage.approved:
        return AppColors.success;
      case AdmissionStage.rejected:
        return AppColors.error;
      case AdmissionStage.verification:
        return AppColors.accent;
      default:
        return AppColors.warning;
    }
  }

  Future<void> _advance(Admission item) async {
    final index = _order.indexOf(item.stage);
    if (item.stage == AdmissionStage.verification) {
      final now = DateTime.now();
      final dob = await showDatePicker(
        context: context,
        helpText: "${item.studentName}'s date of birth",
        initialDate: DateTime(now.year - 10),
        firstDate: DateTime(1990),
        lastDate: now,
        locale: const Locale('en', 'IN'),
        fieldHintText: 'dd/mm/yyyy',
        errorFormatText: 'Enter date as dd/mm/yyyy',
        errorInvalidText: 'Enter a date between 1990 and today',
      );
      if (dob == null || !mounted) return;

      final classroom = await _pickClassroom(item.appliedGradeKey);
      if (classroom == null || !mounted) return;

      final student = Student(
        id: 'adm-${item.id}',
        name: item.studentName,
        rollNumber: DateTime.now().millisecondsSinceEpoch.toString().substring(7),
        fatherName: item.parentName,
        motherName: '',
        contactNumber: item.contactNumber,
        address: '',
        classroomId: classroom.id,
        fees: classroom.baseFees,
        admissionNo: 'REG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        dob: dob,
      );
      await context.read<StudentRepository>().upsert(student);
      await context.read<AdmissionRepository>().upsert(
            item.copyWith(stage: AdmissionStage.approved, createdStudentId: student.id),
          );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Admission approved. Student created in ${classroom.displayName}.')),
        );
      }
      return;
    }
    if (index < 0 || index >= _order.length - 3) return;
    await _setStage(item, _order[index + 1]);
  }

  Future<Classroom?> _pickClassroom(String appliedGradeKey) async {
    final all = await context.read<ClassroomRepository>().getAll();
    if (!mounted) return null;
    final sorted = [...all]
      ..sort((a, b) {
        final gradeCompare = GradeCatalog.orderedKeys
            .indexOf(a.resolvedGradeKey)
            .compareTo(GradeCatalog.orderedKeys.indexOf(b.resolvedGradeKey));
        if (gradeCompare != 0) return gradeCompare;
        return a.resolvedSection.compareTo(b.resolvedSection);
      });
    if (sorted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a classroom first before approving admissions')),
      );
      return null;
    }
    return showModalBottomSheet<Classroom>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('Assign to classroom', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: sorted
                        .map((c) => ListTile(
                              title: Text(c.displayName),
                              trailing: c.resolvedGradeKey == appliedGradeKey
                                  ? const Icon(Icons.star_rounded, color: AppColors.warning, size: 18)
                                  : null,
                              onTap: () => Navigator.pop(sheetContext, c),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _setStage(Admission item, AdmissionStage stage) async {
    await context.read<AdmissionRepository>().upsert(item.copyWith(stage: stage));
    await _load();
  }

  Future<void> _createEnquiry() async {
    final name = TextEditingController();
    final parent = TextEditingController();
    final contact = TextEditingController();
    var grade = '1';
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) {
        return SafeArea(
          child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheet).viewInsets.bottom + 24),
          child: StatefulBuilder(
            builder: (context, setModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('New enquiry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Student name')),
                  const SizedBox(height: 12),
                  TextField(controller: parent, decoration: const InputDecoration(labelText: 'Parent name')),
                  const SizedBox(height: 12),
                  TextField(controller: contact, decoration: const InputDecoration(labelText: 'Contact')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: grade,
                    items: GradeCatalog.orderedKeys
                        .map((k) => DropdownMenuItem(value: k, child: Text(GradeCatalog.label(k))))
                        .toList(),
                    onChanged: (val) => setModal(() => grade = val ?? '1'),
                    decoration: const InputDecoration(labelText: 'Applying for'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: () => Navigator.pop(sheet, true), child: const Text('Save enquiry')),
                ],
              );
            },
          ),
          ),
        );
      },
    );
    if (saved != true || !mounted || name.text.trim().isEmpty) return;
    await context.read<AdmissionRepository>().upsert(
          Admission(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            studentName: name.text.trim(),
            parentName: parent.text.trim(),
            contactNumber: contact.text.trim(),
            appliedGradeKey: grade,
            createdAt: DateTime.now(),
          ),
        );
    await _load();
  }
}
