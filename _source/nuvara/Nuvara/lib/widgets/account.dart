import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../screens/parent/kit.dart' show selectedChildId;
import '../store.dart';
import '../theme.dart';
import 'ui.dart';

/// Account sheet: who is signed in, and sign out. Parents also see every child login remembered on this
/// device, switch between them with one tap, and add another child (like adding accounts in Instagram).
Future<void> showAccountSheet(BuildContext context) async {
  final store = context.read<AppStore>();
  if (store.role == Role.parent) await store.loadAccounts();
  if (!context.mounted) return;
  return showSheet(context, builder: (c) => const _AccountSheet());
}

class _AccountSheet extends StatelessWidget {
  const _AccountSheet();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final parent = store.role == Role.parent;
    final current = store.accounts.where((a) => a.userId == store.userId).firstOrNull;
    final others = store.accounts.where((a) => a.userId != store.userId).toList();
    return SheetBody(
      title: parent ? 'Accounts' : 'Account',
      subtitle: parent ? 'Switch between your children\'s logins' : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Avatar(store.userName, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(store.userName, style: body(16, weight: FontWeight.w700)),
              Text(
                switch (store.role) {
                  Role.admin => 'Centre admin',
                  Role.therapist => 'Therapist',
                  _ => current == null ? 'Parent' : 'Signed in with ${current.login} · ${current.childName}',
                },
                style: body(13, color: C.muted),
              ),
            ]),
          ),
          if (parent) const Icon(Icons.check_circle_rounded, color: C.brand700),
        ]),
        if (parent) ...[
          const SizedBox(height: 16),
          if (others.isNotEmpty) const Overline('Your other children on this device'),
          for (final a in others)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AccountRow(account: a),
            ),
          OutlinedButton.icon(
            onPressed: () {
              final nav = Navigator.of(context);
              nav.pop();
              showSheet(nav.context, builder: (_) => const AddChildSheet());
            },
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
            label: const Text('Add another child'),
          ),
          const SizedBox(height: 6),
          Text('Have more than one child at Nuvara? Add each child\'s login once and switch here without signing in again.', style: body(12, color: C.muted, height: 1.4)),
          const SizedBox(height: 18),
        ] else
          const SizedBox(height: 22),
        if (store.role == Role.admin) ...[
          btn('Change password', icon: Icons.lock_reset_rounded, onPressed: () {
            Navigator.pop(context);
            GoRouter.of(context).push('/password');
          }),
          const SizedBox(height: 10),
        ] else ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.lock_outline_rounded, size: 17, color: C.muted),
            const SizedBox(width: 8),
            Expanded(child: Text('Forgot your password? Ask the centre to reset it. You\'ll then set a new one when you sign in.', style: body(13, color: C.muted, height: 1.4))),
          ]),
          const SizedBox(height: 16),
        ],
        ActionButton(parent && others.isNotEmpty ? 'Sign out of ${current?.login ?? 'this child'}' : 'Sign out', icon: Icons.logout_rounded, kind: 'danger', large: true, onPressed: () async {
          Navigator.pop(context);
          selectedChildId.value = null;
          await store.signOut();
          return null;
        }),
        if (parent && others.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              selectedChildId.value = null;
              await store.signOut(everywhere: true);
            },
            child: Text('Sign out of all ${store.accounts.length} accounts'),
          ),
        ],
      ]),
    );
  }
}

class _AccountRow extends StatefulWidget {
  final SavedAccount account;
  const _AccountRow({required this.account});

  @override
  State<_AccountRow> createState() => _AccountRowState();
}

class _AccountRowState extends State<_AccountRow> {
  bool busy = false;

