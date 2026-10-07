import 'package:flutter/material.dart';

import '../theme.dart';
import '../util.dart';
import '../widgets/ui.dart';
import 'catalog.dart';
import 'model.dart';
import 'widgets.dart';

// The assessment as a readable report, section by section, made from the data (never from screenshots). The same
// blocks feed the on-screen view and the PDF, so both always say the same thing.

sealed class RBlock {
  const RBlock();
}

/// "Chief Complaints: …"
class RText extends RBlock {
  final String label, value;
  const RText(this.label, this.value);
}

/// A rated item: "Walking — Delayed · Age 20 months · Needed support at first".
class RItem extends RBlock {
  final String label;
  final String answer;
  final Mood mood;
  final List<String> details;
  const RItem(this.label, this.answer, this.mood, [this.details = const []]);
}

class RHeading extends RBlock {
  final String text;
  const RHeading(this.text);
}

class RTable extends RBlock {
  final List<String> head;
  final List<List<String>> rows;
  const RTable(this.head, this.rows);
}

/// Numbered entries, e.g. problems with their treatment plans, or goals.
class REntries extends RBlock {
  final List<({String title, String body, String meta})> entries;
  const REntries(this.entries);
}

class RNone extends RBlock {
  final String text;
  const RNone([this.text = 'Not recorded.']);
}

typedef RSection = ({SectionDef def, List<RBlock> blocks});

