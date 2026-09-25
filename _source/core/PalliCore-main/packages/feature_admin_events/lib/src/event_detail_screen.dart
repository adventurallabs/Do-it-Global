import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'event_bloc.dart';
import 'event_categories_screen.dart';

class EventDetailScreen extends StatelessWidget {
  final SchoolEvent event;
  final int families;

  const EventDetailScreen({super.key, required this.event, required this.families});

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => SimpleConfirmDialog(
        title: 'Delete event',
        content: 'Are you sure you want to delete "${event.name}"? Parents who were notified will no longer see it.',
        onConfirm: () {
          context.read<SchoolEventBloc>().add(DeleteSchoolEvent(event.id));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SchoolEventBloc, SchoolEventState>(
      listener: (context, state) {
        if (state is SchoolEventsLoaded && !state.events.any((e) => e.id == event.id)) {
          Navigator.pop(context);
        }
        if (state is SchoolEventError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
          );
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(event.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete event',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(20),
      child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusPill(
                  label: event.isSchoolWide ? 'Whole school' : 'Selected classrooms',
                  color: AppColors.eventCard,
                ),
                const SizedBox(height: 16),
                Text(
                  event.description,
                  style: TextStyle(color: AppColors.onSurface(context), fontSize: 15, height: 1.45),
                ),
                const SizedBox(height: 20),
                _row(context, 'Event date', _pretty(event.eventDate)),
                if (event.requiresFee) ...[
                  _row(context, 'Fee per student', '₹${event.feeAmount.toStringAsFixed(0)}'),
                  if (event.lastPayDate != null) _row(context, 'Last date to pay', _pretty(event.lastPayDate!)),
                ] else
                  _row(context, 'Fee', 'No payment required'),
                _row(context, 'Families notified', '$families'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Sports Day is one event made of many contests. Everything about
          // who ran what, and who won, hangs off a category.
          SoftSurface(
            depth: SoftDepth.one,
            borderRadius: BorderRadius.circular(20),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            onTap: () => EventCategoriesScreen.open(context, event),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_outlined, color: AppColors.eventCard),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Categories and heads',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 3),
                      Text(
                        'Add the contests in this event, give each a head teacher, '
                        'and see who won.',
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
        ],
        ),
      ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.onSurface(context))),
          ),
        ],
      ),
    );
  }

  String _pretty(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
