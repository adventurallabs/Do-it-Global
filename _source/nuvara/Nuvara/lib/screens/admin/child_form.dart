import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../actions.dart';
import '../../assessment/history.dart';
import '../../assessment/model.dart';
import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/credentials.dart';
import '../../widgets/ui.dart';
import 'therapies.dart';

final phoneFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9+ \-]'));
bool validPhone(String s) => s.replaceAll(RegExp(r'\D'), '').length >= 10;
String fmtPlain(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

/// Add or edit a child. A new child first answers "Is an assessment needed?": if yes, they can only be created once
/// their Pediatric OT assessment is completed ("Attend Assessment", above the therapies; the server enforces it);
/// if no (e.g. they already had the centre's paper assessment), they are created without one. Each therapy is charged per attended session at the therapy's base fee, which
/// the admin can change for this child only (e.g. Speech ₹3,000 → ₹300). Progress is not set here: only
/// therapists rate it, session by session.
class ChildFormScreen extends StatefulWidget {
  final String? childId;
  const ChildFormScreen({super.key, this.childId});

  @override
  State<ChildFormScreen> createState() => _ChildFormScreenState();
}

class _ChildFormScreenState extends State<ChildFormScreen> {
  final name = TextEditingController();
  final father = TextEditingController();
  final mother = TextEditingController();
  final phone = TextEditingController();
  final alt = TextEditingController();
  String? dob;

  /// Selected therapies in the order they were picked.
  final List<String> order = [];

  /// Per-session fee for each selected therapy, as typed. Equal to the base fee means "standard".
  final Map<String, TextEditingController> fees = {};
  bool tried = false, dirty = false;

  /// New child: whether an assessment is needed (null until answered), and the intake assessment attended here.
  bool? needsAssessment;
  AssessmentSummary? intake;
  bool get _assessed => intake?.status == 'completed';
  bool get _assessmentReady => needsAssessment == false || (needsAssessment == true && _assessed);

  Child? get existing => widget.childId == null ? null : context.read<AppStore>().child(widget.childId);

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    final c = existing;
    if (c != null) {
      name.text = c.name;
      father.text = c.fatherName;
      mother.text = c.motherName;
      phone.text = c.phone;
      alt.text = c.altPhone;
      dob = c.dob;
      for (final t in c.therapies) {
        order.add(t.therapyId);
        fees[t.therapyId] = TextEditingController(text: fmtPlain(t.sessionFee ?? store.therapy(t.therapyId)?.baseFee ?? 0));
      }
    }
  }

  @override
  void dispose() {
    for (final c in [name, father, mother, phone, alt, ...fees.values]) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() => dirty = true);

  void _toggle(AppStore store, String id) {
    setState(() {
      dirty = true;
      if (order.remove(id)) {
        fees.remove(id)?.dispose();
      } else {
        order.add(id);
        fees[id] = TextEditingController(text: fmtPlain(store.therapy(id)?.baseFee ?? 0));
      }
    });
  }

  /// The fee to save for [id]: null when it equals the therapy's base fee, so later base-fee changes apply.
  double? _ownFee(AppStore store, String id) {
    final v = parseMoney(fees[id]?.text ?? '');
    final base = store.therapy(id)?.baseFee;
    return v == null || base == null || (v - base).abs() < 0.005 ? null : v;
  }

  bool get _badFee => order.any((id) => parseMoney(fees[id]?.text ?? '') == null);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final editing = widget.childId != null;
    final err = <String, String?>{
      'name': tried && name.text.trim().isEmpty ? 'Enter the child\'s name' : null,
      'dob': tried && dob == null ? 'Select the date of birth' : null,
      'phone': tried && !validPhone(phone.text) ? 'Enter a 10-digit contact number' : null,
      'alt': alt.text.trim().isNotEmpty && !validPhone(alt.text) ? 'Enter a 10-digit number or leave it empty' : null,
      'therapy': tried && order.isEmpty ? 'Select at least one therapy' : null,
      'fee': tried && _badFee ? 'Enter a fee for every therapy' : null,
      'needs': tried && !editing && needsAssessment == null ? 'Choose whether this child needs an assessment.' : null,
      'assessment': tried && !editing && needsAssessment == true && !_assessed ? (intake == null ? "Attend the assessment first, or choose 'No' above if it isn't needed." : 'Finish and complete the assessment first.') : null,
    };
    final first = name.text.trim().isEmpty ? 'the child' : firstWord(name.text.trim());

    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirm(
          context,
          title: 'Discard changes?',
          message: intake == null
              ? 'What you entered for this child will be lost.'
              : 'What you typed on this form will be lost. The assessment stays saved: it is offered again the next time you add a child.',
          action: 'Discard',
        );
        if (leave && context.mounted) {
          setState(() => dirty = false);
          await WidgetsBinding.instance.endOfFrame;
          if (context.mounted) context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(editing ? 'Edit child' : 'Add child')),
        // White right down to the screen edge; SafeArea inside keeps the button above the system bar.
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
          child: SafeArea(
            top: false,
            child: Constrained(
              child: ActionButton(editing ? 'Save changes' : 'Create child', icon: Icons.check_rounded, large: true, onPressed: () => _save(store, err)),
            ),
          ),
        ),
        body: PageList(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            _Section(
              title: 'Child',
              icon: Icons.child_care_rounded,
              children: [
                Field('Child\'s name', child: TextField(controller: name, textCapitalization: TextCapitalization.words, style: body(15), onChanged: (_) => _changed(), decoration: InputDecoration(hintText: 'Full name', errorText: err['name']))),
                const SizedBox(height: 16),
                Field(
                  'Date of birth',
                  hint: 'Also makes the parents\' password (first initial + date of birth).',
                  child: PickerField(
                    text: dob == null ? 'Select date' : fmtDate(dob!, 'd MMMM yyyy'),
                    placeholder: dob == null,
                    icon: Icons.cake_outlined,
                    error: err['dob'],
                    onTap: () async {
                      final d = await pickDate(context, initial: dob ?? addDays(todayISO(), -365 * 4), last: DateTime.now(), help: 'Date of birth');
                      if (d != null) {
                        setState(() {
                          dob = d;
                          dirty = true;
                        });
                      }
                    },
                  ),
                ),
                if (dob != null) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.auto_awesome_rounded, size: 16, color: C.brand600),
                    const SizedBox(width: 6),
                    Expanded(child: Text(ageLong(dob!), style: body(13.5, weight: FontWeight.w700, color: C.brand700))),
                  ]),
                ],
              ],
            ),
            _Section(
              title: 'Parents & contact',
              icon: Icons.family_restroom_rounded,
              children: [
                Field('Father\'s name', child: TextField(controller: father, textCapitalization: TextCapitalization.words, style: body(15), onChanged: (_) => _changed(), decoration: const InputDecoration(hintText: 'Father\'s full name'))),
                const SizedBox(height: 16),
                Field('Mother\'s name', child: TextField(controller: mother, textCapitalization: TextCapitalization.words, style: body(15), onChanged: (_) => _changed(), decoration: const InputDecoration(hintText: 'Mother\'s full name'))),
                const SizedBox(height: 16),
                Field(
                  'Contact number',
                  child: TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [phoneFormatter],
                    style: body(15).copyWith(fontFeatures: tnum),
                    onChanged: (_) => _changed(),
                    decoration: InputDecoration(hintText: '98765 43210', errorText: err['phone'], prefixIcon: const Icon(Icons.call_rounded, size: 18, color: C.muted)),
                  ),
                ),
                const SizedBox(height: 16),
                Field(
                  'Alternative contact number',
                  optional: true,
                  child: TextField(
                    controller: alt,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [phoneFormatter],
                    style: body(15).copyWith(fontFeatures: tnum),
                    onChanged: (_) => _changed(),
                    decoration: InputDecoration(hintText: 'Another number to reach the family', errorText: err['alt'], prefixIcon: const Icon(Icons.phone_forwarded_rounded, size: 18, color: C.muted)),
                  ),
                ),
              ],
            ),
            if (!editing)
              _Section(
                title: 'Assessment',
                icon: Icons.assignment_outlined,
                children: [
                  Text('Is an assessment needed?', style: body(13.5, weight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text("Choose 'No' for a child who already had the centre's paper assessment.", style: body(12.5, color: C.muted, height: 1.4)),
                  const SizedBox(height: 10),
                  Segmented<bool?>(
                    expand: true,
                    height: 46,
                    value: needsAssessment,
                    onChanged: (v) => setState(() {
                      needsAssessment = v;
                      dirty = true;
                    }),
                    options: [seg(true, 'Yes', Icons.assignment_outlined), seg(false, 'No', Icons.assignment_turned_in_outlined)],
                  ),
                  if (err['needs'] != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err['needs']!, style: body(12, weight: FontWeight.w700, color: C.red))),
                  if (needsAssessment == true) ...[
                    const SizedBox(height: 16),
                    IntakeAssessmentCard(
                      current: intake,
                      error: err['assessment'],
                      name: () => name.text,
                      dob: () => dob,
                      onChanged: (s) => setState(() {
                        intake = s;
                        if (s == null) return;
                        dirty = true;
                        // The child is created from the same name and date of birth as their assessment (the server
                        // checks they match), so the assessment's fill the form.
                        if (s.childName.trim().isNotEmpty) name.text = s.childName.trim();
                        if (s.dob != null) dob = s.dob;
                      }),
                    ),
                  ] else if (needsAssessment == false) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: C.canvas, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.info_outline_rounded, size: 18, color: C.brand700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${name.text.trim().isEmpty ? 'This child' : first} will be added without an assessment. You can start one any time from their profile (New assessment).',
                            style: body(12.5, height: 1.4),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ],
              ),
            _Section(
              title: 'Therapy needed',
              icon: Icons.favorite_rounded,
              children: [
                Text('Pick from your therapies, or create a new one.', style: body(12.5, color: C.muted)),
                const SizedBox(height: 12),
                TherapyPicker(
                  selected: order.toSet(),
                  error: err['therapy'],
                  onToggle: (id) => _toggle(store, id),
                  onCreated: (t) {
                    if (!order.contains(t.id)) _toggle(store, t.id);
                  },
                ),
              ],
            ),
            _Section(
              title: 'Fees per session',
              icon: Icons.account_balance_wallet_rounded,
              children: [
                if (order.isEmpty)
                  Text('Select therapies to set their fees.', style: body(13, color: C.muted))
                else ...[
                  Text(
                    'The family pays weekly for the sessions $first attends. Change a fee to charge $first differently; the therapy\'s standard fee stays the same for everyone else.',
                    style: body(12.5, color: C.muted, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  for (final id in order)
                    if (store.therapy(id) case final t?) Padding(padding: const EdgeInsets.only(bottom: 12), child: _FeeRow(therapy: t, controller: fees[id]!, onChanged: _changed)),
                  if (err['fee'] != null) Text(err['fee']!, style: body(11.5, weight: FontWeight.w600, color: C.red)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _save(AppStore store, Map<String, String?> err) async {
    setState(() => tried = true);
    if (name.text.trim().isEmpty || dob == null || !validPhone(phone.text) || err['alt'] != null || order.isEmpty || _badFee) {
      throw Exception('Please fix the highlighted fields.');
    }
    if (widget.childId == null && !_assessmentReady) {
      throw Exception(needsAssessment == null
          ? 'Choose whether this child needs an assessment.'
          : (intake == null ? "Attend the assessment first, or choose 'No' if it isn't needed." : 'Complete the assessment first.'));
    }
    final router = GoRouter.of(context);
    final nav = Navigator.of(context, rootNavigator: true);
    final editing = widget.childId != null;
    final before = existing;
    final fees = {for (final id in order) id: _ownFee(store, id)};
    final id = editing
        ? await store.saveChild(id: widget.childId, name: name.text, dob: dob!, father: father.text, mother: mother.text, phone: phone.text, altPhone: alt.text, fees: fees)
        : await store.createAssessedChild(assessmentId: needsAssessment == true ? intake!.id : null, name: name.text, dob: dob!, father: father.text, mother: mother.text, phone: phone.text, altPhone: alt.text, fees: fees);
    final password = defaultPassword(name.text, dob);
    final hasLogin = store.parentLogins.contains(id);
    // Until the family sets their own password, it's the default made from the name and date of birth,
    // so it follows them when they change. A password the family chose is never touched.
    final onDefault = store.onDefaultPassword(store.parentProfileOf[id]);
    var reset = false;
    String? warning = store.loginWarning;
    if (editing && hasLogin && onDefault && warning == null && before != null && defaultPassword(before.name, before.dob) != password) {
      try {
        await store.resetParentPassword(id);
        reset = true;
      } catch (e) {
        warning = 'Saved, but the password could not be updated: ${cleanError(e)} Use "Reset password" on the profile.';
      }
    }
    // Let PopScope rebuild with canPop = true before leaving.
    setState(() => dirty = false);
    await WidgetsBinding.instance.endOfFrame;
    if (editing) {
      router.pop();
    } else {
      router.pushReplacement('/admin/children/$id');
    }
    if (warning != null) return warning;
    final first = firstWord(name.text.trim());
    if (reset || (!editing && hasLogin)) {
      await WidgetsBinding.instance.endOfFrame;
      if (!nav.mounted) return null;
      showLoginDetails(
        nav.context,
        title: reset ? 'New password for the family' : '$first added',
        message: reset
            ? 'The name or date of birth changed, so the starting password changed too. Send the new details to the family.'
            : 'Share these with $first\'s family. They\'ll set their own password the first time they sign in.',
        loginLabel: "Child's ID",
        loginId: store.child(id)?.code ?? '',
        password: password,
      );
      return null;
    }
    return editing ? 'Changes saved' : '$first added';
  }
}

/// One therapy's per-session fee for this child, with the standard fee beside it and a way back to it.
class _FeeRow extends StatelessWidget {
  final Therapy therapy;
  final TextEditingController controller;
  final VoidCallback onChanged;
  const _FeeRow({required this.therapy, required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = therapy;
    final v = parseMoney(controller.text);
    final diff = v == null ? 0.0 : t.baseFee - v;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: t.color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: t.color.withValues(alpha: 0.16))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: t.color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w700))),
          const SizedBox(width: 8),
          Flexible(child: Text('Standard ${money(t.baseFee)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted).copyWith(fontFeatures: tnum))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: MoneyField(controller: controller, error: v == null ? 'Enter a fee' : null, onChanged: (_) => onChanged())),
          const SizedBox(width: 10),
          Text('per session', style: body(12.5, color: C.muted)),
        ]),
        if (v != null && diff.abs() >= 0.005) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(diff > 0 ? Icons.sell_outlined : Icons.trending_up_rounded, size: 16, color: diff > 0 ? C.green : C.amber),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                diff > 0 ? '${money(diff)} less than standard (${(diff / (t.baseFee == 0 ? 1 : t.baseFee) * 100).round()}% off)' : '${money(-diff)} above standard',
                style: body(12, weight: FontWeight.w700, color: diff > 0 ? C.green : C.amber),
              ),
            ),
            TextButton(
              onPressed: () {
                controller.text = fmtPlain(t.baseFee);
                onChanged();
              },
              style: TextButton.styleFrom(minimumSize: const Size(0, 32), visualDensity: VisualDensity.compact),
              child: const Text('Use standard'),
            ),
          ]),
        ],
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _Section({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              IconTile(icon, size: 34),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: display(18))),
            ]),
            const SizedBox(height: 18),
            ...children,
          ]),
        ),
      );
}
