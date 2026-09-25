import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import 'event_participants_screen.dart';
import 'event_rooms_screen.dart';

/// One category a teacher heads: the classes it draws from, and the rooms it
/// is contested in.
///
/// Entering students and running the day are two different jobs on two
/// different days, so they are two tabs rather than one long screen.
class EventCategoryScreen extends StatefulWidget {
  final String teacherId;
  final SchoolEvent event;
  final EventCategory category;

  const EventCategoryScreen({
    super.key,
    required this.teacherId,
    required this.event,
    required this.category,
  });

  static Future<void> open(
    BuildContext context, {
    required String teacherId,
    required SchoolEvent event,
    required EventCategory category,
  }) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventCategoryScreen(
            teacherId: teacherId,
            event: event,
            category: category,
          ),
        ),
      );

  @override
  State<EventCategoryScreen> createState() => _EventCategoryScreenState();
}

class _EventCategoryScreenState extends State<EventCategoryScreen> {
  int _tab = 0;
  List<Classroom> _classrooms = const [];
  List<EventParticipant> _participants = const [];
  Set<String> _openTo = const {};
  bool _loading = true;
  bool _error = false;

  EventProgramRepository get _repo => context.read<EventProgramRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _error = false);
    try {
      final (classrooms, participants, open) = await (
        context.read<ClassroomRepository>().getAll(),
        _repo.participants(widget.category.id),
        _repo.openClassrooms(categoryId: widget.category.id),
      ).wait;
      if (!mounted) return;
      setState(() {
        _classrooms = classrooms;
        _participants = participants;
        _openTo = open[widget.category.id] ?? const {};
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  /// Classrooms grouped by standard, in catalogue order, so the teacher reads
  /// "LKG: A, B, C" rather than an alphabetical jumble of section names.
  List<(String gradeKey, List<Classroom> sections)> get _byStandard {
    final grouped = <String, List<Classroom>>{};
    for (final c in _classrooms) {
      grouped.putIfAbsent(c.resolvedGradeKey, () => []).add(c);
    }
    // Catalogue order (LKG, UKG, 1st …), with anything unrecognised last.
    int rank(String k) {
      final i = GradeCatalog.orderedKeys.indexOf(k);
      return i < 0 ? GradeCatalog.orderedKeys.length : i;
    }
    final keys = grouped.keys.toList()
      ..sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : a.compareTo(b);
      });
    return [
      for (final k in keys)
        (k, grouped[k]!..sort((a, b) => a.resolvedSection.compareTo(b.resolvedSection))),
    ];
  }

  int _countIn(String classroomId) =>
      _participants.where((p) => p.classroomId == classroomId).length;

  /// Opening a class is what puts this category in front of its families —
  /// they cannot see it, let alone enter, until the head does this.
  Future<void> _toggleOpen(Classroom classroom, bool open) async {
    // A fresh set every time: `_openTo` starts life as `const {}` whenever the
    // category has nothing open yet — which is every category the first time
    // a head opens this screen — and a const set cannot be added to.
    final next = {..._openTo};
    if (open) {
      next.add(classroom.id);
    } else {
      next.remove(classroom.id);
    }
    setState(() => _openTo = next);
    try {
      await _repo.setClassroomOpen(
        categoryId: widget.category.id,
        classroomId: classroom.id,
        open: open,
        byTeacher: widget.teacherId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(EventProgramRepository.describeError(e)),
          backgroundColor: AppColors.error,
        ));
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            Text(widget.event.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.onSurfaceMuted(context))),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SoftSegmentedControl(
                labels: const ['Participants', 'Rooms'],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            Expanded(
              child: FadeTabStack(
                index: _tab,
                children: [
                  _participantsTab(),
                  EventRoomsTab(
                    teacherId: widget.teacherId,
                    event: widget.event,
                    category: widget.category,
                    participants: _participants,
                    classrooms: _classrooms,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _participantsTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load classes",
        subtitle: 'Check your connection and try again.',
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    final groups = _byStandard;
    if (groups.isEmpty) {
      return const EmptyState(
        icon: Icons.class_outlined,
        title: 'No classes yet',
        subtitle: 'Classrooms appear here once the admin creates them.',
      );
    }
    final total = _participants.length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 2),
            child: Text(
              total == 0
                  ? 'Pick the classes this category is open to, then add the children taking part.'
                  : '$total participant${total == 1 ? '' : 's'} entered so far.',
              style: TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.onSurfaceMuted(context)),
            ),
          ),
          for (final (gradeKey, sections) in groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
              child: Text(
                GradeCatalog.label(gradeKey).toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: AppColors.onSurfaceMuted(context),
                ),
              ),
            ),
            for (final section in sections)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ClassRow(
                  classroom: section,
                  entered: _countIn(section.id),
                  open: _openTo.contains(section.id),
                  onOpenChanged: (v) => _toggleOpen(section, v),
                  onTap: () async {
                    await EventParticipantsScreen.open(
                      context,
                      teacherId: widget.teacherId,
                      category: widget.category,
                      classroom: section,
                    );
                    if (mounted) _load();
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ClassRow extends StatelessWidget {
  final Classroom classroom;
  final int entered;
  final bool open;
  final ValueChanged<bool> onOpenChanged;
  final VoidCallback onTap;

  const _ClassRow({
    required this.classroom,
    required this.entered,
    required this.open,
    required this.onOpenChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final has = entered > 0;
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            has ? Icons.check_circle_rounded : Icons.class_outlined,
            size: 20,
            color: has ? AppColors.success : AppColors.classroomCard,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(classroom.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 1),
                Text(
                  has
                      ? '$entered entered${open ? ' · open' : ''}'
                      : (open ? 'Open for entries' : 'None yet'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: has
                        ? AppColors.success
                        : (open ? AppColors.accent : AppColors.onSurfaceHint(context)),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(value: open, onChanged: onOpenChanged),
          Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceHint(context)),
        ],
      ),
    );
  }
}
