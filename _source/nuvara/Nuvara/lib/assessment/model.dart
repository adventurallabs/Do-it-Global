import 'dart:math' as math;

import '../models.dart' show Json;
import '../util.dart';
import 'catalog.dart';

// An assessment as the editor holds it: the scalar answers keyed by their database column, rated items as
// findings, and the problem and goal lists. `payload()` is exactly what `save_assessment` takes.

/// The scalar answers `save_assessment` writes, by database column.
const assessmentFields = [
  'therapist_id', 'kind', 'assessment_date', 'current_section', //
  'child_name', 'gender', 'dob', 'referred_by', 'informant', 'hand_dominance', 'surgery', 'surgery_details', 'surgery_date',
  'chief_complaints', 'felt_needs', 'family_history', 'prenatal', 'perinatal', 'postnatal',
  'school_status', 'grade', 'classroom_complaints', 'play_types', 'play_methods', 'group_behaviour',
  'screen_hours', 'screen_minutes', 'screen_content', 'posture_anatomy', 'approaches', 'approach_tags',
  'home_activities', 'home_frequency', 'home_duration', 'home_instructions', 'home_precautions',
];
const _listFields = {'play_types', 'play_methods', 'approach_tags'};
const _findingText = ['label', 'age', 'frequency', 'duration', 'triggers', 'behaviour', 'arom', 'prom', 'notes'];

/// One rated item: a milestone, a behaviour, a reflex, one side of a joint, an ADL…
class Finding {
  final String domain, item, side;
  final Json _m;
  Finding(this.domain, this.item, [this.side = '', Json? values]) : _m = values ?? {};
  factory Finding.of(Json m) => Finding(m['domain'], m['item'], m['side'] ?? '', {
        for (final k in [..._findingText, 'status', 'severity', 'strength'])
          if (m[k] != null && m[k] != '') k: m[k],
      });

  String get key => keyOf(domain, item, side);
  static String keyOf(String domain, String item, [String side = '']) => '$domain|$item|$side';

  String? get status => _m['status'];
  set status(String? v) => _put('status', v);
  String? get severity => _m['severity'];
  set severity(String? v) => _put('severity', v);
  int? get strength => (_m['strength'] as num?)?.toInt();
  set strength(int? v) => _put('strength', v);
  String text(String k) => (_m[k] as String?) ?? '';
  void setText(String k, String v) => _put(k, v);

  void _put(String k, Object? v) {
    if (v == null || v == '') {
      _m.remove(k);
    } else {
      _m[k] = v;
    }
  }

  bool get isEmpty => _m.isEmpty;

  /// Has an answer that counts towards progress: a status, or for a joint any measurement.
  bool get answered => status != null || (domain == 'rom' && (strength != null || text('arom').trim().isNotEmpty || text('prom').trim().isNotEmpty));

  Json toJson() => {'domain': domain, 'item': item, 'side': side, ..._m};
}

class Problem {
  final String id;
  String problem, plan;
  Problem({String? id, this.problem = '', this.plan = ''}) : id = id ?? newId();
  Problem.of(Json m)
      : id = m['id'],
        problem = m['problem'] ?? '',
        plan = m['treatment_plan'] ?? '';
  bool get complete => problem.trim().isNotEmpty && plan.trim().isNotEmpty;
  bool get blank => problem.trim().isEmpty && plan.trim().isEmpty;
}

class Goal {
  final String id, term;
  String description, status;
  String? targetDate, sourceGoalId;
  Goal({String? id, required this.term, this.description = '', this.status = 'not_started', this.targetDate, this.sourceGoalId}) : id = id ?? newId();
  Goal.of(Json m)
      : id = m['id'],
        term = m['term'],
        description = m['description'] ?? '',
        status = m['status'] ?? 'not_started',
        targetDate = m['target_date'],
        sourceGoalId = m['source_goal_id'];
}

