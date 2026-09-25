import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import 'certificate_publish_sheet.dart';

/// What the school did on the day, as the admin sees it: every room of a
/// category, who placed in it, and the button that sends the certificates out.
class EventResultsScreen extends StatefulWidget {
  final SchoolEvent event;
  final EventCategory category;

  const EventResultsScreen({super.key, required this.event, required this.category});

  static Future<void> open(
    BuildContext context, {
    required SchoolEvent event,
    required EventCategory category,
  }) =>
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventResultsScreen(event: event, category: category)),
      );

  @override
  State<EventResultsScreen> createState() => _EventResultsScreenState();
}

class _EventResultsScreenState extends State<EventResultsScreen> {
  List<EventRoom> _rooms = const [];
  Map<String, List<EventStandingRecord>> _standings = const {};
  Map<String, EventCertificate> _published = const {};
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
      final standings = await loadRoomStandings(context, repo: _repo, rooms: rooms);
      if (!mounted) return;
      final certs = await _repo.certificates([for (final r in rooms) r.id]);
      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        _standings = standings;
        _published = {for (final c in certs) c.roomId: c};
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.category.name} · results', overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load results",
        subtitle: 'Check your connection and try again.',
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    if (_rooms.isEmpty) {
      return const EmptyState(
        icon: Icons.meeting_room_outlined,
        title: 'No rooms yet',
        subtitle: "The head of this category creates rooms on the day. Results appear "
            'here as soon as they submit one.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
        itemCount: _rooms.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final room = _rooms[i];
          return AnimatedListItem(
            index: i,
            child: _RoomResultCard(
              room: room,
              category: widget.category,
              standings: _standings[room.id] ?? const [],
              certificate: _published[room.id],
              onDistribute: () => _distribute(room),
            ),
          );
        },
      ),
    );
  }

  Future<void> _distribute(EventRoom room) async {
    final changed = await CertificatePublishSheet.open(
      context,
      event: widget.event,
      category: widget.category,
      room: room,
      standings: _standings[room.id] ?? const [],
      current: _published[room.id],
    );
    if (changed == true) await _load();
  }
}

/// Turns each room's places into a printable standing for every child in it —
/// the placed ones in order, then the runners. Shared by the admin's results
/// screen and the certificate sheet so both name the same people.
Future<Map<String, List<EventStandingRecord>>> loadRoomStandings(
  BuildContext context, {
  required EventProgramRepository repo,
  required List<EventRoom> rooms,
}) async {
  if (rooms.isEmpty) return const {};
  final categoryIds = {for (final r in rooms) r.categoryId};
  final participants = <EventParticipant>[];
  for (final id in categoryIds) {
    participants.addAll(await repo.participants(id));
  }
  if (!context.mounted) return const {};
  final students = await context.read<StudentRepository>().getAll();
  if (!context.mounted) return const {};
  final classrooms = await context.read<ClassroomRepository>().getAll();
  if (!context.mounted) return const {};
  final results = await repo.resultsForRooms([for (final r in rooms) r.id]);

  final studentById = {for (final s in students) s.id: s};
  final roomName = {for (final c in classrooms) c.id: c.displayName};
  final participantById = {for (final p in participants) p.id: p};

  final out = <String, List<EventStandingRecord>>{};
  for (final room in rooms) {
    final ids = await repo.roomParticipantIds(room.id);
    final placed = {
      for (final r in results.where((r) => r.roomId == room.id)) r.participantId: r.position,
    };
    final records = <EventStandingRecord>[
      for (final id in ids)
        if (participantById[id] case final p?)
          EventStandingRecord(
            participantId: id,
            studentId: p.studentId,
            studentName: studentById[p.studentId]?.name.trim() ?? 'Unknown',
            classroomLabel: roomName[p.classroomId] ?? '',
            position: placed[id],
          ),
    ];
    // Placed first, in order; then the runners by name.
    records.sort((a, b) {
      if (a.position != null && b.position != null) return a.position!.compareTo(b.position!);
      if (a.position != null) return -1;
      if (b.position != null) return 1;
      return a.studentName.toLowerCase().compareTo(b.studentName.toLowerCase());
    });
    out[room.id] = records;
  }
  return out;
}

class _RoomResultCard extends StatelessWidget {
  final EventRoom room;
  final EventCategory category;
  final List<EventStandingRecord> standings;
  final EventCertificate? certificate;
  final VoidCallback onDistribute;

  const _RoomResultCard({
    required this.room,
    required this.category,
    required this.standings,
    required this.certificate,
    required this.onDistribute,
  });

  @override
  Widget build(BuildContext context) {
    final mute = AppColors.onSurfaceMuted(context);
    final winners = standings.where((s) => s.standing.isWinner).toList();
    final runners = standings.where((s) => !s.standing.isWinner).toList();
    final done = room.status.isSubmitted;
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(room.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              StatusPill(
                label: room.status.label,
                color: done ? AppColors.success : AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${standings.length} participant${standings.length == 1 ? '' : 's'}'
            '${category.isCompetitive ? ' · ${room.prizeCount} place${room.prizeCount == 1 ? '' : 's'}' : ' · not ranked'}',
            style: TextStyle(fontSize: 12.5, color: mute),
          ),
          if (!done) ...[
            const SizedBox(height: 12),
            Text(
              room.status.isDraft
                  ? 'The head has not started this room yet.'
                  : 'Running now — results appear once the head submits them.',
              style: TextStyle(fontSize: 12.5, color: mute),
            ),
          ] else ...[
            const SizedBox(height: 14),
            for (final w in winners) _WinnerRow(record: w),
            if (runners.isNotEmpty) ...[
              if (winners.isNotEmpty) const SizedBox(height: 10),
              Text('${category.kind.otherName.toUpperCase()} · ${runners.length}',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: mute)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in runners)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(r.studentName,
                          style: TextStyle(fontSize: 11.5, color: AppColors.onSurface(context))),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            if (!category.issuesCertificates)
              Row(
                children: [
                  Icon(Icons.workspace_premium_outlined, size: 17, color: mute),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('This category does not issue certificates.',
                        style: TextStyle(fontSize: 12.5, color: mute)),
                  ),
                ],
              )
            else
            Row(
              children: [
                if (certificate != null) ...[
                  const Icon(Icons.verified_rounded, size: 17, color: AppColors.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Certificates published',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.success)),
                  ),
                  TextButton(onPressed: onDistribute, child: const Text('Change layout')),
                ] else
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: onDistribute,
                        icon: const Icon(Icons.workspace_premium_rounded, size: 19),
                        label: const Text('Distribute certificates'),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WinnerRow extends StatelessWidget {
  final EventStandingRecord record;
  const _WinnerRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final medal = switch (record.position) {
      1 => AdminLook.gold,
      2 => const Color(0xFFA8B3BD),
      3 => const Color(0xFFC08552),
      _ => AppColors.accent,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: medal.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Text('${record.position}',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: medal)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                if (record.classroomLabel.isNotEmpty)
                  Text(record.classroomLabel,
                      style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceMuted(context))),
              ],
            ),
          ),
          Text(record.placeLabel,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: medal)),
        ],
      ),
    );
  }
}
