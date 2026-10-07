import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/ui.dart';

/// Sign-in: parents with their child's ID, therapists with their mobile number, admins with email.
/// Therapist and parent logins are created and reset by the centre admin; after signing in with the
/// password from the centre, they set their own.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final id = TextEditingController();
  final password = TextEditingController();
  final idFocus = FocusNode(debugLabel: 'login id'), passwordFocus = FocusNode(debugLabel: 'login password');

  /// Keeps the form (and the field being typed in) alive when the layout switches between phone and wide,
  /// e.g. when the window resizes as the keyboard opens. Without it the fields were rebuilt, focus was lost
  /// and the keyboard closed after a few characters.
  final _formKey = GlobalKey(debugLabel: 'login form');
  Role role = Role.parent;
  bool hidden = true;

  /// Signing in (and loading the account) after either the button or the keyboard's Done.
  bool busy = false;

  static const _emailHints = [AutofillHints.email];
  static const _userHints = [AutofillHints.username];
  static const _passwordHints = [AutofillHints.password];

  @override
  void dispose() {
    id.dispose();
    password.dispose();
    idFocus.dispose();
    passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only the "restoring a saved login" flag matters here. Watching the whole store rebuilt the form on
    // every store change while the user was typing.
    final restoring = context.select<AppStore, bool>((s) => s.restoring);
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final form = KeyedSubtree(key: _formKey, child: restoring ? const _Restoring() : _form(context.read<AppStore>(), mobile: !wide));
    return Scaffold(
      body: wide ? Row(children: [const Expanded(flex: 21, child: _BrandPanel()), Expanded(flex: 20, child: form)]) : SafeArea(child: form),
    );
  }

  Future<void> _submit(AppStore store) async {
    if (busy) return;
    final k = _kind;
    if (id.text.trim().isEmpty || password.text.isEmpty) {
      toast(context, 'Enter your ${k.label.toLowerCase()} and password.', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => busy = true);
    await store.signIn(role, id.text, password.text);
    // On success the router moves on and this screen goes away; otherwise say what went wrong.
    if (!mounted) return;
    setState(() => busy = false);
    if (store.error != null) toast(context, store.error!, error: true);
  }

  ({String label, String hint, IconData icon, TextInputType keyboard, String first}) get _kind => switch (role) {
        Role.parent => (
            label: "Child's ID",
            hint: 'e.g. C001',
            icon: Icons.badge_outlined,
            keyboard: TextInputType.text,
            first: "First time? Use your child's ID and the password from the centre, then set your own.",
          ),
        Role.therapist => (
            label: 'Mobile number',
            hint: '10-digit mobile number',
            icon: Icons.phone_iphone_rounded,
            keyboard: TextInputType.phone,
            first: 'First time? Use your mobile number and the password from the centre, then set your own.',
          ),
        Role.admin => (label: 'Email', hint: 'you@example.com', icon: Icons.mail_outline_rounded, keyboard: TextInputType.emailAddress, first: ''),
      };

  Widget _form(AppStore store, {required bool mobile}) {
    final k = _kind;
    final narrow = MediaQuery.sizeOf(context).width < 430;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AutofillGroup(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              if (mobile) const _MobileBrand(),
              Text('Welcome back', style: display(32)),
              const SizedBox(height: 6),
              Text('Who is signing in?', style: body(14.5, color: C.muted)),
              const SizedBox(height: 16),
              Segmented<Role>(
                expand: true,
                height: 46,
                value: role,
                onChanged: (r) {
                  if (r == role || busy) return;
                  setState(() {
                    role = r;
                    id.clear();
                  });
                  idFocus.requestFocus();
                },
                // Icons only where there is room for them beside the words.
                options: [
                  seg(Role.parent, 'Parent', narrow ? null : Icons.family_restroom_rounded),
                  seg(Role.therapist, 'Therapist', narrow ? null : Icons.medical_services_outlined),
                  seg(Role.admin, 'Admin', narrow ? null : Icons.admin_panel_settings_outlined),
                ],
              ),
              const SizedBox(height: 22),
              Field(
                k.label,
                child: TextField(
                  key: ValueKey(role),
                  controller: id,
                  readOnly: busy,
                  focusNode: idFocus,
                  keyboardType: k.keyboard,
                  autofillHints: role == Role.admin ? _emailHints : _userHints,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => passwordFocus.requestFocus(),
                  enableSuggestions: false,
                  textCapitalization: role == Role.parent ? TextCapitalization.characters : TextCapitalization.none,
                  autocorrect: false,
                  style: body(15),
                  decoration: InputDecoration(hintText: k.hint, prefixIcon: Icon(k.icon, size: 19, color: C.muted)),
                ),
              ),
              const SizedBox(height: 14),
              Field(
                'Password',
                child: TextField(
                  controller: password,
                  focusNode: passwordFocus,
                  readOnly: busy,
                  obscureText: hidden,
                  autofillHints: _passwordHints,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(store),
                  style: body(15),
                  decoration: InputDecoration(
                    hintText: 'Your password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19, color: C.muted),
                    suffixIcon: IconButton(
                      tooltip: hidden ? 'Show password' : 'Hide password',
                      icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 19),
                      color: C.muted,
                      onPressed: () => setState(() => hidden = !hidden),
                    ),
                  ),
                ),
              ),
              if (k.first.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: C.brand600),
                  const SizedBox(width: 6),
                  Expanded(child: Text(k.first, style: body(12.5, color: C.muted, height: 1.4))),
                ]),
              ],
              const SizedBox(height: 20),
              _SignInButton(busy: busy, onPressed: () => _submit(store)),
              const SizedBox(height: 14),
              if (role == Role.admin)
                TextButton(onPressed: () => showSheet(context, builder: (_) => const _AdminSignup()), child: const Text('New admin? Create your account'))
              else
                Text('Forgot your password? Ask the centre to reset it.', textAlign: TextAlign.center, style: body(12.5, color: C.muted)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Shown while a saved login is reopened.
class _Restoring extends StatelessWidget {
  const _Restoring();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox.square(dimension: 34, child: CircularProgressIndicator(strokeWidth: 3, color: C.brand600)),
          const SizedBox(height: 16),
          Text('Signing you in…', style: body(14, weight: FontWeight.w600, color: C.muted)),
        ]),
      );
}

