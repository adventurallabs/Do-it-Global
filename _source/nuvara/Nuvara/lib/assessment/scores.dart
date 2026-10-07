import '../models.dart' show Json;
import 'catalog.dart';

// How a child's assessments are summarised for the progress chart: criterion-referenced, with no invented weights.
//
// Every rated answer falls into one of three levels, named after the form's own answers:
//   at the expected level  Present, Normal, No concern, Independent, Age appropriate, (behaviour) Absent
//   developing             Delayed, Emerging, Concern, with difficulty / needs assistance, (behaviour) mild
//   not yet                Absent, Impaired, Abnormal, Dependent, Age inappropriate, (behaviour) moderate/severe
// "Not assessed" and "Not applicable" are left out. An area's score is simply the share of its assessed items at
// the expected level; Overall pools every assessed item (it is a count, not an average of areas). Muscle strength
// stays on its own standard 0–5 grade scale. The item-by-item changes between two assessments ("Walking: Delayed →
// Present") are the detail behind every number.

enum Level { expected, developing, notYet }

const levelLabels = {Level.expected: 'At the expected level', Level.developing: 'Developing', Level.notYet: 'Not yet'};

/// One area of the chart and how its answers map to levels.
class ScoreArea {
  final String key, label, domain;
  final List<Item> items;
  final List<Opt> options;

  /// Answer → level. Answers not listed (Not assessed, Not applicable) are left out.
  final Map<String, Level> levels;
  const ScoreArea(this.key, this.label, this.domain, this.items, this.options, this.levels);
}

const _e = Level.expected, _d = Level.developing, _n = Level.notYet;

final scoreAreas = [
  ScoreArea('development', 'Development', 'milestones', Items.milestones, Answers.milestone, const {'present': _e, 'delayed': _d, 'absent': _n}),
  ScoreArea('senses', 'Special senses', 'senses', Items.senses, Answers.senses, const {'normal': _e, 'concern': _d, 'impaired': _n}),
  ScoreArea('play', 'Play skills', 'play_skills', [...Items.playSkills, Items.handleDefeat], [...Answers.skill, ...Answers.defeat], const {
    'present': _e, 'age_appropriate': _e, 'emerging': _d, 'needs_support': _d, 'absent': _n, 'age_inappropriate': _n, //
  }),
  // Behaviour: Absent is the expected answer; a present one counts by severity (see levelOf).
  ScoreArea('behaviour', 'Behaviour', 'behaviour', Items.behaviour, Answers.behaviour, const {'absent': _e, 'present': _n}),
  ScoreArea('sensory', 'Sensory', 'sensory', Items.sensory, Answers.sensory, const {'no_concern': _e, 'concern': _n}),
  ScoreArea('posture', 'Posture', 'posture', Items.posture, Answers.posture, const {'normal': _e, 'abnormal': _n}),
  ScoreArea('reflexes', 'Reflexes', 'reflexes', [...Items.primitiveReflexes, ...Items.otherReflexes], Answers.reflex, const {
    'normal': _e, 'absent': _n, 'retained': _n, 'exaggerated': _n, //
  }),
  ScoreArea('hand', 'Hand function', 'hand', [
    for (final g in handGroups)
      for (final i in g.items) Item(i.key, g.single ? g.title : '${g.title}: ${i.label}'),
  ], Answers.hand, const {'present': _e, 'emerging': _d, 'absent': _n}),
  ScoreArea('adl', 'Daily living (ADL)', 'adl', Items.adl, Answers.adl, const {
    'independent': _e, 'independent_difficulty': _d, 'needs_assistance': _d, 'dependent': _n, //
  }),
];

ScoreArea? _areaOfDomain(String domain) => scoreAreas.where((a) => a.domain == domain).firstOrNull;

/// The level of one answer, or null when it isn't counted.
Level? levelOf(String domain, String? status, [String? severity]) {
  if (status == null) return null;
  if (domain == 'behaviour' && status == 'present') return severity == 'mild' ? _d : _n;
  return _areaOfDomain(domain)?.levels[status];
}

/// How many assessed items of an area (or of all areas) are at each level.
class LevelCount {
  final int expected, developing, notYet;
  const LevelCount([this.expected = 0, this.developing = 0, this.notYet = 0]);
  int get assessed => expected + developing + notYet;

  /// Share at the expected level, 0–100; null when nothing was assessed.
  double? get percent => assessed == 0 ? null : expected * 100 / assessed;
  LevelCount operator +(LevelCount o) => LevelCount(expected + o.expected, developing + o.developing, notYet + o.notYet);
  LevelCount add(Level l) => switch (l) {
        Level.expected => LevelCount(expected + 1, developing, notYet),
        Level.developing => LevelCount(expected, developing + 1, notYet),
        Level.notYet => LevelCount(expected, developing, notYet + 1),
      };
}

