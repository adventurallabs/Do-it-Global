import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../offline.dart' show savedAtLabel;
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/brand.dart';
import '../widgets/ui.dart';
import 'api.dart';
import 'catalog.dart';
import 'editor.dart';
import 'model.dart';
import 'pdf.dart';
import 'pending.dart';
import 'report.dart';
import 'sections.dart';
import 'widgets.dart';

/// Opens one assessment: the editor while it's unfinished (or being edited), otherwise the read-only report.
/// Pops with `true` once the assessment has been completed here.
class AssessmentScreen extends StatefulWidget {
  final String id;
  const AssessmentScreen(this.id, {super.key});

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  AssessmentEditor? _e;
  Object? _error;
  bool _editing = false, _completedHere = false;
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    // Leaving the app (switching away, locking the phone, closing the tab) saves straight away.
    _life = AppLifecycleListener(onInactive: _flush, onHide: _flush, onPause: _flush);
    _load();
  }

  void _flush() => unawaited(_e?.flush());

  @override
  void dispose() {
    _life.dispose();
    _e?.dispose();
    super.dispose();
  }

  bool _canEdit(AppStore store, Assessment a) => store.canEditAssessment(status: a.status, childId: a.childId, assessedBy: a.therapistId);

  Future<void> _load() async {
    final store = context.read<AppStore>();
    setState(() => _error = null);
    try {
      // Waits for a send of this assessment's kept changes that may be running (app start), so they're
      // either already on the server when it loads, or recovered here: never both.
      await PendingAssessments.exclusive(widget.id, () async {
        final a = await store.fetchAssessment(widget.id);
        if (!mounted) return;
        final editable = _canEdit(store, a);
        final e = AssessmentEditor(a, save: store.saveAssessment, userId: store.userId, readOnly: !editable || a.finished);
        final old = _e;
        setState(() => _e = e);
        // Only once nothing on screen listens to it any more.
        if (old != null) WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
        if (editable) await _recover(store, e);
      });
    } catch (err) {
      if (mounted) setState(() => _error = err);
    }
  }

  /// Changes this device kept after a failed save: put them back (same revision), or ask (someone saved since).
  Future<void> _recover(AppStore store, AssessmentEditor e) async {
    final uid = store.userId;
    if (uid == null) return;
    final p = await PendingAssessments.read(uid, e.a.id);
    if (p == null || !mounted) return;
    if (p.rev == e.a.rev) {
      if (e.a.finished) setState(() => _editing = true);
      e.readOnly = false;
      e.restore(p.payload);
      toast(context, 'Recovered changes from ${savedAtLabel(p.savedAt)} that hadn\'t been saved yet.');
      return;
    }
    final keep = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text('Unsaved changes found', style: display(21)),
        content: Text(
          'This device kept changes from ${savedAtLabel(p.savedAt)} that never reached the server, but the assessment has been saved from somewhere else since. Which version do you want?',
          style: body(14.5, color: C.muted, height: 1.45),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Use the saved version')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Use this device\'s changes')),
        ],
      ),
    );
    if (!mounted) return;
    if (keep == true) {
      e.readOnly = false;
      if (e.a.finished) setState(() => _editing = true);
      e.restore(p.payload);
    } else {
      await PendingAssessments.remove(uid, e.a.id);
    }
  }

  Future<bool> _leave() async {
    final e = _e;
    if (e == null || e.readOnly) return true;
    if (await e.flush()) return true;
    if (!mounted) return false;
    final kept = e.userId != null;
    return await confirm(
      context,
      title: e.state == SaveState.conflict ? 'Changed on another device' : 'Not saved to the server yet',
      message: e.state == SaveState.conflict
          ? 'Someone saved this assessment from another device. Your changes are kept on this device; open the assessment again to choose which version to keep.'
          : kept
              ? 'Your latest changes are kept on this device and will be saved automatically when you open this assessment again with a connection.'
              : 'Your latest changes couldn\'t be saved. If you leave now they will be lost.',
      action: 'Leave',
      danger: !kept,
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    if (e == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pediatric OT Assessment')),
        body: _error == null
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Couldn\'t open the assessment',
                  hint: cleanError(_error!),
                  action: btn('Try again', icon: Icons.refresh_rounded, kind: 'filled', onPressed: _load),
                ),
              ),
      );
    }
    return ListenableBuilder(
      listenable: e,
      builder: (context, _) {
        final store = context.read<AppStore>();
        if (e.a.finished && !_editing) {
          return AssessmentView(
            e: e,
            canEdit: _canEdit(store, e.a),
            justCompleted: _completedHere,
            onEdit: () => setState(() {
              _editing = true;
              e.readOnly = false;
              e.goTo(0);
            }),
            onChanged: _load,
            onDone: () => Navigator.of(context).pop(_completedHere),
          );
        }
        Future<void> exit() async {
          final nav = Navigator.of(context);
          if (!await _leave() || !mounted) return;
          // Editing a finished assessment: back to its report rather than out of it.
          if (e.a.finished && _editing) {
            setState(() {
              _editing = false;
              e.readOnly = true;
            });
          } else {
            nav.pop(_completedHere);
          }
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) exit();
          },
          child: AssessmentEditorView(
            e: e,
            onExit: exit,
            onCompleted: () {
              setState(() {
                _completedHere = true;
                _editing = false;
                e.readOnly = true;
              });
            },
            onDeleted: () => Navigator.of(context).pop(false),
          ),
        );
      },
    );
  }
}

