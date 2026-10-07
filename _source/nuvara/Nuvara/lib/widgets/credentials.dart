import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Login details the admin hands to a family or therapist, e.g. after creating a login or resetting a
/// password. Each value can be copied on its own, or both together as a message ready to send.
Future<void> showLoginDetails(
  BuildContext context, {
  required String title,
  required String message,
  required String loginLabel,
  required String loginId,
  required String password,
}) =>
    showDialog<void>(
      context: context,
      barrierColor: C.brand900.withValues(alpha: 0.45),
      builder: (_) => _LoginDetails(title: title, message: message, loginLabel: loginLabel, loginId: loginId, password: password),
    );

class _LoginDetails extends StatefulWidget {
  final String title, message, loginLabel, loginId, password;
  const _LoginDetails({required this.title, required this.message, required this.loginLabel, required this.loginId, required this.password});

  @override
  State<_LoginDetails> createState() => _LoginDetailsState();
}

class _LoginDetailsState extends State<_LoginDetails> {
  /// What was copied last ('id', 'password' or 'all'); shown as a tick for a moment.
  String? copied;
  Timer? _clear;

  @override
  void dispose() {
    _clear?.cancel();
    super.dispose();
  }

  Future<void> _copy(String what, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => copied = what);
    _clear?.cancel();
    _clear = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => copied = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final all = '${w.loginLabel}: ${w.loginId}\nPassword: ${w.password}';
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: C.greenBg, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.key_rounded, color: C.green, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(w.title, style: display(21))),
            ]),
            const SizedBox(height: 12),
            Text(w.message, style: body(13.5, color: C.muted, height: 1.45)),
            const SizedBox(height: 18),
            _row(w.loginLabel, w.loginId, 'id'),
            const SizedBox(height: 10),
            _row('Password', w.password, 'password', big: true),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => _copy('all', all),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
              icon: Icon(copied == 'all' ? Icons.check_rounded : Icons.copy_all_rounded, size: 19),
              label: Text(copied == 'all' ? 'Copied' : 'Copy login details'),
            ),
            const SizedBox(height: 4),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          ]),
        ),
      ),
    );
  }

  Widget _row(String label, String value, String key, {bool big = false}) => Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        decoration: BoxDecoration(color: C.brand50, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.brand100)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: body(11.5, weight: FontWeight.w600, color: C.brand700)),
              const SizedBox(height: 2),
              SelectableText(value, maxLines: 1, style: display(big ? 22 : 18, color: C.brand900).copyWith(fontFeatures: tnum, letterSpacing: 0.4)),
            ]),
          ),
          IconButton(
            tooltip: copied == key ? 'Copied' : 'Copy ${label.toLowerCase()}',
            icon: Icon(copied == key ? Icons.check_rounded : Icons.copy_rounded, size: 19, color: copied == key ? C.green : C.brand700),
            onPressed: () => _copy(key, value),
          ),
        ]),
      );
}
