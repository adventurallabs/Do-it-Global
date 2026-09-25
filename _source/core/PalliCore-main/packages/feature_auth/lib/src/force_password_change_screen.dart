import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_models/core_models.dart' show UserRole;
import 'login_bloc.dart';

/// Shown whenever the resolved user still has must_change_password set (a
/// fresh teacher/parent login, one just reset by an admin, or an admin who
/// has only signed in with Google and has no password for email login yet). Nothing else
/// in the app is reachable until this succeeds — enforced both by the router
/// redirect and by RLS on the backend.
class ForcePasswordChangeScreen extends StatefulWidget {
  const ForcePasswordChangeScreen({super.key});

  @override
  State<ForcePasswordChangeScreen> createState() => _ForcePasswordChangeScreenState();
}

class _ForcePasswordChangeScreenState extends State<ForcePasswordChangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordC = TextEditingController();
  final _confirmC = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _passwordC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: _passwordC.text));
      if (!mounted) return;
      context.read<LoginBloc>().add(PasswordChangeCompleted());
    } catch (e) {
      setState(() => _error = 'Could not update your password: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loginState = context.read<LoginBloc>().state;
    final isAdmin = loginState is LoginSuccess && loginState.user.role == UserRole.admin;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SoftSurface(
                depth: SoftDepth.three,
                borderRadius: BorderRadius.circular(28),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_reset_rounded, color: AdminLook.gold, size: 40),
                      const SizedBox(height: 16),
                      Text(isAdmin ? 'Set a password for email login' : 'Set a new password',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AdminLook.inkOf(context))),
                      const SizedBox(height: 6),
                      Text(
                        isAdmin
                            ? 'You signed in with Google. Set a password so you can also '
                                'sign in with your email and password — Google keeps working too.'
                            : 'This is your first sign-in with a temporary password. Choose a '
                                'new one to continue — you\'ll use it every time from now on.',
                        style: TextStyle(color: AdminLook.muteOf(context), fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 22),
                      SoftField(
                        child: TextFormField(
                          controller: _passwordC,
                          obscureText: _obscure,
                          style: TextStyle(color: AdminLook.inkOf(context)),
                          decoration: InputDecoration(
                            hintText: 'New password',
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.lock_outline, color: AdminLook.muteOf(context), size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: AdminLook.muteOf(context), size: 20),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          validator: (v) =>
                              (v == null || v.length < 8) ? 'At least 8 characters' : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SoftField(
                        child: TextFormField(
                          controller: _confirmC,
                          obscureText: _obscure,
                          style: TextStyle(color: AdminLook.inkOf(context)),
                          decoration: InputDecoration(
                            hintText: isAdmin ? 'Re-enter password' : 'Confirm new password',
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.lock_outline, color: AdminLook.muteOf(context), size: 20),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          validator: (v) => v != _passwordC.text ? 'Passwords do not match' : null,
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                      const SizedBox(height: 20),
                      if (_saving)
                        const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                      else
                        SoftPrimaryButton(label: 'Set password & continue', onPressed: _onSubmit, gold: true),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () => context.read<LoginBloc>().add(LogoutRequested()),
                          child: Text('Sign out', style: TextStyle(color: AdminLook.muteOf(context))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