// ======================================================================== editor

class AssessmentEditorView extends StatefulWidget {
  final AssessmentEditor e;
  final Future<void> Function() onExit;
  final VoidCallback onCompleted, onDeleted;
  const AssessmentEditorView({super.key, required this.e, required this.onExit, required this.onCompleted, required this.onDeleted});

  @override
  State<AssessmentEditorView> createState() => _AssessmentEditorViewState();
}

class _AssessmentEditorViewState extends State<AssessmentEditorView> {
  /// Set once the therapist tries to complete: from then on missing essentials are marked at their fields.
  bool _showErrors = false;
  final _scroll = <int, ScrollController>{};

  AssessmentEditor get e => widget.e;

  @override
  void dispose() {
    for (final c in _scroll.values) {
      c.dispose();
    }
    super.dispose();
  }

  ScrollController _scrollFor(int i) => _scroll[i] ??= ScrollController();

  void _go(int i) {
    FocusManager.instance.primaryFocus?.unfocus();
    e.goTo(i);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _scroll[i];
      if (c != null && c.hasClients) c.jumpTo(0);
    });
  }

  Map<String, String> _errors(List<Issue> issues) => {
        for (final i in issues)
          // Impossible values are always pointed out; missing essentials only once completion was attempted.
          if (_showErrors || !(i.message.startsWith('Enter') || i.message.startsWith('Select') || i.message.startsWith('Add') || i.message.startsWith('Choose'))) i.field: i.message,
      };

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: e, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final rail = width >= 1000;
    final issues = assessmentIssues(e.a);
    final errors = _errors(issues);
    final page = e.reviewing
        ? _ReviewPage(e: e, issues: issues, onGo: (i) => _go(i), controller: _scrollFor(sections.length))
        : _SectionPage(key: ValueKey('page${e.section}|${e.generation}'), e: e, errors: errors, controller: _scrollFor(e.section));
    // The step buttons sit under the form itself (not under the section list), and make way for the keyboard on
    // phones so the field being typed in stays in view.
    final typing = !rail && MediaQuery.viewInsetsOf(context).bottom > 0;
    final content = Column(children: [
      Expanded(child: page),
      if (!typing) _BottomBar(e: e, onGo: _go, onComplete: () => _complete(issues)),
    ]);
    return Scaffold(
      backgroundColor: C.canvas,
      body: Column(children: [
        _Header(e: e, wide: width >= 720, onExit: widget.onExit, onDeleted: widget.onDeleted, onReview: () => _go(sections.length)),
        if (e.state == SaveState.conflict) _ConflictBar(e: e),
        Expanded(
          child: rail
              ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(width: 292, child: _Rail(e: e, onGo: _go)),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(child: content),
                ])
              : Column(children: [_Strip(e: e, onGo: _go), Expanded(child: content)]),
        ),
      ]),
    );
  }

  Future<void> _complete(List<Issue> issues) async {
    final store = context.read<AppStore>();
    final critical = issues.where((i) => i.critical).toList();
    if (critical.isNotEmpty) {
      setState(() => _showErrors = true);
      if (!e.reviewing) _go(sections.length);
      toast(context, critical.length == 1 ? critical.first.message : '${critical.length} things are needed before completing. They\'re listed at the top.', error: true);
      return;
    }
    final open = [for (final s in sections) if (!sectionProgress(e.a, s.id).complete) s];
    final ok = await confirm(
      context,
      title: 'Complete this assessment?',
      message: open.isEmpty
          ? 'Every section is recorded. It will be saved as completed in ${e.a.childName.trim().isEmpty ? 'the child' : firstWord(e.a.childName.trim())}\'s assessment history.'
          : '${plural(open.length, 'section')} ${open.length == 1 ? 'isn\'t' : 'aren\'t'} fully recorded (${open.take(4).map((s) => s.short).join(', ')}${open.length > 4 ? '…' : ''}). '
              'Unanswered items will show as not recorded. You can still edit the assessment later.',
      action: 'Complete assessment',
      danger: false,
    );
    if (!ok || !mounted) return;
    try {
      await e.complete(store.completeAssessment);
      if (e.a.childId != null) unawaited(store.refreshAssessments(e.a.childId!));
      widget.onCompleted();
    } catch (err) {
      if (mounted) toast(context, cleanError(err), error: true);
    }
  }
}