/// "Sign in", becoming a spinner with "Signing in…" while the account loads. Keeps its colour while busy.
class _SignInButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onPressed;
  const _SignInButton({required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        button: true,
        label: busy ? 'Signing in, please wait' : null,
        child: FilledButton(
          onPressed: busy ? () {} : onPressed,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 54)),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: busy
                ? Row(key: const ValueKey('busy'), mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)),
                    const SizedBox(width: 12),
                    const Text('Signing in…'),
                  ])
                : const Row(key: ValueKey('idle'), mainAxisSize: MainAxisSize.min, children: [
                    Text('Sign in'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ]),
          ),
        ),
      );
}

/// Create an admin account. Only emails the centre has approved can do this (checked on the server).
class _AdminSignup extends StatefulWidget {
  const _AdminSignup();

  @override
  State<_AdminSignup> createState() => _AdminSignupState();
}

class _AdminSignupState extends State<_AdminSignup> {
  final name = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();
  final again = TextEditingController();
  bool hidden = true, tried = false;

  @override
  void dispose() {
    for (final c in [name, email, pass, again]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final err = <String, String?>{
      'name': tried && name.text.trim().isEmpty ? 'Enter your name' : null,
      'email': tried && !email.text.contains('@') ? 'Enter your email' : null,
      'pass': tried && pass.text.length < 8 ? 'At least 8 characters' : null,
      'again': tried && pass.text != again.text ? 'The passwords don\'t match' : null,
    };
    InputDecoration deco(String hint, IconData icon, String? error, {bool secret = false}) => InputDecoration(
          hintText: hint,
          errorText: error,
          prefixIcon: Icon(icon, size: 19, color: C.muted),
          suffixIcon: secret
              ? IconButton(tooltip: hidden ? 'Show password' : 'Hide password', icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 19), color: C.muted, onPressed: () => setState(() => hidden = !hidden))
              : null,
        );
    return SheetBody(
      title: 'Create admin account',
      subtitle: 'For centre administrators approved by Nuvara',
      footer: [
        btn('Cancel', onPressed: () => Navigator.pop(context)),
        ActionButton('Create account', icon: Icons.check_rounded, onPressed: () async {
          setState(() => tried = true);
          if (err.values.any((e) => e != null) || name.text.trim().isEmpty || !email.text.contains('@') || pass.text.length < 8 || pass.text != again.text) {
            throw Exception('Please fix the highlighted fields.');
          }
          final nav = Navigator.of(context);
          await store.signUpAdmin(name: name.text, email: email.text, password: pass.text);
          if (store.error != null) throw Exception(store.error);
          nav.pop();
          return 'Welcome to Nuvara';
        }),
      ],
      child: AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Field('Your name', child: TextField(controller: name, textCapitalization: TextCapitalization.words, autofillHints: const [AutofillHints.name], style: body(15), onChanged: (_) => setState(() {}), decoration: deco('Full name', Icons.person_outline_rounded, err['name']))),
          const SizedBox(height: 14),
          Field('Email', hint: 'Must be an email approved for admin access.', child: TextField(controller: email, keyboardType: TextInputType.emailAddress, autocorrect: false, autofillHints: const [AutofillHints.email], style: body(15), onChanged: (_) => setState(() {}), decoration: deco('you@example.com', Icons.mail_outline_rounded, err['email']))),
          const SizedBox(height: 14),
          Field('Password', child: TextField(controller: pass, obscureText: hidden, autofillHints: const [AutofillHints.newPassword], style: body(15), onChanged: (_) => setState(() {}), decoration: deco('At least 8 characters', Icons.lock_outline_rounded, err['pass'], secret: true))),
          const SizedBox(height: 14),
          Field('Confirm password', child: TextField(controller: again, obscureText: hidden, style: body(15), onChanged: (_) => setState(() {}), decoration: deco('Type it again', Icons.lock_outline_rounded, err['again'], secret: true))),
        ]),
      ),
    );
  }
}

