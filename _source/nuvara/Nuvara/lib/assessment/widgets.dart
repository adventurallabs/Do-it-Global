import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../util.dart';
import '../widgets/ui.dart';
import 'catalog.dart';
import 'editor.dart';
import 'model.dart';

// The building blocks of the assessment form. Answers are big tappable pills (tap again to clear), free text
// saves as you type, and optional notes stay folded away until wanted, so a typical item is one tap.

({Color fg, Color bg}) moodColors(Mood m) => switch (m) {
      Mood.good => (fg: C.green, bg: C.greenBg),
      Mood.watch => (fg: C.amber, bg: C.amberBg),
      Mood.concern => (fg: C.red, bg: C.redBg),
      Mood.info => (fg: C.blue, bg: C.blueBg),
      Mood.neutral => (fg: C.brand700, bg: C.brand50),
    };

Tone moodTone(Mood m) => switch (m) {
      Mood.good => Tone.green,
      Mood.watch => Tone.amber,
      Mood.concern => Tone.red,
      Mood.info => Tone.blue,
      Mood.neutral => Tone.neutral,
    };

/// One answer pill.
class _Pill extends StatelessWidget {
  final String label;
  final bool selected, multi;
  final Mood mood;
  final VoidCallback? onTap;
  final bool dense;
  const _Pill({required this.label, required this.selected, required this.mood, required this.onTap, this.multi = false, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final c = moodColors(mood);
    final fg = selected ? c.fg : (onTap == null ? C.muted : C.ink);
    return Semantics(
      button: true,
      selected: selected,
      checked: multi ? selected : null,
      inMutuallyExclusiveGroup: multi ? null : true,
      child: Material(
        color: selected ? c.bg : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11), side: BorderSide(color: selected ? c.fg.withValues(alpha: 0.55) : C.line, width: selected ? 1.4 : 1)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            constraints: BoxConstraints(minHeight: dense ? 36 : 42),
            padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 13, vertical: 7),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (selected) ...[Icon(Icons.check_rounded, size: dense ? 14 : 16, color: c.fg), const SizedBox(width: 5)],
              Flexible(child: Text(label, style: body(dense ? 12.5 : 13.5, weight: selected ? FontWeight.w700 : FontWeight.w600, color: fg, height: 1.2))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Pick one (tap the chosen one again to clear it).
class Pills extends StatelessWidget {
  final List<Opt> options;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final bool dense;
  const Pills({super.key, required this.options, required this.value, required this.onChanged, this.dense = false});

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in options)
          _Pill(
            label: o.label,
            mood: o.mood,
            dense: dense,
            selected: o.value == value,
            onTap: onChanged == null ? null : () => onChanged!(o.value == value ? null : o.value),
          ),
      ]);
}

/// Pick any number.
class MultiPills extends StatelessWidget {
  final List<Opt> options;
  final List<String> values;
  final ValueChanged<List<String>>? onChanged;
  const MultiPills({super.key, required this.options, required this.values, required this.onChanged});

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in options)
          _Pill(
            label: o.label,
            mood: Mood.info,
            multi: true,
            selected: values.contains(o.value),
            onTap: onChanged == null
                ? null
                : () => onChanged!(values.contains(o.value) ? [for (final v in values) if (v != o.value) v] : [for (final x in options) if (x.value == o.value || values.contains(x.value)) x.value]),
          ),
      ]);
}

/// A text box that writes through [onChanged] as you type. It reloads from [value] only when its key changes
/// (the editor's generation is part of the keys the sections use).
class BoundText extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String? hint, error;
  final int minLines;
  final int? maxLines;
  final bool readOnly, dense;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? formatters;
  final TextCapitalization capitalization;
  final Widget? suffix;
  final int? maxLength;
  final ValueChanged<String>? onSubmitted;
  const BoundText({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint,
    this.error,
    this.minLines = 1,
    this.maxLines,
    this.readOnly = false,
    this.dense = false,
    this.keyboard,
    this.formatters,
    this.capitalization = TextCapitalization.sentences,
    this.suffix,
    this.maxLength,
    this.onSubmitted,
  });

  @override
  State<BoundText> createState() => _BoundTextState();
}