List<RSection> buildReport(Assessment a) {
  String? opt(List<Opt> o, String k) => labelOf(o, a.pick(k));
  List<RBlock> texts(List<(String, String?)> pairs) => [
        for (final (l, v) in pairs)
          if (v != null && v.trim().isNotEmpty) RText(l, v.trim()),
      ];
  List<RBlock> items(String domain, List<Item> list, List<Opt> options, {List<String> Function(Finding f)? more}) => [
        for (final i in list)
          if (a.peek(domain, i.key) case final f? when f.status != null || f.text('notes').isNotEmpty)
            RItem(i.label, labelOf(options, f.status) ?? '—', moodOf(options, f.status), [...?more?.call(f), if (f.text('notes').trim().isNotEmpty) f.text('notes').trim()]),
      ];
  List<RBlock> orNone(List<RBlock> b) => b.isEmpty ? const [RNone()] : b;

  final dob = a.pick('dob'), doa = a.pick('assessment_date');
  final hours = a.number('screen_hours'), minutes = a.number('screen_minutes');
  return [
    for (final s in sections)
      (
        def: s,
        blocks: orNone(switch (s.id) {
          'demographics' => [
              ...texts([
                ('Name', a.childName),
                ('Gender', opt(Answers.gender, 'gender')),
                ('Date of Birth', dob == null ? null : fmtDate(dob, 'd MMM yyyy')),
                ('Age', dob == null || doa == null ? null : ageAt(dob, doa)),
                ('Date of Assessment', doa == null ? null : fmtDate(doa, 'd MMM yyyy')),
                ('Referred By', a.text('referred_by')),
                ('Informant', a.text('informant')),
                ('Hand Dominance', opt(Answers.handDominance, 'hand_dominance')),
                ('Surgical procedures done', opt(Answers.yesNo, 'surgery')),
                if (a.pick('surgery') == 'yes') ...[
                  ('Procedure details', a.text('surgery_details')),
                  ('Date of Surgery', a.pick('surgery_date') == null ? null : fmtDate(a.pick('surgery_date')!, 'd MMM yyyy')),
                ],
                ('Chief Complaints', a.text('chief_complaints')),
                ('Felt Needs', a.text('felt_needs')),
              ]),
            ],
          'medical' => texts([('Family History', a.text('family_history')), ('Prenatal', a.text('prenatal')), ('Perinatal', a.text('perinatal')), ('Post-natal', a.text('postnatal'))]),
          'senses' => items('senses', Items.senses, Answers.senses),
          'development' => items('milestones', Items.milestones, Answers.milestone, more: (f) => [if (f.text('age').isNotEmpty) 'Age ${f.text('age')}']),
          'education' => texts([('School Status', opt(Answers.school, 'school_status')), ('Grade', a.text('grade')), ('Classroom Complaints', a.text('classroom_complaints'))]),
          'play' => [
              ...texts([
                ('Type of Play', a.many('play_types').map((v) => labelOf(Answers.playTypes, v) ?? v).join(', ')),
                ('Method', a.many('play_methods').map((v) => labelOf(Answers.playMethods, v) ?? v).join(', ')),
              ]),
              ...items('play_skills', Items.playSkills, Answers.skill),
              ...texts([('Group Behaviour', opt(Answers.group, 'group_behaviour'))]),
              ...items('play_skills', [Items.handleDefeat], Answers.defeat),
            ],
          'screen' => texts([
              ('Duration per day', hours == null && minutes == null ? null : [if (hours != null) plural(hours, 'hour'), if (minutes != null) plural(minutes, 'minute')].join(' ')),
              ('Type of Content', a.text('screen_content')),
            ]),
          'behaviour' => items('behaviour', Items.behaviour, Answers.behaviour, more: (f) => [
                ?labelOf(Answers.severity, f.severity),
                if (f.text('frequency').isNotEmpty) 'Frequency: ${f.text('frequency')}',
                if (f.text('triggers').isNotEmpty) 'Trigger: ${f.text('triggers')}',
              ]),
          'sensory' => items('sensory', Items.sensory, Answers.sensory, more: (f) => [
                if (f.text('duration').isNotEmpty) 'Duration: ${f.text('duration')}',
                if (f.text('triggers').isNotEmpty) 'Triggers: ${f.text('triggers')}',
                if (f.text('behaviour').isNotEmpty) 'Associated behaviour: ${f.text('behaviour')}',
              ]),
          'posture' => [...texts([('Anatomy', a.text('posture_anatomy'))]), ...items('posture', Items.posture, Answers.posture)],
          'reflexes' => [
              if (items('reflexes', Items.primitiveReflexes, Answers.reflex) case final p when p.isNotEmpty) ...[const RHeading('Primitive Reflexes'), ...p],
              if (items('reflexes', Items.otherReflexes, Answers.reflex) case final o when o.isNotEmpty) ...[const RHeading('Other Reflexes'), ...o],
            ],
          'rom' => [
              if ([...Items.upperJoints, ...Items.lowerJoints].any((j) => Items.sides.any((s) => a.peek('rom', j.key, s.key)?.answered ?? false)))
                RTable(const ['Joint', 'R AROM', 'R PROM', 'R Strength', 'L AROM', 'L PROM', 'L Strength'], [
                  for (final (g, joints) in [('Upper', Items.upperJoints), ('Lower', Items.lowerJoints)])
                    for (final j in joints)
                      [
                        '${j.label} ($g)',
                        for (final s in Items.sides) ...[
                          a.peek('rom', j.key, s.key)?.text('arom') ?? '',
                          a.peek('rom', j.key, s.key)?.text('prom') ?? '',
                          a.peek('rom', j.key, s.key)?.strength == null ? '' : '${a.peek('rom', j.key, s.key)!.strength}/5',
                        ],
                      ],
                ]),
            ],
          'hand' => [
              for (final g in handGroups)
                if (items('hand', g.items, Answers.hand) case final x when x.isNotEmpty) ...[if (!g.single) RHeading(g.title), ...g.single ? [for (final i in x.cast<RItem>()) RItem(g.title, i.answer, i.mood, i.details)] : x],
            ],
          'adl' => [
              ...items('adl', Items.adl, Answers.adl),
              for (final f in a.otherAdls)
                if (f.status != null || f.text('label').trim().isNotEmpty)
                  RItem('Others: ${f.text('label').trim().isEmpty ? 'Unnamed' : f.text('label').trim()}', labelOf(Answers.adl, f.status) ?? '—', moodOf(Answers.adl, f.status), [if (f.text('notes').trim().isNotEmpty) f.text('notes').trim()]),
            ],
          'plan' => [
              if (a.problems.where((p) => !p.blank).isNotEmpty)
                REntries([for (final p in a.problems.where((p) => !p.blank)) (title: p.problem.trim(), body: p.plan.trim(), meta: 'Treatment plan')]),
            ],
          'goals' => [
              for (final (term, title) in const [('short', 'Short-Term Goals'), ('long', 'Long-Term Goals')])
                if (a.goalsOf(term).where((g) => g.description.trim().isNotEmpty).toList() case final gs when gs.isNotEmpty) ...[
                  RHeading(title),
                  REntries([
                    for (final g in gs)
                      (
                        title: g.description.trim(),
                        body: '',
                        meta: [labelOf(Answers.goalStatus, g.status) ?? '', if (g.targetDate != null) 'Target ${fmtDate(g.targetDate!, 'd MMM yyyy')}'].join(' · '),
                      ),
                  ]),
                ],
            ],
          'approaches' => texts([('Approaches Used', a.text('approaches')), ('Approaches', a.many('approach_tags').join(', '))]),
          'home' => texts([
              ('Home activities', a.text('home_activities')),
              ('Frequency', a.text('home_frequency')),
              ('Duration', a.text('home_duration')),
              ('Parent / caregiver instructions', a.text('home_instructions')),
              ('Precautions / notes', a.text('home_precautions')),
            ]),
          _ => const <RBlock>[],
        }),
      ),
  ];
}