  Future<void> _switch() async {
    final store = context.read<AppStore>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => busy = true);
    try {
      nav.pop();
      selectedChildId.value = null;
      await store.switchAccount(widget.account);
      messenger.showSnackBar(SnackBar(content: Text('Switched to ${widget.account.childName}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(cleanError(e)), backgroundColor: C.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    return Material(
      color: C.canvas,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : _switch,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(children: [
            Avatar(a.childName, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                NameWithId(a.childName, a.login, style: body(14.5, weight: FontWeight.w700)),
                Text('Tap to switch', style: body(12, color: C.muted)),
              ]),
            ),
            busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.swap_horiz_rounded, color: C.brand700),
          ]),
        ),
      ),
    );
  }
}

/// Signs in to another child's login on this device and switches to it. A wrong password changes nothing.
class AddChildSheet extends StatefulWidget {
  const AddChildSheet({super.key});

  @override
  State<AddChildSheet> createState() => _AddChildSheetState();
}

class _AddChildSheetState extends State<AddChildSheet> {
  final id = TextEditingController();
  final password = TextEditingController();
  final idFocus = FocusNode(), passwordFocus = FocusNode();
  bool hidden = true;

  @override
  void dispose() {
    id.dispose();
    password.dispose();
    idFocus.dispose();
    passwordFocus.dispose();
    super.dispose();
  }

  Future<String?> _add() async {
    if (id.text.trim().isEmpty || password.text.isEmpty) throw Exception("Enter your child's ID and password.");
    final store = context.read<AppStore>();
    final nav = Navigator.of(context);
    final route = ModalRoute.of(context);
    FocusScope.of(context).unfocus();
    await store.addAccount(id.text, password.text);
    selectedChildId.value = null;
    // A new login goes straight to "set your password", which already closed this sheet.
    if (route != null && route.isActive) nav.removeRoute(route);
    return 'Added ${normaliseChildCode(id.text)}. Switch between children from the bar at the top of each page.';
  }

  @override
  Widget build(BuildContext context) => SheetBody(
        title: 'Add another child',
        subtitle: 'Sign in with that child\'s ID',
        footer: [
          btn('Cancel', onPressed: () => Navigator.pop(context)),
          ActionButton('Add and switch', icon: Icons.person_add_alt_1_rounded, onPressed: _add),
        ],
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Field(
            "Child's ID",
            child: TextField(
              controller: id,
              focusNode: idFocus,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => passwordFocus.requestFocus(),
              style: body(15),
              decoration: const InputDecoration(hintText: 'e.g. C002', prefixIcon: Icon(Icons.badge_outlined, size: 19, color: C.muted)),
            ),
          ),
          const SizedBox(height: 14),
          Field(
            'Password',
            child: TextField(
              controller: password,
              focusNode: passwordFocus,
              obscureText: hidden,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              style: body(15),
              decoration: InputDecoration(
                hintText: 'That child\'s password',
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
          const SizedBox(height: 10),
          Text('New login? Use the password from the centre; you\'ll set your own next.', style: body(12, color: C.muted, height: 1.4)),
        ]),
      );
}

/// The signed-in person's picture; opens the account sheet. For parents with several children on this
/// device, a small badge shows how many accounts there are.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final name = store.userName.isEmpty ? 'Parent' : store.userName;
    final n = store.role == Role.parent ? store.accounts.length : 0;
    return Semantics(
      button: true,
      label: n > 1 ? 'Accounts, $n on this device' : 'Account',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => showAccountSheet(context),
        child: Badge(
          isLabelVisible: n > 1,
          label: Text('$n'),
          backgroundColor: C.brand700,
          offset: const Offset(-2, 2),
          child: Avatar(name, size: 46),
        ),
      ),
    );
  }
}

/// Opens the phone dialler. Returns false (and shows a toast) when the device can't place calls.
Future<bool> callNumber(BuildContext context, String number) async {
  final digits = number.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.isEmpty) return false;
  final ok = await launchUrl(Uri(scheme: 'tel', path: digits)).catchError((_) => false);
  if (!ok && context.mounted) toast(context, 'Calling isn\'t available on this device. Number: $number');
  return ok;
}
