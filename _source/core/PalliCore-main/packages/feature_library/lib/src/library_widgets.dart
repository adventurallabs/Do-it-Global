import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

/// Library accent colours, drawn from the app palette so the library reads
/// as part of PalliCore rather than a bolt-on.
class LibraryColors {
  static const Color books = AppColors.academicsCard;
  static const Color shelves = AppColors.feeCard;
  static const Color issue = AppColors.studentCard;
  static const Color collect = AppColors.leaveCard;
  static const Color unassigned = AppColors.warning;
  static const Color shelved = AppColors.success;
  static const Color issued = AppColors.examCard;
}

final DateFormat libraryDate = DateFormat('d MMM yyyy');

void showLibraryError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(libraryErrorMessage(error))));
}

void showLibraryDone(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Keeps a library screen in step with every other one: [reload] runs once
/// on open and again whenever anything in the library changes — on this
/// phone or another.
///
/// Reloads never overlap. A change that lands mid-read queues one more read,
/// so the last thing drawn always comes from a read that started after the
/// last change — an older, slower response can't paint over a newer one.
mixin LibraryLive<T extends StatefulWidget> on State<T> {
  StreamSubscription<void>? _librarySub;
  Future<void>? _inFlight;
  bool _again = false;

  LibraryRepository get library => context.read<LibraryRepository>();

  /// Reads the screen's data and sets state. Call [refreshLibrary] instead
  /// of this directly, so reads stay in order.
  Future<void> reload();

  Future<void> refreshLibrary() {
    if (_inFlight != null) {
      _again = true;
      return _inFlight!;
    }
    return _inFlight = () async {
      try {
        do {
          _again = false;
          await reload();
        } while (_again && mounted);
      } finally {
        _inFlight = null;
      }
    }();
  }

  @override
  void initState() {
    super.initState();
    _librarySub = library.changes.listen((_) {
      if (mounted) refreshLibrary();
    });
    refreshLibrary();
  }

  @override
  void dispose() {
    _librarySub?.cancel();
    super.dispose();
  }
}

/// Runs a library write, reporting a failure in a snackbar. Returns
/// whether it succeeded.
Future<bool> runLibraryAction(BuildContext context, Future<void> Function() action, {String? done}) async {
  try {
    await action();
    if (done != null && context.mounted) showLibraryDone(context, done);
    return true;
  } catch (e) {
    if (context.mounted) showLibraryError(context, e);
    return false;
  }
}

Future<bool> confirmYesNo(
  BuildContext context, {
  required String title,
  required String message,
  String yes = 'Yes',
  String no = 'No',
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      // A bulk-delete plan can list many books; it must scroll, not overflow.
      content: SingleChildScrollView(child: Text(message)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(no)),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.error) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(yes),
        ),
      ],
    ),
  );
  return ok == true;
}

/// The typed-DELETE confirmation. Resolves true only once the word has been
/// typed and the action pressed.
Future<bool> confirmTypedDelete(BuildContext context, {required String title, required String message}) async {
  var confirmed = false;
  await showDialog<void>(
    context: context,
    builder: (_) => VerificationDialog(
      title: title,
      content: message,
      confirmWord: 'DELETE',
      actionLabel: 'Delete',
      onConfirm: () => confirmed = true,
    ),
  );
  return confirmed;
}

/// Asks how many copies. Returns immediately with 1 when only one is
/// possible, and null if cancelled.
Future<int?> askCopyCount(
  BuildContext context, {
  required String title,
  required String message,
  required int max,
  int? initial,
  String action = 'Continue',
}) async {
  if (max <= 0) return null;
  if (max == 1) return 1;
  return showDialog<int>(
    context: context,
    builder: (ctx) =>
        _CountDialog(title: title, message: message, max: max, initial: (initial ?? 1).clamp(1, max), action: action),
  );
}

class _CountDialog extends StatefulWidget {
  final String title;
  final String message;
  final int max;
  final int initial;
  final String action;

  const _CountDialog({
    required this.title,
    required this.message,
    required this.max,
    required this.initial,
    required this.action,
  });

  @override
  State<_CountDialog> createState() => _CountDialogState();
}