class _Header extends StatelessWidget {
  final AssessmentEditor e;
  final bool wide;
  final Future<void> Function() onExit;
  final VoidCallback onDeleted, onReview;
  const _Header({required this.e, required this.wide, required this.onExit, required this.onDeleted, required this.onReview});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final a = e.a;
    final child = store.child(a.childId);
    final pct = progressPercent(a);
    final name = a.childName.trim().isEmpty ? 'New child' : a.childName.trim();
    return Material(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Container(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
          padding: EdgeInsets.fromLTRB(wide ? 12 : 4, 6, wide ? 16 : 8, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              IconButton(tooltip: 'Save & exit', onPressed: onExit, icon: const Icon(Icons.arrow_back_rounded)),
              if (wide) ...[const NuvaraMark(size: 30), const SizedBox(width: 12)],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('PEDIATRIC OT ASSESSMENT', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(10.5, weight: FontWeight.w800, color: C.clay600).copyWith(letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: display(wide ? 20 : 17))),
                    const SizedBox(width: 8),
                    IdBadge(child?.code ?? 'New'),
                  ]),
                ]),
              ),
              if (wide) ...[
                const SizedBox(width: 8),
                Flexible(child: AutosaveIndicator(e)),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onExit,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
                  icon: const Icon(Icons.save_alt_rounded, size: 18),
                  label: Text(a.finished ? 'Save & close' : 'Save draft & exit'),
                ),
              ],
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (v) async {
                  switch (v) {
                    case 'exit':
                      await onExit();
                    case 'review':
                      onReview();
                    case 'pdf':
                      try {
                        await shareAssessmentPdf(store, a, childCode: child?.code);
                      } catch (err) {
                        if (context.mounted) toast(context, cleanError(err), error: true);
                      }
                    case 'delete':
                      final ok = await confirm(context, title: 'Delete this draft?', message: 'Everything recorded in this unfinished assessment will be deleted. This can\'t be undone.', action: 'Delete draft');
                      if (!ok || !context.mounted) return;
                      try {
                        e.readOnly = true;
                        await store.deleteAssessment(a.id);
                        if (a.childId != null) unawaited(store.refreshAssessments(a.childId!));
                        onDeleted();
                      } catch (err) {
                        e.readOnly = false;
                        if (context.mounted) toast(context, cleanError(err), error: true);
                      }
                  }
                },
                itemBuilder: (_) => [
                  _menu('exit', Icons.save_alt_rounded, a.finished ? 'Save & close' : 'Save draft & exit'),
                  _menu('review', Icons.fact_check_outlined, a.finished ? 'Review' : 'Review & complete'),
                  _menu('pdf', Icons.picture_as_pdf_outlined, 'Download PDF'),
                  if (!a.finished && (store.isAdmin || a.createdBy == store.userId)) ...[const PopupMenuDivider(), _menu('delete', Icons.delete_outline_rounded, 'Delete draft', danger: true)],
                ],
              ),
            ]),
            const SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: wide ? 8 : 12),
              child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                _MetaChip(icon: Icons.category_outlined, label: labelOf(Answers.kind, a.kind) ?? 'Type', onTap: () => _pickKind(context)),
                _MetaChip(icon: Icons.event_rounded, label: fmtDate(a.date, 'd MMM yyyy'), onTap: () => _pickDate(context)),
                _MetaChip(
                  icon: Icons.person_outline_rounded,
                  label: a.therapistId == null ? 'Choose therapist' : store.therapistName(a.therapistId),
                  warn: a.therapistId == null,
                  onTap: store.isAdmin ? () => _pickTherapist(context) : null,
                ),
                if (a.status == 'completed') const StatusChip('Completed · editing', tone: Tone.green),
                if (!wide) AutosaveIndicator(e, compact: true),
              ]),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: wide ? 8 : 12),
              child: Row(children: [
                Text('Assessment progress', style: body(12, weight: FontWeight.w600, color: C.muted)),
                const SizedBox(width: 10),
                Expanded(child: Bar(pct / 100, height: 6, color: pct == 100 ? C.green : C.clay500)),
                const SizedBox(width: 10),
                Text('$pct%', style: body(13, weight: FontWeight.w800).copyWith(fontFeatures: tnum)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  PopupMenuItem<String> _menu(String v, IconData icon, String label, {bool danger = false}) => PopupMenuItem(
        value: v,
        child: Row(children: [Icon(icon, size: 20, color: danger ? C.red : C.muted), const SizedBox(width: 12), Text(label, style: body(14, color: danger ? C.red : C.ink))]),
      );

  Future<void> _pickKind(BuildContext context) async {
    final v = await showSheet<String>(
      context,
      builder: (c) => SheetBody(
        title: 'Assessment type',
        child: Column(children: [
          for (final o in Answers.kind)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(o.label, style: body(15, weight: FontWeight.w600)),
              trailing: o.value == e.a.kind ? const Icon(Icons.check_circle_rounded, color: C.brand700) : null,
              onTap: () => Navigator.pop(c, o.value),
            ),
        ]),
      ),
    );
    if (v != null) e.change(() => e.a.put('kind', v));
  }

  Future<void> _pickDate(BuildContext context) async {
    final d = await pickDate(context, initial: e.a.date, first: DateTime(DateTime.now().year - 5), last: DateTime.now(), help: 'Date of assessment');
    if (d != null) e.change(() => e.a.put('assessment_date', d));
  }

  Future<void> _pickTherapist(BuildContext context) async {
    final store = context.read<AppStore>();
    final v = await showSheet<String>(
      context,
      builder: (c) => SheetBody(
        title: 'Therapist',
        subtitle: 'Who did this assessment',
        child: Column(children: [
          for (final t in store.activeTherapists)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Avatar(t.name, size: 36),
              title: Text(t.name, style: body(15, weight: FontWeight.w600)),
              subtitle: Text(t.therapyIds.map(store.therapyName).join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, color: C.muted)),
              trailing: t.id == e.a.therapistId ? const Icon(Icons.check_circle_rounded, color: C.brand700) : null,
              onTap: () => Navigator.pop(c, t.id),
            ),
          if (store.activeTherapists.isEmpty) Text('Add a therapist first (Home → Therapists).', style: body(14, color: C.muted)),
        ]),
      ),
    );
    if (v != null) e.change(() => e.a.put('therapist_id', v));
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool warn;
  const _MetaChip({required this.icon, required this.label, required this.onTap, this.warn = false});

  @override
  Widget build(BuildContext context) => Material(
        color: warn ? C.amberBg : C.canvas,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: warn ? C.amber.withValues(alpha: 0.4) : C.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: warn ? C.amber : C.brand700),
              const SizedBox(width: 6),
              ConstrainedBox(constraints: const BoxConstraints(maxWidth: 200), child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, weight: FontWeight.w700, color: warn ? C.amber : C.ink))),
              if (onTap != null) ...[const SizedBox(width: 2), Icon(Icons.arrow_drop_down_rounded, size: 18, color: warn ? C.amber : C.muted)],
            ]),
          ),
        ),
      );
}