class _BoundTextState extends State<BoundText> {
  late final _c = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(BoundText old) {
    super.didUpdateWidget(old);
    // Set from outside (a quick-fill button) while the text box isn't the one being typed in.
    if (widget.value != _c.text && widget.value != old.value) _c.text = widget.value;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multi = widget.minLines > 1 || (widget.maxLines ?? 1) > 1;
    return TextField(
      controller: _c,
      readOnly: widget.readOnly,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      minLines: widget.minLines,
      maxLines: multi ? (widget.maxLines ?? 12) : 1,
      maxLength: widget.maxLength,
      keyboardType: widget.keyboard ?? (multi ? TextInputType.multiline : TextInputType.text),
      textInputAction: multi ? TextInputAction.newline : TextInputAction.next,
      inputFormatters: widget.formatters,
      textCapitalization: widget.capitalization,
      style: body(widget.dense ? 13.5 : 14.5, height: 1.4),
      decoration: InputDecoration(
        hintText: widget.readOnly ? null : widget.hint,
        errorText: widget.error,
        counterText: '',
        isDense: true,
        filled: true,
        fillColor: widget.readOnly ? C.canvas : Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: widget.dense ? 10 : 13),
        suffixIcon: widget.suffix,
      ),
    );
  }
}

/// Label above a control, with an optional "Required" marker.
class Labelled extends StatelessWidget {
  final String label;
  final Widget child;
  final bool required;
  final String? hint;
  const Labelled(this.label, {super.key, required this.child, this.required = false, this.hint});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Flexible(child: Text(label, style: body(12.5, weight: FontWeight.w700, color: const Color(0xFF2B2E4A)))),
          if (required) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(color: C.clay50, borderRadius: BorderRadius.circular(5)),
              child: Text('Required', style: body(10, weight: FontWeight.w800, color: C.clay600)),
            ),
          ],
        ]),
        const SizedBox(height: 7),
        child,
        if (hint != null) Padding(padding: const EdgeInsets.only(top: 5), child: Text(hint!, style: body(11.5, color: C.muted))),
      ]);
}

/// Side by side when there's room, stacked on phones.
class TwoCol extends StatelessWidget {
  final List<Widget> children;
  final double breakpoint, gap;
  const TwoCol({super.key, required this.children, this.breakpoint = 560, this.gap = 16});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < breakpoint) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final (i, w) in children.indexed) ...[if (i > 0) SizedBox(height: gap), w],
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final (i, w) in children.indexed) ...[if (i > 0) SizedBox(width: gap), Expanded(child: w)],
        ]);
      });
}

/// A white card holding one group of the form.
class FormCard extends StatelessWidget {
  final String? title, hint;
  final IconData? icon;
  final Widget? trailing;
  final List<Widget> children;
  final EdgeInsets padding;
  const FormCard({super.key, this.title, this.hint, this.icon, this.trailing, required this.children, this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 18)});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line), boxShadow: softShadow),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (title != null)
              Padding(
                padding: EdgeInsets.fromLTRB(padding.left, 14, 10, children.isEmpty ? 14 : 0),
                child: Row(children: [
                  if (icon != null) ...[IconTile(icon!, size: 30), const SizedBox(width: 10)],
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title!, style: display(16)),
                      if (hint != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(hint!, style: body(12, color: C.muted))),
                    ]),
                  ),
                  ?trailing,
                ]),
              ),
            if (children.isNotEmpty) Padding(padding: title == null ? padding : padding.copyWith(top: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)),
          ]),
        ),
      );
}

