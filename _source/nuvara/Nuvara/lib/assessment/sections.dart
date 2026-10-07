import 'package:flutter/material.dart';

import '../theme.dart';
import '../util.dart';
import '../widgets/ui.dart';
import 'catalog.dart';
import 'editor.dart';
import 'model.dart';
import 'widgets.dart';

/// The fields of one section of the form. [errors] are messages by field key, shown under those fields.
class SectionBody extends StatelessWidget {
  final AssessmentEditor e;
  final String id;
  final Map<String, String> errors;
  const SectionBody({super.key, required this.e, required this.id, this.errors = const {}});

  Assessment get a => e.a;
  bool get ro => e.readOnly;

  // ---- helpers

  Widget _text(String key, String label, {String? hint, int lines = 1, bool required = false, TextCapitalization cap = TextCapitalization.sentences, int? maxLength}) => Labelled(
        label,
        required: required,
        child: BoundText(
          key: ValueKey('${e.generation}|$key'),
          value: a.text(key),
          hint: hint,
          minLines: lines,
          readOnly: ro,
          capitalization: cap,
          maxLength: maxLength,
          error: errors[key],
          onChanged: (v) => e.setText(key, v),
        ),
      );

  Widget _single(String key, String label, List<Opt> options, {bool required = false, String? hint}) => Labelled(
        label,
        required: required,
        hint: hint,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Pills(options: options, value: a.pick(key), onChanged: ro ? null : (v) => e.change(() => a.put(key, v))),
          if (errors[key] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(errors[key]!, style: body(11.5, weight: FontWeight.w600, color: C.red))),
        ]),
      );

  Widget _date(String key, String label, {bool required = false, DateTime? first, DateTime? last, String? hint}) => Labelled(
        label,
        required: required,
        hint: hint,
        child: DateAnswer(
          value: a.pick(key),
          error: errors[key],
          first: first,
          last: last,
          help: label,
          clearable: !required,
          onChanged: ro ? null : (v) => e.change(() => a.put(key, v)),
        ),
      );

  Widget _findingText(Finding f, String key, String label, {String? hint, int lines = 1}) => Labelled(
        label,
        child: BoundText(
          key: ValueKey('${e.generation}|${f.key}|$key'),
          value: f.text(key),
          hint: hint,
          minLines: lines,
          dense: true,
          readOnly: ro,
          onChanged: (v) => e.setFindingText(f, key, v),
        ),
      );

  ItemRow _row(String domain, Item i, List<Opt> options, {List<Widget> Function(Finding f)? details, bool Function(Finding f)? noteOpen, String noteLabel = 'Notes', bool dense = false}) => ItemRow(
        key: ValueKey('${e.generation}|$domain|${i.key}'),
        e: e,
        finding: a.finding(domain, i.key),
        label: i.label,
        options: options,
        details: details,
        noteOpen: noteOpen,
        noteLabel: noteLabel,
        dense: dense,
      );

  static const _gap = SizedBox(height: 18);

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: switch (id) {
        'demographics' => _demographics(context),
        'medical' => _medical(),
        'senses' => _senses(),
        'development' => _development(),
        'education' => _education(),
        'play' => _play(),
        'screen' => _screen(),
        'behaviour' => _behaviour(),
        'sensory' => _sensory(),
        'posture' => _posture(),
        'reflexes' => _reflexes(),
        'rom' => [RomSection(e: e)],
        'hand' => _hand(),
        'adl' => _adl(),
        'plan' => [ProblemList(e: e, error: errors['problems'])],
        'goals' => [GoalList(e: e, term: 'short'), GoalList(e: e, term: 'long')],
        'approaches' => _approaches(),
        'home' => _home(),
        _ => const [],
      });

  // ---- sections

  List<Widget> _demographics(BuildContext context) {
    final dob = a.pick('dob'), doa = a.pick('assessment_date');
    final now = DateTime.now();
    return [
      FormCard(title: 'Basic information', icon: Icons.person_outline_rounded, children: [
        TwoCol(children: [
          _text('child_name', 'Name', hint: 'Child\'s full name', required: true, cap: TextCapitalization.words, maxLength: 120),
          _single('gender', 'Gender', Answers.gender, required: true),
        ]),
        _gap,
        TwoCol(children: [
          _date('dob', 'Date of Birth', required: true, first: DateTime(now.year - 25), last: now),
          Labelled('Age', hint: 'Worked out from the dates', child: _ReadBox(dob == null || doa == null ? 'Enter the date of birth' : ageAt(dob, doa), muted: dob == null || doa == null)),
        ]),
        _gap,
        TwoCol(children: [
          _date('assessment_date', 'Date of Assessment (DOA)', required: true, first: DateTime(now.year - 5), last: now),
          _single('hand_dominance', 'Hand Dominance', Answers.handDominance),
        ]),
        _gap,
        TwoCol(children: [
          _text('referred_by', 'Referred By', hint: 'Doctor, school, self…', cap: TextCapitalization.words),
          _text('informant', 'Informant', hint: 'Who gave the history', cap: TextCapitalization.words),
        ]),
      ]),
      FormCard(title: 'Surgical history', icon: Icons.healing_outlined, children: [
        _single('surgery', 'Any surgical procedures done?', Answers.yesNo),
        if (a.pick('surgery') == 'yes') ...[
          _gap,
          TwoCol(children: [
            _text('surgery_details', 'Procedure details', hint: 'Procedure, reason, outcome', lines: 3),
            _date('surgery_date', 'Date of Surgery', first: dob == null ? DateTime(now.year - 25) : parseD(dob), last: now),
          ]),
        ],
      ]),
      FormCard(title: 'Clinical information', icon: Icons.assignment_ind_outlined, children: [
        _text('chief_complaints', 'Chief Complaints', hint: 'The main concerns, in the family\'s words', lines: 4, required: true),
        _gap,
        _text('felt_needs', 'Felt Needs', hint: 'What the family hopes therapy will change', lines: 3),
      ]),
    ];
  }

  List<Widget> _medical() => [
        FormCard(title: 'Family History', icon: Icons.family_restroom_rounded, children: [
          BoundText(key: ValueKey('${e.generation}|family_history'), value: a.text('family_history'), hint: 'Consanguinity, similar conditions in the family, …', minLines: 4, readOnly: ro, onChanged: (v) => e.setText('family_history', v)),
        ]),
        FormCard(title: 'Medical History', icon: Icons.medical_information_outlined, children: [
          _text('prenatal', 'Prenatal', hint: 'Pregnancy: illness, medication, complications…', lines: 3),
          _gap,
          _text('perinatal', 'Perinatal', hint: 'Birth: term, delivery, birth weight, cry…', lines: 3),
          _gap,
          _text('postnatal', 'Post-natal', hint: 'After birth: NICU, jaundice, seizures, illnesses…', lines: 3),
        ]),
      ];

  List<Widget> _senses() => [
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 760 ? 3 : (c.maxWidth >= 520 ? 2 : 1);
          final w = (c.maxWidth - 14 * (cols - 1)) / cols;
          return Wrap(spacing: 14, children: [
            for (final (i, s) in Items.senses.indexed)
              SizedBox(
                width: w,
                child: _SenseCard(e: e, finding: a.finding('senses', s.key), label: s.label, icon: const [Icons.visibility_outlined, Icons.hearing_rounded, Icons.record_voice_over_outlined][i]),
              ),
          ]);
        }),
      ];

  List<Widget> _development() => [
        FormCard(
          padding: EdgeInsets.zero,
          children: [
            ItemList(rows: [
              for (final m in Items.milestones)
                _row('milestones', m, Answers.milestone, details: (f) => [
                      if (f.status == 'present' || f.status == 'delayed')
                        _findingText(f, 'age', f.status == 'delayed' ? 'Age achieved / observed' : 'Age achieved', hint: 'e.g. 20 months'),
                    ]),
            ]),
          ],
        ),
      ];

  List<Widget> _education() {
    final going = a.pick('school_status') != 'not_school_going';
    return [
      FormCard(title: 'School', icon: Icons.school_outlined, children: [
        _single('school_status', 'School Status', Answers.school),
        if (going) ...[
          _gap,
          SizedBox(width: 260, child: _text('grade', 'Grade', hint: 'e.g. LKG, Grade 2')),
          _gap,
          _text('classroom_complaints', 'Classroom Complaints', hint: 'What teachers report: attention, handwriting, sitting tolerance…', lines: 4),
        ],
      ]),
    ];
  }

  List<Widget> _play() => [
        FormCard(title: 'Type of Play', hint: 'Select all that apply', icon: Icons.groups_2_outlined, children: [
          MultiPills(options: Answers.playTypes, values: a.many('play_types'), onChanged: ro ? null : (v) => e.change(() => a.put('play_types', v))),
        ]),
        FormCard(title: 'Method', hint: 'Select all that apply', icon: Icons.extension_outlined, children: [
          MultiPills(options: Answers.playMethods, values: a.many('play_methods'), onChanged: ro ? null : (v) => e.change(() => a.put('play_methods', v))),
        ]),
        FormCard(
          title: 'Social / Play Skills',
          icon: Icons.handshake_outlined,
          padding: const EdgeInsets.only(bottom: 4),
          children: [ItemList(rows: [for (final s in Items.playSkills) _row('play_skills', s, Answers.skill)])],
        ),
        FormCard(title: 'Group Behaviour', icon: Icons.diversity_3_outlined, children: [
          Pills(options: Answers.group, value: a.pick('group_behaviour'), onChanged: ro ? null : (v) => e.change(() => a.put('group_behaviour', v))),
        ]),
        FormCard(padding: EdgeInsets.zero, children: [_row('play_skills', Items.handleDefeat, Answers.defeat)]),
      ];

  List<Widget> _screen() {
    final h = a.number('screen_hours'), m = a.number('screen_minutes');
    final over = (h ?? 0) * 60 + (m ?? 0) > 24 * 60;
    return [
      FormCard(title: 'Duration per Day', icon: Icons.timer_outlined, children: [
        Wrap(spacing: 24, runSpacing: 14, children: [
          Labelled('Hours', child: NumberStepper(value: h, unit: 'hr', max: 24, onChanged: ro ? null : (v) => e.change(() => a.put('screen_hours', v)))),
          Labelled('Minutes', child: NumberStepper(value: m, unit: 'min', max: 55, step: 5, onChanged: ro ? null : (v) => e.change(() => a.put('screen_minutes', v)))),
        ]),
        if (over) Padding(padding: const EdgeInsets.only(top: 8), child: Text('A day has only 24 hours.', style: body(12, weight: FontWeight.w600, color: C.red))),
      ]),
      FormCard(title: 'Type of Content', icon: Icons.ondemand_video_outlined, children: [
        BoundText(key: ValueKey('${e.generation}|screen_content'), value: a.text('screen_content'), hint: 'Cartoons, rhymes, games, video calls… and on which device', minLines: 3, readOnly: ro, onChanged: (v) => e.setText('screen_content', v)),
      ]),
    ];
  }

  List<Widget> _behaviour() => [
        FormCard(
          padding: EdgeInsets.zero,
          children: [
            ItemList(rows: [
              for (final b in Items.behaviour)
                _row('behaviour', b, Answers.behaviour,
                    noteOpen: (_) => false,
                    details: (f) => [
                          if (f.status == 'present') ...[
                            Labelled('Severity', child: Pills(options: Answers.severity, value: f.severity, dense: true, onChanged: ro ? null : (v) => e.change(() => f.severity = v))),
                            TwoCol(breakpoint: 460, gap: 12, children: [
                              _findingText(f, 'frequency', 'Frequency / observation', hint: 'e.g. several times a day'),
                              _findingText(f, 'triggers', 'Trigger / notes', hint: 'What sets it off'),
                            ]),
                          ],
                        ]),
            ]),
          ],
        ),
      ];

  List<Widget> _sensory() => [
        FormCard(
          padding: EdgeInsets.zero,
          children: [
            ItemList(rows: [
              for (final s in Items.sensory)
                _row('sensory', s, Answers.sensory,
                    noteLabel: 'Therapist notes',
                    details: (f) => [
                          if (f.status == 'concern') ...[
                            TwoCol(breakpoint: 460, gap: 12, children: [
                              _findingText(f, 'duration', 'Duration', hint: 'Since when / how long'),
                              _findingText(f, 'triggers', 'Triggering factors'),
                            ]),
                            _findingText(f, 'behaviour', 'Associated behaviour', lines: 2),
                          ],
                        ],
                    noteOpen: (f) => f.status == 'concern'),
            ]),
          ],
        ),
      ];

  List<Widget> _posture() => [
        FormCard(title: 'Anatomy', icon: Icons.accessibility_new_rounded, children: [
          BoundText(
            key: ValueKey('${e.generation}|posture_anatomy'),
            value: a.text('posture_anatomy'),
            hint: 'Specify if any abnormalities are present',
            minLines: 3,
            readOnly: ro,
            onChanged: (v) => e.setText('posture_anatomy', v),
          ),
        ]),
        FormCard(
          title: 'Postural Assessment',
          icon: Icons.airline_seat_recline_normal_rounded,
          padding: const EdgeInsets.only(bottom: 4),
          children: [
            ItemList(rows: [for (final p in Items.posture) _row('posture', p, Answers.posture, noteOpen: (f) => f.status == 'abnormal', noteLabel: 'Describe what you observed')]),
          ],
        ),
      ];

  List<Widget> _reflexes() => [
        FormCard(
          title: 'Primitive Reflexes',
          icon: Icons.bolt_outlined,
          padding: const EdgeInsets.only(bottom: 4),
          children: [ItemList(rows: [for (final r in Items.primitiveReflexes) _row('reflexes', r, Answers.reflex, dense: true)])],
        ),
        FormCard(
          title: 'Other Reflexes',
          icon: Icons.electric_bolt_outlined,
          padding: const EdgeInsets.only(bottom: 4),
          children: [ItemList(rows: [for (final r in Items.otherReflexes) _row('reflexes', r, Answers.reflex, dense: true)])],
        ),
      ];

  List<Widget> _hand() => [
        for (final g in handGroups)
          if (g.single)
            FormCard(title: g.title, icon: Icons.back_hand_outlined, children: [
              Pills(options: Answers.hand, value: a.finding('hand', g.items.first.key).status, onChanged: ro ? null : (v) => e.change(() => a.finding('hand', g.items.first.key).status = v)),
              const SizedBox(height: 12),
              BoundText(
                key: ValueKey('${e.generation}|hand|${g.key}|notes'),
                value: a.finding('hand', g.items.first.key).text('notes'),
                hint: 'Assessment / notes',
                minLines: 2,
                dense: true,
                readOnly: ro,
                onChanged: (v) => e.setFindingText(a.finding('hand', g.items.first.key), 'notes', v),
              ),
            ])
          else
            FormCard(
              title: g.title,
              icon: Icons.pan_tool_alt_outlined,
              padding: const EdgeInsets.only(bottom: 4),
              children: [ItemList(rows: [for (final i in g.items) _row('hand', i, Answers.hand, dense: true)])],
            ),
      ];

  List<Widget> _adl() {
    const needsHelp = {'independent_difficulty', 'needs_assistance', 'dependent'};
    return [
      FormCard(
        padding: EdgeInsets.zero,
        children: [
          ItemList(rows: [
            for (final d in Items.adl) _row('adl', d, Answers.adl, dense: true, noteOpen: (f) => needsHelp.contains(f.status), noteLabel: 'Notes / assistance required'),
          ]),
        ],
      ),
      FormCard(
        title: 'Others',
        hint: 'Any other activity of daily living you assessed',
        icon: Icons.add_task_rounded,
        children: [
          for (final f in a.otherAdls)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 6, 14),
                decoration: BoxDecoration(color: C.canvas, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(
                      child: BoundText(key: ValueKey('${e.generation}|${f.key}|label'), value: f.text('label'), hint: 'ADL name, e.g. Brushing teeth', dense: true, readOnly: ro, onChanged: (v) => e.setFindingText(f, 'label', v)),
                    ),
                    if (!ro) IconButton(tooltip: 'Remove', onPressed: () => e.change(() => a.findings.remove(f.key)), icon: const Icon(Icons.delete_outline_rounded, color: C.muted)),
                  ]),
                  const SizedBox(height: 10),
                  Padding(padding: const EdgeInsets.only(right: 8), child: Pills(options: Answers.adl, value: f.status, dense: true, onChanged: ro ? null : (v) => e.change(() => f.status = v))),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: BoundText(key: ValueKey('${e.generation}|${f.key}|notes'), value: f.text('notes'), hint: 'Notes / assistance required', minLines: 2, dense: true, readOnly: ro, onChanged: (v) => e.setFindingText(f, 'notes', v)),
                  ),
                ]),
              ),
            ),
          if (!ro)
            Align(
              alignment: Alignment.centerLeft,
              child: btn('Add another ADL', icon: Icons.add_rounded, kind: 'soft', onPressed: () => e.change(() => a.finding('adl', '${Items.adlOtherPrefix}${newId().substring(0, 8)}'))),
            )
          else if (a.otherAdls.isEmpty)
            Text('None recorded.', style: body(13, color: C.muted)),
        ],
      ),
    ];
  }

  List<Widget> _approaches() => [
        FormCard(title: 'Approaches Used', icon: Icons.lightbulb_outline_rounded, children: [
          BoundText(key: ValueKey('${e.generation}|approaches'), value: a.text('approaches'), hint: 'The therapy approaches and frames of reference you plan to use', minLines: 5, readOnly: ro, onChanged: (v) => e.setText('approaches', v)),
          const SizedBox(height: 16),
          Labelled('Approaches as tags', hint: ro ? null : 'Type one and press Enter. Optional.', child: _TagInput(e: e)),
        ]),
      ];

  List<Widget> _home() => [
        FormCard(title: 'Home Program', icon: Icons.home_outlined, children: [
          _text('home_activities', 'Home activities', hint: 'What the family should practise at home', lines: 4),
          _gap,
          TwoCol(children: [
            _text('home_frequency', 'Frequency', hint: 'e.g. twice a day, 5 days a week'),
            _text('home_duration', 'Duration', hint: 'e.g. 15 minutes each'),
          ]),
          _gap,
          _text('home_instructions', 'Parent / caregiver instructions', lines: 3),
          _gap,
          _text('home_precautions', 'Precautions / notes', lines: 3),
        ]),
      ];
}