/// A random v4 UUID for new problems and goals, so they keep their identity across saves.
String newId() {
  final r = math.Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

class Assessment {
  final String id;
  String? childId;
  String status;
  int rev;
  final String? createdBy, copiedFrom;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? completedAt;
  final Json f;
  final Map<String, Finding> findings;
  final List<Problem> problems;
  final List<Goal> goals;

  Assessment({
    required this.id,
    this.childId,
    this.status = 'draft',
    this.rev = 1,
    this.createdBy,
    this.copiedFrom,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.completedAt,
    Json? fields,
    Map<String, Finding>? findings,
    List<Problem>? problems,
    List<Goal>? goals,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        f = fields ?? {'kind': 'initial', 'assessment_date': todayISO()},
        findings = findings ?? {},
        problems = problems ?? [],
        goals = goals ?? [];

  /// A row of `assessments` with its findings, problems and goals embedded.
  factory Assessment.of(Json m) {
    DateTime? at(String k) => m[k] == null ? null : DateTime.parse(m[k]).toLocal();
    final fields = <String, dynamic>{};
    for (final k in assessmentFields) {
      final v = m[k];
      if (v == null || v == '') continue;
      fields[k] = _listFields.contains(k) ? [for (final x in v as List) '$x'] : (v is num ? v.toInt() : v);
    }
    final fs = [for (final x in (m['assessment_findings'] as List? ?? const [])) Finding.of((x as Map).cast<String, dynamic>())];
    final ps = [for (final x in (m['assessment_problems'] as List? ?? const [])) (x as Map).cast<String, dynamic>()]
      ..sort((a, b) => ((a['position'] as num?) ?? 0).compareTo((b['position'] as num?) ?? 0));
    final gs = [for (final x in (m['assessment_goals'] as List? ?? const [])) (x as Map).cast<String, dynamic>()]
      ..sort((a, b) => ((a['position'] as num?) ?? 0).compareTo((b['position'] as num?) ?? 0));
    return Assessment(
      id: m['id'],
      childId: m['child_id'],
      status: m['status'],
      rev: (m['rev'] as num).toInt(),
      createdBy: m['created_by'],
      copiedFrom: m['copied_from'],
      createdAt: at('created_at'),
      updatedAt: at('updated_at'),
      completedAt: at('completed_at'),
      fields: fields,
      findings: {for (final x in fs) x.key: x},
      problems: [for (final p in ps) Problem.of(p)],
      goals: [for (final g in gs) Goal.of(g)],
    );
  }

  // ---- answers
  String text(String k) => (f[k] as String?) ?? '';
  String? pick(String k) => f[k] as String?;
  int? number(String k) => (f[k] as num?)?.toInt();
  List<String> many(String k) => [...?(f[k] as List?)?.cast<String>()];
  void put(String k, Object? v) {
    if (v == null || v == '' || (v is List && v.isEmpty)) {
      f.remove(k);
    } else {
      f[k] = v;
    }
  }

  String get kind => pick('kind') ?? 'initial';
  String get date => pick('assessment_date') ?? todayISO();
  String? get therapistId => pick('therapist_id');
  String get childName => text('child_name');
  bool get finished => status == 'completed' || status == 'archived';

  /// The finding for an item, created empty on first use (empty ones are never saved).
  Finding finding(String domain, String item, [String side = '']) => findings.putIfAbsent(Finding.keyOf(domain, item, side), () => Finding(domain, item, side));
  Finding? peek(String domain, String item, [String side = '']) => findings[Finding.keyOf(domain, item, side)];
  String? statusOf(String domain, String item) => peek(domain, item)?.status;

  /// "Others" ADLs, in the order they were added.
  List<Finding> get otherAdls => [for (final x in findings.values) if (x.domain == 'adl' && x.item.startsWith(Items.adlOtherPrefix)) x];

  List<Goal> goalsOf(String term) => goals.where((g) => g.term == term).toList();

  Json payload() => {
        'fields': {...f, 'progress': progressPercent(this)},
        'findings': [for (final x in findings.values) if (!x.isEmpty) x.toJson()],
        'problems': [
          for (final (i, p) in problems.indexed)
            if (!p.blank) {'id': p.id, 'position': i, 'problem': p.problem.trim(), 'treatment_plan': p.plan.trim()},
        ],
        'goals': [
          for (final term in const ['short', 'long'])
            for (final (i, g) in goalsOf(term).indexed)
              if (g.description.trim().isNotEmpty) {'id': g.id, 'term': g.term, 'position': i, 'description': g.description.trim(), 'target_date': g.targetDate, 'status': g.status},
        ],
      };

  /// Takes over everything from [other] (the same assessment as saved elsewhere).
  void replaceWith(Assessment other) {
    childId = other.childId;
    status = other.status;
    rev = other.rev;
    updatedAt = other.updatedAt;
    completedAt = other.completedAt;
    f
      ..clear()
      ..addAll(other.f);
    findings
      ..clear()
      ..addAll(other.findings);
    problems
      ..clear()
      ..addAll(other.problems);
    goals
      ..clear()
      ..addAll(other.goals);
  }

  /// This assessment with [payload]'s answers in place of its own (unsynced changes kept on the device).
  void applyPayload(Json payload) {
    final fields = (payload['fields'] as Map? ?? const {}).cast<String, dynamic>();
    f
      ..clear()
      ..addAll({for (final e in fields.entries) if (e.key != 'progress' && e.value != null) e.key: _listFields.contains(e.key) ? [for (final x in e.value as List) '$x'] : e.value});
    final fs = [for (final x in (payload['findings'] as List? ?? const [])) Finding.of((x as Map).cast<String, dynamic>())];
    findings
      ..clear()
      ..addAll({for (final x in fs) x.key: x});
    final keep = {for (final g in goals) g.id: g.sourceGoalId};
    problems
      ..clear()
      ..addAll([for (final x in (payload['problems'] as List? ?? const [])) Problem.of((x as Map).cast<String, dynamic>())]);
    goals
      ..clear()
      ..addAll([
        for (final x in (payload['goals'] as List? ?? const []))
          Goal.of({...(x as Map).cast<String, dynamic>(), 'source_goal_id': keep[x['id']]}),
      ]);
  }
}

/// A row of the assessment history: enough to list it without loading its answers.
class AssessmentSummary {
  final String id, kind, status, date, childName;
  final String? childId, therapistId, createdBy, dob;
  final int progress;
  final DateTime createdAt, updatedAt;
  final DateTime? completedAt;
  AssessmentSummary(Json m)
      : id = m['id'],
        childId = m['child_id'],
        kind = m['kind'],
        status = m['status'],
        date = m['assessment_date'],
        childName = m['child_name'] ?? '',
        dob = m['dob'],
        therapistId = m['therapist_id'],
        createdBy = m['created_by'],
        progress = (m['progress'] as num?)?.toInt() ?? 0,
        createdAt = DateTime.parse(m['created_at']).toLocal(),
        updatedAt = DateTime.parse(m['updated_at']).toLocal(),
        completedAt = m['completed_at'] == null ? null : DateTime.parse(m['completed_at']).toLocal();
  static const columns = 'id, child_id, kind, status, assessment_date, child_name, dob, therapist_id, created_by, progress, created_at, updated_at, completed_at';
  bool get finished => status == 'completed' || status == 'archived';
  String get kindLabel => labelOf(Answers.kind, kind) ?? 'Assessment';
  String get statusLabel => labelOf(Answers.status, status) ?? status;
}

// ---------------------------------------------------------------- progress

typedef Progress = ({int done, int total});

extension ProgressX on Progress {
  bool get complete => total > 0 && done >= total;
  bool get started => done > 0;
}

bool _has(Assessment a, String k) {
  final v = a.f[k];
  return v != null && (v is! String || v.trim().isNotEmpty) && (v is! List || v.isNotEmpty);
}

Progress _count(Iterable<bool> parts) {
  var done = 0, total = 0;
  for (final p in parts) {
    total++;
    if (p) done++;
  }
  return (done: done, total: total);
}

/// How much of a section is recorded. "Not assessed" counts as recorded: the therapist made a decision.
Progress sectionProgress(Assessment a, String id) {
  bool st(String domain, String item, [String side = '']) => a.peek(domain, item, side)?.answered ?? false;
  return switch (id) {
    'demographics' => _count([
        for (final k in const ['child_name', 'gender', 'dob', 'assessment_date', 'referred_by', 'informant', 'hand_dominance', 'surgery', 'chief_complaints', 'felt_needs']) _has(a, k),
        if (a.pick('surgery') == 'yes') _has(a, 'surgery_details'),
      ]),
    'medical' => _count([for (final k in const ['family_history', 'prenatal', 'perinatal', 'postnatal']) _has(a, k)]),
    'senses' => _count([for (final i in Items.senses) st('senses', i.key)]),
    'development' => _count([for (final i in Items.milestones) st('milestones', i.key)]),
    'education' => _count([
        _has(a, 'school_status'),
        if (a.pick('school_status') != 'not_school_going') ...[_has(a, 'grade'), _has(a, 'classroom_complaints')],
      ]),
    'play' => _count([
        _has(a, 'play_types'),
        _has(a, 'play_methods'),
        for (final i in Items.playSkills) st('play_skills', i.key),
        _has(a, 'group_behaviour'),
        st('play_skills', Items.handleDefeat.key),
      ]),
    'screen' => _count([a.number('screen_hours') != null || a.number('screen_minutes') != null, _has(a, 'screen_content')]),
    'behaviour' => _count([for (final i in Items.behaviour) st('behaviour', i.key)]),
    'sensory' => _count([for (final i in Items.sensory) st('sensory', i.key)]),
    'posture' => _count([_has(a, 'posture_anatomy'), for (final i in Items.posture) st('posture', i.key)]),
    'reflexes' => _count([for (final i in [...Items.primitiveReflexes, ...Items.otherReflexes]) st('reflexes', i.key)]),
    'rom' => _count([
        for (final j in [...Items.upperJoints, ...Items.lowerJoints])
          for (final s in Items.sides) st('rom', j.key, s.key),
      ]),
    'hand' => _count([
        for (final g in handGroups)
          for (final i in g.items) st('hand', i.key),
      ]),
    'adl' => _count([for (final i in Items.adl) st('adl', i.key)]),
    'plan' => _count([a.problems.any((p) => p.complete)]),
    'goals' => _count([a.goalsOf('short').any((g) => g.description.trim().isNotEmpty), a.goalsOf('long').any((g) => g.description.trim().isNotEmpty)]),
    'approaches' => _count([_has(a, 'approaches') || _has(a, 'approach_tags')]),
    'home' => _count([for (final k in const ['home_activities', 'home_frequency', 'home_duration', 'home_instructions', 'home_precautions']) _has(a, k)]),
    _ => (done: 0, total: 0),
  };
}

int progressPercent(Assessment a) {
  var done = 0, total = 0;
  for (final s in sections) {
    final p = sectionProgress(a, s.id);
    done += p.done;
    total += p.total;
  }
  return total == 0 ? 0 : (done * 100 / total).floor();
}

// ---------------------------------------------------------------- checks

/// Something to fix, and where.
class Issue {
  final String section, field, message;

  /// Blocks completion (the database refuses it too). Otherwise it's a warning shown at the field.
  final bool critical;
  const Issue(this.section, this.field, this.message, {this.critical = true});
}

/// Mirrors `private.assessment_gaps` plus field sanity checks. Only what a clinical record can't be without
/// blocks completion; everything else may be left empty.
List<Issue> assessmentIssues(Assessment a, {String? today}) {
  final now = today ?? todayISO();
  final dob = a.pick('dob'), doa = a.pick('assessment_date'), surgery = a.pick('surgery_date');
  return [
    if (a.therapistId == null) const Issue('header', 'therapist_id', 'Choose the therapist who did the assessment.'),
    if (doa == null) const Issue('demographics', 'assessment_date', 'Select the date of assessment.'),
    if (doa != null && doa.compareTo(now) > 0) const Issue('demographics', 'assessment_date', 'The assessment date can\'t be in the future.'),
    if (a.childName.trim().isEmpty) const Issue('demographics', 'child_name', 'Enter the child\'s name.'),
    if (dob == null) const Issue('demographics', 'dob', 'Select the date of birth.'),
    if (dob != null && doa != null && dob.compareTo(doa) > 0) const Issue('demographics', 'dob', 'The date of birth is after the assessment date.'),
    if (a.pick('gender') == null) const Issue('demographics', 'gender', 'Select the gender.'),
    if (a.text('chief_complaints').trim().isEmpty) const Issue('demographics', 'chief_complaints', 'Enter the chief complaints.'),
    if (surgery != null && (surgery.compareTo(now) > 0 || (dob != null && surgery.compareTo(dob) < 0)))
      const Issue('demographics', 'surgery_date', 'The date of surgery must be between the date of birth and today.'),
    if (!a.problems.any((p) => p.complete)) const Issue('plan', 'problems', 'Add at least one problem identified with its treatment plan.'),
    for (final p in a.problems)
      if (!p.blank && !p.complete) Issue('plan', 'problem:${p.id}', p.problem.trim().isEmpty ? 'A treatment plan has no problem written for it.' : 'Add the treatment plan for "${p.problem.trim()}".', critical: false),
  ];
}

/// Age at the assessment date, e.g. "4 years, 3 months".
String ageAt(String dob, String on) {
  final b = parseD(dob), d = parseD(on);
  var months = (d.year - b.year) * 12 + d.month - b.month;
  if (d.day < b.day) months--;
  if (months < 0) return '—';
  final y = months ~/ 12, m = months % 12;
  return [if (y > 0) plural(y, 'year'), if (m > 0 || y == 0) plural(m, 'month')].join(', ');
}