class _CountDialogState extends State<_CountDialog> {
  late int _n = widget.initial;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.message, style: TextStyle(color: AppColors.onSurfaceMuted(context))),
          const SizedBox(height: 16),
          CopyStepper(value: _n, max: widget.max, onChanged: (v) => setState(() => _n = v)),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: _n == widget.max ? null : () => setState(() => _n = widget.max),
              child: Text('All ${widget.max}'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _n), child: Text(widget.action)),
      ],
    );
  }
}

/// A − n + stepper bounded to [min]..[max]. The number can also be typed.
class CopyStepper extends StatefulWidget {
  final int value;
  final int max;
  final int min;
  final ValueChanged<int> onChanged;

  const CopyStepper({super.key, required this.value, required this.max, this.min = 1, required this.onChanged});

  @override
  State<CopyStepper> createState() => _CopyStepperState();
}

class _CopyStepperState extends State<CopyStepper> {
  late final TextEditingController _c = TextEditingController(text: '${widget.value}');

  @override
  void didUpdateWidget(CopyStepper old) {
    super.didUpdateWidget(old);
    if ('${widget.value}' != _c.text) _c.text = '${widget.value}';
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _typed(String s) {
    final n = int.tryParse(s);
    if (n == null) return;
    final clamped = n.clamp(widget.min, widget.max);
    if (clamped != n) _c.text = '$clamped';
    if (clamped != widget.value) widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.filledTonal(
          onPressed: widget.value > widget.min ? () => widget.onChanged(widget.value - 1) : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: TextField(
            controller: _c,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            decoration: const InputDecoration(isDense: true),
            onChanged: _typed,
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: widget.value < widget.max ? () => widget.onChanged(widget.value + 1) : null,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

/// A small labelled number, used for a book's copy breakdown.
class CountTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const CountTile({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$value', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, height: 1.1)),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceMuted(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-column grid of [CountTile]s that keeps its tiles the same height.
class CountGrid extends StatelessWidget {
  final List<Widget> tiles;
  const CountGrid({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.55,
      padding: EdgeInsets.zero,
      children: tiles,
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Coloured pill that says where a loan stands against its due date.
class DueChip extends StatelessWidget {
  final LibraryLoan loan;
  const DueChip({super.key, required this.loan});

  static Color colorFor(LoanDueState s) {
    switch (s) {
      case LoanDueState.overdue:
        return AppColors.error;
      case LoanDueState.dueToday:
      case LoanDueState.dueSoon:
        return AppColors.warning;
      case LoanDueState.onTime:
        return AppColors.success;
      case LoanDueState.returned:
        return AppColors.endedPeriod;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = loan.dueState();
    final color = colorFor(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state == LoanDueState.overdue || state == LoanDueState.dueToday) ...[
            Icon(Icons.priority_high_rounded, size: 13, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            loan.dueLabel(),
            style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Red pill for a book still out with someone who left the school, was
/// deactivated, or whose record was erased. Draws nothing otherwise.
class BorrowerStatusChip extends StatelessWidget {
  final LibraryLoan loan;
  const BorrowerStatusChip({super.key, required this.loan});

  @override
  Widget build(BuildContext context) {
    if (!loan.borrowerGone) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_off_outlined, size: 13, color: AppColors.error),
          const SizedBox(width: 4),
          Text(
            loan.borrowerStatusLabel,
            style: const TextStyle(color: AppColors.error, fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// A book cover stand-in: the title's initial on a tinted block.
class BookSpine extends StatelessWidget {
  final String title;
  final double size;
  const BookSpine({super.key, required this.title, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final letter = title.trim().isEmpty ? '?' : title.trim()[0].toUpperCase();
    const palette = [
      AppColors.academicsCard,
      AppColors.feeCard,
      AppColors.examCard,
      AppColors.eventCard,
      AppColors.studentCard,
      AppColors.leaveCard,
    ];
    final color = palette[title.hashCode.abs() % palette.length];
    return Container(
      width: size * 0.78,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(4),
          bottomLeft: const Radius.circular(4),
          topRight: Radius.circular(size * 0.18),
          bottomRight: Radius.circular(size * 0.18),
        ),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Text(
        letter,
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: size * 0.4),
      ),
    );
  }
}

/// Shown in place of a list when a read failed — never an empty list, which
/// would look like the library has nothing.
class LibraryLoadError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const LibraryLoadError({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              libraryErrorMessage(error),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.onSurfaceMuted(context)),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
