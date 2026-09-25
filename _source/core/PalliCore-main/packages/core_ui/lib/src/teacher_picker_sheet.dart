import 'package:flutter/material.dart';
import 'package:core_models/core_models.dart';
import 'app_colors.dart';

/// Why a teacher can't be picked for this slot, in words an admin can act on.
class TeacherUnavailable {
  /// What they are doing instead — "Mathematics · LKG A".
  final String reason;

  /// When — "Monday 9:30 – 10:15 AM".
  final String? detail;

  const TeacherUnavailable(this.reason, {this.detail});

  /// Built straight from a clashing booking, so every screen words it the
  /// same way.
  factory TeacherUnavailable.fromBooking(StaffBooking booking) =>
      TeacherUnavailable(booking.label, detail: booking.detail);

  String get sentence => detail == null ? reason : '$reason · $detail';
}

/// What the picker returned. [teacher] is null when the admin chose the
/// explicit "no staff" option; a null [StaffPick] means they dismissed it.
class StaffPick {
  final Teacher? teacher;
  const StaffPick(this.teacher);
  bool get isNone => teacher == null;
}

/// Opens a searchable, subject-filterable bottom sheet to pick one teacher
/// out of [teachers]. Returns the picked [Teacher], or null if dismissed.
///
/// Teachers listed in [unavailable] are shown but cannot be picked — the
/// reason sits under their name, so "why can't I choose her?" is answered on
/// the spot instead of after a failed save.
Future<Teacher?> showTeacherPicker({
  required BuildContext context,
  required List<Teacher> teachers,
  required String title,
  String? subtitle,
  Map<String, TeacherUnavailable> unavailable = const {},
  String? selectedId,
}) async {
  final pick = await showStaffPicker(
    context: context,
    teachers: teachers,
    title: title,
    subtitle: subtitle,
    unavailable: unavailable,
    selectedId: selectedId,
  );
  return pick?.teacher;
}

/// [showTeacherPicker] plus an explicit "no staff" row — for slots like
/// breaks and lunch, where nobody is the right answer rather than a missing
/// one.
Future<StaffPick?> showStaffPicker({
  required BuildContext context,
  required List<Teacher> teachers,
  required String title,
  String? subtitle,
  Map<String, TeacherUnavailable> unavailable = const {},
  String? noneLabel,
  String? noneSubtitle,
  String? selectedId,
}) {
  return showModalBottomSheet<StaffPick>(
    context: context,
    isScrollControlled: true,
    builder: (_) => TeacherPickerSheet(
      teachers: teachers,
      title: title,
      subtitle: subtitle,
      unavailable: unavailable,
      noneLabel: noneLabel,
      noneSubtitle: noneSubtitle,
      selectedId: selectedId,
    ),
  );
}

class TeacherPickerSheet extends StatefulWidget {
  final List<Teacher> teachers;
  final String title;
  final String? subtitle;
  final Map<String, TeacherUnavailable> unavailable;
  final String? noneLabel;
  final String? noneSubtitle;
  final String? selectedId;

  const TeacherPickerSheet({
    super.key,
    required this.teachers,
    required this.title,
    this.subtitle,
    this.unavailable = const {},
    this.noneLabel,
    this.noneSubtitle,
    this.selectedId,
  });

  @override
  State<TeacherPickerSheet> createState() => _TeacherPickerSheetState();
}

class _TeacherPickerSheetState extends State<TeacherPickerSheet> {
  final _searchC = TextEditingController();
  String _query = '';
  final Set<String> _subjectFilter = {};
  bool _hideBusy = false;

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  bool _isBusy(Teacher t) => widget.unavailable.containsKey(t.id);

  List<String> get _availableSubjects {
    final subjects = <String>{};
    for (final t in widget.teachers) {
      subjects.addAll(t.subjects);
    }
    final sorted = subjects.toList()..sort();
    return sorted;
  }

  bool _matches(Teacher t) {
    if (_subjectFilter.isNotEmpty && !t.subjects.any(_subjectFilter.contains)) {
      return false;
    }
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    if (t.name.toLowerCase().contains(query)) return true;
    if (t.contactNumber.toLowerCase().contains(query)) return true;
    if (t.qualification.toLowerCase().contains(query)) return true;
    if (t.subjects.any((s) => s.toLowerCase().contains(query))) return true;
    return false;
  }

  /// Free staff first, busy ones after — the admin scrolls through people
  /// they can actually pick before meeting the ones they can't.
  (List<Teacher> free, List<Teacher> busy) get _filtered {
    final free = <Teacher>[];
    final busy = <Teacher>[];
    for (final t in widget.teachers) {
      if (!_matches(t)) continue;
      (_isBusy(t) ? busy : free).add(t);
    }
    int byName(Teacher a, Teacher b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());
    free.sort(byName);
    busy.sort(byName);
    return (free, busy);
  }

