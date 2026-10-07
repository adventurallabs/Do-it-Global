import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../store.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// Set a new password. Shown on its own after a therapist or parent signs in with the default password
/// (no way past it except signing out), and to admins from the account sheet as "Change password".
class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key});

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final pass = TextEditingController();
  final again = TextEditingController();
  bool hidden = true, tried = false;

  @override
  void dispose() {
    pass.dispose();
    again.dispose();
    super.dispose();
  }

  bool get longEnough => pass.text.length >= 8;
  bool get hasLetterAndNumber => RegExp(r'[A-Za-z]').hasMatch(pass.text) && RegExp(r'\d').hasMatch(pass.text);
  bool get matches => pass.text.isNotEmpty && pass.text == again.text;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final forced = store.mustChangePassword;
    return PopScope(
      canPop: !forced,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !forced,
          title: Text(forced ? '' : 'Change password'),
          actions: [if (forced) TextButton(onPressed: store.signOut, child: const Text('Sign out'))],
        ),
        body: PageList(
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                margin: const EdgeInsets.only(top: 8, bottom: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [C.brand800, C.brand600]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.lock_person_rounded, color: Colors.white, size: 30),
              ),
            ),
            Text(forced ? 'Set your own password' : 'Choose a new password', textAlign: TextAlign.center, style: display(26)),
            const SizedBox(height: 8),
            Text(
              forced
                  // The centre's placeholder name ("Parent of Aarav") isn't a name to greet anyone by.
                  ? '${store.userName.trim().isEmpty || store.userName.startsWith('Parent of ') ? 'Welcome!' : 'Welcome, ${store.userName.split(' ').first}!'} You signed in with the password from the centre. For your safety, choose your own to continue.'
                  : 'You will use it the next time you sign in.',
              textAlign: TextAlign.center,
              style: body(14, color: C.muted, height: 1.45),
            ),
            const SizedBox(height: 26),
            AppCard(
              padding: const EdgeInsets.all(18),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Field('New password', child: _field(pass, 'At least 8 characters', [AutofillHints.newPassword])),
                    const SizedBox(height: 14),
                    Field('Confirm new password', child: _field(again, 'Type it again', const [], error: tried && !matches ? 'The two passwords don\'t match' : null)),
                    const SizedBox(height: 16),
                    _Rule(ok: longEnough, text: 'At least 8 characters'),
                    _Rule(ok: hasLetterAndNumber, text: 'Letters and at least one number'),
                    _Rule(ok: matches, text: 'Both passwords match'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ActionButton(forced ? 'Save and continue' : 'Save password', icon: Icons.check_rounded, large: true, onPressed: () => _save(store)),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, List<String> hints, {String? error}) => TextField(
    controller: c,
    obscureText: hidden,
    autofillHints: hints,
    onChanged: (_) => setState(() {}),
    style: body(15),
    decoration: InputDecoration(
      hintText: hint,
      errorText: error,
      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19, color: C.muted),
      suffixIcon: IconButton(
        tooltip: hidden ? 'Show password' : 'Hide password',
        icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 19),
        color: C.muted,
        onPressed: () => setState(() => hidden = !hidden),
      ),
    ),
  );

  Future<String?> _save(AppStore store) async {
    setState(() => tried = true);
    if (!longEnough || !hasLetterAndNumber) throw Exception('Use at least 8 characters with letters and a number.');
    if (!matches) throw Exception('The two passwords don\'t match.');
    final router = GoRouter.of(context);
    final forced = store.mustChangePassword;
    await store.setPassword(pass.text);
    // When it was required, the router moves on by itself once the flag clears.
    if (!forced && router.canPop()) router.pop();
    return 'Password saved';
  }
}

class _Rule extends StatelessWidget {
  final bool ok;
  final String text;
  const _Rule({required this.ok, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Icon(ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, key: ValueKey(ok), size: 18, color: ok ? C.green : C.muted),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: body(13, weight: FontWeight.w600, color: ok ? C.ink : C.muted),
          ),
        ),
      ],
    ),
  );
}
