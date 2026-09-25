import 'package:flutter/material.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

/// The one thing an admin must read before archiving somebody.
///
/// Archiving is not reversible after 30 days — the record and everything
/// hanging off it are erased by the nightly job whether or not anyone comes
/// back. So the consequences are spelled out in full, and the only way past
/// is a button that says the admin understood them.
class ExitExplainer {
  ExitExplainer._();

  /// Returns true when the admin confirmed. [note] is filled in by reference
  /// so the caller can store what they typed.
  static Future<bool> confirm(
    BuildContext context, {
    required String subjectName,
    required bool isStaff,
    required ExitReason reason,
    required ValueChanged<String> onNote,
    List<String> extraConsequences = const [],
  }) async {
    final noteController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ExitExplainerDialog(
        subjectName: subjectName,
        isStaff: isStaff,
        reason: reason,
        noteController: noteController,
        extraConsequences: extraConsequences,
      ),
    );
    if (result == true) onNote(noteController.text.trim());
    noteController.dispose();
    return result == true;
  }
}

class _ExitExplainerDialog extends StatefulWidget {
  final String subjectName;
  final bool isStaff;
  final ExitReason reason;
  final TextEditingController noteController;
  final List<String> extraConsequences;

  const _ExitExplainerDialog({
    required this.subjectName,
    required this.isStaff,
    required this.reason,
    required this.noteController,
    required this.extraConsequences,
  });

  @override
  State<_ExitExplainerDialog> createState() => _ExitExplainerDialogState();
}

class _ExitExplainerDialogState extends State<_ExitExplainerDialog> {
  bool _acknowledged = false;

  String get _who => widget.isStaff ? 'staff member' : 'student';

  List<(IconData, String, Color)> _points(BuildContext context) {
    final purgeDate = ArchivePolicy.purgeDateFor(DateTime.now());
    return [
      (
        Icons.inventory_2_outlined,
        'Their record moves to the ${widget.reason.isGraduation ? 'Graduated' : 'Discontinued'} '
            'archive and leaves the normal directory, counts and lists.',
        AppColors.accent,
      ),
      if (widget.isStaff)
        (
          Icons.lock_outline_rounded,
          'Their login stops working immediately and any open session is signed out.',
          AppColors.warning,
        )
      else
        (
          Icons.lock_outline_rounded,
          "The parent's login keeps working until the record is erased, so they can still "
              'see past marks and fees.',
          AppColors.warning,
        ),
      if (widget.isStaff)
        (
          Icons.school_outlined,
          'They are removed as class teacher, and their timetable periods are left '
              'unassigned for you to fill.',
          AppColors.accent,
        )
      else
        (
          Icons.school_outlined,
          'They are taken off the class roll and will not appear in attendance, marks '
              'or homework lists.',
          AppColors.accent,
        ),
      ...widget.extraConsequences.map((text) => (Icons.info_outline_rounded, text, AppColors.accent)),
      (
        Icons.download_rounded,
        'You have 30 days to download their full record as CSV or Excel from the archive.',
        AppColors.success,
      ),
      (
        Icons.delete_forever_rounded,
        'On ${_longDate(purgeDate)} everything is erased for good — the record, '
            '${widget.isStaff ? 'their login' : 'their marks, attendance, fees, messages and parent login'}. '
            'This cannot be undone and the download is the only copy that survives.',
        AppColors.error,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final points = _points(context);
    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 32),
      title: Text('Mark ${widget.subjectName} as ${widget.reason.verb}?'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please read what happens to this $_who before you continue.',
                style: TextStyle(fontSize: 13.5, color: AppColors.onSurfaceMuted(context)),
              ),
              const SizedBox(height: 14),
              for (final (icon, text, color) in points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 17, color: color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              TextField(
                controller: widget.noteController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Reason (optional)',
                  hintText: widget.reason == ExitReason.transferred
                      ? 'e.g. Moved to St. Mary\'s, Coimbatore'
                      : 'e.g. Resigned, effective this term',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.accent,
                value: _acknowledged,
                onChanged: (v) => setState(() => _acknowledged = v ?? false),
                title: const Text(
                  'I understand the record will be erased after 30 days',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.warning,
            foregroundColor: Colors.white,
          ),
          onPressed: _acknowledged ? () => Navigator.pop(context, true) : null,
          child: const Text('Understood, continue'),
        ),
      ],
    );
  }
}

String _longDate(DateTime dt) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}
