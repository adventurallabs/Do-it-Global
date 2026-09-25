import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart';
import 'directory_bloc.dart';
import 'person_documents_section.dart';

class StudentFormScreen extends StatefulWidget {
  final Student? student;
  const StudentFormScreen({super.key, this.student});

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameC;
  late final TextEditingController _rollC;
  late final TextEditingController _fatherC;
  late final TextEditingController _motherC;
  late final TextEditingController _contactC;
  late final TextEditingController _secContactC;
  late final TextEditingController _addressC;
  late final TextEditingController _feesC;
  late final TextEditingController _admissionNoC;
  late final TextEditingController _emergencyC;
  late final TextEditingController _emergencyAltC;
  late final TextEditingController _bloodC;
  late final TextEditingController _pickupC;
  late final TextEditingController _dropC;

  Gender? _gender;
  /// Null until somebody answers. "No" is a real answer and must not be
  /// confused with never having been asked.
  bool? _needsTransport;
  String? _busId;
  List<Bus> _buses = const [];
  PickedPhoto? _photo;

  /// Minted up front rather than at save, so a photo can be uploaded
  /// against a child who does not have a row yet.
  late final String _studentId;
  DateTime? _dob;
  String? _classroomId;
  List<Classroom> _classrooms = [];
  String? _classroomError;
  bool _saving = false;