/// A small round "add a note" toggle shown next to an item's name; filled when the item has a note.
class NoteButton extends StatelessWidget {
  final bool open, hasNote;
  final VoidCallback onTap;
  const NoteButton({super.key, required this.open, required this.hasNote, required this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: open ? 'Hide note' : (hasNote ? 'Show note' : 'Add a note'),
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        icon: Icon(hasNote ? Icons.sticky_note_2_rounded : Icons.edit_note_rounded, size: 21, color: hasNote || open ? C.brand600 : C.muted),
      );
}

/// One rated item of a list (a milestone, a behaviour, a reflex…): its name, the answer pills, then whatever
/// the answer opens up ([details]) and an optional note. Name left of the pills on wide screens, above on phones.
class ItemRow extends StatefulWidget {
  final AssessmentEditor e;
  final Finding finding;
  final String label;
  final List<Opt> options;

  /// Shown under the pills when the answer calls for more (e.g. severity once a behaviour is Present).
  final List<Widget> Function(Finding f)? details;

  /// Show the note box without a tap (e.g. an abnormal posture should be described).
  final bool Function(Finding f)? noteOpen;
  final String noteLabel;
  final bool dense;
  const ItemRow({super.key, required this.e, required this.finding, required this.label, required this.options, this.details, this.noteOpen, this.noteLabel = 'Notes', this.dense = false});

  @override
  State<ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<ItemRow> {
  late bool _open = widget.finding.text('notes').isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final f = widget.finding, e = widget.e;
    final forced = widget.noteOpen?.call(f) ?? false;
    final showNote = _open || forced || f.text('notes').isNotEmpty;
    final extra = widget.details?.call(f) ?? const <Widget>[];
    final pills = Pills(options: widget.options, value: f.status, dense: widget.dense, onChanged: e.readOnly ? null : (v) => e.change(() => f.status = v));
    final note = showNote
        ? Padding(
            padding: const EdgeInsets.only(top: 10),
            child: BoundText(
              key: ValueKey('${e.generation}|${f.key}|notes'),
              value: f.text('notes'),
              hint: widget.noteLabel,
              minLines: 2,
              dense: true,
              readOnly: e.readOnly,
              onChanged: (v) => e.setFindingText(f, 'notes', v),
            ),
          )
        : null;
    final noteButton = e.readOnly || forced ? null : NoteButton(open: showNote, hasNote: f.text('notes').isNotEmpty, onTap: () => setState(() => _open = !showNote));
    final name = Text(widget.label, style: body(14.5, weight: FontWeight.w700, height: 1.25));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 640;
        final below = [
          if (extra.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: _Reveal(children: extra)),
          ?note,
        ];
        if (wide) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 190, child: Padding(padding: const EdgeInsets.only(top: 11, right: 12), child: name)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [pills, ...below]),
              ),
            ),
            SizedBox(width: 40, child: noteButton),
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Expanded(child: name), ?noteButton, if (noteButton == null) const SizedBox(height: 40)]),
          const SizedBox(height: 6),
          Padding(padding: const EdgeInsets.only(right: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [pills, ...below])),
        ]);
      }),
    );
  }
}

/// The follow-up questions an answer opens, on a soft tinted panel so they read as part of that answer.
class _Reveal extends StatelessWidget {
  final List<Widget> children;
  const _Reveal({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(color: C.brand50.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(14), border: Border.all(color: C.brand100)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, w) in children.indexed) ...[if (i > 0) const SizedBox(height: 12), w],
        ]),
      );
}

/// Rows of [ItemRow]s in one card, divided by hairlines.
class ItemList extends StatelessWidget {
  final List<Widget> rows;
  const ItemList({super.key, required this.rows});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final (i, r) in rows.indexed) ...[if (i > 0) const Divider(indent: 16, endIndent: 16), r],
      ]);
}

