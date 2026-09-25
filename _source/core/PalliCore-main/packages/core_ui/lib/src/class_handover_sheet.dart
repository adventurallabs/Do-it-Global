import 'package:flutter/material.dart';
import 'package:core_models/core_models.dart';
import 'app_colors.dart';
import 'admin_look.dart';
import 'teacher_picker_sheet.dart';

/// What the admin decided in the handover sheet.
class HandoverChoice {
  /// The incoming class teacher. Null means "leave the class without one".
  final Teacher? newClassTeacher;

  /// Whether the outgoing teacher's periods in this class move across too.
  final bool movePeriods;

  const HandoverChoice({this.newClassTeacher, this.movePeriods = false});
}

/// Hands a class from one teacher to another, and says plainly what travels
/// with it.
///
/// The fear an admin has here is that changing the teacher loses the class —
/// its students, their marks, the year's progress. It doesn't: all of that
/// belongs to the classroom, and the new teacher sees it the moment they are
/// named. What genuinely needs a decision is the timetable, because periods
/// name a person rather than a class.
Future<HandoverChoice?> showClassHandoverSheet({
  required BuildContext context,
  required String className,
  required List<Teacher> candidates,
  Teacher? outgoing,
  /// Periods the outgoing teacher holds in this class.
  List<StaffBooking> periodsInClass = const [],
  /// Teachers who cannot take the class, keyed by id — typically because
  /// they already run another homeroom.
  Map<String, TeacherUnavailable> unavailable = const {},
  /// Given a candidate, which of [periodsInClass] they could not take over
  /// because they are elsewhere at that hour. Kept as a callback so the
  /// check runs against live data when the pick is made.
  Future<List<StaffBooking>> Function(Teacher candidate)? clashesFor,
  bool allowNoTeacher = false,
}) {
  return showModalBottomSheet<HandoverChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ClassHandoverSheet(
      className: className,
      candidates: candidates,
      outgoing: outgoing,
      periodsInClass: periodsInClass,
      unavailable: unavailable,
      clashesFor: clashesFor,
      allowNoTeacher: allowNoTeacher,
    ),
  );
}

class _ClassHandoverSheet extends StatefulWidget {
  final String className;
  final List<Teacher> candidates;
  final Teacher? outgoing;
  final List<StaffBooking> periodsInClass;
  final Map<String, TeacherUnavailable> unavailable;
  final Future<List<StaffBooking>> Function(Teacher candidate)? clashesFor;
  final bool allowNoTeacher;

  const _ClassHandoverSheet({
    required this.className,
    required this.candidates,
    required this.outgoing,
    required this.periodsInClass,
    required this.unavailable,
    required this.clashesFor,
    required this.allowNoTeacher,
  });

  @override
  State<_ClassHandoverSheet> createState() => _ClassHandoverSheetState();
}

class _ClassHandoverSheetState extends State<_ClassHandoverSheet> {
  Teacher? _picked;
  bool _movePeriods = true;
  bool _checking = false;
  List<StaffBooking> _clashes = const [];

  bool get _hasPeriods => widget.periodsInClass.isNotEmpty;