/// Shows a value in a box that looks like a field but can't be edited.
class _ReadBox extends StatelessWidget {
  final String text;
  final bool muted;
  const _ReadBox(this.text, {this.muted = false});

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(color: C.canvas, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
        child: Text(text, style: body(14.5, weight: muted ? FontWeight.w400 : FontWeight.w700, color: muted ? C.muted : C.ink)),
      );
}

class _SenseCard extends StatelessWidget {
  final AssessmentEditor e;
  final Finding finding;
  final String label;
  final IconData icon;
  const _SenseCard({required this.e, required this.finding, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => FormCard(title: label, icon: icon, children: [
        Pills(options: Answers.senses, value: finding.status, dense: true, onChanged: e.readOnly ? null : (v) => e.change(() => finding.status = v)),
        const SizedBox(height: 12),
        BoundText(
          key: ValueKey('${e.generation}|${finding.key}|notes'),
          value: finding.text('notes'),
          hint: 'Notes (optional)',
          minLines: 2,
          dense: true,
          readOnly: e.readOnly,
          onChanged: (v) => e.setFindingText(finding, 'notes', v),
        ),
      ]);
}

class _TagInput extends StatefulWidget {
  final AssessmentEditor e;
  const _TagInput({required this.e});

  @override
  State<_TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<_TagInput> {
  final _c = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add() {
    final t = _c.text.trim();
    if (t.isEmpty) return;
    final tags = widget.e.a.many('approach_tags');
    if (!tags.any((x) => x.toLowerCase() == t.toLowerCase())) widget.e.change(() => widget.e.a.put('approach_tags', [...tags, t]));
    _c.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.e;
    final tags = e.a.many('approach_tags');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (tags.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in tags)
              InputChip(
                label: Text(t, style: body(13, weight: FontWeight.w600, color: C.brand800)),
                backgroundColor: C.brand50,
                side: const BorderSide(color: C.brand100),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onDeleted: e.readOnly ? null : () => e.change(() => e.a.put('approach_tags', [for (final x in tags) if (x != t) x])),
                deleteButtonTooltipMessage: 'Remove',
              ),
          ]),
        ),
      if (!e.readOnly)
        TextField(
          controller: _c,
          focusNode: _focus,
          style: body(14.5),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => _add(),
          decoration: InputDecoration(hintText: 'e.g. Sensory integration', suffixIcon: IconButton(tooltip: 'Add', onPressed: _add, icon: const Icon(Icons.add_rounded))),
        ),
      if (e.readOnly && tags.isEmpty) Text('None added.', style: body(13, color: C.muted)),
    ]);
  }
}

