import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_models/core_models.dart' as models;
import 'package:core_ui/core_ui.dart';
import 'admin_signup_screen.dart';
import 'auth_widgets.dart';
import 'login_bloc.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  models.UserRole _selectedRole = models.UserRole.admin;
  final _phoneC = TextEditingController();
  final _passwordC = TextEditingController();
  final _emailC = TextEditingController();
  final _adminPasswordC = TextEditingController();
  final _passwordFocus = FocusNode();
  final _adminPasswordFocus = FocusNode();
  bool _obscure = true;
  String? _error;

  // one staggered entrance: badge (flies in from the splash) -> title -> roles -> card
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();

  @override
  void dispose() {
    _intro.dispose();
    _phoneC.dispose();
    _passwordC.dispose();
    _emailC.dispose();
    _adminPasswordC.dispose();
    _passwordFocus.dispose();
    _adminPasswordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    final bloc = context.read<LoginBloc>();
    if (_selectedRole == models.UserRole.admin) {
      final email = _emailC.text.trim();
      if (email.isEmpty || _adminPasswordC.text.isEmpty) {
        setState(() => _error = 'Enter your email and password.');
        return;
      }
      setState(() => _error = null);
      bloc.add(AdminEmailLoginRequested(email, _adminPasswordC.text));
      return;
    }
    if (_phoneC.text.trim().isEmpty || _passwordC.text.isEmpty) {
      setState(() => _error = 'Enter your mobile number and password.');
      return;
    }
    setState(() => _error = null);
    bloc.add(TeacherLoginRequested(_phoneC.text, _passwordC.text));
  }

  void _google() {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    context.read<LoginBloc>().add(AdminGoogleLoginRequested());
  }

  Widget _stagger(int i, Widget child) {
    final a = CurvedAnimation(
      parent: _intro,
      curve: Interval((i * 0.14).clamp(0, 0.6), (0.45 + i * 0.14).clamp(0, 1), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: a,
      builder: (context, c) => Opacity(
        opacity: a.value,
        child: Transform.translate(offset: Offset(0, 18 * (1 - a.value)), child: c),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: BlocConsumer<LoginBloc, LoginState>(
                // authStateNotifier is kept in sync globally (see PalliCoreApp) so
                // the router can react even after this screen is disposed.
                listener: (context, state) {
                  if (state is LoginFailure) setState(() => _error = state.message);
                },
                builder: (context, state) {
                  return Column(
                    children: [
                      const BrandMark(size: 92, heroTag: BrandMark.splashHeroTag),
                      const SizedBox(height: 18),
                      _stagger(
                        0,
                        Column(
                          children: [
                            Text(
                              'PalliCore',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.8,
                                color: AdminLook.inkOf(context),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'A quieter way to run a school',
                              style: TextStyle(fontSize: 14, color: AdminLook.muteOf(context)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      _stagger(1, _buildRoleSelector()),
                      const SizedBox(height: 22),
                      _stagger(2, _buildLoginCard(context, state)),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    void pick(models.UserRole r) => setState(() {
          _selectedRole = r;
          _error = null;
        });
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _RoleCard(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Admin',
            selected: _selectedRole == models.UserRole.admin,
            onTap: () => pick(models.UserRole.admin),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _RoleCard(
            icon: Icons.school_outlined,
            label: 'Teacher',
            selected: _selectedRole == models.UserRole.teacher,
            onTap: () => pick(models.UserRole.teacher),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(BuildContext context, LoginState state) {
    final loading = state is LoginLoading;
    final admin = _selectedRole == models.UserRole.admin;
    return SoftSurface(
      depth: SoftDepth.three,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              admin ? 'Admin access' : 'Staff login',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AdminLook.inkOf(context)),
            ),
            const SizedBox(height: 6),
            Text(
              admin
                  ? 'Use the email your school approved — with its password, or '
                      'with Google. Either one reaches the same account.'
                  : 'Teachers and the librarian: use the phone number and '
                      'password issued by your admin.',
              style: TextStyle(color: AdminLook.muteOf(context), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 22),
            if (admin) ...[
              AuthTextField(
                controller: _emailC,
                label: 'Email address',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                onSubmitted: (_) => _adminPasswordFocus.requestFocus(),
              ),
              const SizedBox(height: 12),
              AuthTextField(
                controller: _adminPasswordC,
                focusNode: _adminPasswordFocus,
                label: 'Password',
                icon: Icons.lock_outline,
                obscure: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => loading ? null : _submit(),
                onToggleObscure: () => setState(() => _obscure = !_obscure),
              ),
              const SizedBox(height: 16),
            ],
            if (!admin) ...[
              AuthTextField(
                controller: _phoneC,
                label: 'Mobile Number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                onSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              const SizedBox(height: 12),
              AuthTextField(
                controller: _passwordC,
                focusNode: _passwordFocus,
                label: 'Password',
                icon: Icons.lock_outline,
                obscure: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => loading ? null : _submit(),
                onToggleObscure: () => setState(() => _obscure = !_obscure),
              ),
              const SizedBox(height: 16),
            ],
            AuthErrorBanner(message: _error),
            SoftPrimaryButton(
              label: loading ? 'Signing in…' : (admin ? 'Sign in' : 'Login'),
              icon: loading ? null : Icons.arrow_forward_rounded,
              onPressed: loading ? null : _submit,
              gold: true,
            ),
            if (admin) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: Divider(color: AdminLook.muteOf(context).withValues(alpha: 0.3))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('or',
                        style: TextStyle(fontSize: 12, color: AdminLook.muteOf(context))),
                  ),
                  Expanded(child: Divider(color: AdminLook.muteOf(context).withValues(alpha: 0.3))),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: loading ? null : _google,
                icon: const Icon(Icons.account_circle_outlined, size: 20),
                label: const Text('Continue with Google'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: loading ? null : () => AdminSignUpScreen.open(context),
                  child: const Text("Didn't have an account? Sign up"),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: SoftSurface(
        depth: selected ? SoftDepth.two : SoftDepth.one,
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selected ? AdminLook.gold.withValues(alpha: 0.16) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: selected ? AdminLook.gold : AppColors.onSurfaceHint(context), size: 24),
                ),
                const Spacer(),
                AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.check_circle_rounded, size: 20, color: AdminLook.gold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? AdminLook.inkOf(context) : AppColors.onSurfaceMuted(context),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
