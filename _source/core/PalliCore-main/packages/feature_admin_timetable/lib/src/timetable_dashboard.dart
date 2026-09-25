import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:core_models/core_models.dart';
import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart';
import 'timetable_bloc.dart';
import 'timetable_screen.dart';

class TimetableDashboard extends StatelessWidget {
  final String classroomId;

  const TimetableDashboard({super.key, required this.classroomId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TimetableBloc(context.read())..add(LoadTimetables(classroomId)),
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Timetables'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.go('/admin/classrooms'),
            ),
          ),
          body: SafeArea(
            child: BlocConsumer<TimetableBloc, TimetableState>(
            listener: (context, state) {
              if (state is TimetableError) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
              }
            },
            builder: (context, state) {
              if (state is TimetableLoading || state is TimetableInitial) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is TimetablesLoaded) {
                if (state.timetables.isEmpty) {
                  return EmptyState(
                    icon: Icons.calendar_month_rounded,
                    title: 'No timetable yet',
                    subtitle: 'Compose a weekly schedule for this classroom',
                    actionLabel: 'Create timetable',
                    onAction: () => _createPreset(context),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  itemCount: state.timetables.length,
                  itemBuilder: (context, index) {
                    final timetable = state.timetables[index];
                    return AnimatedListItem(
                      index: index,
                      delay: const Duration(milliseconds: 20),
                      duration: const Duration(milliseconds: 280),
                      child: _PresetCard(
                        timetable: timetable,
                        onActivate: () => _activate(context, timetable),
                        onOpen: () => _openEditor(context, timetable),
                        onDelete: () => _confirmDelete(context, timetable),
                      ),
                    );
                  },
                );
              }
              if (state is TimetableError) {
                return EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load timetables', subtitle: state.message);
              }
              return const SizedBox.shrink();
            },
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _createPreset(context),
            icon: const Icon(Icons.add),
            label: const Text('New timetable'),
            shape: const StadiumBorder(),
          ),
        ),
      ),
    );
  }

  /// "Set active" from the list publishes a whole week at once, so it gets
  /// the same double-booking check as the editor — a draft written before
  /// the rule existed must not go live silently.
  Future<void> _activate(BuildContext context, Timetable timetable) async {
    final bloc = context.read<TimetableBloc>();
    try {
      final (teachers, classrooms, timetables) = await (
        context.read<TeacherRepository>().getAll(),
        context.read<ClassroomRepository>().getAll(),
        context.read<TimetableRepository>().getAll(),
      ).wait;
      final names = {for (final c in classrooms) c.id: c.displayName};
      final staffNames = {for (final t in teachers) t.id: t.name};
      final clashes = StaffAvailability.clashesAgainst(
        timetable.periods,
        others: StaffAvailability.bookings(
          timetables,
          excludeClassroomIds: {classroomId},
          classroomNames: names,
        ),
        timetableId: timetable.id,
        timetableName: timetable.name,
        classroomId: classroomId,
        classroomName: names[classroomId] ?? classroomId,
      );
      if (clashes.isNotEmpty && context.mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Teachers are double-booked'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activating "${timetable.name}" would put a teacher in two classrooms '
                  'at the same time:',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 10),
                for (final clash in clashes.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• ${staffNames[clash.staffId] ?? clash.staffId} — ${clash.a.dayOfWeek} '
                      '${clash.a.range}: ${clash.a.periodName} here and ${clash.b.periodName} '
                      'for ${clash.b.classroomName}',
                      style: TextStyle(fontSize: 13, height: 1.35, color: AppColors.onSurfaceMuted(ctx)),
                    ),
                  ),
                if (clashes.length > 4)
                  Text('…and ${clashes.length - 4} more',
                      style: TextStyle(fontSize: 13, color: AppColors.onSurfaceMuted(ctx))),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Open and fix')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Activate anyway'),
              ),
            ],
          ),
        );
        if (proceed != true) {
          if (context.mounted) _openEditor(context, timetable);
          return;
        }
      }
    } catch (_) {
      // Offline: the editor's own check still runs every time a period is
      // saved, so don't block publishing on a failed lookup.
    }
    bloc.add(ActivateTimetable(timetable.id, classroomId));
  }

  void _openEditor(BuildContext context, Timetable timetable) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<TimetableBloc>(),
          child: TimetableScreen(timetable: timetable),
        ),
      ),
    );
  }

  void _createPreset(BuildContext context) {
    final nameController = TextEditingController();
    TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 30);
    TimeOfDay endTime = const TimeOfDay(hour: 15, minute: 30);
    var intervalCount = 8;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
          child: StatefulBuilder(
            builder: (ctx, setDialogState) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(99)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('New timetable', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, letterSpacing: -0.4)),
                      const SizedBox(height: 6),
                      Text('Name the preset, set school hours, then compose periods.', style: TextStyle(color: AppColors.onSurfaceMuted(context))),
                      const SizedBox(height: 20),
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        decoration: const InputDecoration(labelText: 'Preset name', hintText: 'Regular week'),
                      ),
                      const SizedBox(height: 14),
                      _TimeRow(label: 'Day starts', time: startTime, onChanged: (t) => setDialogState(() => startTime = t)),
                      const SizedBox(height: 10),
                      _TimeRow(label: 'Day ends', time: endTime, onChanged: (t) => setDialogState(() => endTime = t)),
                      const SizedBox(height: 16),
                      Text('Periods per day: $intervalCount', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Slider(
                        value: intervalCount.toDouble(),
                        min: 4,
                        max: 12,
                        divisions: 8,
                        label: '$intervalCount',
                        onChanged: (value) => setDialogState(() => intervalCount = value.round()),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;
                          // First timetable for this classroom goes live immediately —
                          // there's nothing else it could conflict with, and it avoids
                          // the classroom silently having no schedule until someone
                          // remembers to hit "Set active" separately.
                          final currentState = context.read<TimetableBloc>().state;
                          final isFirst = currentState is TimetablesLoaded && currentState.timetables.isEmpty;
                          final timetable = Timetable(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            classroomId: classroomId,
                            name: name,
                            isActive: isFirst,
                            periods: const [],
                            startTime: _format(startTime),
                            endTime: _format(endTime),
                            intervalCount: intervalCount,
                          );
                          context.read<TimetableBloc>().add(CreateTimetable(timetable));
                          Navigator.pop(sheetContext);
                          _openEditor(context, timetable);
                        },
                        child: const Text('Create and compose'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, Timetable timetable) {
    showDialog<void>(
      context: context,
      builder: (_) => VerificationDialog(
        title: 'Delete timetable',
        content: 'This removes "${timetable.name}" including every period. Type Delete to confirm.',
        onConfirm: () => context.read<TimetableBloc>().add(DeleteTimetable(timetable.id, classroomId)),
      ),
    );
  }

  String _format(TimeOfDay time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

class _PresetCard extends StatelessWidget {
  final Timetable timetable;
  final VoidCallback onActivate;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _PresetCard({required this.timetable, required this.onActivate, required this.onOpen, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      depth: SoftDepth.two,
      borderRadius: BorderRadius.circular(22),
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.calendar_month_rounded, color: AppColors.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(timetable.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          '${_format12(timetable.startTime)} – ${_format12(timetable.endTime)} · ${timetable.periods.length} periods',
                          style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (timetable.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(20)),
                      child: const Text('ACTIVE', style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                    )
                  else
                    TextButton(onPressed: onActivate, child: const Text('Set active')),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  ),
                  FilledButton.tonal(
                    onPressed: onOpen,
                    child: const Text('Compose'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _format12(String value) {
    final parts = value.split(':');
    final hour = int.parse(parts[0]);
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${parts[1]} $suffix';
  }
}

class _TimeRow extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onChanged;

  const _TimeRow({required this.label, required this.time, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(14),
      child: SoftSurface(
        depth: SoftDepth.two,
        borderRadius: BorderRadius.circular(14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(label, style: TextStyle(color: AppColors.onSurfaceMuted(context))),
            const Spacer(),
            Text(time.format(context), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            const Icon(Icons.schedule, size: 18, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}
