import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

/// One room, through its whole life: pick the line-up, start it, say how many
/// places it awards, assign them, submit.
///
/// Each step closes the one before it, and the database enforces every lock
/// again — a place, once submitted, is what a family will be told.
class EventRoomScreen extends StatefulWidget {
  final String teacherId;
  final SchoolEvent event;
  final EventCategory category;
  final EventRoom room;
  final List<EventParticipant> participants;
  final List<Classroom> classrooms;

  const EventRoomScreen({
    super.key,
    required this.teacherId,
    required this.event,
    required this.category,
    required this.room,
    required this.participants,
    required this.classrooms,
  });

  static Future<void> open(
    BuildContext context, {
    required String teacherId,
    required SchoolEvent event,
    required EventCategory category,
    required EventRoom room,
    required List<EventParticipant> participants,
    required List<Classroom> classrooms,
  }) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventRoomScreen(
            teacherId: teacherId,
            event: event,
            category: category,
            room: room,
            participants: participants,
            classrooms: classrooms,
          ),
        ),
      );

  @override
  State<EventRoomScreen> createState() => _EventRoomScreenState();
}

class _EventRoomScreenState extends State<EventRoomScreen> {
  late EventRoom _room = widget.room;

  /// Re-read on every load rather than trusted from the category screen: a
  /// family can enter a child from PalliConnect while the head is standing on
  /// this screen, and a stale list resolved them to "Unknown".
  late List<EventParticipant> _participants = widget.participants;
  Set<String> _inRoom = {};
  Map<int, String> _places = {};
  Map<String, Student> _students = const {};
  bool _loading = true;
  bool _error = false;
  bool _busy = false;

  EventProgramRepository get _repo => context.read<EventProgramRepository>();