class _ConflictBar extends StatelessWidget {
  final AssessmentEditor e;
  const _ConflictBar({required this.e});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    return Container(
      color: C.redBg,
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(children: [
        const Icon(Icons.sync_problem_rounded, color: C.red),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Someone saved this assessment from another device. Your changes are kept here — choose which version to keep.',
              style: body(13, weight: FontWeight.w600, color: C.red, height: 1.35)),
        ),
        const SizedBox(width: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          ActionButton('Load theirs', kind: 'text', onPressed: () async {
            e.takeTheirs(await store.fetchAssessment(e.a.id));
            return 'Loaded the latest saved version';
          }),
          ActionButton('Keep mine', onPressed: () async {
            final theirs = await store.fetchAssessment(e.a.id);
            if (!await e.keepMine(theirs.rev)) throw Exception('Couldn\'t save. Check your connection and try again.');
            return 'Your version is saved';
          }),
        ]),
      ]),
    );
  }
}

/// Every section with its state, on the left on wide screens.
class _Rail extends StatelessWidget {
  final AssessmentEditor e;
  final ValueChanged<int> onGo;
  const _Rail({required this.e, required this.onGo});

  @override
  Widget build(BuildContext context) {
    final done = sections.where((s) => sectionProgress(e.a, s.id).complete).length;
    return Container(
      color: Colors.white,
      child: ListView(padding: const EdgeInsets.fromLTRB(12, 14, 12, 24), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
          child: Row(children: [
            Expanded(child: Overline('Sections')),
            Text('$done of ${sections.length} done', style: body(11.5, weight: FontWeight.w700, color: C.muted)),
          ]),
        ),
        for (final (i, s) in sections.indexed) _RailTile(number: i + 1, title: s.short, p: sectionProgress(e.a, s.id), current: e.section == i, onTap: () => onGo(i)),
        const SizedBox(height: 10),
        _ReviewTile(current: e.reviewing, finished: e.a.finished, onTap: () => onGo(sections.length)),
      ]),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final bool current, finished;
  final VoidCallback onTap;
  const _ReviewTile({required this.current, required this.finished, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: current ? C.brand800 : C.clay50,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(children: [
              Icon(Icons.fact_check_rounded, size: 22, color: current ? Colors.white : C.clay600),
              const SizedBox(width: 12),
              Expanded(child: Text(finished ? 'Review' : 'Review & complete', style: body(14, weight: FontWeight.w800, color: current ? Colors.white : C.clay600))),
            ]),
          ),
        ),
      );
}

