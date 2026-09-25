import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'ops_format.dart';

/// Queue of parent-raised student leave / absence / late requests.
/// Used by admins and by class teachers (pass the reviewer's id).
class StudentLeaveDeskScreen extends StatefulWidget {
  final String reviewerId;
  final bool showBack;
  const StudentLeaveDeskScreen({
    super.key,
    required this.reviewerId,
    this.showBack = true,
  });

  @override
  State<StudentLeaveDeskScreen> createState() => _StudentLeaveDeskScreenState();
}

class _StudentLeaveDeskScreenState extends State<StudentLeaveDeskScreen> {
  List<StudentLeaveRequest> _requests = [];
  Map<String, String> _studentNames = {};
  bool _loading = true;
  bool _hasError = false;
  bool _pendingOnly = true;
  StreamSubscription<dynamic>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = context.read<StudentLeaveRepository>().watch().listen((requests) {
      if (mounted && requests.isNotEmpty) setState(() => _requests = requests);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final (requests, students) = await (
        context.read<StudentLeaveRepository>().getAll(),
        context.read<StudentRepository>().getAll(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _studentNames = {for (final s in students) s.id: s.name};
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  List<StudentLeaveRequest> get _visible => _pendingOnly
      ? _requests
          .where((r) =>
              r.status == StudentLeaveStatus.requested ||
              r.status == StudentLeaveStatus.underReview)
          .toList()
      : _requests;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student leave & absence'),
        leading: widget.showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.maybePop(context),
              )
            : null,
        actions: [
          IconButton(
            tooltip: _pendingOnly ? 'Show all' : 'Show pending only',
            icon: Icon(_pendingOnly ? Icons.filter_list_rounded : Icons.filter_list_off_rounded),
            onPressed: () => setState(() => _pendingOnly = !_pendingOnly),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
          ? EmptyState(
              icon: Icons.cloud_off_rounded,
              title: "Couldn't load requests",
              subtitle: 'Check your connection and try again.',
              actionLabel: 'Retry',
              onAction: _load,
            )
          : _visible.isEmpty
              ? const EmptyState(
                  icon: Icons.event_available_rounded,
                  title: 'Nothing to review',
                  subtitle: 'Parent leave and absence requests will show up here.',
                )
              : RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    itemCount: _visible.length,
                    itemBuilder: (context, index) => _card(_visible[index]),
                  ),
                ),
      ),
    );
  }

  Widget _card(StudentLeaveRequest r) {
    final name = _studentNames[r.studentId] ?? 'Student';
    final dates = r.toDate == null || r.durationDays <= 1
        ? prettyDate(r.fromDate)
        : '${prettyDate(r.fromDate)} – ${prettyDate(r.toDate!)}  (${r.durationDays} days)';
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              StatusPill(label: _statusLabel(r.status), color: _statusColor(r.status)),
            ],
          ),
          const SizedBox(height: 6),
          Text(_kindLabel(r.kind),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text(dates, style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13)),
          const SizedBox(height: 4),
          Text(r.reason, style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 13)),
          if (r.reviewNote != null && r.reviewNote!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Note: ${r.reviewNote}',
                style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 12)),
          ],
          if (r.status == StudentLeaveStatus.requested ||
              r.status == StudentLeaveStatus.underReview) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => _review(r, StudentLeaveStatus.rejected),
                  child: const Text('Reject'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _review(r, StudentLeaveStatus.approved),
                  child: Text(r.kind == StudentLeaveKind.leave
                      ? 'Approve & mark excused'
                      : 'Acknowledge'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _review(StudentLeaveRequest r, StudentLeaveStatus status) async {
    String? note;
    if (status == StudentLeaveStatus.rejected) {
      note = await _askNote(context);
      if (note == null) return;
    }
    await context.read<StudentLeaveRepository>().review(
          r,
          status: status,
          reviewedBy: widget.reviewerId,
          note: note,
        );
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == StudentLeaveStatus.approved
              ? 'Approved. Parent notified.'
              : 'Rejected. Parent notified.'),
        ),
      );
    }
  }

  Future<String?> _askNote(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reason for rejection'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Shared with the parent'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  String _kindLabel(StudentLeaveKind kind) => switch (kind) {
        StudentLeaveKind.leave => 'Leave request',
        StudentLeaveKind.lateInfo => 'Arriving late',
        StudentLeaveKind.absentInfo => 'Absence notice',
      };

  String _statusLabel(StudentLeaveStatus s) => switch (s) {
        StudentLeaveStatus.requested => 'pending',
        StudentLeaveStatus.underReview => 'in review',
        StudentLeaveStatus.approved => 'approved',
        StudentLeaveStatus.rejected => 'rejected',
      };

  Color _statusColor(StudentLeaveStatus s) => switch (s) {
        StudentLeaveStatus.requested => AppColors.warning,
        StudentLeaveStatus.underReview => AppColors.warning,
        StudentLeaveStatus.approved => AppColors.success,
        StudentLeaveStatus.rejected => AppColors.error,
      };
}
