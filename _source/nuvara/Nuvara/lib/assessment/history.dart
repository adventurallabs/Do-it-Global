import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/ui.dart';
import 'api.dart';
import 'catalog.dart';
import 'model.dart';
import 'widgets.dart';

/// A child's assessments, newest first: type, date, therapist, status, last update. Tapping one opens it
/// (the report once completed, the editor while unfinished). [base] is the child's route, e.g. `/admin/children/<id>`.
class AssessmentHistory extends StatefulWidget {
  final Child child;
  final String base;
  const AssessmentHistory({super.key, required this.child, required this.base});

  @override
  State<AssessmentHistory> createState() => _AssessmentHistoryState();
}

class _AssessmentHistoryState extends State<AssessmentHistory> {
  Object? _error;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      await context.read<AppStore>().loadAssessments(widget.child.id);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _open(String id) async {
    await context.push('${widget.base}/assessments/$id');
    if (mounted) unawaited(context.read<AppStore>().refreshAssessments(widget.child.id));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final c = widget.child;
    final all = store.assessmentsOf(c.id);
    final list = all?.where((s) => _showArchived || s.status != 'archived').toList();
    final archived = all?.where((s) => s.status == 'archived').length ?? 0;
    final canStart = store.canStartAssessment(c.id) && c.active;
    final hasCompleted = all?.any((s) => s.status == 'completed') ?? false;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(
        'Assessments',
        hint: all == null || all.isEmpty ? 'Pediatric OT assessment' : '${plural(all.length, 'assessment')} on record',
        action: canStart ? TextButton.icon(onPressed: () => _start(context), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('New assessment')) : null,
      ),
      if (all == null && _error == null)
        const AppCard(child: SizedBox(height: 64, child: Center(child: CircularProgressIndicator())))
      else if (_error != null && all == null)
        EmptyState(icon: Icons.cloud_off_rounded, title: 'Couldn\'t load assessments', hint: cleanError(_error!), action: btn('Try again', icon: Icons.refresh_rounded, onPressed: _load))
      else if (all!.isEmpty)
        c.assessmentNeeded
            ? _NoAssessment(child: c, onStart: canStart ? () => _start(context) : null)
            : EmptyState(
                icon: Icons.assignment_outlined,
                title: 'No assessments in the app yet',
                hint: 'Start one whenever ${c.first} needs assessing. Each one is kept, and the scores build a progress chart over time.',
                action: canStart ? btn('New assessment', icon: Icons.add_rounded, kind: 'filled', onPressed: () => _start(context)) : null,
              )
      else ...[
        if (c.assessmentNeeded && !hasCompleted && !all.any((s) => !s.finished))
          Padding(padding: const EdgeInsets.only(bottom: 10), child: _NoAssessment(child: c, onStart: canStart ? () => _start(context) : null)),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final (i, s) in list!.indexed) ...[if (i > 0) const Divider(indent: 70), _HistoryRow(s: s, onTap: () => _open(s.id))],
          ]),
        ),
        if (archived > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: () => setState(() => _showArchived = !_showArchived), child: Text(_showArchived ? 'Hide archived' : 'Show ${plural(archived, 'archived assessment')}')),
          ),
      ],
    ]);
  }

  Future<void> _start(BuildContext context) => startNewAssessment(context, widget.child, widget.base);
}

/// "New assessment" from anywhere on a child's profile: asks for the type (and therapist), then opens it.
/// [base] is the child's route, e.g. `/admin/children/<id>`.
Future<void> startNewAssessment(BuildContext context, Child child, String base) async {
  final store = context.read<AppStore>();
  if (store.assessmentsOf(child.id) == null) {
    try {
      await store.loadAssessments(child.id);
    } catch (e) {
      if (context.mounted) toast(context, cleanError(e), error: true);
      return;
    }
  }
  if (!context.mounted) return;
  final id = await startAssessmentSheet(context, store, child);
  if (id != null && context.mounted) await context.push('$base/assessments/$id');
  // Whatever happened in there (saved a draft, completed it, deleted it) shows on the profile straight away.
  unawaited(store.refreshAssessments(child.id));
}