// ---------------------------------------------------------------- range of motion

/// AROM, PROM and muscle strength for each joint, right and left. A table where there is room; on phones one
/// card per joint, so nothing scrolls sideways.
class RomSection extends StatelessWidget {
  final AssessmentEditor e;
  const RomSection({super.key, required this.e});

  static const _groups = [('Upper Extremity', Items.upperJoints), ('Lower Extremity', Items.lowerJoints)];

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) => c.maxWidth >= 780 ? _table() : _cards());

  Widget _cell(Finding f, String key, {bool dense = true}) => BoundText(
        key: ValueKey('${e.generation}|${f.key}|$key'),
        value: f.text(key),
        hint: '—',
        dense: dense,
        readOnly: e.readOnly,
        capitalization: TextCapitalization.characters,
        onChanged: (v) => e.setFindingText(f, key, v),
        suffix: e.readOnly || dense ? null : _QuickRom(onPick: (v) => e.change(() => f.setText(key, v))),
      );

  Widget _strength(Finding f, double size) => StrengthPicker(value: f.strength, size: size, onChanged: e.readOnly ? null : (v) => e.change(() => f.strength = v));

  Widget _table() {
    Widget head(String t, {TextAlign align = TextAlign.left, Color color = C.muted}) =>
        Text(t, textAlign: align, style: body(11, weight: FontWeight.w800, color: color).copyWith(letterSpacing: 0.6));
    const strengthW = 6 * 28.0 + 5 * 4;
    Widget side(String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(color: C.brand50, borderRadius: BorderRadius.circular(8)),
            child: head(label, align: TextAlign.center, color: C.brand700),
          ),
        );
    return FormCard(padding: const EdgeInsets.fromLTRB(16, 14, 16, 10), children: [
      Row(children: [const SizedBox(width: 104), side('RIGHT'), const SizedBox(width: 16), side('LEFT')]),
      const SizedBox(height: 8),
      Row(children: [
        SizedBox(width: 104, child: head('JOINT')),
        for (final s in [0, 1]) ...[
          if (s == 1) const SizedBox(width: 16),
          Expanded(child: head('AROM')),
          const SizedBox(width: 8),
          Expanded(child: head('PROM')),
          const SizedBox(width: 8),
          SizedBox(width: strengthW, child: head('STRENGTH  0–5', align: TextAlign.center)),
        ],
      ]),
      for (final (title, joints) in _groups) ...[
        Padding(padding: const EdgeInsets.only(top: 16, bottom: 4), child: Overline(title)),
        for (final (i, j) in joints.indexed) ...[
          if (i > 0) const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              SizedBox(width: 104, child: Text(j.label, style: body(14, weight: FontWeight.w700))),
              for (final s in Items.sides) ...[
                if (s.key == 'left') const SizedBox(width: 16),
                Expanded(child: _cell(e.a.finding('rom', j.key, s.key), 'arom')),
                const SizedBox(width: 8),
                Expanded(child: _cell(e.a.finding('rom', j.key, s.key), 'prom')),
                const SizedBox(width: 8),
                _strength(e.a.finding('rom', j.key, s.key), 28),
              ],
            ]),
          ),
        ],
      ],
    ]);
  }

  Widget _cards() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final (title, joints) in _groups) ...[
          Padding(padding: const EdgeInsets.only(top: 4, bottom: 2, left: 4), child: Overline(title)),
          for (final j in joints)
            FormCard(
              title: j.label,
              trailing: e.readOnly ? null : TextButton(onPressed: () => _copyRight(j.key), child: const Text('Copy right → left')),
              children: [
                for (final s in Items.sides) ...[
                  if (s.key == 'left') const SizedBox(height: 16),
                  Text(s.label.toUpperCase(), style: body(11, weight: FontWeight.w800, color: C.brand700).copyWith(letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: Labelled('AROM', child: _cell(e.a.finding('rom', j.key, s.key), 'arom', dense: false))),
                    const SizedBox(width: 10),
                    Expanded(child: Labelled('PROM', child: _cell(e.a.finding('rom', j.key, s.key), 'prom', dense: false))),
                  ]),
                  const SizedBox(height: 10),
                  Labelled('Strength', child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: _strength(e.a.finding('rom', j.key, s.key), 38))),
                ],
              ],
            ),
        ],
      ]);

  void _copyRight(String joint) {
    final r = e.a.finding('rom', joint, 'right');
    e.change(() {
      final l = e.a.finding('rom', joint, 'left');
      l.setText('arom', r.text('arom'));
      l.setText('prom', r.text('prom'));
      l.strength = r.strength;
      e.generation++;
    });
  }
}

