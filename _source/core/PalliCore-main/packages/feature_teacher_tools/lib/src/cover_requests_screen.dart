import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

/// Lets a teacher accept/reject requests from colleagues asking them to
/// cover one of their periods for the day, and see the status of requests
/// they've sent out themselves.
class CoverRequestsScreen extends StatefulWidget {
  final String teacherId;
  const CoverRequestsScreen({super.key, required this.teacherId});

  @override
  State<CoverRequestsScreen> createState() => _CoverRequestsScreenState();
}

class _CoverRequestsScreenState extends State<CoverRequestsScreen> {
  List<PeriodReassignment> _all = [];
  Map<String, String> _teacherNames = {};
  bool _loading = true;
  StreamSubscription<dynamic>? _sub;

  PeriodReassignmentRepository get _repo => context.read<PeriodReassignmentRepository>();

  @override
  void initState() {
    super.initState();
    _load();
    _sub = _repo.watch().listen((items) {
      if (mounted && items.isNotEmpty) setState(() => _all = items);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await _repo.getAll();
    final teachers = await context.read<TeacherRepository>().getAll();
    if (!mounted) return;
    setState(() {
      _all = items;
      _teacherNames = {for (final t in teachers) t.id: t.name};
      _loading = false;
    });
  }

  List<PeriodReassignment> get _incoming => _all
      .where((r) => r.toStaffId == widget.teacherId && r.status == PeriodReassignmentStatus.pending)
      .toList();

  List<PeriodReassignment> get _sent =>
      [...(_all.where((r) => r.fromStaffId == widget.teacherId))]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cover requests')),
      body: SafeArea(
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_incoming.isEmpty && _sent.isEmpty)
              ? const EmptyState(
                  icon: Icons.swap_horiz_rounded,
                  title: 'Nothing here yet',
                  subtitle: 'Requests to cover a colleague\'s period, and ones you send, show up here.',
                )
              : RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    children: [
                      if (_incoming.isNotEmpty) ...[
                        const Text('Requests for you', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 8),
                        ..._incoming.map(_incomingCard),
                        const SizedBox(height: 20),
                      ],
                      if (_sent.isNotEmpty) ...[
                        const Text('Sent by you', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 8),
                        ..._sent.map(_sentCard),
                      ],
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _incomingCard(PeriodReassignment r) {
    final fromName = _teacherNames[r.fromStaffId] ?? 'A teacher';
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.periodName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            '$fromName wants you to cover this — today at ${Schedule.format12(r.startTime)}, ${r.durationMinutes} min',
            style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () => _respond(r, PeriodReassignmentStatus.rejected),
                child: const Text('Decline'),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => _respond(r, PeriodReassignmentStatus.accepted),
                child: const Text('Accept'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sentCard(PeriodReassignment r) {
    final toName = _teacherNames[r.toStaffId] ?? 'A teacher';
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.periodName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text('Asked $toName · ${Schedule.format12(r.startTime)}', style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12)),
              ],
            ),
          ),
          StatusPill(label: _statusLabel(r.status), color: _statusColor(r.status)),
        ],
      ),
    );
  }

  Future<void> _respond(PeriodReassignment r, PeriodReassignmentStatus status) async {
    if (status == PeriodReassignmentStatus.accepted) {
      await context.read<TimetableRepository>().addTemporaryCoverage(
            timetableId: r.timetableId,
            original: Period(
              id: r.periodId,
              name: r.periodName,
              staffId: r.fromStaffId,
              startTime: r.startTime,
              durationMinutes: r.durationMinutes,
              dayOfWeek: r.dayOfWeek,
            ),
            substituteStaffId: widget.teacherId,
            date: r.periodDate,
          );
    }
    await _repo.respond(r, status: status);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status == PeriodReassignmentStatus.accepted
            ? 'You\'re covering "${r.periodName}" today.'
            : 'Declined. The original teacher has been notified.')),
      );
    }
  }

  String _statusLabel(PeriodReassignmentStatus s) => switch (s) {
        PeriodReassignmentStatus.pending => 'pending',
        PeriodReassignmentStatus.accepted => 'accepted',
        PeriodReassignmentStatus.rejected => 'declined',
      };

  Color _statusColor(PeriodReassignmentStatus s) => switch (s) {
        PeriodReassignmentStatus.pending => AppColors.warning,
        PeriodReassignmentStatus.accepted => AppColors.success,
        PeriodReassignmentStatus.rejected => AppColors.error,
      };
}