class _RailTile extends StatelessWidget {
  final int number;
  final String title;
  final Progress p;
  final bool current;
  final VoidCallback onTap;
  const _RailTile({required this.number, required this.title, required this.p, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: current ? C.brand50 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(children: [
                SectionMark(p, current: current, number: number),
                const SizedBox(width: 12),
                Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13.5, weight: current ? FontWeight.w800 : FontWeight.w600, color: current ? C.brand900 : C.ink))),
                if (!p.complete && p.total > 1) Text('${p.done}/${p.total}', style: body(11, weight: FontWeight.w700, color: C.muted).copyWith(fontFeatures: tnum)),
              ]),
            ),
          ),
        ),
      );
}

/// Phones and tablets: the sections as a scrolling strip under the header, plus a button listing them all.
class _Strip extends StatefulWidget {
  final AssessmentEditor e;
  final ValueChanged<int> onGo;
  const _Strip({required this.e, required this.onGo});

  @override
  State<_Strip> createState() => _StripState();
}

class _StripState extends State<_Strip> {
  final _keys = List.generate(sections.length + 1, (_) => GlobalKey());
  int _shown = -1;

  void _reveal() {
    final i = widget.e.section;
    if (i == _shown) return;
    _shown = i;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _keys[i].currentContext;
      if (c != null) Scrollable.ensureVisible(c, alignment: 0.4, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
    });
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.e;
    _reveal();
    return Container(
      height: 56,
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: C.line))),
      child: Row(children: [
        IconButton(tooltip: 'All sections', onPressed: () => _all(context), icon: const Icon(Icons.format_list_numbered_rounded, color: C.brand700)),
        Expanded(
          // Not a lazy list: every chip exists, so the current one can always be scrolled into view.
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(0, 9, 12, 9),
            child: Row(children: [
              for (final (i, s) in sections.indexed)
                Padding(
                  key: _keys[i],
                  padding: const EdgeInsets.only(right: 6),
                  child: _StripChip(number: i + 1, label: s.short, p: sectionProgress(e.a, s.id), current: e.section == i, onTap: () => widget.onGo(i)),
                ),
              Padding(
                key: _keys[sections.length],
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  avatar: Icon(Icons.fact_check_rounded, size: 17, color: e.reviewing ? Colors.white : C.clay600),
                  label: Text('Review', style: body(12.5, weight: FontWeight.w800, color: e.reviewing ? Colors.white : C.clay600)),
                  backgroundColor: e.reviewing ? C.brand800 : C.clay50,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onPressed: () => widget.onGo(sections.length),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Future<void> _all(BuildContext context) async {
    final e = widget.e;
    final i = await showSheet<int>(
      context,
      builder: (c) => SheetBody(
        title: 'Sections',
        subtitle: '${progressPercent(e.a)}% recorded',
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: Column(children: [
          for (final (i, s) in sections.indexed) _RailTile(number: i + 1, title: s.title, p: sectionProgress(e.a, s.id), current: e.section == i, onTap: () => Navigator.pop(c, i)),
          const SizedBox(height: 8),
          _ReviewTile(current: e.reviewing, finished: e.a.finished, onTap: () => Navigator.pop(c, sections.length)),
        ]),
      ),
    );
    if (i != null) widget.onGo(i);
  }
}

class _StripChip extends StatelessWidget {
  final int number;
  final String label;
  final Progress p;
  final bool current;
  final VoidCallback onTap;
  const _StripChip({required this.number, required this.label, required this.p, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: current ? C.brand800 : (p.complete ? C.greenBg : C.canvas),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: current ? C.brand800 : (p.complete ? Colors.transparent : C.line))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (p.complete)
                Icon(Icons.check_circle_rounded, size: 16, color: current ? Colors.white : C.green)
              else
                Text('$number', style: body(12, weight: FontWeight.w800, color: current ? C.brand200 : C.muted).copyWith(fontFeatures: tnum)),
              const SizedBox(width: 6),
              Text(label, style: body(12.5, weight: FontWeight.w700, color: current ? Colors.white : C.ink)),
            ]),
          ),
        ),
      );
}

/// Which items a section's "Mark the rest" fills, and with which answers.
({List<Opt> options, void Function(Assessment a, String v) fill})? _bulk(String id) {
  void rest(Assessment a, String domain, Iterable<String> keys, String v) {
    for (final k in keys) {
      final f = a.finding(domain, k);
      f.status ??= v;
    }
  }

  return switch (id) {
    'senses' => (options: Answers.senses, fill: (a, v) => rest(a, 'senses', Items.senses.map((i) => i.key), v)),
    'development' => (options: Answers.milestone, fill: (a, v) => rest(a, 'milestones', Items.milestones.map((i) => i.key), v)),
    'behaviour' => (options: Answers.behaviour, fill: (a, v) => rest(a, 'behaviour', Items.behaviour.map((i) => i.key), v)),
    'sensory' => (options: Answers.sensory, fill: (a, v) => rest(a, 'sensory', Items.sensory.map((i) => i.key), v)),
    'posture' => (options: Answers.posture, fill: (a, v) => rest(a, 'posture', Items.posture.map((i) => i.key), v)),
    'reflexes' => (options: Answers.reflex, fill: (a, v) => rest(a, 'reflexes', [...Items.primitiveReflexes, ...Items.otherReflexes].map((i) => i.key), v)),
    'hand' => (options: Answers.hand, fill: (a, v) => rest(a, 'hand', [for (final g in handGroups) ...g.items.map((i) => i.key)], v)),
    'adl' => (options: Answers.adl, fill: (a, v) => rest(a, 'adl', Items.adl.map((i) => i.key), v)),
    _ => null,
  };
}

class _SectionPage extends StatelessWidget {
  final AssessmentEditor e;
  final Map<String, String> errors;
  final ScrollController controller;
  const _SectionPage({super.key, required this.e, required this.errors, required this.controller});

  @override
  Widget build(BuildContext context) {
    final s = sections[e.section];
    final p = sectionProgress(e.a, s.id);
    final bulk = e.readOnly ? null : _bulk(s.id);
    final romFill = s.id == 'rom' && !e.readOnly;
    final pad = MediaQuery.sizeOf(context).width < 600 ? 14.0 : 24.0;
    return ListView(
      controller: controller,
      padding: EdgeInsets.fromLTRB(pad, 20, pad, 40),
      children: [
        Constrained(
          maxWidth: s.id == 'rom' ? 1060 : 880,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 2),
              child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.end, spacing: 12, runSpacing: 10, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('SECTION ${e.section + 1} OF ${sections.length}', style: body(11, weight: FontWeight.w800, color: C.muted).copyWith(letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(s.title, style: display(24, weight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(p.complete ? Icons.check_circle_rounded : Icons.pie_chart_outline_rounded, size: 15, color: p.complete ? C.green : C.muted),
                    const SizedBox(width: 5),
                    Text(p.complete ? 'All recorded' : '${p.done} of ${p.total} recorded', style: body(12.5, weight: FontWeight.w600, color: p.complete ? C.green : C.muted)),
                  ]),
                ]),
                if (bulk != null && !p.complete) FillRest(options: bulk.options, onPick: (v) => e.change(() => bulk.fill(e.a, v))),
                if (romFill)
                  FillRest(
                    label: 'Fill empty AROM / PROM',
                    options: [for (final q in romQuick) Opt(q, q)],
                    onPick: (v) => e.change(() {
                      for (final j in [...Items.upperJoints, ...Items.lowerJoints]) {
                        for (final sd in Items.sides) {
                          final f = e.a.finding('rom', j.key, sd.key);
                          if (f.text('arom').isEmpty) f.setText('arom', v);
                          if (f.text('prom').isEmpty) f.setText('prom', v);
                        }
                      }
                      e.generation++;
                    }),
                  ),
              ]),
            ),
            SectionBody(e: e, id: s.id, errors: errors),
          ]),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  final AssessmentEditor e;
  final ValueChanged<int> onGo;
  final VoidCallback onComplete;
  const _BottomBar({required this.e, required this.onGo, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final i = e.section;
    final last = i == sections.length - 1;
    final narrow = MediaQuery.sizeOf(context).width < 420;
    Widget primary;
    if (e.reviewing) {
      primary = e.a.finished
          ? FilledButton.icon(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.check_rounded), label: const Text('Done'))
          : FilledButton.icon(
              onPressed: onComplete,
              style: FilledButton.styleFrom(backgroundColor: C.green, minimumSize: const Size(0, 50)),
              icon: const Icon(Icons.task_alt_rounded),
              label: const Text('Complete assessment'),
            );
    } else {
      primary = FilledButton(
        onPressed: () async {
          FocusManager.instance.primaryFocus?.unfocus();
          onGo(i + 1);
          unawaited(e.flush());
        },
        style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: Text(last ? (e.a.finished ? 'Save & review' : 'Save & review') : (narrow ? 'Save & next' : 'Save & continue'), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_rounded, size: 18),
        ]),
      );
    }
    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: SafeArea(
        top: false,
        child: Constrained(
          maxWidth: 880,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            if (i > 0)
              OutlinedButton(
                onPressed: () => onGo(i - 1),
                style: OutlinedButton.styleFrom(minimumSize: const Size(50, 50), padding: EdgeInsets.symmetric(horizontal: narrow ? 12 : 16)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.arrow_back_rounded, size: 18), if (!narrow) ...[const SizedBox(width: 6), const Text('Previous')]]),
              ),
            if (i == 0) const SizedBox.shrink(),
            const SizedBox(width: 12),
            Flexible(child: ConstrainedBox(constraints: BoxConstraints(minWidth: narrow ? 0 : 230), child: primary)),
          ]),
        ),
      ),
    );
  }
}