class _MobileBrand extends StatelessWidget {
  const _MobileBrand();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: HeroSurface(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Align(alignment: Alignment.centerLeft, child: FittedBox(child: NuvaraWordmark(height: 26, light: true, inline: true))),
            const SizedBox(height: 18),
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Every step forward '),
                TextSpan(text: 'matters', style: display(23, color: C.sky)),
              ]),
              style: display(23, color: Colors.white, height: 1.15),
            ),
          ]),
        ),
      );
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    const points = [
      (Icons.calendar_view_week_rounded, 'Weekly timetables with no double-booked therapists or children'),
      (Icons.insights_rounded, "Every session's report and each child's progress in one place"),
      (Icons.account_balance_wallet_outlined, 'Fees for attended sessions, paid with UPI at any time'),
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: heroGradient),
      child: Stack(children: [
        Positioned(top: -160, right: -160, child: _glow(C.sky.withValues(alpha: 0.26), 520)),
        Positioned(bottom: -180, left: -140, child: _glow(C.clay500.withValues(alpha: 0.24), 480)),
        // Scrolls rather than overflowing on short windows (a landscape tablet with the keyboard open).
        LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Align(alignment: Alignment.centerLeft, child: NuvaraWordmark(height: 26, light: true, inline: true)),
                    const Spacer(),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text.rich(
                          TextSpan(children: [
                            const TextSpan(text: 'Every step forward '),
                            TextSpan(text: 'matters', style: display(46, color: C.sky)),
                          ]),
                          style: display(46, color: Colors.white, height: 1.08),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Schedules, sessions, progress and fees stay connected, so the centre runs smoothly and families always know what comes next.',
                          style: body(15, color: C.brand200, height: 1.6),
                        ),
                        const SizedBox(height: 34),
                        for (final (i, p) in points.indexed)
                          Entrance(
                            delay: Duration(milliseconds: 200 + 90 * i),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Row(children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.07),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                                  ),
                                  child: Icon(p.$1, size: 17, color: i == 1 ? C.sky : C.clay100),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(p.$2, style: body(14, color: C.brand100))),
                              ]),
                            ),
                          ),
                      ]),
                    ),
                    const Spacer(),
                    Text('Timetable · Children · Therapists · Fees · Progress', style: body(12, color: C.brand300)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _glow(Color c, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)])),
      );
}