class _NoAssessment extends StatelessWidget {
  final Child child;
  final VoidCallback? onStart;
  const _NoAssessment({required this.child, this.onStart});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: C.amberBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.amber.withValues(alpha: 0.25))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.assignment_late_outlined, color: C.amber),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('No completed assessment yet', style: body(14.5, weight: FontWeight.w800, color: C.amber)),
                const SizedBox(height: 3),
                Text('Every child needs a Pediatric OT assessment on record. It saves as you go, so it can be finished over more than one sitting.',
                    style: body(13, color: const Color(0xFF6B4A12), height: 1.4)),
              ]),
            ),
          ]),
          if (onStart != null) ...[
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: btn('Attend Assessment', icon: Icons.assignment_outlined, kind: 'accent', onPressed: onStart)),
          ],
        ]),
      );
}

class _HistoryRow extends StatelessWidget {
  final AssessmentSummary s;
  final VoidCallback onTap;
  const _HistoryRow({required this.s, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final (icon, color) = switch (s.status) {
      'completed' => (Icons.task_alt_rounded, C.green),
      'archived' => (Icons.inventory_2_outlined, C.muted),
      _ => (Icons.edit_note_rounded, C.clay600),
    };
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 10, 13),
        child: Row(children: [
          IconTile(icon, color: color, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.kindLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14.5, weight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                [fmtDate(s.date, 'd MMM yyyy'), s.therapistId == null ? 'No therapist yet' : store.therapistName(s.therapistId)].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: body(12.5, weight: FontWeight.w600, color: C.ink.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 5),
              Row(children: [
                if (!s.finished) ...[
                  SizedBox(width: 72, child: Bar(s.progress / 100, height: 5)),
                  const SizedBox(width: 8),
                  Text('${s.progress}% · ', style: body(11.5, weight: FontWeight.w700, color: C.muted).copyWith(fontFeatures: tnum)),
                ],
                Flexible(child: Text('Updated ${timeAgo(s.updatedAt)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11.5, color: C.muted))),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            StatusChip(s.statusLabel, tone: moodTone(moodOf(Answers.status, s.status))),
            if (!s.finished) ...[const SizedBox(height: 6), Text('Continue', style: body(12.5, weight: FontWeight.w800, color: C.brand700))],
          ]),
          const Icon(Icons.chevron_right_rounded, color: C.muted),
        ]),
      ),
    );
  }
}

/// Asks for the type (and, for the admin, the therapist) and starts an assessment for [child]. A re-assessment
/// can start from the last completed one, so only what changed needs entering. Returns the new id.
Future<String?> startAssessmentSheet(BuildContext context, AppStore store, Child child) async {
  final history = store.assessmentsOf(child.id) ?? const <AssessmentSummary>[];
  final unfinished = history.where((s) => !s.finished).toList();
  if (unfinished.isNotEmpty) {
    final open = unfinished.first;
    final choice = await showDialog<String>(
      context: context,
      barrierColor: C.brand900.withValues(alpha: 0.45),
      builder: (c) => AlertDialog(
        title: Text('An assessment is still open', style: display(21)),
        content: Text(
          'The ${open.kindLabel.toLowerCase()} from ${fmtDate(open.date, 'd MMM')} is ${open.progress}% recorded. Continue it, or start a separate new one?',
          style: body(14.5, color: C.muted, height: 1.45),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          OutlinedButton(onPressed: () => Navigator.pop(c, 'new'), child: const Text('Start new')),
          FilledButton(onPressed: () => Navigator.pop(c, 'continue'), child: const Text('Continue it')),
        ],
      ),
    );
    if (choice == 'continue') return open.id;
    if (choice != 'new' || !context.mounted) return null;
  }
  final last = history.where((s) => s.status == 'completed').firstOrNull;
  return showSheet<String>(context, builder: (_) => _StartSheet(child: child, last: last));
}

class _StartSheet extends StatefulWidget {
  final Child child;
  final AssessmentSummary? last;
  const _StartSheet({required this.child, required this.last});

