import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/session_provider.dart';
import '../app_shell/app_shell.dart';
import 'login_screen.dart';
import 'force_password_change_screen.dart';
import 'connection_error_screen.dart';
import '../../core/design_system/app_page_transitions.dart';

/// Swaps between Login / forced-password-change / the real app / a
/// connection-error screen as [sessionProvider] changes — sign-in, sign-out,
/// a session expiring, all flow through here with no separate navigation
/// calls needed.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(sessionProvider.select((s) => s.status));
    // Signing in / out used to swap screens in a single frame; now the old
    // one fades out before the new one fades in.
    final Widget screen = switch (status) {
      SessionStatus.ready => const AppShell(),
      SessionStatus.needsPasswordChange => const ForcePasswordChangeScreen(),
      SessionStatus.error => const ConnectionErrorScreen(),
      SessionStatus.signedOut || SessionStatus.unknown => const LoginScreen(),
    };
    final key = switch (status) {
      SessionStatus.signedOut || SessionStatus.unknown => 'login',
      _ => status.name,
    };
    return FadeThroughSwitcher(child: KeyedSubtree(key: ValueKey(key), child: screen));
  }
}
