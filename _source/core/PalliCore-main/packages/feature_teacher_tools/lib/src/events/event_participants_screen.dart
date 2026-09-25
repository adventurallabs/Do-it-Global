import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import '../progress/progress_widgets.dart' show sortedRoster;

/// Who is taking part from one classroom.
///
/// It opens empty on purpose: this is the entry list, not the class roster.
/// "Add participant" is where the roster appears, with a tick beside each
/// child.
class EventParticipantsScreen extends StatefulWidget {
  final String teacherId;
  final EventCategory category;
  final Classroom classroom;

  const EventParticipantsScreen({
    super.key,
    required this.teacherId,
    required this.category,
    required this.classroom,
  });

  static Future<void> open(
    BuildContext context, {
    required String teacherId,
    required EventCategory category,
    required Classroom classroom,
  }) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventParticipantsScreen(
            teacherId: teacherId,
            category: category,
            classroom: classroom,
          ),
        ),
      );

  @override
  State<EventParticipantsScreen> createState() => _EventParticipantsScreenState();
}

class _EventParticipantsScreenState extends State<EventParticipantsScreen> {
  List<Student> _roster = const [];
  List<EventParticipant> _entered = const [];
  bool _loading = true;
  bool _error = false;
  bool _busy = false;

  EventProgramRepository get _repo => context.read<EventProgramRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _error = false);
    try {
      final (roster, all) = await (
        context.read<StudentRepository>().getByClassroom(widget.classroom.id),
        _repo.participants(widget.category.id),
      ).wait;
      if (!mounted) return;
      setState(() {
        _roster = sortedRoster(roster);
        _entered = all.where((p) => p.classroomId == widget.classroom.id).toList();
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

  Student? _studentOf(EventParticipant p) =>
      _roster.where((s) => s.id == p.studentId).firstOrNull;

  void _fail(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(EventProgramRepository.describeError(error)),
        backgroundColor: AppColors.error,
      ));
  }

  Future<void> _addParticipants() async {
    final already = {for (final p in _entered) p.studentId};
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _PickSheet(
        classroom: widget.classroom,
        roster: _roster,
        already: already,
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.addParticipants(
        categoryId: widget.category.id,
        classroomId: widget.classroom.id,
        studentIds: picked.toList(),
        addedBy: widget.teacherId,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${picked.length} added to ${widget.category.name}.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(EventParticipant p) async {
    final name = _studentOf(p)?.name ?? 'This student';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from this category?'),
        content: Text('$name will no longer be entered for ${widget.category.name}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.removeParticipants([p.id]);
      await _load();
    } catch (e) {
      _fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.classroom.displayName} · ${widget.category.name}',
            overflow: TextOverflow.ellipsis),
      ),
      floatingActionButton: _loading || _error
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : _addParticipants,
              icon: const Icon(Icons.person_add_alt_rounded),
              label: const Text('Add participant'),
              shape: const StadiumBorder(),
            ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load this class",
        subtitle: 'Check your connection and try again.',
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    if (_entered.isEmpty) {
      return EmptyState(
        icon: Icons.groups_2_outlined,
        title: 'No one entered yet',
        subtitle: 'Tap "Add participant" to pick the children from '
            '${widget.classroom.displayName} taking part in ${widget.category.name}.',
        actionLabel: 'Add participant',
        onAction: _addParticipants,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
        itemCount: _entered.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 2),
              child: Text(
                '${_entered.length} entered from ${widget.classroom.displayName}',
                style: TextStyle(fontSize: 12.5, color: AppColors.onSurfaceMuted(context)),
              ),
            );
          }
          final p = _entered[i - 1];
          final student = _studentOf(p);
          return _EnteredRow(
            name: student?.name ?? 'Student no longer in this class',
            roll: student?.rollNumber ?? '',
            selfRegistered: p.selfRegistered,
            onRemove: () => _remove(p),
          );
        },
      ),
    );
  }
}

class _EnteredRow extends StatelessWidget {
  final String name;
  final String roll;
  final bool selfRegistered;
  final VoidCallback onRemove;

  const _EnteredRow({
    required this.name,
    required this.roll,
    required this.selfRegistered,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_outlined, size: 18, color: AppColors.eventCard),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                if (selfRegistered) ...[
                  const SizedBox(height: 1),
                  Text('Entered by the family',
                      style: TextStyle(fontSize: 11, color: AppColors.accent)),
                ],
              ],
            ),
          ),
          if (roll.isNotEmpty)
            Text('Roll $roll',
                style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceMuted(context))),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: 'Remove',
            color: AppColors.onSurfaceHint(context),
          ),
        ],
      ),
    );
  }
}

/// The class roster with a tick beside each child. Children already entered
/// are shown ticked and locked, so the sheet reads as the full class rather
/// than a shrinking list of leftovers.
class _PickSheet extends StatefulWidget {
  final Classroom classroom;
  final List<Student> roster;
  final Set<String> already;

  const _PickSheet({required this.classroom, required this.roster, required this.already});

  @override
  State<_PickSheet> createState() => _PickSheetState();
}

class _PickSheetState extends State<_PickSheet> {
  final Set<String> _picked = {};
  String _query = '';

  List<Student> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.roster;
    return widget.roster
        .where((s) => s.name.toLowerCase().contains(q) || s.rollNumber.contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final available = widget.roster.where((s) => !widget.already.contains(s.id)).length;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.classroom.displayName,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  available == 0
                      ? 'Everyone in this class is already entered.'
                      : 'Tick the children taking part.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.onSurfaceMuted(context)),
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                    hintText: 'Search by name or roll number',
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: visible.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(28),
                    child: Text('No student matches that.'),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final s = visible[i];
                      final entered = widget.already.contains(s.id);
                      final picked = _picked.contains(s.id);
                      return CheckboxListTile(
                        value: entered || picked,
                        onChanged: entered
                            ? null
                            : (v) => setState(() {
                                  if (v == true) {
                                    _picked.add(s.id);
                                  } else {
                                    _picked.remove(s.id);
                                  }
                                }),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          entered
                              ? 'Already entered'
                              : (s.rollNumber.isEmpty ? '' : 'Roll ${s.rollNumber}'),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: entered ? AppColors.success : AppColors.onSurfaceMuted(context),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: SizedBox(
                height: 50,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _picked.isEmpty ? null : () => Navigator.pop(context, _picked),
                  icon: const Icon(Icons.person_add_alt_rounded, size: 19),
                  label: Text(
                    _picked.isEmpty
                        ? 'Add participant'
                        : 'Add ${_picked.length} participant${_picked.length == 1 ? '' : 's'}',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
