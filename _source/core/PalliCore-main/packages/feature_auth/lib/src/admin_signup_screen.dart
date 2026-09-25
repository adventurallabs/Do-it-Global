import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_ui/core_ui.dart';

import 'auth_widgets.dart';
import 'login_bloc.dart';

/// Creating the password login for an admin the school has already approved.
///
/// The gate is not here — it is the `auth_admin` allowlist, checked by the
/// `admin-signup` function with the service role. This screen only collects
/// the three fields and reports what the server said, because a check the
/// client could do is a check the client could skip.
class AdminSignUpScreen extends StatefulWidget {
  const AdminSignUpScreen({super.key});

  static Future<void> open(BuildContext context) {
    final bloc = context.read<LoginBloc>();
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(value: bloc, child: const AdminSignUpScreen()),
      ),
    );
  }

  @override
  State<AdminSignUpScreen> createState() => _AdminSignUpScreenState();
}

class _AdminSignUpScreenState extends State<AdminSignUpScreen> {
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();
  final _confirmC = TextEditingController();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _obscure = true;
  String? _error;

  static const _minPassword = 8;

  @override
  void dispose() {
    _emailC.dispose();
    _passwordC.dispose();
    _confirmC.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  /// Only the things the server cannot tell them faster. Whether the address
  /// is approved is the server's answer, not ours.
  String? _localProblem() {
    final email = _emailC.text.trim();
    if (email.isEmpty || !email.contains('@') || email.endsWith('@')) {
      return 'Enter the email address your school approved.';
    }
    if (_passwordC.text.length < _minPassword) {
      return 'Use a password of at least $_minPassword characters.';
    }
    if (_passwordC.text != _confirmC.text) {
      return 'The two passwords do not match.';
    }
    return null;
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    final problem = _localProblem();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() => _error = null);
    context.read<LoginBloc>().add(
          AdminSignUpRequested(_emailC.text, _passwordC.text),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Create admin account'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: BlocConsumer<LoginBloc, LoginState>(
                listener: (context, state) async {
                  if (state is LoginFailure) {
                    setState(() => _error = state.message);
                  }
                  if (state is AdminSignUpSucceeded) {
                    if (!context.mounted) return;
                    // Straight in — they just chose this password, so asking
                    // them to type it again would be ceremony.
                    context.read<LoginBloc>().add(
                          AdminEmailLoginRequested(state.email, _passwordC.text),
                        );
                    Navigator.pop(context);
                  }
                },
                builder: (context, state) {
                  final loading = state is LoginLoading;
                  return SoftSurface(
                    depth: SoftDepth.three,
                    borderRadius: BorderRadius.circular(28),
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Set your password',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AdminLook.inkOf(context),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Your school has to have added your email as an admin '
                          'first. Use that same address here.',
                          style: TextStyle(
                            color: AdminLook.muteOf(context),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 22),
                        AuthTextField(
                          controller: _emailC,
                          label: 'Email address',
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          onSubmitted: (_) => _passwordFocus.requestFocus(),
                        ),
                        const SizedBox(height: 12),
                        AuthTextField(
                          controller: _passwordC,
                          focusNode: _passwordFocus,
                          label: 'Password',
                          icon: Icons.lock_outline,
                          obscure: _obscure,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                          onSubmitted: (_) => _confirmFocus.requestFocus(),
                          onToggleObscure: () => setState(() => _obscure = !_obscure),
                        ),
                        const SizedBox(height: 12),
                        AuthTextField(
                          controller: _confirmC,
                          focusNode: _confirmFocus,
                          label: 'Re-enter password',
                          icon: Icons.lock_reset_rounded,
                          obscure: _obscure,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.newPassword],
                          onSubmitted: (_) => loading ? null : _submit(),
                        ),
                        const SizedBox(height: 16),
                        AuthErrorBanner(message: _error),
                        SoftPrimaryButton(
                          label: loading ? 'Creating…' : 'Create account',
                          icon: loading ? null : Icons.person_add_alt_rounded,
                          onPressed: loading ? null : _submit,
                          gold: true,
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: TextButton(
                            onPressed: loading ? null : () => Navigator.pop(context),
                            child: const Text('Already have an account? Sign in'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