/// Muscle strength, 0/5 to 5/5, in one tap.
class StrengthPicker extends StatelessWidget {
  final int? value;
  final ValueChanged<int?>? onChanged;
  final double size;
  const StrengthPicker({super.key, required this.value, required this.onChanged, this.size = 38});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Muscle strength',
        value: value == null ? 'not recorded' : '$value out of 5',
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var g = 0; g <= 5; g++)
            Padding(
              padding: EdgeInsets.only(right: g == 5 ? 0 : 4),
              child: Material(
                color: value == g ? C.brand800 : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9), side: BorderSide(color: value == g ? C.brand800 : C.line)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onChanged == null
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          onChanged!(value == g ? null : g);
                        },
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Center(child: Text('$g', style: body(size < 34 ? 12.5 : 14, weight: FontWeight.w800, color: value == g ? Colors.white : C.ink).copyWith(fontFeatures: tnum))),
                  ),
                ),
              ),
            ),
        ]),
      );
}

/// Whole numbers with − and + buttons, e.g. screen time hours.
class NumberStepper extends StatelessWidget {
  final int? value;
  final int min, max, step;
  final String unit;
  final ValueChanged<int?>? onChanged;
  final String? error;
  const NumberStepper({super.key, required this.value, required this.unit, required this.onChanged, this.min = 0, required this.max, this.step = 1, this.error});

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, int? next, String tip) => IconButton.outlined(
          tooltip: tip,
          onPressed: onChanged == null || next == null ? null : () => onChanged!(next),
          style: IconButton.styleFrom(side: const BorderSide(color: C.line), backgroundColor: Colors.white, minimumSize: const Size(44, 44)),
          icon: Icon(icon, size: 20),
        );
    final v = value;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        button(Icons.remove_rounded, v == null ? null : (v - step < min ? null : v - step), 'Less'),
        Container(
          width: 84,
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: C.canvas, borderRadius: BorderRadius.circular(12), border: Border.all(color: error != null ? C.red : C.line)),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: v == null ? '–' : '$v', style: display(19).copyWith(fontFeatures: tnum)),
            TextSpan(text: ' $unit', style: body(12, weight: FontWeight.w600, color: C.muted)),
          ])),
        ),
        button(Icons.add_rounded, v == null ? min + (step == 1 ? 1 : step) : (v + step > max ? null : v + step), 'More'),
        if (v != null && onChanged != null) TextButton(onPressed: () => onChanged!(null), child: const Text('Clear')),
      ]),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 5), child: Text(error!, style: body(11.5, weight: FontWeight.w600, color: C.red))),
    ]);
  }
}

/// A date answer: tap to pick, with a clear button.
class DateAnswer extends StatelessWidget {
  final String? value;
  final ValueChanged<String?>? onChanged;
  final String placeholder;
  final DateTime? first, last;
  final String? error, help;
  final bool clearable;
  const DateAnswer({super.key, required this.value, required this.onChanged, this.placeholder = 'Select date', this.first, this.last, this.error, this.help, this.clearable = true});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: PickerField(
            text: value == null ? placeholder : fmtDate(value!, 'd MMM yyyy'),
            placeholder: value == null,
            icon: Icons.event_rounded,
            error: error,
            onTap: onChanged == null
                ? () {}
                : () async {
                    final now = DateTime.now();
                    final lastDay = last ?? DateTime(now.year + 3);
                    var initial = value ?? iso(now);
                    if (parseD(initial).isAfter(lastDay)) initial = iso(lastDay);
                    final d = await pickDate(context, initial: initial, first: first, last: lastDay, help: help);
                    if (d != null) onChanged!(d);
                  },
          ),
        ),
        if (clearable && value != null && onChanged != null)
          IconButton(tooltip: 'Clear date', onPressed: () => onChanged!(null), icon: const Icon(Icons.close_rounded, size: 18, color: C.muted)),
      ]);
}

