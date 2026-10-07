import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../actions.dart';
import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/ui.dart';

/// Ask the centre for another slot instead of [session]: for this day only, or regularly from now on.
/// The family picks one of that day's other sessions of the same therapy, or suggests a time when none suit.
Future<void> showRescheduleSheet(BuildContext context, Session session, Child kid) => showSheet(context, builder: (_) => _RescheduleSheet(session: session, kid: kid));

class _RescheduleSheet extends StatefulWidget {
  final Session session;
  final Child kid;
  const _RescheduleSheet({required this.session, required this.kid});

  @override
  State<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<_RescheduleSheet> {
  String scope = 'once';
  List<RescheduleOption>? options;
  Object? loadError;
  RescheduleOption? picked;

  /// Suggesting a time instead of picking a session (always so when there is nothing to pick).
  bool custom = false;
  String? start, end;

  /// "For this day" with a suggested time: the day the family would like instead (the session's own by default).
  late String day = widget.session.date;
  final reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() => loadError = null);
    try {
      final o = await context.read<AppStore>().rescheduleOptions(widget.session, widget.kid.id);
      if (!mounted) return;
      setState(() {
        options = o;
        if (o.isEmpty) custom = true;
      });
    } catch (e) {
      // They can still suggest a time while the list is unavailable.
      if (mounted) {
        setState(() {
          loadError = e;
          custom = true;
        });
      }
    }
  }

  int get _length => toMin(widget.session.end) - toMin(widget.session.start);

  void _setStart(String v) => setState(() {
        start = v;
        end = fromMin((toMin(v) + _length).clamp(0, 23 * 60 + 59));
      });

  /// Why the request can't be sent yet, or null.
  String? get _blocker {
    if (!custom) return picked == null ? 'Choose a session' : null;
    if (start == null) return 'Choose a time';
    if (toMin(end!) <= toMin(start!)) return 'The end time must be after the start.';
    if (scope == 'once' && '$day $start'.compareTo('${todayISO()} ${nowHM()}') <= 0) return 'Choose a time that is still ahead.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session, kid = widget.kid;
    final store = context.read<AppStore>();
    final therapy = store.therapyName(s.therapyId);
    final blocker = _blocker;
    final weekday = fmtDate(s.date, 'EEEE');
    // Three days either side of the session (Sunday too: the centre is open every day), never before today.
    final today = todayISO();
    final days = [for (var i = -3; i <= 3; i++) addDays(s.date, i)].where((d) => d.compareTo(today) >= 0).toList();
    return SheetBody(
      title: 'Request another slot',
      subtitle: '${relDay(s.date)}, ${fmtSpan(s.start, s.end)} · ${s.name}',
      footer: [
        btn('Cancel', onPressed: () => Navigator.pop(context)),
        ActionButton('Send request', icon: Icons.send_rounded, onPressed: blocker != null
            ? null
            : () async {
                final nav = Navigator.of(context);
                await store.requestReschedule(s, kid.id,
                    scope: scope, target: custom ? null : picked, date: custom && scope == 'once' ? day : null, start: start, end: end, reason: reason.text);
                nav.pop();
                return 'Request sent. The centre will confirm or suggest another time.';
              }),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Overline('How often?'),
        Segmented<String>(
          expand: true,
          height: 44,
          value: scope,
          onChanged: (v) => setState(() => scope = v),
          options: [seg('once', 'For this day'), seg('series', 'Regularly')],
        ),
        const SizedBox(height: 8),
        Text(
          scope == 'once'
              ? 'Only ${kid.first}\'s session on ${fmtDate(s.date, 'EEE, d MMM')} changes.'
              : 'This session and every later $therapy session on ${weekday}s at ${fmtTime(s.start)} move to the new time.',
          style: body(12.5, color: C.muted, height: 1.4),
        ),
        const SizedBox(height: 18),
        Overline(custom && (options?.isEmpty ?? true) ? 'When would suit you?' : 'Other $therapy sessions on ${fmtDate(s.date, 'EEE, d MMM')}'),
        if (options == null && loadError == null)
          const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Center(child: SizedBox.square(dimension: 26, child: CircularProgressIndicator(strokeWidth: 2.6))))
        else ...[
          if (loadError != null)
            _Notice(
              icon: Icons.cloud_off_rounded,
              text: "Couldn't load the other sessions. Check your connection, or suggest a time below.",
              action: TextButton(onPressed: _loadOptions, child: const Text('Try again')),
            )
          else if (options!.isEmpty)
            _Notice(icon: Icons.event_busy_rounded, text: "There are no other $therapy sessions left that day. Tell the centre a time that suits you and they'll arrange one.")
          else ...[
            for (final o in options!)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _OptionTile(
                  option: o,
                  therapist: store.therapistName(o.therapistId),
                  selected: !custom && picked?.sessionId == o.sessionId,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      custom = false;
                      picked = o;
                    });
                  },
                ),
              ),
            _OptionTile.custom(
              selected: custom,
              onTap: () => setState(() {
                custom = true;
                picked = null;
              }),
            ),
          ],
          if (custom) ...[
            if (scope == 'once') ...[
              const SizedBox(height: 12),
              Text('Which day?', style: body(12.5, weight: FontWeight.w700)),
              const SizedBox(height: 7),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final d in days)
                  ChoiceChip(
                    selected: d == day,
                    label: Text(relDay(d)),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => day = d);
                    },
                  ),
              ]),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: Field(
                  'From',
                  child: start == null
                      ? PickerField(
                          text: 'Choose',
                          placeholder: true,
                          icon: Icons.schedule_rounded,
                          onTap: () async {
                            final m = toMin(s.start);
                            final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60));
                            if (t != null) _setStart(fromMin(t.hour * 60 + t.minute));
                          },
                        )
                      : TimeField(value: start!, onChanged: _setStart),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Field(
                  'To',
                  child: end == null ? const PickerField(text: '—', placeholder: true, icon: Icons.schedule_rounded, onTap: _noop) : TimeField(value: end!, onChanged: (v) => setState(() => end = v)),
                ),
              ),
            ]),
            if (start != null && blocker != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(blocker, style: body(12, weight: FontWeight.w600, color: C.red))),
          ],
        ],
        const SizedBox(height: 14),
        Field(
          'Reason',
          optional: true,
          child: TextField(
            controller: reason,
            minLines: 2,
            maxLines: 4,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            style: body(14.5),
            decoration: const InputDecoration(hintText: 'e.g. Office meeting at that time', counterText: ''),
          ),
        ),
        const SizedBox(height: 6),
        Text("Nothing changes until the centre approves. You'll see their answer in Schedule.", style: body(12, color: C.muted, height: 1.4)),
      ]),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final RescheduleOption? option;
  final String therapist;
  final bool selected;
  final VoidCallback onTap;
  const _OptionTile({required this.option, required this.therapist, required this.selected, required this.onTap});
  const _OptionTile.custom({required this.selected, required this.onTap})
      : option = null,
        therapist = '';

  @override
  Widget build(BuildContext context) {
    final o = option;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? C.brand50 : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: selected ? C.brand600 : C.line, width: selected ? 1.6 : 1)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            child: Row(children: [
              Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, size: 20, color: selected ? C.brand700 : C.muted),
              const SizedBox(width: 10),
              Expanded(
                child: o == null
                    ? Text('None of these suit me, suggest a time', style: body(14, weight: FontWeight.w600))
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(fmtSpan(o.start, o.end), style: body(14.5, weight: FontWeight.w700).copyWith(fontFeatures: tnum)),
                        Text('${o.name} · $therapist', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, color: C.muted)),
                      ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;
  const _Notice({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(color: C.canvas, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(icon, size: 18, color: C.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: body(12.5, color: C.ink, height: 1.4))),
          ?action,
        ]),
      );
}

void _noop() {}