// ======================================================================== review

class _ReviewPage extends StatelessWidget {
  final AssessmentEditor e;
  final List<Issue> issues;
  final ValueChanged<int> onGo;
  final ScrollController controller;
  const _ReviewPage({required this.e, required this.issues, required this.onGo, required this.controller});

  @override
  Widget build(BuildContext context) {
    final critical = issues.where((i) => i.critical).toList();
    final warnings = issues.where((i) => !i.critical).toList();
    final pct = progressPercent(e.a);
    final done = sections.where((s) => sectionProgress(e.a, s.id).complete).length;
    final pad = MediaQuery.sizeOf(context).width < 600 ? 14.0 : 24.0;
    int sectionOf(Issue i) => i.section == 'header' ? 0 : sectionIndex(i.section);
    return ListView(controller: controller, padding: EdgeInsets.fromLTRB(pad, 20, pad, 40), children: [
      Constrained(
        maxWidth: 880,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(e.a.finished ? 'REVIEW' : 'BEFORE YOU COMPLETE', style: body(11, weight: FontWeight.w800, color: C.muted).copyWith(letterSpacing: 1)),
          const SizedBox(height: 4),
          Text('Assessment Summary', style: display(24, weight: FontWeight.w500)),
          const SizedBox(height: 16),
          HeroSurface(
            child: Row(children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox.expand(child: CircularProgressIndicator(value: pct / 100, strokeWidth: 6, color: pct == 100 ? const Color(0xFF6EE7A8) : C.clay500, backgroundColor: Colors.white.withValues(alpha: 0.15))),
                  Text('$pct%', style: display(16, color: Colors.white).copyWith(fontFeatures: tnum)),
                ]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$done of ${sections.length} sections fully recorded', style: body(15, weight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                    critical.isEmpty ? 'Everything essential is in place.' : '${plural(critical.length, 'essential')} still needed.',
                    style: body(13, color: Colors.white.withValues(alpha: 0.8)),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          if (critical.isNotEmpty || warnings.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: critical.isEmpty ? C.amberBg : C.redBg, borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Icon(critical.isEmpty ? Icons.info_outline_rounded : Icons.error_outline_rounded, color: critical.isEmpty ? C.amber : C.red, size: 20),
                  const SizedBox(width: 8),
                  Text(critical.isEmpty ? 'Worth a look' : 'Needed before completing', style: body(14, weight: FontWeight.w800, color: critical.isEmpty ? C.amber : C.red)),
                ]),
                const SizedBox(height: 4),
                for (final i in [...critical, ...warnings])
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onGo(sectionOf(i)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Row(children: [
                        Expanded(
                          child: Text.rich(TextSpan(children: [
                            TextSpan(text: '${i.section == 'header' ? 'Header' : sections[sectionOf(i)].short} — ', style: body(13, weight: FontWeight.w800)),
                            TextSpan(text: i.message, style: body(13)),
                          ])),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: C.muted),
                      ]),
                    ),
                  ),
              ]),
            ),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
            child: Column(children: [
              for (final (i, s) in sections.indexed) ...[
                if (i > 0) const Divider(indent: 58),
                _ReviewRow(number: i + 1, def: s, p: sectionProgress(e.a, s.id), onTap: () => onGo(i)),
              ],
            ]),
          ),
          const SizedBox(height: 14),
          Text('Tap any section to check or change it. Unanswered items appear as not recorded in the report.', style: body(12.5, color: C.muted, height: 1.4)),
        ]),
      ),
    ]);
  }
}

