import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:go_router/go_router.dart';
import 'event_bloc.dart';
import 'compose_event_screen.dart';
import 'event_detail_screen.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  SchoolEventsLoaded? _cached;

  @override
  void initState() {
    super.initState();
    context.read<SchoolEventBloc>().add(LoadSchoolEvents());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<SchoolEventBloc, SchoolEventState>(
        builder: (context, state) {
          if (state is SchoolEventsLoaded) {
            _cached = state;
          }
          if (state is SchoolEventLoading && _cached == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is SchoolEventError && _cached == null) {
            return Center(child: Text(state.message, style: const TextStyle(color: AppColors.error)));
          }
          final loaded = state is SchoolEventsLoaded ? state : _cached;
          if (loaded != null) {
            if (loaded.events.isEmpty) {
              return EmptyState(
                icon: Icons.event_available_rounded,
                title: 'No events yet',
                subtitle: 'Compose an event and notify families',
                actionLabel: 'Compose event',
                onAction: () => _openCompose(context),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              itemCount: loaded.events.length,
              itemBuilder: (context, index) {
                final event = loaded.events[index];
                return AnimatedListItem(
                  index: index,
                  child: _EventCard(
                    event: event,
                    families: loaded.noticeCounts[event.id] ?? 0,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: context.read<SchoolEventBloc>(),
                            child: EventDetailScreen(event: event, families: loaded.noticeCounts[event.id] ?? 0),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          }
          return const SizedBox();
        },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCompose(context),
        icon: Icon(Icons.edit_calendar_rounded),
        label: Text('Compose'),
        shape: const StadiumBorder(),
      ),
    );
  }

  Future<void> _openCompose(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<SchoolEventBloc>(),
          child: const ComposeEventScreen(),
        ),
      ),
    );
    if (context.mounted) {
      context.read<SchoolEventBloc>().add(LoadSchoolEvents());
    }
  }
}

class _EventCard extends StatelessWidget {
  final SchoolEvent event;
  final int families;
  final VoidCallback onTap;

  const _EventCard({required this.event, required this.families, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.eventCard.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.event_rounded, color: AppColors.eventCard),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      event.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface(context),
                      ),
                    ),
                  ),
                  StatusPill(
                    label: event.isSchoolWide ? 'Whole school' : 'Selected classes',
                    color: event.isSchoolWide ? AppColors.accent : AppColors.eventCard,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                event.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 12),
              Text(
                '${_pretty(event.eventDate)} · ${event.requiresFee ? '₹${event.feeAmount.toStringAsFixed(0)} / student' : 'No fee'} · $families families notified',
                style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _pretty(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