  void _explain(Teacher teacher) {
    final blocked = widget.unavailable[teacher.id];
    if (blocked == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${teacher.name} is not free — ${blocked.sentence}'),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final (free, busy) = _filtered;
    final subjects = _availableSubjects;
    final totalBusy = widget.teachers.where(_isBusy).length;
    final showBusySection = busy.isNotEmpty && !_hideBusy;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.75,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 42, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(99))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12),
                      ),
                    ],
                    if (totalBusy > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.event_busy_rounded, size: 14, color: AppColors.warning),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${widget.teachers.length - totalBusy} of ${widget.teachers.length} free · '
                              '$totalBusy already has a class at this time',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchC,
                  autofocus: true,
                  onChanged: (val) => setState(() => _query = val),
                  decoration: InputDecoration(
                    hintText: 'Search by name, subject or contact',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchC.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ),
              if (subjects.isNotEmpty || totalBusy > 0) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      if (totalBusy > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            avatar: const Icon(Icons.check_circle_outline_rounded, size: 16),
                            label: const Text('Free only', style: TextStyle(fontSize: 12)),
                            selected: _hideBusy,
                            visualDensity: VisualDensity.compact,
                            onSelected: (selected) => setState(() => _hideBusy = selected),
                          ),
                        ),
                      ...subjects.map((subject) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(subject, style: const TextStyle(fontSize: 12)),
                              selected: _subjectFilter.contains(subject),
                              visualDensity: VisualDensity.compact,
                              onSelected: (selected) => setState(() {
                                if (selected) {
                                  _subjectFilter.add(subject);
                                } else {
                                  _subjectFilter.remove(subject);
                                }
                              }),
                            ),
                          )),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: free.isEmpty && !showBusySection && widget.noneLabel == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            busy.isEmpty
                                ? 'No staff found'
                                : 'Nobody is free for this slot. Clear "Free only" to see who is busy and when.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.onSurfaceMuted(context)),
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        children: [
                          if (widget.noneLabel != null)
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.onSurfaceHint(context).withValues(alpha: 0.15),
                                child: Icon(Icons.free_breakfast_outlined,
                                    size: 20, color: AppColors.onSurfaceMuted(context)),
                              ),
                              title: Text(widget.noneLabel!),
                              subtitle: widget.noneSubtitle == null ? null : Text(widget.noneSubtitle!),
                              trailing: widget.selectedId == StaffAvailability.noStaffId
                                  ? const Icon(Icons.check_rounded, color: AppColors.accent)
                                  : null,
                              onTap: () => Navigator.pop(context, const StaffPick(null)),
                            ),
                          if (free.isEmpty && busy.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                              child: Text(
                                'Nobody is free for this slot.',
                                style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12),
                              ),
                            ),
                          ...free.map(_tile),
                          if (showBusySection) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.lock_clock_rounded, size: 15, color: AppColors.warning),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Already teaching at this time',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                      color: AppColors.onSurfaceMuted(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...busy.map(_tile),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(Teacher teacher) {
    final blocked = widget.unavailable[teacher.id];
    final selected = widget.selectedId == teacher.id;
    final subtitle = teacher.subjects.isEmpty ? teacher.qualification : teacher.subjects.join(', ');

    final tile = ListTile(
      leading: CircleAvatar(
        backgroundColor: (blocked == null ? AppColors.accent : AppColors.warning).withValues(alpha: 0.15),
        child: Text(
          teacher.name.isEmpty ? '?' : teacher.name[0].toUpperCase(),
          style: TextStyle(
            color: blocked == null ? AppColors.accent : AppColors.warning,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        teacher.name,
        style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
      ),
      subtitle: blocked == null
          ? Text(subtitle)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle.isNotEmpty) Text(subtitle),
                const SizedBox(height: 2),
                Text(
                  blocked.reason,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warning),
                ),
                if (blocked.detail != null)
                  Text(
                    blocked.detail!,
                    style: TextStyle(fontSize: 11, color: AppColors.onSurfaceMuted(context)),
                  ),
              ],
            ),
      isThreeLine: blocked != null,
      trailing: blocked != null
          ? const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.warning)
          : selected
              ? const Icon(Icons.check_rounded, color: AppColors.accent)
              : null,
      onTap: blocked != null ? () => _explain(teacher) : () => Navigator.pop(context, StaffPick(teacher)),
    );

    if (blocked == null) return tile;
    // Dimmed, but still readable and still tappable — the tap explains the
    // clash rather than silently doing nothing.
    return Opacity(opacity: 0.55, child: tile);
  }
}
