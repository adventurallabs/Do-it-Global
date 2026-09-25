import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_provider.dart';
import '../../core/data/parent_repository.dart';
import '../../core/design_system/app_spacing.dart';
import '../../shared/widgets/premium_card.dart';
import 'profile_gaps_provider.dart';

/// The details the school is still waiting on, asked for one at a time.
///
/// Only the fields actually missing appear. A form that shows everything and
/// pre-fills most of it invites a parent to skim past the one box that
/// matters — and the school has been waiting on that box for a term.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CompleteProfileScreen()),
      );

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _blood = TextEditingController();
  final _emergency = TextEditingController();
  final _emergencyAlt = TextEditingController();
  final _address = TextEditingController();
  String? _gender;
  DateTime? _dob;
  bool? _needsTransport;
  bool _saving = false;

  /// The field widgets below live outside this State, so they set values
  /// through here rather than reaching in for a protected `setState`.
  void setGender(String? value) => setState(() => _gender = value);
  void setDob(DateTime value) => setState(() => _dob = value);
  void setNeedsTransport(bool? value) => setState(() => _needsTransport = value);
  DateTime? get dob => _dob;

  @override
  void dispose() {
    _blood.dispose();
    _emergency.dispose();
    _emergencyAlt.dispose();
    _address.dispose();
    super.dispose();
  }

  void _say(String message, {bool bad = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: bad ? Colors.red.shade700 : null,
      ));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(parentRepositoryProvider).updateOwnChildDetails(
            gender: _gender,
            bloodGroup: _blood.text.trim().isEmpty ? null : _blood.text.trim(),
            dob: _dob,
            address: _address.text.trim().isEmpty ? null : _address.text.trim(),
            emergencyContact:
                _emergency.text.trim().isEmpty ? null : _emergency.text.trim(),
            emergencyContactAlt:
                _emergencyAlt.text.trim().isEmpty ? null : _emergencyAlt.text.trim(),
            needsTransport: _needsTransport,
          );
      // The session holds the child, so it has to be re-read before the gap
      // list can agree with what was just sent.
      await ref.read(sessionProvider.notifier).refresh();
      ref.invalidate(studentProfileGapsProvider);
      if (!mounted) return;
      _say('Thank you — sent to the school.');
      Navigator.pop(context);
    } catch (_) {
      _say("Couldn't send that. Check your connection and try again.", bad: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gaps = ref.watch(familyProfileGapsProvider);
    final fields = {for (final g in gaps) g.field};
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Complete your details')),
      body: SafeArea(
        child: gaps.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, size: 46, color: Colors.green.shade600),
                      const SizedBox(height: 14),
                      Text('Nothing outstanding',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(
                        'The school has everything it needs for now.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, 40),
                children: [
                  PremiumCard(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        'The school is waiting on ${gaps.length} '
                        'detail${gaps.length == 1 ? '' : 's'}. You can send '
                        'them now or come back later.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final gap in gaps)
                    if (_builders[gap.field] case final build?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _GapField(gap: gap, child: build(this)),
                      ),
                  if (fields.contains('photoUrl') || fields.contains('documents'))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: PremiumCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, size: 19),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'A photo and documents are best handed in at the '
                                  'school office.',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded, size: 19),
                      label: Text(_saving ? 'Sending…' : 'Send to the school'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// One builder per answerable gap, so the screen only ever renders the
  /// boxes the school is actually waiting on.
  static final Map<String, Widget Function(_CompleteProfileScreenState)> _builders = {
    'gender': (s) => DropdownButtonFormField<String>(
          initialValue: s._gender,
          items: const [
            DropdownMenuItem(value: 'male', child: Text('Male')),
            DropdownMenuItem(value: 'female', child: Text('Female')),
            DropdownMenuItem(value: 'other', child: Text('Other')),
          ],
          onChanged: s.setGender,
          decoration: const InputDecoration(labelText: 'Gender'),
        ),
    'bloodGroup': (s) => TextField(
          controller: s._blood,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
              labelText: 'Blood group', hintText: 'O+, A-, AB+ …'),
        ),
    'emergencyContact': (s) => Column(
          children: [
            TextField(
              controller: s._emergency,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Emergency contact number'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: s._emergencyAlt,
              keyboardType: TextInputType.phone,
              decoration:
                  const InputDecoration(labelText: 'Another number (optional)'),
            ),
          ],
        ),
    'address': (s) => TextField(
          controller: s._address,
          maxLines: 2,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Home address'),
        ),
    'dob': (s) => _DobField(state: s),
    'needsTransport': (s) => DropdownButtonFormField<bool>(
          initialValue: s._needsTransport,
          items: const [
            DropdownMenuItem(value: true, child: Text('Yes, on the school bus')),
            DropdownMenuItem(value: false, child: Text('No, we make our own way')),
          ],
          onChanged: s.setNeedsTransport,
          decoration: const InputDecoration(labelText: 'Does your child use the bus?'),
        ),
  };
}

class _DobField extends StatelessWidget {
  final _CompleteProfileScreenState state;
  const _DobField({required this.state});

  @override
  Widget build(BuildContext context) {
    final dob = state.dob;
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: dob ?? DateTime(now.year - 8),
          firstDate: DateTime(now.year - 25),
          lastDate: now,
        );
        if (picked != null) state.setDob(picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Date of birth'),
        child: Text(dob == null
            ? 'Tap to choose'
            : '${dob.day.toString().padLeft(2, '0')}/'
                '${dob.month.toString().padLeft(2, '0')}/${dob.year}'),
      ),
    );
  }
}

class _GapField extends StatelessWidget {
  final ProfileGap gap;
  final Widget child;

  const _GapField({required this.gap, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (gap.isCritical) ...[
                  Icon(Icons.priority_high_rounded, size: 16, color: Colors.red.shade700),
                  const SizedBox(width: 5),
                ],
                Expanded(
                  child: Text(gap.ask,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}