class _ReviewRow extends StatelessWidget {
  final int number;
  final SectionDef def;
  final Progress p;
  final VoidCallback onTap;
  const _ReviewRow({required this.number, required this.def, required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
          child: Row(children: [
            SectionMark(p, number: number),
            const SizedBox(width: 16),
            Expanded(child: Text(def.title, style: body(14.5, weight: FontWeight.w600))),
            Text(
              p.complete ? 'Done' : (p.started ? '${p.done} of ${p.total}' : 'Not started'),
              style: body(12.5, weight: FontWeight.w700, color: p.complete ? C.green : (p.started ? C.amber : C.muted)),
            ),
            const Icon(Icons.chevron_right_rounded, color: C.muted),
          ]),
        ),
      );
}

// ======================================================================== completed: the report

class AssessmentView extends StatelessWidget {
  final AssessmentEditor e;
  final bool canEdit, justCompleted;
  final VoidCallback onEdit, onDone;
  final Future<void> Function() onChanged;
  const AssessmentView({super.key, required this.e, required this.canEdit, required this.justCompleted, required this.onEdit, required this.onDone, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final a = e.a;
    final child = store.child(a.childId);
    final archived = a.status == 'archived';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onDone();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(tooltip: 'Back', onPressed: onDone, icon: const Icon(Icons.arrow_back_rounded)),
          title: const Text('Pediatric OT Assessment'),
          actions: [
            IconButton(
              tooltip: 'Download PDF',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () async {
                try {
                  await shareAssessmentPdf(store, a, childCode: child?.code);
                } catch (err) {
                  if (context.mounted) toast(context, cleanError(err), error: true);
                }
              },
            ),
            if (store.isAdmin)
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (v) async {
                  final ok = await confirm(
                    context,
                    title: archived ? 'Bring back this assessment?' : 'Archive this assessment?',
                    message: archived ? 'It returns to the active history and can be edited again.' : 'It stays in the child\'s history, read-only, marked as archived. Nothing is deleted.',
                    action: archived ? 'Bring back' : 'Archive',
                    danger: false,
                  );
                  if (!ok) return;
                  try {
                    await store.archiveAssessment(a.id, !archived);
                    if (a.childId != null) unawaited(store.refreshAssessments(a.childId!));
                    await onChanged();
                  } catch (err) {
                    if (context.mounted) toast(context, cleanError(err), error: true);
                  }
                },
                itemBuilder: (_) => [PopupMenuItem(value: 'archive', child: Text(archived ? 'Bring back from archive' : 'Archive', style: body(14)))],
              ),
          ],
        ),
        floatingActionButton: canEdit ? FloatingActionButton.extended(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), label: const Text('Edit')) : null,
        body: PageList(children: [
          if (justCompleted)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: C.greenBg, borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  const Icon(Icons.task_alt_rounded, color: C.green),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Assessment completed and saved to the history.', style: body(14, weight: FontWeight.w700, color: C.green))),
                  TextButton(onPressed: onDone, child: const Text('Done')),
                ]),
              ),
            ),
          HeroSurface(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const NuvaraMark(size: 26),
                const SizedBox(width: 10),
                Expanded(child: Text('PEDIATRIC OT ASSESSMENT', style: body(11, weight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.75)).copyWith(letterSpacing: 1))),
                StatusChip(labelOf(Answers.status, a.status) ?? a.status, tone: archived ? Tone.neutral : Tone.green),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Flexible(child: Text(a.childName, style: display(24, color: Colors.white))),
                const SizedBox(width: 8),
                if (child != null) IdBadge(child.code, light: true),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 16, runSpacing: 6, children: [
                for (final t in [
                  labelOf(Answers.kind, a.kind) ?? '',
                  fmtDate(a.date, 'd MMM yyyy'),
                  if (a.therapistId != null) store.therapistName(a.therapistId),
                  if (a.pick('dob') != null) ageAt(a.pick('dob')!, a.date),
                ])
                  Text(t, style: body(13, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.88))),
              ]),
              if (a.completedAt != null) ...[
                const SizedBox(height: 8),
                Text('Completed ${fmtDateTime(a.completedAt!)} · last updated ${fmtDateTime(a.updatedAt)}', style: body(12, color: Colors.white.withValues(alpha: 0.65))),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          AssessmentReport(
            a,
            onEditSection: canEdit
                ? (i) {
                    onEdit();
                    e.goTo(i);
                  }
                : null,
          ),
        ]),
      ),
    );
  }
}
