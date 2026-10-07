import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../actions.dart';
import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/ui.dart';

/// The therapies the centre offers, each with its standard fee per attended session.
class TherapiesScreen extends StatelessWidget {
  const TherapiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Our therapies')),
      floatingActionButton: store.therapies.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showTherapySheet(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create therapy'),
              backgroundColor: C.brand700,
              foregroundColor: Colors.white,
            ),
      body: PageList(
        onRefresh: store.refresh,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Text('Each therapy\'s fee is charged for every session a child attends; families pay weekly. A child can have their own fee, set on their profile.', style: body(13.5, color: C.muted, height: 1.45)),
          ),
          if (store.therapies.isEmpty)
            EmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'No therapies yet',
              hint: 'Add the therapies your centre provides, like Speech Therapy or Occupational Therapy, with their base fee.',
              action: btn('Create therapy', icon: Icons.add_rounded, kind: 'filled', onPressed: () => showTherapySheet(context)),
            )
          else
            for (final t in store.therapies)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: () => showTherapySheet(context, therapy: t),
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    IconTile(Icons.favorite_rounded, color: t.color, size: 44),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15.5, weight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          '${plural(store.childrenCount(t.id), 'child', 'children')} · ${plural(store.therapistCount(t.id), 'therapist')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: body(12.5, color: C.muted),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(money(t.baseFee), style: display(19).copyWith(fontFeatures: tnum)),
                      Text('per session', style: body(11, color: C.muted)),
                    ]),
                  ]),
                ),
              ),
        ],
      ),
    );
  }
}

/// Create or edit a therapy. Returns the saved therapy, so forms can select a therapy they just created.
Future<Therapy?> showTherapySheet(BuildContext context, {Therapy? therapy, String? initialName}) =>
    showSheet<Therapy>(context, builder: (_) => _TherapySheet(therapy: therapy, initialName: initialName));

class _TherapySheet extends StatefulWidget {
  final Therapy? therapy;
  final String? initialName;
  const _TherapySheet({this.therapy, this.initialName});

  @override
  State<_TherapySheet> createState() => _TherapySheetState();
}

class _TherapySheetState extends State<_TherapySheet> {
  late final name = TextEditingController(text: widget.therapy?.name ?? widget.initialName ?? '');
  late final fee = TextEditingController(text: widget.therapy == null ? '' : _plain(widget.therapy!.baseFee));
  bool tried = false;

  static String _plain(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  void dispose() {
    name.dispose();
    fee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = widget.therapy;
    final kids = t == null ? 0 : store.childrenCount(t.id);
    final followers = t == null ? 0 : store.activeChildren.where((c) => c.therapyOf(t.id) != null && c.therapyOf(t.id)!.sessionFee == null).length;
    final newFee = parseMoney(fee.text);
    final dup = store.therapies.any((x) => x.id != t?.id && x.name.trim().toLowerCase() == name.text.trim().toLowerCase());

    return SheetBody(
      title: t == null ? 'Create therapy' : 'Edit therapy',
      subtitle: t == null ? 'Add a therapy your centre provides' : 'Used by ${plural(kids, 'child', 'children')}',
      trailing: t == null
          ? null
          : IconButton(
              tooltip: 'Delete therapy',
              icon: const Icon(Icons.delete_outline_rounded, color: C.red),
              onPressed: () => _delete(context, store, t),
            ),
      footer: [
        btn('Cancel', onPressed: () => Navigator.pop(context)),
        ActionButton('Save', icon: Icons.check_rounded, onPressed: () async {
          setState(() => tried = true);
          if (name.text.trim().isEmpty || newFee == null || dup) throw Exception('Fill in the highlighted fields.');
          final nav = Navigator.of(context);
          final saved = await store.saveTherapy(id: t?.id, name: name.text, baseFee: newFee);
          nav.pop(saved);
          return t == null ? '${saved.name} added' : 'Therapy updated';
        }),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Field(
          'Therapy name',
          child: TextField(
            controller: name,
            autofocus: t == null && widget.initialName == null,
            textCapitalization: TextCapitalization.words,
            style: body(15),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'e.g. Speech Therapy',
              errorText: dup ? 'This therapy already exists' : (tried && name.text.trim().isEmpty ? 'Enter a name' : null),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Field(
          'Fee per session',
          hint: 'Charged for each session a child attends, unless the child has their own fee.',
          child: MoneyField(
            controller: fee,
            autofocus: widget.initialName != null,
            onChanged: (_) => setState(() {}),
            error: tried && newFee == null ? 'Enter the fee per session' : null,
          ),
        ),
        if (t != null && newFee != null && newFee != t.baseFee && followers > 0) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.amberBg, borderRadius: BorderRadius.circular(14)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: C.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Applies to the next sessions marked for ${plural(followers, 'child', 'children')} on the standard fee. Children with their own fee, and sessions already marked, keep their price.',
                  style: body(12.5, weight: FontWeight.w600, color: C.amber, height: 1.4),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Future<void> _delete(BuildContext context, AppStore store, Therapy t) async {
    final used = store.childrenCount(t.id) + store.therapistCount(t.id);
    if (used > 0) {
      toast(context, '${t.name} is assigned to ${plural(store.childrenCount(t.id), 'child', 'children')} and ${plural(store.therapistCount(t.id), 'therapist')}. Remove it from them first.', error: true);
      return;
    }
    final ok = await confirm(context, title: 'Delete ${t.name}?', message: 'The centre will no longer offer this therapy.');
    if (!ok || !context.mounted) return;
    final nav = Navigator.of(context);
    try {
      await store.deleteTherapy(t.id);
      nav.pop();
      if (context.mounted) toast(context, '${t.name} deleted');
    } catch (e) {
      if (context.mounted) toast(context, cleanError(e), error: true);
    }
  }
}

/// Multi-select of therapies with a "New therapy" chip that creates one in place.
class TherapyPicker extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final ValueChanged<Therapy> onCreated;
  final String? error;
  const TherapyPicker({super.key, required this.selected, required this.onToggle, required this.onCreated, this.error});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final t in store.therapies) TogglePill(t.name, active: selected.contains(t.id), color: t.color, onTap: () => onToggle(t.id)),
        ActionChip(
          avatar: const Icon(Icons.add_rounded, size: 17, color: C.brand700),
          label: const Text('New therapy'),
          labelStyle: body(13, weight: FontWeight.w700, color: C.brand700),
          backgroundColor: C.brand50,
          side: const BorderSide(color: C.brand200),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
          onPressed: () async {
            final t = await showTherapySheet(context);
            if (t != null) onCreated(t);
          },
        ),
      ]),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(error!, style: body(11.5, weight: FontWeight.w600, color: C.red))),
    ]);
  }
}
