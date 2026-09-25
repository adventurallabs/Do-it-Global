import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'neo_widgets.dart';

/// Premium 2-step verification dialog for dangerous operations.
/// Step 1: User clicks "I understand" button
/// Step 2: User types "Delete" to confirm
class VerificationDialog extends StatefulWidget {
  final String title;
  final String content;
  final VoidCallback onConfirm;
  /// The exact phrase the user must type to enable the action button.
  final String confirmWord;
  /// Label on the enabled action button (defaults to a generic delete label).
  final String actionLabel;

  const VerificationDialog({
    super.key,
    required this.title,
    required this.content,
    required this.onConfirm,
    this.confirmWord = 'Delete',
    this.actionLabel = 'Initiate Deletion',
  });

  @override
  State<VerificationDialog> createState() => _VerificationDialogState();
}

class _VerificationDialogState extends State<VerificationDialog>
    with SingleTickerProviderStateMixin {
  bool _understood = false;
  final TextEditingController _controller = TextEditingController();
  bool _canDelete = false;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _tryDelete() {
    if (!_canDelete) {
      _shakeController.forward(from: 0);
      return;
    }
    Navigator.of(context).pop();
    widget.onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: SoftSurface(
        depth: SoftDepth.three,
        borderRadius: BorderRadius.circular(28),
        padding: EdgeInsets.zero,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Red warning header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: AppColors.dangerGradient,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Content — scrolls when the message is long (a delete plan
            // listing many shelves) instead of overflowing the dialog.
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.content,
                    style: TextStyle(
                      color: AppColors.onSurfaceMuted(context),
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  if (!_understood)
                    // Step 1: I understand button
                    ElevatedButton(
                      onPressed: () => setState(() => _understood = true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceElevated,
                        foregroundColor: AppColors.onSurface(context),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('I understand the consequences'),
                    ),

                  if (_understood) ...[
                    // Step 2: Type "Delete"
                    Text(
                      'Type "${widget.confirmWord}" to confirm:',
                      style: TextStyle(
                        color: AppColors.onSurfaceMuted(context),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedBuilder3(
                      animation: _shakeController,
                      builder: (context, child) {
                        final shake = _shakeController.isAnimating
                            ? (2 * _shakeController.value - 1).abs() * 8 *
                                (_shakeController.value < 0.5 ? 1 : -1)
                            : 0.0;
                        return Transform.translate(
                          offset: Offset(shake, 0),
                          child: child,
                        );
                      },
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        onChanged: (value) {
                          setState(() => _canDelete = value == widget.confirmWord);
                        },
                        decoration: InputDecoration(
                          hintText: widget.confirmWord,
                          filled: true,
                          fillColor: AppColors.surfaceLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _canDelete ? AppColors.error : AppColors.divider,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _canDelete ? AppColors.error : AppColors.accent,
                              width: 2,
                            ),
                          ),
                        ),
                        style: TextStyle(color: AppColors.onSurface(context)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _canDelete ? _tryDelete : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _canDelete ? AppColors.error : AppColors.surfaceElevated,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors.surfaceElevated,
                              disabledForegroundColor: AppColors.onSurfaceHint(context),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(widget.actionLabel),
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (!_understood) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ],
              ),
            ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

/// Simple one-step confirmation dialog (for announcements)
class SimpleConfirmDialog extends StatelessWidget {
  final String title;
  final String content;
  final VoidCallback onConfirm;

  const SimpleConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(
        content,
        style: TextStyle(color: AppColors.onSurfaceMuted(context)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

class AnimatedBuilder3 extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder3({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}

/// Asks before signing out — the sign-out button sits in page headers where
/// a stray tap is easy.
Future<bool> confirmSignOut(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text('You will need to sign in again to use the app.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
      ],
    ),
  );
  return ok == true;
}