/// "✓ Saved 12:42 PM", "Saving…", "Offline · kept on this device", "Not saved · Retry".
class AutosaveIndicator extends StatelessWidget {
  final AssessmentEditor editor;
  final bool compact;
  const AutosaveIndicator(this.editor, {super.key, this.compact = false});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<SaveInfo>(
        valueListenable: editor.info,
        builder: (context, s, _) {
          final at = s.at == null ? null : fmtTime('${s.at!.hour.toString().padLeft(2, '0')}:${s.at!.minute.toString().padLeft(2, '0')}');
          final (IconData? icon, String text, Color color, bool spin) = switch (s.state) {
            SaveState.saved => (Icons.cloud_done_rounded, at == null ? (compact ? 'Saved' : 'All changes saved') : (compact ? at : 'Saved $at'), C.green, false),
            SaveState.pending => (Icons.edit_rounded, compact ? 'Editing' : 'Editing…', C.muted, false),
            SaveState.saving => (null, 'Saving…', C.muted, true),
            SaveState.offline => (Icons.cloud_off_rounded, compact ? 'Offline' : 'Offline · kept on this device', C.amber, false),
            SaveState.error => (Icons.error_outline_rounded, compact ? 'Not saved' : 'Not saved · Retry', C.red, false),
            SaveState.conflict => (Icons.sync_problem_rounded, compact ? 'Changed elsewhere' : 'Changed on another device', C.red, false),
          };
          final chip = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (spin) SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.8, color: color)) else Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, weight: FontWeight.w700, color: color))),
            ]),
          );
          final tappable = s.state == SaveState.error || s.state == SaveState.offline;
          return Semantics(
            liveRegion: true,
            label: s.error == null ? text : '$text. ${s.error}',
            child: Tooltip(
              message: s.error ?? (s.state == SaveState.offline ? 'Your changes are kept on this device and will be saved as soon as you\'re back online.' : text),
              child: tappable ? InkWell(borderRadius: BorderRadius.circular(99), onTap: editor.retry, child: chip) : chip,
            ),
          );
        },
      );
}

/// A section's state in the navigation: done, partly recorded, or not started.
class SectionMark extends StatelessWidget {
  final Progress p;
  final bool current;
  final int number;
  const SectionMark(this.p, {super.key, this.current = false, required this.number});

  @override
  Widget build(BuildContext context) {
    if (p.complete) {
      return Container(width: 26, height: 26, decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, size: 16, color: Colors.white));
    }
    return SizedBox(
      width: 26,
      height: 26,
      child: Stack(alignment: Alignment.center, children: [
        CircularProgressIndicator(value: p.total == 0 ? 0 : p.done / p.total, strokeWidth: 2.6, color: C.clay500, backgroundColor: current ? C.brand100 : C.line),
        Text('$number', style: body(10.5, weight: FontWeight.w800, color: current ? C.brand800 : C.muted).copyWith(fontFeatures: tnum)),
      ]),
    );
  }
}

/// "Mark the rest as …": answers every item still empty in one go.
class FillRest extends StatelessWidget {
  final List<Opt> options;
  final ValueChanged<String> onPick;
  final String label;
  const FillRest({super.key, required this.options, required this.onPick, this.label = 'Mark the rest'});

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: 'Answer every item still empty',
        onSelected: onPick,
        itemBuilder: (_) => [
          PopupMenuItem(enabled: false, height: 32, child: Text('Mark unanswered items as', style: body(12, weight: FontWeight.w700, color: C.muted))),
          for (final o in options)
            PopupMenuItem(
              value: o.value,
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: moodColors(o.mood).fg, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Text(o.label, style: body(14)),
              ]),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: C.brand50, borderRadius: BorderRadius.circular(11)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.done_all_rounded, size: 17, color: C.brand700),
            const SizedBox(width: 6),
            Text(label, style: body(12.5, weight: FontWeight.w700, color: C.brand700)),
            const Icon(Icons.arrow_drop_down_rounded, size: 20, color: C.brand700),
          ]),
        ),
      );
}