class _QuickRom extends StatelessWidget {
  final ValueChanged<String> onPick;
  const _QuickRom({required this.onPick});

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: 'Quick answer',
        icon: const Icon(Icons.arrow_drop_down_rounded, color: C.muted),
        onSelected: onPick,
        itemBuilder: (_) => [for (final q in romQuick) PopupMenuItem(value: q, child: Text(q, style: body(14)))],
      );
}

// ---------------------------------------------------------------- problems, goals

class ProblemList extends StatelessWidget {
  final AssessmentEditor e;
  final String? error;
  const ProblemList({super.key, required this.e, this.error});

  @override
  Widget build(BuildContext context) {
    final a = e.a;
    // Always one row to type into (blank rows are never saved).
    if (a.problems.isEmpty && !e.readOnly) a.problems.add(Problem());
    void edit(Problem p, void Function() fn) {
      final was = p.complete;
      e.change(fn, rebuild: was != p.complete);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(error!, style: body(12.5, weight: FontWeight.w700, color: C.red)),
        ),
      for (final (i, p) in a.problems.indexed)
        FormCard(
          title: 'Problem ${i + 1}',
          trailing: e.readOnly || (a.problems.length == 1 && p.blank)
              ? null
              : IconButton(tooltip: 'Remove problem', onPressed: () => e.change(() => a.problems.remove(p)), icon: const Icon(Icons.delete_outline_rounded, color: C.muted)),
          children: [
            TwoCol(breakpoint: 600, children: [
              Labelled('Problem Identified',
                  child: BoundText(key: ValueKey('${e.generation}|p|${p.id}|problem'), value: p.problem, hint: 'e.g. Poor fine motor coordination', minLines: 3, readOnly: e.readOnly, onChanged: (v) => edit(p, () => p.problem = v))),
              Labelled('Treatment Plan',
                  child: BoundText(
                      key: ValueKey('${e.generation}|p|${p.id}|plan'),
                      value: p.plan,
                      hint: 'e.g. Fine motor coordination activities and graded manipulation tasks',
                      minLines: 3,
                      readOnly: e.readOnly,
                      onChanged: (v) => edit(p, () => p.plan = v))),
            ]),
          ],
        ),
      if (!e.readOnly) Align(alignment: Alignment.centerLeft, child: btn('Add problem', icon: Icons.add_rounded, kind: 'soft', onPressed: () => e.change(() => a.problems.add(Problem())))),
    ]);
  }
}

