import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart';
import 'directory_bloc.dart';
import 'person_documents_section.dart';

class TeacherFormScreen extends StatefulWidget {
  final Teacher? teacher;
  const TeacherFormScreen({super.key, this.teacher});

  @override
  State<TeacherFormScreen> createState() => _TeacherFormScreenState();
}

class _TeacherFormScreenState extends State<TeacherFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameC;
  late final TextEditingController _contactC;
  late final TextEditingController _qualC;
  late final TextEditingController _addressC;
  late final TextEditingController _salaryC;
  StaffRole _role = StaffRole.teaching;
  DateTime? _dob;
  Gender? _gender;
  late final TextEditingController _emergencyC;
  PickedPhoto? _photo;

  /// Minted up front so a photo can be uploaded before the row exists.
  late final String _staffId;
  final Set<String> _subjects = {};
  String? _subjectsError;
  bool _saving = false;

  bool get _isEditing => widget.teacher != null;

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(text: widget.teacher?.name ?? '');
    _contactC = TextEditingController(text: widget.teacher?.contactNumber ?? '');
    _qualC = TextEditingController(text: widget.teacher?.qualification ?? '');
    _addressC = TextEditingController(text: widget.teacher?.address ?? '');
    _salaryC = TextEditingController(text: widget.teacher?.salary.toStringAsFixed(0) ?? '');
    _role = widget.teacher?.role ?? StaffRole.teaching;
    _dob = widget.teacher?.dob;
    _gender = widget.teacher?.gender;
    _emergencyC =
        TextEditingController(text: widget.teacher?.emergencyContact ?? '');
    _staffId =
        widget.teacher?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    _subjects.addAll(widget.teacher?.subjects ?? const []);
  }

  @override
  void dispose() {
    for (final c in [_nameC, _contactC, _qualC, _addressC, _salaryC]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit staff' : 'Add staff')),
      body: SafeArea(
        child: BlocListener<DirectoryBloc, DirectoryState>(
        listener: (context, state) {
          if (state is DirectoryLoaded) Navigator.pop(context);
        },
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _field(_nameC, 'Full Name', Icons.person_outline),
              // This number is the teacher's login — it must be one they can
              // type back in exactly, so hold it to the same rule sign-in uses.
              _field(_contactC, 'Phone Number (used to sign in)', Icons.phone_outlined,
                  keyboard: TextInputType.phone,
                  validator: (val) => normalizeLoginPhone(val ?? '').length == 10
                      ? null
                      : 'Enter a 10-digit phone number'),
              _dateField(),
              if (!_isEditing)
                const Padding(
                  padding: EdgeInsets.only(bottom: 14, left: 4),
                  child: Text(
                    "This becomes their login (phone number + password). The default "
                    "password is their name's first letter followed by their date of "
                    "birth — they'll be asked to change it on first sign-in.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              _field(_qualC, 'Qualification', Icons.school_outlined),
              _field(_addressC, 'Address', Icons.location_on_outlined, maxLines: 2),
              _field(_salaryC, 'Salary (₹)', Icons.currency_rupee, keyboard: TextInputType.number),
              PersonPhotoField(
                currentUrl: widget.teacher?.photoUrl,
                onPicked: (photo) => _photo = photo,
                label: 'Staff photo',
              ),
              DropdownButtonFormField<Gender>(
                initialValue: _gender,
                isExpanded: true,
                items: [
                  for (final g in Gender.values)
                    DropdownMenuItem(value: g, child: Text(g.label)),
                ],
                onChanged: (v) => setState(() => _gender = v),
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  prefixIcon: Icon(Icons.wc_outlined),
                ),
                hint: const Text('Not recorded'),
              ),
              const SizedBox(height: 14),
              _field(_emergencyC, 'Emergency contact', Icons.emergency_outlined,
                  keyboard: TextInputType.phone, required_: false),
              const SizedBox(height: 14),
              DropdownButtonFormField<StaffRole>(
                value: _role,
                items: StaffRole.values
                    .map((role) => DropdownMenuItem(value: role, child: Text(_label(role))))
                    .toList(),
                onChanged: (val) => setState(() {
                  _role = val ?? StaffRole.teaching;
                  if (_role != StaffRole.teaching) _subjectsError = null;
                }),
                decoration: InputDecoration(
                  labelText: 'Staff type',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  helperText: _role == StaffRole.librarian
                      ? 'Signs in with the same staff login, straight into the Digital Library.'
                      : null,
                  helperMaxLines: 2,
                ),
              ),
              const SizedBox(height: 20),
              _subjectsField(),
              if (_isEditing) ...[
                const SizedBox(height: 6),
                Text('DOCUMENTS',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: AppColors.onSurfaceMuted(context))),
                const SizedBox(height: 10),
                PersonDocumentsSection(
                  ownerType: DocumentOwner.teacher,
                  ownerId: _staffId,
                  kinds: DocumentKind.forTeachers,
                ),
              ],
              const SizedBox(height: 24),
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
                  child: _saving
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isEditing ? 'Update staff' : 'Add staff',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  String _label(StaffRole role) {
    switch (role) {
      case StaffRole.teaching:
        return 'Teaching staff';
      case StaffRole.nonTeaching:
        return 'Non-teaching staff';
      case StaffRole.driver:
        return 'Driver';
      case StaffRole.office:
        return 'Office staff';
      case StaffRole.librarian:
        return 'Librarian (signs in to the Digital Library)';
    }
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {TextInputType? keyboard,
      int maxLines = 1,
      bool required_ = true,
      String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        validator: validator ??
            (required_ ? (val) => val == null || val.isEmpty ? 'Required' : null : null),
      ),
    );
  }

  Widget _dateField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: FormField<DateTime>(
        initialValue: _dob,
        validator: (val) => val == null ? 'Required' : null,
        builder: (state) => InkWell(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: _dob ?? DateTime(now.year - 25),
              firstDate: DateTime(1950),
              lastDate: now,
              locale: const Locale('en', 'IN'),
              fieldHintText: 'dd/mm/yyyy',
              errorFormatText: 'Enter date as dd/mm/yyyy',
              errorInvalidText: 'Enter a date between 1950 and today',
            );
            if (picked == null) return;
            setState(() => _dob = picked);
            state.didChange(picked);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Date of Birth',
              prefixIcon: const Icon(Icons.cake_outlined),
              errorText: state.errorText,
            ),
            child: Text(
              _dob == null
                  ? ''
                  : '${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}',
            ),
          ),
        ),
      ),
    );
  }

  Widget _subjectsField() {
    final custom = _subjects.where((s) => !SubjectCatalog.orderedSubjects.contains(s)).toList();
    final options = [...SubjectCatalog.orderedSubjects, ...custom];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.menu_book_outlined, size: 20, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              _role == StaffRole.teaching ? 'Specializes in' : 'Specializes in (optional)',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...options.map((subject) => FilterChip(
                  label: Text(subject),
                  selected: _subjects.contains(subject),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _subjects.add(subject);
                      _subjectsError = null;
                    } else {
                      _subjects.remove(subject);
                    }
                  }),
                )),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Custom'),
              onPressed: _addCustomSubject,
            ),
          ],
        ),
        if (_subjectsError != null) ...[
          const SizedBox(height: 6),
          Text(_subjectsError!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
        ],
      ],
    );
  }

  Future<void> _addCustomSubject() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add subject'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Sanskrit'),
          onSubmitted: (val) => Navigator.pop(context, val),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Add')),
        ],
      ),
    );
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return;
    setState(() {
      _subjects.add(trimmed);
      _subjectsError = null;
    });
  }

  Future<void> _onSave() async {
    final formValid = _formKey.currentState!.validate();
    final subjectsValid = _role != StaffRole.teaching || _subjects.isNotEmpty;
    if (!subjectsValid) {
      setState(() => _subjectsError = 'Select at least one subject');
    }
    if (!formValid || !subjectsValid) return;

    // A librarian works only in the library, so they can't also be the
    // class teacher of a section — that class would be left with nobody.
    final becomingLibrarian =
        _isEditing && _role == StaffRole.librarian && widget.teacher!.role != StaffRole.librarian;
    if (becomingLibrarian) {
      final classrooms = await context.read<ClassroomRepository>().getAll();
      final mine = classrooms.where((c) => c.classTeacherId == widget.teacher!.id).toList();
      if (mine.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${widget.teacher!.name} is class teacher of '
              '${mine.map((c) => c.displayName).join(', ')}. Hand the class to another teacher first.'),
        ));
        return;
      }
    }

    setState(() => _saving = true);
    var photoUrl = widget.teacher?.photoUrl;
    if (_photo != null) {
      try {
        photoUrl = await context.read<PersonMediaRepository>().uploadPhoto(
              ownerType: DocumentOwner.teacher,
              ownerId: _staffId,
              bytes: _photo!.bytes,
              extension: _photo!.extension,
            );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Saved without the photo: '
                  '${PersonMediaRepository.describeError(e)}')));
        }
      }
    }
    if (!mounted) return;

    final phone = normalizeLoginPhone(_contactC.text);
    if (_isEditing) {
      // The phone is the login, and the database moves the login with it —
      // or refuses if another account already has that number. The regular
      // save below doesn't report server errors, so do this part on its own
      // and stop here if it fails, rather than letting the teacher find out
      // at the login screen.
      if (phone != normalizeLoginPhone(widget.teacher!.contactNumber)) {
        try {
          await context.read<TeacherRepository>().changeLoginPhone(widget.teacher!.id, phone);
        } catch (e) {
          if (!mounted) return;
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Phone number not changed: ${TeacherRepository.describeError(e)}')));
          return;
        }
        if (!mounted) return;
      }
      setState(() => _saving = false);
      final teacher = widget.teacher!.copyWith(
        name: _nameC.text,
        contactNumber: phone,
        qualification: _qualC.text,
        address: _addressC.text,
        salary: double.tryParse(_salaryC.text) ?? 0,
        role: _role,
        dob: _dob,
        gender: _gender,
        emergencyContact:
            _emergencyC.text.trim().isEmpty ? null : _emergencyC.text.trim(),
        photoUrl: photoUrl,
        subjects: _subjects.toList(),
      );
      context.read<DirectoryBloc>().add(UpdateTeacher(teacher));
      return;
    }

    final teacher = Teacher(
      id: _staffId,
      name: _nameC.text.trim(),
      contactNumber: phone,
      qualification: _qualC.text.trim(),
      address: _addressC.text.trim(),
      salary: double.tryParse(_salaryC.text) ?? 0,
      role: _role,
      dob: _dob,
      gender: _gender,
      photoUrl: photoUrl,
      emergencyContact:
          _emergencyC.text.trim().isEmpty ? null : _emergencyC.text.trim(),
      joinDate: DateTime.now(),
      subjects: _subjects.toList(),
    );
    try {
      final tempPassword = await context.read<TeacherRepository>().createWithLogin(teacher);
      if (!mounted) return;
      await _showTempPasswordDialog(teacher.name, tempPassword);
      if (!mounted) return;
      context.read<DirectoryBloc>().add(LoadDirectory());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create login: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showTempPasswordDialog(String name, String tempPassword) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Temporary password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$name can sign in with this password. It is shown only once — '
                "they'll be asked to set their own on first login."),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SelectableText(tempPassword,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined),
                  tooltip: 'Copy',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: tempPassword));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')));
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ],
      ),
    );
  }
}