  Future<void> _pick() async {
    final teacher = await showTeacherPicker(
      context: context,
      teachers: widget.candidates,
      title: 'New class teacher for ${widget.className}',
      subtitle: 'They take roll call, the daily diary and the class notes',
      unavailable: widget.unavailable,
      selectedId: _picked?.id,
    );
    if (teacher == null || !mounted) return;
    setState(() {
      _picked = teacher;
      _clashes = const [];
      _checking = widget.clashesFor != null && _hasPeriods;
    });
    if (widget.clashesFor == null || !_hasPeriods) return;
    final clashes = await widget.clashesFor!(teacher);
    if (!mounted) return;
    setState(() {
      _clashes = clashes;
      _checking = false;
      // Never offer to create a double-booking: if some of the periods would
      // collide, the move is off by default and the admin is told why.
      if (clashes.isNotEmpty) _movePeriods = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final periodCount = widget.periodsInClass.length;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.onSurfaceHint(context).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Change class teacher',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            widget.outgoing == null
                ? '${widget.className} has no class teacher right now.'
                : '${widget.outgoing!.name} currently runs ${widget.className}.',
            style: TextStyle(fontSize: 13, color: AppColors.onSurfaceMuted(context)),
          ),
          const SizedBox(height: 16),
          _keepsCard(),
          const SizedBox(height: 14),
          _pickField(),
          if (_hasPeriods) ...[
            const SizedBox(height: 14),
            _periodsCard(periodCount),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _picked == null && !widget.allowNoTeacher
                  ? null
                  : _checking
                      ? null
                      : () => Navigator.pop(
                            context,
                            HandoverChoice(
                              newClassTeacher: _picked,
                              movePeriods: _movePeriods && _hasPeriods && _clashes.isEmpty,
                            ),
                          ),
              child: Text(_picked == null ? 'Leave without a class teacher' : 'Hand over the class'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  /// The reassurance, stated first: the class is not the teacher's property.
  Widget _keepsCard() {
    const keeps = [
      (Icons.groups_outlined, 'Every student stays on the roll'),
      (Icons.grading_rounded, 'All marks and exam results stay with the class'),
      (Icons.star_rounded, 'Stars, progress notes and the year so far stay'),
      (Icons.fact_check_outlined, 'The attendance history stays'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.09),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('The new teacher inherits the whole class',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.success)),
          const SizedBox(height: 8),
          for (final (icon, text) in keeps)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Icon(icon, size: 15, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _pickField() {
    return InkWell(
      onTap: _pick,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'New class teacher',
          suffixIcon: Icon(Icons.search_rounded, size: 20),
        ),
        child: Row(
          children: [
            if (_picked != null)
              CircleAvatar(
                radius: 13,
                backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                child: Text(
                  _picked!.name.isEmpty ? '?' : _picked!.name[0].toUpperCase(),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent),
                ),
              )
            else
              Icon(Icons.person_outline_rounded, size: 18, color: AppColors.onSurfaceHint(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _picked?.name ?? 'Tap to choose',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _picked == null ? AppColors.onSurfaceHint(context) : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The one genuine decision: periods name a person, so they do not follow
  /// the class on their own.
  Widget _periodsCard(int periodCount) {
    final label = '$periodCount ${periodCount == 1 ? 'period' : 'periods'}';
    final subjects = {for (final p in widget.periodsInClass) p.periodName}.join(', ');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      decoration: BoxDecoration(
        color: AdminLook.gold.withValues(alpha: 0.08),
        border: Border.all(color: AdminLook.gold.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.outgoing == null
                ? '$label in this class need a teacher'
                : '${widget.outgoing!.name} also teaches $label here',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            subjects,
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted(context)),
          ),
          if (_checking)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('Checking whether they are free…', style: TextStyle(fontSize: 12.5)),
                ],
              ),
            )
          else if (_clashes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.person_off_outlined, size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_picked?.name ?? 'They'} already teach another class during '
                    '${_clashes.length == 1 ? 'one of these periods' : '${_clashes.length} of these periods'} '
                    '(${_clashes.map((c) => '${c.dayOfWeek.substring(0, 3)} ${c.range}').take(2).join(', ')}). '
                    'The periods stay unassigned — give them to someone free from the timetable.',
                    style: const TextStyle(fontSize: 12, height: 1.35, color: AppColors.error),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ] else
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeThumbColor: AdminLook.gold,
              value: _movePeriods,
              onChanged: _picked == null ? null : (v) => setState(() => _movePeriods = v),
              title: Text(
                _picked == null
                    ? 'Choose a teacher to move these periods'
                    : 'Also give these periods to ${_picked!.name}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _movePeriods
                    ? 'They will teach these subjects and can record their marks.'
                    : 'The periods are left unassigned for you to fill from the timetable.',
                style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceMuted(context)),
              ),
            ),
        ],
      ),
    );
  }
}