  @override
  State<_StartSheet> createState() => _StartSheetState();
}

class _StartSheetState extends State<_StartSheet> {
  late String kind = widget.last == null ? 'initial' : 'reassessment';
  late bool copy = widget.last != null;
  String? therapist;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    therapist = store.isAdmin ? (store.activeTherapists.length == 1 ? store.activeTherapists.first.id : widget.last?.therapistId) : store.therapistId;
    if (therapist != null && store.therapist(therapist)?.active != true) therapist = null;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return SheetBody(
      title: 'New assessment',
      subtitle: '${widget.child.name} · ${widget.child.code}',
      footer: [
        btn('Cancel', onPressed: () => Navigator.pop(context)),
        ActionButton('Start assessment', icon: Icons.arrow_forward_rounded, onPressed: () async {
          final nav = Navigator.of(context);
          final id = await store.createAssessment(childId: widget.child.id, kind: kind, therapistId: therapist, copyFrom: copy ? widget.last?.id : null);
          nav.pop(id);
          return null;
        }),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Labelled('Assessment type', child: Pills(options: Answers.kind, value: kind, onChanged: (v) => setState(() => kind = v ?? kind))),
        if (store.isAdmin) ...[
          const SizedBox(height: 18),
          Labelled(
            'Therapist',
            hint: 'You can change this later in the assessment.',
            child: Pills(options: [for (final t in store.activeTherapists) Opt(t.id, t.name)], value: therapist, onChanged: (v) => setState(() => therapist = v)),
          ),
        ],
        if (widget.last != null) ...[
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(color: C.canvas, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
            child: SwitchListTile(
              value: copy,
              onChanged: (v) => setState(() => copy = v),
              title: Text('Start from the last assessment', style: body(14.5, weight: FontWeight.w700)),
              subtitle: Text(
                'Pre-fills everything from ${fmtDate(widget.last!.date, 'd MMM yyyy')}, so you only change what\'s different. The earlier assessment is kept as it is.',
                style: body(12.5, color: C.muted, height: 1.35),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

// ======================================================================== intake (Add child)

/// The "Attend Assessment" step of the Add child form. A new child can't be created until it is completed.
/// The assessment saves itself as a draft, so leaving the form never loses it: it's offered again next time.
class IntakeAssessmentCard extends StatefulWidget {
  /// The intake assessment chosen for this form, if any.
  final AssessmentSummary? current;
  final ValueChanged<AssessmentSummary?> onChanged;

  /// What's typed on the form, to pre-fill the assessment with.
  final String Function() name;
  final String? Function() dob;
  final String? error;
  const IntakeAssessmentCard({super.key, required this.current, required this.onChanged, required this.name, required this.dob, this.error});

  @override
  State<IntakeAssessmentCard> createState() => _IntakeAssessmentCardState();
}

class _IntakeAssessmentCardState extends State<IntakeAssessmentCard> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    context.read<AppStore>().loadIntakeDrafts().catchError((_) => const <AssessmentSummary>[]).whenComplete(() {
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _open(String id) async {
    final store = context.read<AppStore>();
    await context.push('/admin/children/new/assessment/$id');
    if (!mounted) return;
    try {
      final s = await store.fetchAssessmentSummary(id);
      widget.onChanged(s);
      unawaited(store.loadIntakeDrafts().catchError((_) => const <AssessmentSummary>[]));
    } catch (_) {
      // Deleted from inside the editor.
      widget.onChanged(null);
      unawaited(store.loadIntakeDrafts().catchError((_) => const <AssessmentSummary>[]));
    }
  }

  /// An intake that belongs to nobody being added: a draft is deleted; a completed one is archived (kept, as every
  /// finished clinical record is).
  Future<void> _remove(AssessmentSummary d) async {
    final store = context.read<AppStore>();
    final done = d.status == 'completed';
    final ok = await confirm(
      context,
      title: done ? 'Archive this assessment?' : 'Delete this draft?',
      message: done
          ? 'The completed assessment for ${d.childName.trim().isEmpty ? 'this child' : d.childName.trim()} is kept in the archive but no longer offered here.'
          : 'Everything recorded in this unfinished assessment is deleted. This can\'t be undone.',
      action: done ? 'Archive' : 'Delete',
      danger: !done,
    );
    if (!ok || !mounted) return;
    try {
      done ? await store.archiveAssessment(d.id, true) : await store.deleteAssessment(d.id);
      if (widget.current?.id == d.id) widget.onChanged(null);
      await store.loadIntakeDrafts();
    } catch (e) {
      if (mounted) toast(context, cleanError(e), error: true);
    }
  }

  Future<String?> _start() async {
    final store = context.read<AppStore>();
    final therapist = store.activeTherapists.length == 1 ? store.activeTherapists.first.id : null;
    final id = await store.createAssessment(kind: 'initial', therapistId: therapist, name: widget.name(), dob: widget.dob());
    await _open(id);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final s = widget.current;
    final others = store.intakeDrafts.where((d) => d.id != s?.id).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (s == null) ...[
        Text('Mandatory before the child can be created. It saves as you go, so you can leave and continue later.', style: body(12.5, color: C.muted, height: 1.4)),
        const SizedBox(height: 14),
        ActionButton('Attend Assessment', icon: Icons.assignment_outlined, large: true, style: FilledButton.styleFrom(backgroundColor: C.clay600), onPressed: _start),
      ] else
        _Current(s: s, onOpen: () => _open(s.id)),
      if (widget.error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(widget.error!, style: body(12, weight: FontWeight.w700, color: C.red))),
      if (_loading && s == null)
        const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator(minHeight: 2))
      else if (others.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(s == null ? 'Or continue an unfinished one' : 'Other unfinished intake assessments', style: body(12.5, weight: FontWeight.w700, color: C.muted)),
        const SizedBox(height: 8),
        for (final d in others.take(4))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: C.canvas,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: C.line)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  widget.onChanged(d);
                  _open(d.id);
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.childName.trim().isEmpty ? 'Unnamed child' : d.childName, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w700)),
                        Text('${d.status == 'completed' ? 'Completed' : '${d.progress}% recorded'} · saved ${timeAgo(d.updatedAt)}', style: body(12, color: C.muted)),
                      ]),
                    ),
                    Text(d.status == 'completed' ? 'Use' : 'Continue', style: body(13, weight: FontWeight.w800, color: C.brand700)),
                    IconButton(
                      tooltip: d.status == 'completed' ? 'Archive (not for a child being added)' : 'Delete this draft',
                      onPressed: () => _remove(d),
                      icon: const Icon(Icons.close_rounded, size: 18, color: C.muted),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ],
    ]);
  }
}

class _Current extends StatelessWidget {
  final AssessmentSummary s;
  final VoidCallback onOpen;
  const _Current({required this.s, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final done = s.status == 'completed';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: done ? C.greenBg : C.amberBg, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (done)
            const Icon(Icons.task_alt_rounded, color: C.green, size: 30)
          else
            SizedBox(
              width: 34,
              height: 34,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox.expand(child: CircularProgressIndicator(value: s.progress / 100, strokeWidth: 3.5, color: C.clay500, backgroundColor: Colors.white)),
                Text('${s.progress}', style: body(10.5, weight: FontWeight.w800).copyWith(fontFeatures: tnum)),
              ]),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(done ? 'Assessment completed' : 'Assessment in progress · ${s.progress}%', style: body(14.5, weight: FontWeight.w800, color: done ? C.green : C.amber)),
              Text(
                [fmtDate(s.date, 'd MMM yyyy'), if (s.therapistId != null) store.therapistName(s.therapistId), 'saved ${timeAgo(s.updatedAt)}'].join(' · '),
                style: body(12.5, color: C.ink.withValues(alpha: 0.7)),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: done ? btn('View or edit', icon: Icons.visibility_outlined, onPressed: onOpen) : btn('Continue Assessment', icon: Icons.play_arrow_rounded, kind: 'filled', onPressed: onOpen),
        ),
      ]),
    );
  }
}