class GoalList extends StatelessWidget {
  final AssessmentEditor e;
  final String term;
  const GoalList({super.key, required this.e, required this.term});

  @override
  Widget build(BuildContext context) {
    final a = e.a;
    final goals = a.goalsOf(term);
    if (goals.isEmpty && !e.readOnly) {
      final g = Goal(term: term);
      a.goals.add(g);
      goals.add(g);
    }
    final name = term == 'short' ? 'Short-Term Goals' : 'Long-Term Goals';
    void edit(Goal g, void Function() fn) {
      final was = g.description.trim().isNotEmpty;
      e.change(fn, rebuild: was != g.description.trim().isNotEmpty);
    }

    return FormCard(
      title: name,
      icon: term == 'short' ? Icons.outlined_flag_rounded : Icons.flag_rounded,
      hint: term == 'short' ? 'What to achieve in the coming weeks' : 'Where therapy is heading over months',
      children: [
        for (final (i, g) in goals.indexed) ...[
          if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider()),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(top: 10, right: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: C.brand50, borderRadius: BorderRadius.circular(8)),
              child: Text('${i + 1}', style: body(12, weight: FontWeight.w800, color: C.brand700)),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                BoundText(key: ValueKey('${e.generation}|g|${g.id}'), value: g.description, hint: 'Goal description', minLines: 2, readOnly: e.readOnly, onChanged: (v) => edit(g, () => g.description = v)),
                const SizedBox(height: 10),
                TwoCol(breakpoint: 620, gap: 12, children: [
                  Labelled('Target date', hint: 'Optional', child: DateAnswer(value: g.targetDate, placeholder: 'No target date', onChanged: e.readOnly ? null : (v) => e.change(() => g.targetDate = v))),
                  Labelled('Status', child: Pills(options: Answers.goalStatus, value: g.status, dense: true, onChanged: e.readOnly ? null : (v) => e.change(() => g.status = v ?? 'not_started'))),
                ]),
              ]),
            ),
            if (!e.readOnly && !(goals.length == 1 && g.description.trim().isEmpty))
              IconButton(tooltip: 'Remove goal', onPressed: () => e.change(() => a.goals.remove(g)), icon: const Icon(Icons.delete_outline_rounded, color: C.muted)),
          ]),
        ],
        if (!e.readOnly) ...[
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: btn(term == 'short' ? 'Add short-term goal' : 'Add long-term goal', icon: Icons.add_rounded, kind: 'soft', onPressed: () => e.change(() => a.goals.add(Goal(term: term)))),
          ),
        ],
      ],
    );
  }
}
