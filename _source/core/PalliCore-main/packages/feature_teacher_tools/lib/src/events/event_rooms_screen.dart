import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import 'event_room_screen.dart';

/// The rooms a category is contested in — heats, matches, rounds.
///
/// A category can have as many as the day needs, and each carries its own
/// line-up and its own set of places.
class EventRoomsTab extends StatefulWidget {
  final String teacherId;
  final SchoolEvent event;
  final EventCategory category;
  final List<EventParticipant> participants;
  final List<Classroom> classrooms;

  const EventRoomsTab({
    super.key,
    required this.teacherId,
    required this.event,
    required this.category,
    required this.participants,
    required this.classrooms,
  });

  @override
  State<EventRoomsTab> createState() => _EventRoomsTabState();
}

class _EventRoomsTabState extends State<EventRoomsTab> {
  List<EventRoom> _rooms = const [];
  Map<String, int> _sizes = const {};
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
      final rooms = await _repo.rooms(widget.category.id);
      if (!mounted) return;
      final sizes = <String, int>{};
      for (final r in rooms) {
        sizes[r.id] = (await _repo.roomParticipantIds(r.id)).length;
      }
      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        _sizes = sizes;
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

  void _fail(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(EventProgramRepository.describeError(error)),
        backgroundColor: AppColors.error,
      ));
  }

  Future<void> _newRoom() async {
    final suggested = 'Round ${_rooms.length + 1}';
    final controller = TextEditingController(text: suggested);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New room'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Room name',
            hintText: 'Heat 1, Final, Under-10…',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      final room = EventRoom(
        id: EventProgramRepository.newId('er'),
        categoryId: widget.category.id,
        name: name,
        createdBy: widget.teacherId,
      );
      await _repo.saveRoom(room);
      await _load();
      if (mounted) _open(room);
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _open(EventRoom room) async {
    await EventRoomScreen.open(
      context,
      teacherId: widget.teacherId,
      event: widget.event,
      category: widget.category,
      room: room,
      participants: widget.participants,
      classrooms: widget.classrooms,
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load rooms",
        subtitle: 'Check your connection and try again.',
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    if (widget.participants.isEmpty) {
      return const EmptyState(
        icon: Icons.groups_2_outlined,
        title: 'Enter participants first',
        subtitle: 'A room is a group of the children already entered for this category. '
            'Add them on the Participants tab, then come back on the day.',
      );
    }
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            itemCount: _rooms.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 2),
                  child: Text(
                    _rooms.isEmpty
                        ? 'On the day, make a room for each heat or match and put the '
                            'children in it.'
                        : '${_rooms.length} room${_rooms.length == 1 ? '' : 's'} · '
                            '${widget.participants.length} entered for this category',
                    style: TextStyle(
                        fontSize: 12.5, height: 1.35, color: AppColors.onSurfaceMuted(context)),
                  ),
                );
              }
              final room = _rooms[i - 1];
              return _RoomCard(
                room: room,
                size: _sizes[room.id] ?? 0,
                onTap: () => _open(room),
              );
            },
          ),
        ),
        Positioned(
          right: 4,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'new-room',
            onPressed: _newRoom,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New room'),
            shape: const StadiumBorder(),
          ),
        ),
      ],
    );
  }
}

class _RoomCard extends StatelessWidget {
  final EventRoom room;
  final int size;
  final VoidCallback onTap;

  const _RoomCard({required this.room, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (room.status) {
      EventRoomStatus.draft => (AppColors.onSurfaceHint(context), Icons.edit_outlined),
      EventRoomStatus.started => (AppColors.warning, Icons.timer_outlined),
      EventRoomStatus.submitted => (AppColors.success, Icons.verified_rounded),
    };
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  '$size participant${size == 1 ? '' : 's'}'
                  '${room.status.isDraft ? '' : ' · ${room.prizeCount} place${room.prizeCount == 1 ? '' : 's'}'}',
                  style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted(context)),
                ),
              ],
            ),
          ),
          StatusPill(label: room.status.label, color: color),
          Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceHint(context)),
        ],
      ),
    );
  }
}
