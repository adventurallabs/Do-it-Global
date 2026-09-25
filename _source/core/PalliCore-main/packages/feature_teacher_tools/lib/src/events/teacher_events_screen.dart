import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import 'event_category_screen.dart';

/// What a teacher who heads a category sees of events.
///
/// A teacher who heads nothing never gets here — the dashboard card that
/// leads to it is not drawn for them.
class TeacherEventsScreen extends StatefulWidget {
  final String teacherId;
  const TeacherEventsScreen({super.key, required this.teacherId});

  static Future<void> open(BuildContext context, {required String teacherId}) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TeacherEventsScreen(teacherId: teacherId)),
      );

  @override
  State<TeacherEventsScreen> createState() => _TeacherEventsScreenState();
}

class _TeacherEventsScreenState extends State<TeacherEventsScreen> {
  List<EventCategory> _mine = const [];
  Map<String, SchoolEvent> _events = const {};
  Map<String, int> _entered = const {};
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
      final mine = await _repo.categoriesHeadedBy(widget.teacherId);
      if (!mounted) return;
      final events = await context.read<SchoolEventRepository>().getAll();
      if (!mounted) return;
      final counts = <String, int>{};
      for (final c in mine) {
        counts[c.id] = (await _repo.participants(c.id)).length;
      }
      if (!mounted) return;
      setState(() {
        _mine = mine;
        _events = {for (final e in events) e.id: e};
        _entered = counts;
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
      appBar: AppBar(title: const Text('My events')),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load your events",
        subtitle: 'Check your connection and try again.',
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    if (_mine.isEmpty) {
      return const EmptyState(
        icon: Icons.emoji_events_outlined,
        title: 'Nothing assigned to you',
        subtitle: 'When the admin makes you head of an event category, it appears here.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        itemCount: _mine.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final category = _mine[i];
          final event = _events[category.eventId];
          return AnimatedListItem(
            index: i,
            child: _CategoryCard(
              category: category,
              event: event,
              entered: _entered[category.id] ?? 0,
              onTap: event == null
                  ? null
                  : () async {
                      await EventCategoryScreen.open(
                        context,
                        teacherId: widget.teacherId,
                        event: event,
                        category: category,
                      );
                      if (mounted) _load();
                    },
            ),
          );
        },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final EventCategory category;
  final SchoolEvent? event;
  final int entered;
  final VoidCallback? onTap;

  const _CategoryCard({
    required this.category,
    required this.event,
    required this.entered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final mute = AppColors.onSurfaceMuted(context);
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.eventCard.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.emoji_events_rounded, size: 21, color: AppColors.eventCard),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  event?.name ?? 'Event removed',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: mute),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.groups_2_outlined, size: 14, color: AppColors.accent),
                    const SizedBox(width: 5),
                    Text(
                      entered == 0
                          ? 'No participants entered yet'
                          : '$entered participant${entered == 1 ? '' : 's'} entered',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: entered == 0 ? mute : AppColors.accent),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceHint(context)),
        ],
      ),
    );
  }
}

/// The card on the teacher's dashboard, drawn only for a head.
///
/// A teacher who heads nothing gets nothing: an events tile that opened onto
/// "nothing assigned to you" would be a permanent piece of clutter on every
/// other teacher's home screen.
class TeacherEventsCard extends StatefulWidget {
  final String teacherId;

  /// Changes whenever the dashboard reloads, so the card re-reads with it.
  final Object? refreshToken;

  const TeacherEventsCard({super.key, required this.teacherId, this.refreshToken});

  @override
  State<TeacherEventsCard> createState() => _TeacherEventsCardState();
}

class _TeacherEventsCardState extends State<TeacherEventsCard> {
  List<EventCategory> _mine = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TeacherEventsCard old) {
    super.didUpdateWidget(old);
    if (old.teacherId != widget.teacherId || old.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load() async {
    try {
      final mine = await context.read<EventProgramRepository>().categoriesHeadedBy(widget.teacherId);
      if (mounted) {
        setState(() {
          _mine = mine;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _mine.isEmpty) return const SizedBox.shrink();
    final names = _mine.map((c) => c.name).join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftSurface(
        depth: SoftDepth.one,
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        onTap: () => TeacherEventsScreen.open(context, teacherId: widget.teacherId),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AdminLook.gold.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.emoji_events_rounded, color: AdminLook.gold, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _mine.length == 1 ? 'Event head' : 'Event head · ${_mine.length} categories',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    names,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5, height: 1.3, color: AppColors.onSurfaceMuted(context)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceHint(context)),
          ],
        ),
      ),
    );
  }
}
