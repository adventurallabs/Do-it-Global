import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'progress/progress_widgets.dart';

class TeacherLeaveScreen extends StatefulWidget {
  final String teacherId;
  const TeacherLeaveScreen({super.key, required this.teacherId});

  @override
  State<TeacherLeaveScreen> createState() => _TeacherLeaveScreenState();
}

class _TeacherLeaveScreenState extends State<TeacherLeaveScreen> {
  final _reason = TextEditingController();
  DateTime _from = _dayOnly(DateTime.now().add(const Duration(days: 1)));
  DateTime _to = _dayOnly(DateTime.now().add(const Duration(days: 1)));
  List<LeaveRequest> _mine = [];
  bool _sending = false;

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await context.read<LeaveRequestRepository>().getByTeacher(widget.teacherId);
      if (!mounted) return;
      setState(() => _mine = [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
    } catch (_) {}
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  int get _days => _to.difference(_from).inDays + 1;

  Future<void> _pick({required bool from}) async {
    final now = _dayOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: from ? now : _from,
      lastDate: now.add(const Duration(days: 180)),
      locale: const Locale('en', 'IN'),
      fieldHintText: 'dd/mm/yyyy',
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (_reason.text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    final repo = context.read<LeaveRequestRepository>();
    await repo.upsert(LeaveRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      teacherId: widget.teacherId,
      fromDate: _from,
      toDate: _to,
      reason: _reason.text.trim(),
      createdAt: DateTime.now(),
    ));
    _reason.clear();
    await _load();
    if (!mounted) return;
    setState(() => _sending = false);
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Leave request sent to the admin')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave request')),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            SoftSurface(
              depth: SoftDepth.one,
              borderRadius: BorderRadius.circular(22),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: _dateBox('From', _from, () => _pick(from: true))),
                      const SizedBox(width: 10),
                      Expanded(child: _dateBox('To', _to, () => _pick(from: false))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _days == 1 ? '1 day' : '$_days days',
                    style: TextStyle(fontSize: 12.5, color: AppColors.onSurfaceMuted(context)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reason,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      hintText: 'e.g. Medical appointment',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SoftPrimaryButton(
                    label: _sending ? 'Sending…' : 'Send request',
                    icon: Icons.send_rounded,
                    onPressed: _reason.text.trim().isEmpty || _sending ? null : _submit,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            ProgressSectionTitle('Your requests', trailing: _mine.isEmpty ? null : '${_mine.length}'),
            if (_mine.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('No leave requests yet.',
                    style: TextStyle(color: AppColors.onSurfaceMuted(context))),
              )
            else
              SoftSurface(
                depth: SoftDepth.one,
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < _mine.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        title: Text(_mine[i].reason, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(_mine[i].fromDate == _mine[i].toDate
                            ? _fmt(_mine[i].fromDate)
                            : '${_fmt(_mine[i].fromDate)} – ${_fmt(_mine[i].toDate)}'),
                        trailing: _StatusChip(status: _mine[i].status),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dateBox(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.event_outlined),
          isDense: true,
        ),
        child: Text(_fmt(date), style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final LeaveStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      LeaveStatus.pending => ('Pending', AppColors.warning),
      LeaveStatus.approved => ('Approved', AppColors.success),
      LeaveStatus.rejected => ('Declined', AppColors.error),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
