import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/design_system/app_spacing.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../shared/models/message.dart';

/// Leave request in three taps: when (Today / Tomorrow / pick dates), why
/// (a reason chip), send. The duration comes from the dates — no separate
/// "number of days" to keep in sync.
class LeaveRequestForm extends StatefulWidget {
  final Function(LeaveRequest) onSubmit;

  const LeaveRequestForm({super.key, required this.onSubmit});

  @override
  State<LeaveRequestForm> createState() => _LeaveRequestFormState();
}

enum _When { today, tomorrow, custom }

class _LeaveRequestFormState extends State<LeaveRequestForm> {
  final _noteController = TextEditingController();
  _When? _when;
  DateTimeRange? _range;
  String? _reason; // a chip label; 'other' uses the note as the reason

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTimeRange? get _dates {
    final today = _day(DateTime.now());
    return switch (_when) {
      _When.today => DateTimeRange(start: today, end: today),
      _When.tomorrow => DateTimeRange(
          start: today.add(const Duration(days: 1)), end: today.add(const Duration(days: 1))),
      _When.custom => _range,
      null => null,
    };
  }

  int get _days => _dates == null ? 0 : _dates!.end.difference(_dates!.start).inDays + 1;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final today = _day(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      initialDateRange: _range,
      locale: Localizations.localeOf(context),
    );
    if (picked != null) {
      setState(() {
        _range = DateTimeRange(start: _day(picked.start), end: _day(picked.end));
        _when = _When.custom;
      });
    }
  }

  String get _finalReason {
    final note = _noteController.text.trim();
    if (_reason == null || _reason == 'other') return note;
    return note.isEmpty ? _reason! : '$_reason — $note';
  }

  bool get _valid => _dates != null && _finalReason.isNotEmpty;

  void _submit() {
    if (!_valid) return;
    final dates = _dates!;
    final single = _days == 1;
    widget.onSubmit(LeaveRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      reason: _finalReason,
      duration: _days,
      date: single ? dates.start : null,
      fromDate: single ? null : dates.start,
      toDate: single ? null : dates.end,
      createdAt: DateTime.now(),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final reasons = [
      l10n.reasonUnwell,
      l10n.reasonDoctor,
      l10n.reasonFamily,
      l10n.reasonTravel,
    ];
    final dates = _dates;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.requestLeave, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.whenLabel, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                ChoiceChip(
                  label: Text(l10n.todayLabel),
                  selected: _when == _When.today,
                  onSelected: (_) => setState(() => _when = _When.today),
                ),
                ChoiceChip(
                  label: Text(l10n.tomorrowLabel),
                  selected: _when == _When.tomorrow,
                  onSelected: (_) => setState(() => _when = _When.tomorrow),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.date_range_rounded, size: 18),
                  label: Text(_when == _When.custom && _range != null
                      ? (_days == 1
                          ? DateFormat.MMMd(locale).format(_range!.start)
                          : '${DateFormat.MMMd(locale).format(_range!.start)} – ${DateFormat.MMMd(locale).format(_range!.end)}')
                      : l10n.pickDates),
                  selected: _when == _When.custom,
                  onSelected: (_) => _pickRange(),
                ),
              ],
            ),
            if (dates != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${DateFormat.MMMEd(locale).format(dates.start)}'
                '${_days > 1 ? ' – ${DateFormat.MMMEd(locale).format(dates.end)}' : ''}'
                ' · ${l10n.leaveDays(_days)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(l10n.whyLabel, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final r in reasons)
                  ChoiceChip(
                    label: Text(r),
                    selected: _reason == r,
                    onSelected: (_) => setState(() => _reason = r),
                  ),
                ChoiceChip(
                  label: Text(l10n.reasonOther),
                  selected: _reason == 'other',
                  onSelected: (_) => setState(() => _reason = 'other'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _noteController,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: _reason == 'other' ? l10n.describeReason : l10n.addNoteOptional,
                hintText: l10n.reasonHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _valid ? _submit : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.send_rounded),
              label: Text(l10n.send),
            ),
          ],
        ),
      ),
    );
  }
}