  bool get _isEditing => widget.student != null;

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(text: widget.student?.name ?? '');
    _rollC = TextEditingController(text: widget.student?.rollNumber ?? '');
    _fatherC = TextEditingController(text: widget.student?.fatherName ?? '');
    _motherC = TextEditingController(text: widget.student?.motherName ?? '');
    _contactC = TextEditingController(text: widget.student?.contactNumber ?? '');
    _secContactC = TextEditingController(text: widget.student?.secondaryContactNumber ?? '');
    _addressC = TextEditingController(text: widget.student?.address ?? '');
    _feesC = TextEditingController(text: widget.student?.fees.toStringAsFixed(0) ?? '');
    _admissionNoC = TextEditingController(text: widget.student?.admissionNo ?? '');
    _emergencyC = TextEditingController(text: widget.student?.emergencyContact ?? '');
    _emergencyAltC = TextEditingController(text: widget.student?.emergencyContactAlt ?? '');
    _bloodC = TextEditingController(text: widget.student?.bloodGroup ?? '');
    _pickupC = TextEditingController();
    _dropC = TextEditingController();
    _gender = widget.student?.gender;
    _needsTransport = widget.student?.needsTransport;
    _studentId =
        widget.student?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    _loadTransport();
    _dob = widget.student?.dob;
    _classroomId = (widget.student?.classroomId.isNotEmpty ?? false) ? widget.student!.classroomId : null;
    _loadClassrooms();
  }

  /// Buses and the child's existing travel arrangement, if any.
  Future<void> _loadTransport() async {
    try {
      final media = context.read<PersonMediaRepository>();
      final buses = await context.read<BusRepository>().getAll();
      if (!mounted) return;
      StudentTransport? existing;
      if (widget.student != null) {
        existing = await media.transport(widget.student!.id);
      }
      if (!mounted) return;
      setState(() {
        _buses = buses;
        if (existing != null) {
          _busId = existing.busId;
          _pickupC.text = existing.pickupLocation ?? '';
          _dropC.text = existing.dropLocation ?? '';
        }
      });
    } catch (_) {
      // Transport is an extra; the rest of the form still works without it.
    }
  }

  Future<void> _loadClassrooms() async {
    final state = context.read<DirectoryBloc>().state;
    List<Classroom> classrooms;
    if (state is DirectoryLoaded) {
      classrooms = state.classrooms;
    } else {
      classrooms = await context.read<ClassroomRepository>().getAll();
    }
    classrooms = [...classrooms]
      ..sort((a, b) {
        final gradeCompare =
            GradeCatalog.orderedKeys.indexOf(a.resolvedGradeKey).compareTo(GradeCatalog.orderedKeys.indexOf(b.resolvedGradeKey));
        if (gradeCompare != 0) return gradeCompare;
        return a.resolvedSection.compareTo(b.resolvedSection);
      });
    if (!mounted) return;
    setState(() => _classrooms = classrooms);
  }

  @override
  void dispose() {
    for (final c in [
      _nameC, _rollC, _fatherC, _motherC, _contactC, _secContactC, _addressC,
      _feesC, _admissionNoC, _emergencyC, _emergencyAltC, _bloodC, _pickupC, _dropC,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Student' : 'Add Student')),
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
              _field(_admissionNoC, 'Register / Admission Number', Icons.badge_outlined),
              _classroomField(),
              _dateField(),
              if (!_isEditing)
                const Padding(
                  padding: EdgeInsets.only(bottom: 14, left: 4),
                  child: Text(
                    "This becomes the parent's login (register number). The default "
                    "password is the student's name's first letter followed by their date "
                    "of birth — they'll be asked to set their own on first sign-in.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              _field(_rollC, 'Roll Number', Icons.tag),
              _field(_fatherC, "Father's Name", Icons.person_rounded),
              _field(_motherC, "Mother's Name", Icons.person_rounded),
              _field(_contactC, 'Contact Number', Icons.phone_outlined, keyboard: TextInputType.phone),
              _field(_secContactC, 'Secondary Contact', Icons.phone, keyboard: TextInputType.phone, required_: false),
              _field(_addressC, 'Address', Icons.location_on_outlined, maxLines: 2),
              _field(_feesC, 'Fees (₹)', Icons.currency_rupee, keyboard: TextInputType.number),

              const _SectionHeader(
                'About the child',
                note: 'Anything left blank is asked for later — on the '
                    "parent's app, and here on their profile.",
              ),
              PersonPhotoField(
                currentUrl: widget.student?.photoUrl,
                onPicked: (photo) => _photo = photo,
              ),
              _genderField(),
              _field(_bloodC, 'Blood group', Icons.bloodtype_outlined, required_: false),

              const _SectionHeader(
                'In an emergency',
                note: 'Who the school calls when the parents cannot be reached.',
              ),
              _field(_emergencyC, 'Emergency contact', Icons.emergency_outlined,
                  keyboard: TextInputType.phone, required_: false),
              _field(_emergencyAltC, 'Alternative number (optional)', Icons.phone_forwarded_outlined,
                  keyboard: TextInputType.phone, required_: false),

              const _SectionHeader('Transport'),
              _transportField(),
              if (_needsTransport == true) ...[
                _busField(),
                _field(_pickupC, 'Pickup location', Icons.trip_origin, required_: false),
                _field(_dropC, 'Drop location', Icons.place_outlined, required_: false),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14, left: 4),
                  child: Text(
                    'The bus and the two stops can be filled in later — saying '
                    'yes here is enough for now.',
                    style: TextStyle(fontSize: 11.5, height: 1.3, color: AppColors.onSurfaceMuted(context)),
                  ),
                ),
              ],

              if (_isEditing) ...[
                const _SectionHeader('Documents'),
                PersonDocumentsSection(
                  ownerType: DocumentOwner.student,
                  ownerId: _studentId,
                  kinds: DocumentKind.forStudents,
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 4, left: 4),
                  child: Text(
                    'Documents can be uploaded from the profile once the child '
                    'has been added.',
                    style: TextStyle(fontSize: 11.5, height: 1.3, color: AppColors.onSurfaceMuted(context)),
                  ),
                ),
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
                      : Text(_isEditing ? 'Update Student' : 'Add Student',
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

  Widget _field(TextEditingController c, String label, IconData icon,
      {TextInputType? keyboard, int maxLines = 1, bool required_ = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        validator: required_ ? (val) => val == null || val.isEmpty ? 'Required' : null : null,
      ),
    );
  }

  /// Transport lives in its own table. Saying "no" clears any arrangement
  /// rather than leaving a half-answer behind.
  Future<void> _saveTransport() async {
    try {
      final media = context.read<PersonMediaRepository>();
      if (_needsTransport != true) {
        await media.clearTransport(_studentId);
        return;
      }
      await media.saveTransport(StudentTransport(
        studentId: _studentId,
        busId: _busId,
        pickupLocation: _pickupC.text.trim().isEmpty ? null : _pickupC.text.trim(),
        dropLocation: _dropC.text.trim().isEmpty ? null : _dropC.text.trim(),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not save the travel details: '
              '${PersonMediaRepository.describeError(e)}')));
    }
  }

  Widget _genderField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<Gender>(
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
    );
  }

  Widget _transportField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<bool>(
        initialValue: _needsTransport,
        isExpanded: true,
        items: const [
          DropdownMenuItem(value: true, child: Text('Yes — travels by school bus')),
          DropdownMenuItem(value: false, child: Text('No — makes their own way')),
        ],
        onChanged: (v) => setState(() => _needsTransport = v),
        decoration: const InputDecoration(
          labelText: 'Needs transport',
          prefixIcon: Icon(Icons.directions_bus_outlined),
        ),
        hint: const Text('Not asked yet'),
      ),
    );
  }

  Widget _busField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        initialValue: _buses.any((b) => b.id == _busId) ? _busId : null,
        isExpanded: true,
        items: [
          for (final b in _buses)
            DropdownMenuItem(value: b.id, child: Text('Bus ${b.busNumber}')),
        ],
        onChanged: (v) => setState(() => _busId = v),
        decoration: const InputDecoration(
          labelText: 'Bus number',
          prefixIcon: Icon(Icons.airport_shuttle_outlined),
        ),
        hint: Text(_buses.isEmpty ? 'No buses on record yet' : 'Not assigned yet'),
      ),
    );
  }

  Widget _classroomField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        initialValue: _classroomId,
        isExpanded: true,
        items: _classrooms
            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.displayName)))
            .toList(),
        onChanged: (val) => setState(() {
          _classroomId = val;
          _classroomError = null;
        }),
        decoration: InputDecoration(
          labelText: 'Classroom',
          prefixIcon: const Icon(Icons.class_outlined),
          errorText: _classroomError,
        ),
        hint: Text(_classrooms.isEmpty ? 'Loading classrooms…' : 'Select classroom'),
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
              initialDate: _dob ?? DateTime(now.year - 10),
              firstDate: DateTime(1990),
              lastDate: now,
              locale: const Locale('en', 'IN'),
              fieldHintText: 'dd/mm/yyyy',
              errorFormatText: 'Enter date as dd/mm/yyyy',
              errorInvalidText: 'Enter a date between 1990 and today',
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

  Future<void> _onSave() async {
    final formValid = _formKey.currentState!.validate();
    final classroomValid = _classroomId != null && _classroomId!.isNotEmpty;
    if (!classroomValid) {
      setState(() => _classroomError = 'Select the student\'s classroom');
    }
    if (!formValid || !classroomValid) return;

    setState(() => _saving = true);

    // The photo goes up first: if it fails we can still save the child, and
    // the gap list will simply keep asking for a picture.
    var photoUrl = widget.student?.photoUrl;
    if (_photo != null) {
      try {
        photoUrl = await context.read<PersonMediaRepository>().uploadPhoto(
              ownerType: DocumentOwner.student,
              ownerId: _studentId,
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

    final student = Student(
      id: _studentId,
      name: _nameC.text,
      rollNumber: _rollC.text,
      photoUrl: photoUrl,
      fatherName: _fatherC.text,
      motherName: _motherC.text,
      contactNumber: _contactC.text,
      secondaryContactNumber: _secContactC.text.isEmpty ? null : _secContactC.text,
      address: _addressC.text,
      classroomId: _classroomId!,
      fees: double.tryParse(_feesC.text) ?? 0,
      admissionNo: _admissionNoC.text.trim(),
      isActive: widget.student?.isActive ?? true,
      deactivatedAt: widget.student?.deactivatedAt,
      dob: _dob,
      gender: _gender,
      bloodGroup: _bloodC.text.trim().isEmpty ? null : _bloodC.text.trim(),
      emergencyContact: _emergencyC.text.trim().isEmpty ? null : _emergencyC.text.trim(),
      emergencyContactAlt:
          _emergencyAltC.text.trim().isEmpty ? null : _emergencyAltC.text.trim(),
      needsTransport: _needsTransport,
      admissionDate: widget.student?.admissionDate ?? DateTime.now(),
    );

    await _saveTransport();
    if (!mounted) return;

    if (_isEditing) {
      setState(() => _saving = false);
      context.read<DirectoryBloc>().add(UpdateStudent(student));
      return;
    }

    final repo = context.read<StudentRepository>();
    try {
      await repo.upsert(student);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save student: $e')));
        setState(() => _saving = false);
      }
      return;
    }

    try {
      final tempPassword = await repo.issueParentLogin(student.id);
      if (mounted) await _showTempPasswordDialog(tempPassword);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Student saved, but could not create parent login: $e')));
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);
    context.read<DirectoryBloc>().add(LoadDirectory());
  }

  Future<void> _showTempPasswordDialog(String tempPassword) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Temporary password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("The parent can sign in with this password. It is shown only once — "
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

/// A quiet heading so a long form reads as a few short ones.
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? note;

  const _SectionHeader(this.title, {this.note});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 12, left: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: AppColors.onSurfaceMuted(context))),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(note!,
                style: TextStyle(
                    fontSize: 11.5, height: 1.3, color: AppColors.onSurfaceMuted(context))),
          ],
        ],
      ),
    );
  }
}