/// One rated answer as the chart needs it.
class ItemResult {
  final String domain, item, side, label;
  final String? status, severity;
  final int? strength;
  const ItemResult({required this.domain, required this.item, this.side = '', this.label = '', this.status, this.severity, this.strength});
  String get key => '$domain|$item|$side';
  Level? get level => levelOf(domain, status, severity);
}

/// One completed assessment on the chart.
class AssessmentPoint {
  final String id, date, kind;
  final Map<String, ItemResult> items;
  final Map<String, LevelCount> areas;
  final LevelCount overall;

  /// Average muscle strength grade (0–5) over the joints graded, and how many were graded.
  final double? strength;
  final int strengthGraded;

  AssessmentPoint._(this.id, this.date, this.kind, this.items, this.areas, this.overall, this.strength, this.strengthGraded);

  factory AssessmentPoint({required String id, required String date, required String kind, required List<ItemResult> items}) {
    final areas = <String, LevelCount>{};
    var overall = const LevelCount();
    var gradeSum = 0, graded = 0;
    for (final r in items) {
      if (r.domain == 'rom') {
        if (r.strength != null) {
          gradeSum += r.strength!;
          graded++;
        }
        continue;
      }
      final l = r.level;
      final area = _areaOfDomain(r.domain);
      if (l == null || area == null) continue;
      areas[area.key] = (areas[area.key] ?? const LevelCount()).add(l);
      overall = overall.add(l);
    }
    return AssessmentPoint._(id, date, kind, {for (final r in items) r.key: r}, areas, overall, graded == 0 ? null : gradeSum / graded, graded);
  }

  factory AssessmentPoint.of(Json m) => AssessmentPoint(
        id: m['assessment_id'],
        date: m['assessment_date'],
        kind: m['kind'],
        items: [
          for (final x in (m['findings'] as List? ?? const []))
            if ((x as Map).cast<String, dynamic>() case final f)
              ItemResult(
                domain: f['domain'],
                item: f['item'],
                side: f['side'] ?? '',
                label: f['label'] ?? '',
                status: f['status'],
                severity: f['severity'],
                strength: (f['strength'] as num?)?.toInt(),
              ),
        ],
      );

  /// The value plotted for a series: % at the expected level, or the average strength grade.
  double? value(String series) => switch (series) {
        'overall' => overall.percent,
        'strength' => strength,
        _ => areas[series]?.percent,
      };
}

/// The series a chart can draw: Overall, each area that was ever assessed, and muscle strength.
String seriesLabel(String key) => switch (key) {
      'overall' => 'Overall',
      'strength' => 'Muscle strength',
      _ => scoreAreas.where((a) => a.key == key).firstOrNull?.label ?? key,
    };

bool isGradeSeries(String key) => key == 'strength';

/// An item whose result is different from the assessment before.
class Change {
  final String area, label, from, to;
  final bool better;
  const Change({required this.area, required this.label, required this.from, required this.to, required this.better});
}

/// What changed for each item assessed in both [before] and [after], best news first within each direction.
List<Change> changesBetween(AssessmentPoint before, AssessmentPoint after) {
  final out = <Change>[];
  for (final r in after.items.values) {
    final was = before.items[r.key];
    if (was == null) continue;
    if (r.domain == 'rom') {
      if (r.strength != null && was.strength != null && r.strength != was.strength) {
        final joint = [...Items.upperJoints, ...Items.lowerJoints].where((j) => j.key == r.item).firstOrNull?.label ?? r.item;
        out.add(Change(area: 'Muscle strength', label: '$joint (${r.side})', from: '${was.strength}/5', to: '${r.strength}/5', better: r.strength! > was.strength!));
      }
      continue;
    }
    final a = r.level, b = was.level;
    if (a == null || b == null || a == b) continue;
    final area = _areaOfDomain(r.domain);
    if (area == null) continue;
    final name = r.item.startsWith(Items.adlOtherPrefix)
        ? (r.label.trim().isEmpty ? 'Other ADL' : r.label.trim())
        : (area.items.where((i) => i.key == r.item).firstOrNull?.label ?? r.item);
    String answer(ItemResult x) {
      final s = labelOf(area.options, x.status) ?? x.status ?? '';
      final sev = labelOf(Answers.severity, x.severity);
      return x.domain == 'behaviour' && x.status == 'present' && sev != null ? '$s ($sev)' : s;
    }

    out.add(Change(area: area.label, label: name, from: answer(was), to: answer(r), better: a.index < b.index));
  }
  return out;
}