  /// A non-competitive category has no podium: the room starts, everyone
  /// takes part, and it finishes. Mass drill and the Republic Day song are
  /// not races, and asking the head for three winners would invent some.
  bool get _competitive => widget.category.isCompetitive;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _error = false);
    try {
      final fresh = await _repo.room(_room.id);
      if (!mounted) return;
      final ids = await _repo.roomParticipantIds(_room.id);
      if (!mounted) return;
      final results = await _repo.results(_room.id);
      if (!mounted) return;
      final students = await context.read<StudentRepository>().getAll();
      if (!mounted) return;
      final entered = await _repo.participants(widget.category.id);
      if (!mounted) return;
      setState(() {
        if (fresh != null) _room = fresh;
        _participants = entered;
        _inRoom = ids.toSet();
        _places = {for (final r in results) r.position: r.participantId};
        _students = {for (final s in students) s.id: s};
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

  String _nameOf(String participantId) {
    final p = _participants.where((p) => p.id == participantId).firstOrNull;
    if (p == null) return 'Unknown';
    return _students[p.studentId]?.name.trim() ?? 'Unknown';
  }

  String _classOf(String participantId) {
    final p = _participants.where((p) => p.id == participantId).firstOrNull;
    if (p == null) return '';
    return widget.classrooms.where((c) => c.id == p.classroomId).firstOrNull?.displayName ?? '';
  }

  void _fail(Object error) => _say(EventProgramRepository.describeError(error));

  /// A sentence of our own — [EventProgramRepository.describeError] only
  /// knows how to read the database's refusals, and would flatten this one
  /// into "something went wrong".
  void _say(String message) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
  }

  // ------------------------------------------------------------ line-up --

  Future<void> _editLineUp() async {
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _LineUpSheet(
        category: widget.category,
        participants: _participants,
        selected: _inRoom,
        nameOf: _nameOf,
        classOf: _classOf,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.setRoomParticipants(_room.id, picked.toList());
      await _load();
    } catch (e) {
      _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // -------------------------------------------------------------- start --

  Future<void> _start() async {
    var count = 0;
    if (_competitive) {
      final picked = await showDialog<int>(
        context: context,
        builder: (_) => _PrizeCountDialog(
          initial: _room.prizeCount,
          participants: _inRoom.length,
        ),
      );
      if (picked == null || !mounted) return;
      count = picked;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start this room?'),
        content: Text(
          '${_inRoom.length} participant${_inRoom.length == 1 ? '' : 's'} are in '
          '${_room.name}. Once it starts, nobody can be added or removed.\n\n'
          '${_competitive ? 'It will award $count place${count == 1 ? '' : 's'}.' : 'Nobody is ranked here — everyone taking part is a participant.'}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not yet')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start event')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.startRoom(_room.id, prizeCount: _competitive ? count : 0);
      await _load();
      if (mounted) HapticFeedback.mediumImpact();
    } catch (e) {
      _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------------- places --

  Future<void> _assign(int position) async {
    final taken = {
      for (final e in _places.entries)
        if (e.key != position) e.value,
    };
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _PlacePickSheet(
        position: position,
        candidates: _inRoom.toList(),
        taken: taken,
        current: _places[position],
        nameOf: _nameOf,
        classOf: _classOf,
      ),
    );
    if (choice == null || !mounted) return;
    setState(() {
      if (choice.isEmpty) {
        _places.remove(position);
      } else {
        _places[position] = choice;
      }
    });
    await _persistPlaces();
  }

  /// Saved as it goes, so backing out of the screen mid-ceremony does not
  /// lose the places already called.
  Future<void> _persistPlaces() async {
    try {
      await _repo.saveResults(
        roomId: _room.id,
        byPosition: _places,
        recordedBy: widget.teacherId,
      );
    } catch (e) {
      _fail(e);
      await _load();
    }
  }

  Future<void> _submit() async {
    final missing = [
      if (_competitive)
        for (var i = 1; i <= _room.prizeCount; i++)
          if (!_places.containsKey(i)) i,
    ];
    if (missing.isNotEmpty) {
      _say('Assign ${missing.length == 1 ? 'the' : 'all'} '
          '${missing.map(EventStandingRecord.ordinal).join(', ')} '
          'place${missing.length == 1 ? '' : 's'} before submitting.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 34),
        title: Text(_competitive ? 'Submit these results?' : 'Finish this room?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_competitive)
              for (var i = 1; i <= _room.prizeCount; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${EventStandingRecord.ordinal(i)} place · ${_nameOf(_places[i]!)}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                )
            else
              Text('${_inRoom.length} participant${_inRoom.length == 1 ? '' : 's'} took part.',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text(
              _competitive
                  ? 'This cannot be edited afterwards. The other participants become '
                      'runners, and the admin can send certificates out.'
                  : 'This cannot be edited afterwards. Everyone here is recorded as a '
                      'participant, and the admin can send certificates out.',
              style: const TextStyle(fontSize: 12.5, height: 1.35),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Go back')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_competitive ? 'Submit' : 'Finish'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.submitRoom(_room.id);
      await _load();
      if (mounted) {
        HapticFeedback.mediumImpact();
        showSavedToast(
          context,
          title: _competitive ? 'Results submitted' : 'Room finished',
          subtitle: '${_room.name} is final.',
        );
      }
    } catch (e) {
      _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------- UI ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_room.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            Text(widget.category.name,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.onSurfaceMuted(context))),
          ],
        ),
      ),
      bottomNavigationBar: _loading || _error ? null : _action(),
      body: SafeArea(child: _body()),
    );
  }

  Widget? _action() {
    if (_room.status.isSubmitted) return null;
    final isDraft = _room.status.isDraft;
    return StickyActionBar(
      child: SizedBox(
        height: 52,
        child: FilledButton.icon(
          onPressed: _busy || (isDraft && _inRoom.isEmpty) ? null : (isDraft ? _start : _submit),
          style: isDraft ? null : FilledButton.styleFrom(backgroundColor: AppColors.error),
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(isDraft ? Icons.play_arrow_rounded : Icons.lock_rounded, size: 20),
          label: Text(
            isDraft ? 'Start event' : (_competitive ? 'Submit results' : 'Finish event'),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load this room",
        subtitle: 'Check your connection and try again.',
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _StatusBanner(room: _room, size: _inRoom.length, kind: widget.category.kind),
          const SizedBox(height: 14),
          // No podium in a non-competitive category, so no places to assign.
          if (!_room.status.isDraft && _competitive) ...[
            _SectionTitle(
              _room.status.isSubmitted ? 'Final result' : 'Assign places',
              trailing: '${_room.prizeCount} place${_room.prizeCount == 1 ? '' : 's'}',
            ),
            const SizedBox(height: 8),
            for (var i = 1; i <= _room.prizeCount; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PlaceSlot(
                  position: i,
                  participantId: _places[i],
                  name: _places[i] == null ? null : _nameOf(_places[i]!),
                  classLabel: _places[i] == null ? '' : _classOf(_places[i]!),
                  locked: _room.status.isSubmitted,
                  onTap: _room.status.isSubmitted ? null : () => _assign(i),
                ),
              ),
            const SizedBox(height: 18),
          ],
          _SectionTitle(
            _room.status.isDraft ? 'Line-up' : widget.category.kind.otherName,
            trailing: _room.status.isDraft
                ? '${_inRoom.length} in'
                : '${_inRoom.length - _places.length}',
          ),
          const SizedBox(height: 8),
          if (_inRoom.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Nobody in this room yet. Add the children competing in it.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceMuted(context)),
              ),
            )
          else
            for (final id in _inRoom.where((id) => !_places.containsValue(id)))
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: _PersonRow(name: _nameOf(id), classLabel: _classOf(id)),
              ),
          if (_room.status.isDraft) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _editLineUp,
                icon: const Icon(Icons.group_add_outlined, size: 19),
                label: Text(_inRoom.isEmpty ? 'Add participants' : 'Edit line-up'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final EventRoom room;
  final int size;
  final EventCategoryKind kind;
  const _StatusBanner({required this.room, required this.size, required this.kind});

  @override
  Widget build(BuildContext context) {
    final (color, text) = switch (room.status) {
      EventRoomStatus.draft => (
          AppColors.accent,
          'Add everyone competing in this room, then start it. Starting fixes '
              'the line-up.',
        ),
      EventRoomStatus.started => (
          AppColors.warning,
          kind.isCompetitive
              ? 'Running. Tap each place to say who won it, then submit — the '
                  'line-up is now fixed.'
              : 'Running. Nobody is ranked here — finish the room when it is done.',
        ),
      EventRoomStatus.submitted => (
          AppColors.success,
          kind.isCompetitive
              ? 'Submitted. These places are final and the admin can send out '
                  'certificates.'
              : 'Finished. Everyone here took part as a participant.',
        ),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            switch (room.status) {
              EventRoomStatus.draft => Icons.edit_outlined,
              EventRoomStatus.started => Icons.timer_outlined,
              EventRoomStatus.submitted => Icons.verified_rounded,
            },
            size: 19,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${room.status.label} · $size participant${size == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(text,
                    style: TextStyle(
                        fontSize: 12.5, height: 1.35, color: AppColors.onSurfaceMuted(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final String? trailing;
  const _SectionTitle(this.text, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: AppColors.onSurfaceMuted(context))),
        if (trailing != null)
          Text(trailing!,
              style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceHint(context))),
      ],
    );
  }
}

/// One numbered box. Empty until the head taps it and picks a child.
class _PlaceSlot extends StatelessWidget {
  final int position;
  final String? participantId;
  final String? name;
  final String classLabel;
  final bool locked;
  final VoidCallback? onTap;

  const _PlaceSlot({
    required this.position,
    required this.participantId,
    required this.name,
    required this.classLabel,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final medal = switch (position) {
      1 => AdminLook.gold,
      2 => const Color(0xFFA8B3BD),
      3 => const Color(0xFFC08552),
      _ => AppColors.accent,
    };
    final filled = participantId != null;
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: medal.withValues(alpha: filled ? 0.18 : 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: medal.withValues(alpha: filled ? 0.7 : 0.25), width: 1.4),
            ),
            child: Text(EventStandingRecord.ordinal(position),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: medal)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: filled
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      if (classLabel.isNotEmpty)
                        Text(classLabel,
                            style: TextStyle(
                                fontSize: 11.5, color: AppColors.onSurfaceMuted(context))),
                    ],
                  )
                : Text(
                    'Tap to choose the ${EventStandingRecord.ordinal(position)} place winner',
                    style: TextStyle(fontSize: 13, color: AppColors.onSurfaceHint(context)),
                  ),
          ),
          Icon(
            locked
                ? Icons.lock_rounded
                : (filled ? Icons.edit_rounded : Icons.add_circle_outline_rounded),
            size: 19,
            color: AppColors.onSurfaceHint(context),
          ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final String name;
  final String classLabel;
  const _PersonRow({required this.name, required this.classLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          if (classLabel.isNotEmpty)
            Text(classLabel,
                style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceMuted(context))),
        ],
      ),
    );
  }
}

/// How many places this room awards. Three unless the head says otherwise.
class _PrizeCountDialog extends StatefulWidget {
  final int initial;
  final int participants;
  const _PrizeCountDialog({required this.initial, required this.participants});

  @override
  State<_PrizeCountDialog> createState() => _PrizeCountDialogState();
}

class _PrizeCountDialogState extends State<_PrizeCountDialog> {
  late int _count = widget.initial;

  int get _max => widget.participants.clamp(1, 20);

  @override
  Widget build(BuildContext context) {
    final count = _count.clamp(1, _max);
    return AlertDialog(
      title: const Text('How many prizes?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Three is the usual. Everyone in the room who does not place '
            'becomes a runner.',
            style: TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.onSurfaceMuted(context)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: count <= 1 ? null : () => setState(() => _count = count - 1),
                icon: const Icon(Icons.remove_rounded),
              ),
              SizedBox(
                width: 76,
                child: Text('$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
              ),
              IconButton.filledTonal(
                onPressed: count >= _max ? null : () => setState(() => _count = count + 1),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: Text('Up to $_max, the size of this room',
                style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceHint(context))),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, count), child: const Text('Continue')),
      ],
    );
  }
}

/// Which of the category's entrants are in this room.
class _LineUpSheet extends StatefulWidget {
  final EventCategory category;
  final List<EventParticipant> participants;
  final Set<String> selected;
  final String Function(String) nameOf;
  final String Function(String) classOf;

  const _LineUpSheet({
    required this.category,
    required this.participants,
    required this.selected,
    required this.nameOf,
    required this.classOf,
  });

  @override
  State<_LineUpSheet> createState() => _LineUpSheetState();
}

class _LineUpSheetState extends State<_LineUpSheet> {
  late Set<String> _picked = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    final all = widget.participants;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Who is in this room?',
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                'Everyone entered for ${widget.category.name}, from every class.',
                style: TextStyle(fontSize: 12.5, color: AppColors.onSurfaceMuted(context)),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: all.length,
            itemBuilder: (context, i) {
              final p = all[i];
              final picked = _picked.contains(p.id);
              return CheckboxListTile(
                value: picked,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _picked.add(p.id);
                  } else {
                    _picked.remove(p.id);
                  }
                }),
                title: Text(widget.nameOf(p.id),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                subtitle: Text(widget.classOf(p.id),
                    style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceMuted(context))),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: SizedBox(
              height: 50,
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _picked),
                child: Text('Save line-up · ${_picked.length}'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Picking who took one place. Children already given another place are
/// shown, but cannot be picked twice.
class _PlacePickSheet extends StatelessWidget {
  final int position;
  final List<String> candidates;
  final Set<String> taken;
  final String? current;
  final String Function(String) nameOf;
  final String Function(String) classOf;

  const _PlacePickSheet({
    required this.position,
    required this.candidates,
    required this.taken,
    required this.current,
    required this.nameOf,
    required this.classOf,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${EventStandingRecord.ordinal(position)} place',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text('Pick the child who came ${EventStandingRecord.ordinal(position)}.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.onSurfaceMuted(context))),
            ],
          ),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: candidates.length,
            itemBuilder: (context, i) {
              final id = candidates[i];
              final blocked = taken.contains(id);
              return ListTile(
                enabled: !blocked,
                dense: true,
                onTap: blocked ? null : () => Navigator.pop(context, id),
                leading: Icon(
                  current == id ? Icons.radio_button_checked_rounded : Icons.person_outline_rounded,
                  color: current == id ? AppColors.accent : AppColors.onSurfaceHint(context),
                ),
                title: Text(nameOf(id),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  blocked ? 'Already given another place' : classOf(id),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: blocked ? AppColors.warning : AppColors.onSurfaceMuted(context),
                  ),
                ),
              );
            },
          ),
        ),
        if (current != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context, ''),
                icon: const Icon(Icons.backspace_outlined, size: 18),
                label: const Text('Clear this place'),
              ),
            ),
          ),
      ],
    );
  }
}