/// The report on screen.
class AssessmentReport extends StatelessWidget {
  final Assessment a;
  final void Function(int section)? onEditSection;
  const AssessmentReport(this.a, {super.key, this.onEditSection});

  @override
  Widget build(BuildContext context) {
    final report = buildReport(a);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final (i, s) in report.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
            padding: const EdgeInsets.fromLTRB(18, 14, 10, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                IconTile(s.def.icon, size: 30),
                const SizedBox(width: 10),
                Expanded(child: Text('${i + 1}. ${s.def.title}', style: display(16))),
                if (onEditSection != null) IconButton(tooltip: 'Edit ${s.def.short}', onPressed: () => onEditSection!(i), icon: const Icon(Icons.edit_outlined, size: 19, color: C.muted)),
              ]),
              const SizedBox(height: 10),
              Padding(padding: const EdgeInsets.only(right: 8), child: _Blocks(s.blocks)),
            ]),
          ),
        ),
    ]);
  }
}

class _Blocks extends StatelessWidget {
  final List<RBlock> blocks;
  const _Blocks(this.blocks);

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final b in blocks)
          switch (b) {
            RText(:final label, :final value) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: LayoutBuilder(builder: (context, c) {
                  final l = Text(label, style: body(12.5, weight: FontWeight.w700, color: C.muted));
                  final v = SelectableText(value, style: body(14, height: 1.45));
                  return c.maxWidth >= 520
                      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 180, child: Padding(padding: const EdgeInsets.only(top: 1), child: l)), Expanded(child: v)])
                      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [l, const SizedBox(height: 2), v]);
                }),
              ),
            RItem(:final label, :final answer, :final mood, :final details) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(label, style: body(14, weight: FontWeight.w600))),
                    const SizedBox(width: 8),
                    StatusChip(answer, tone: moodTone(mood)),
                  ]),
                  if (details.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: SelectableText(details.join(' · '), style: body(12.5, color: C.muted, height: 1.4))),
                ]),
              ),
            RHeading(:final text) => Padding(padding: const EdgeInsets.only(top: 10, bottom: 2), child: Overline(text)),
            RTable(:final head, :final rows) => _RomReport(head: head, rows: rows),
            REntries(:final entries) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final (i, x) in entries.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: C.brand50, borderRadius: BorderRadius.circular(7)),
                        child: Text('${i + 1}', style: body(11.5, weight: FontWeight.w800, color: C.brand700)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SelectableText(x.title, style: body(14, weight: FontWeight.w700, height: 1.35)),
                          if (x.body.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(x.meta, style: body(11.5, weight: FontWeight.w700, color: C.muted)),
                            SelectableText(x.body, style: body(13.5, height: 1.4)),
                          ] else if (x.meta.isNotEmpty)
                            Text(x.meta, style: body(12, weight: FontWeight.w600, color: C.muted)),
                        ]),
                      ),
                    ]),
                  ),
              ]),
            RNone(:final text) => Text(text, style: body(13, color: C.muted)),
          },
      ]);
}

/// Range of motion: one row per joint on wide screens, stacked per joint on phones.
class _RomReport extends StatelessWidget {
  final List<String> head;
  final List<List<String>> rows;
  const _RomReport({required this.head, required this.rows});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        String v(String s) => s.isEmpty ? '—' : s;
        final recorded = rows.where((r) => r.skip(1).any((x) => x.isNotEmpty)).toList();
        if (c.maxWidth >= 620) {
          return Table(
            columnWidths: const {0: FlexColumnWidth(1.6)},
            border: const TableBorder(horizontalInside: BorderSide(color: C.line)),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: C.brand50),
                children: [for (final h in head) Padding(padding: const EdgeInsets.all(8), child: Text(h, style: body(11.5, weight: FontWeight.w800, color: C.brand700)))],
              ),
              for (final r in recorded) TableRow(children: [for (final (i, x) in r.indexed) Padding(padding: const EdgeInsets.all(8), child: Text(i == 0 ? x : v(x), style: body(13, weight: i == 0 ? FontWeight.w700 : FontWeight.w500)))]),
            ],
          );
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final r in recorded)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r[0], style: body(14, weight: FontWeight.w700)),
                Text('Right — AROM ${v(r[1])} · PROM ${v(r[2])} · Strength ${v(r[3])}', style: body(12.5, color: C.muted)),
                Text('Left — AROM ${v(r[4])} · PROM ${v(r[5])} · Strength ${v(r[6])}', style: body(12.5, color: C.muted)),
              ]),
            ),
        ]);
      });
}
