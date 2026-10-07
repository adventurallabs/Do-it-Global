// The Pediatric OT assessment: data model, progress and completion checks, autosave behaviour, and every
// section rendered offline from phone to desktop without layout errors.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nuvara/assessment/api.dart';
import 'package:nuvara/assessment/catalog.dart';
import 'package:nuvara/assessment/editor.dart';
import 'package:nuvara/assessment/model.dart';
import 'package:nuvara/assessment/pending.dart';
import 'package:nuvara/assessment/progress_chart.dart';
import 'package:nuvara/assessment/report.dart';
import 'package:nuvara/assessment/scores.dart';
import 'package:nuvara/assessment/screen.dart';
import 'package:nuvara/models.dart';
import 'package:nuvara/theme.dart';
import 'package:nuvara/util.dart';
import 'package:provider/provider.dart';

import 'fixtures.dart';

Assessment filled() {
  final a = Assessment(id: 'a1', childId: 'c1', status: 'in_progress', fields: {
    'kind': 'initial',
    'assessment_date': addDays(todayISO(), -1),
    'therapist_id': 't1',
    'child_name': 'Aarav Sharma',
    'dob': '2020-01-14',
    'gender': 'male',
    'chief_complaints': 'Poor grip and handwriting',
    'play_types': ['solitary', 'parallel'],
    'screen_hours': 2,
  });
  a.finding('milestones', 'walking')
    ..status = 'delayed'
    ..setText('age', '20 months');
  a.finding('rom', 'shoulder', 'right')
    ..strength = 4
    ..setText('arom', 'WFL');
  a.finding('behaviour', 'tantrums').status = 'present';
  a.problems.add(Problem(problem: 'Poor fine motor coordination', plan: 'Graded manipulation tasks'));
  a.goals.add(Goal(term: 'short', description: 'Pincer grasp on small pegs', status: 'in_progress'));
  return a;
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('model', () {
    test('the catalogue keeps every item of the paper form', () {
      expect(sections, hasLength(18));
      expect(Items.milestones, hasLength(9));
      expect(Items.behaviour, hasLength(13));
      expect(Items.sensory, hasLength(7));
      expect(Items.primitiveReflexes.length + Items.otherReflexes.length, 14);
      expect(Items.upperJoints.length + Items.lowerJoints.length, 8);
      expect(Items.adl, hasLength(11));
      expect([for (final g in handGroups) g.title], ['Reach', 'Grasp', 'Prehension', 'Non-Prehension', 'Release', 'In-Hand Manipulation', 'Pencil Grasp', 'Pinch']);
      // Keys are stored in the database, so they must be unique within their domain.
      for (final list in [Items.milestones, Items.behaviour, Items.sensory, [...Items.primitiveReflexes, ...Items.otherReflexes], Items.adl, [for (final g in handGroups) ...g.items]]) {
        expect(list.map((i) => i.key).toSet(), hasLength(list.length));
      }
    });

    test('payload leaves out empty findings and blank rows, and survives a round trip', () {
      final a = filled();
      a.finding('senses', 'vision'); // touched but never answered
      a.problems.add(Problem());
      a.goals.add(Goal(term: 'long'));
      final p = a.payload();
      expect((p['findings'] as List), hasLength(3));
      expect((p['problems'] as List), hasLength(1));
      expect((p['goals'] as List), hasLength(1));
      expect((p['fields'] as Map)['progress'], progressPercent(a));

      final b = Assessment(id: 'a1');
      b.applyPayload(p);
      expect(b.payload()['findings'], p['findings']);
      expect(b.many('play_types'), ['solitary', 'parallel']);
      expect(b.peek('milestones', 'walking')!.text('age'), '20 months');
    });

    test('a database row parses, lists and all', () {
      final a = Assessment.of({
        'id': 'x',
        'child_id': 'c1',
        'status': 'completed',
        'rev': 4,
        'kind': 'reassessment',
        'assessment_date': '2026-10-01',
        'play_types': ['cooperative'],
        'screen_hours': 3,
        'gender': null,
        'created_at': '2026-10-01T10:00:00Z',
        'updated_at': '2026-10-02T10:00:00Z',
        'completed_at': '2026-10-02T10:00:00Z',
        'assessment_findings': [
          {'domain': 'reflexes', 'item': 'moro', 'side': '', 'status': 'retained', 'notes': '', 'age': '', 'strength': null},
        ],
        'assessment_problems': [
          {'id': 'p2', 'position': 1, 'problem': 'B', 'treatment_plan': 'b'},
          {'id': 'p1', 'position': 0, 'problem': 'A', 'treatment_plan': 'a'},
        ],
        'assessment_goals': [
          {'id': 'g1', 'term': 'long', 'position': 0, 'description': 'Write name', 'status': 'not_started', 'target_date': null, 'source_goal_id': 'g0'},
        ],
      });
      expect(a.finished, isTrue);
      expect(a.rev, 4);
      expect(a.number('screen_hours'), 3);
      expect(a.pick('gender'), isNull);
      expect(a.statusOf('reflexes', 'moro'), 'retained');
      expect(a.problems.map((p) => p.problem), ['A', 'B']);
      expect(a.goals.single.sourceGoalId, 'g0');
    });

    test('progress counts "Not assessed" as recorded and follows conditional fields', () {
      final a = Assessment(id: 'a');
      expect(sectionProgress(a, 'development'), (done: 0, total: 9));
      for (final m in Items.milestones) {
        a.finding('milestones', m.key).status = 'not_assessed';
      }
      expect(sectionProgress(a, 'development').complete, isTrue);
      expect(sectionProgress(a, 'education').total, 3);
      a.put('school_status', 'not_school_going');
      expect(sectionProgress(a, 'education'), (done: 1, total: 1));
      a.put('surgery', 'yes');
      expect(sectionProgress(a, 'demographics').total, 11);
      expect(progressPercent(a), greaterThan(0));
    });

    test('completion needs only the essentials, and impossible dates are caught', () {
      final a = filled();
      expect(assessmentIssues(a).where((i) => i.critical), isEmpty);

      final empty = Assessment(id: 'e');
      final fields = assessmentIssues(empty).where((i) => i.critical).map((i) => i.field).toSet();
      expect(fields, containsAll(['therapist_id', 'child_name', 'dob', 'gender', 'chief_complaints', 'problems']));
      // Optional sections never block.
      expect(fields.any((f) => f.startsWith('home') || f.startsWith('screen')), isFalse);

      a.put('assessment_date', addDays(todayISO(), 3));
      a.put('surgery_date', '2019-01-01');
      final msgs = assessmentIssues(a).map((i) => i.field);
      expect(msgs, containsAll(['assessment_date', 'surgery_date']));

      final b = filled()..problems.first.plan = '';
      expect(assessmentIssues(b).any((i) => i.field == 'problems' && i.critical), isTrue);
      expect(assessmentIssues(b).any((i) => !i.critical), isTrue);
    });

    test('the report shows recorded answers, section by section', () {
      final r = buildReport(filled());
      expect(r, hasLength(sections.length));
      final dev = r.firstWhere((s) => s.def.id == 'development').blocks.single as RItem;
      expect(dev.label, 'Walking');
      expect(dev.answer, 'Delayed');
      expect(dev.details, ['Age 20 months']);
      expect(r.firstWhere((s) => s.def.id == 'home').blocks.single, isA<RNone>());
      expect(r.firstWhere((s) => s.def.id == 'rom').blocks.single, isA<RTable>());
      expect(ageAt('2020-01-14', '2024-04-20'), '4 years, 3 months');
    });
  });

  group('progress scores', () {
    test('answers count as expected / developing / not yet, with nothing weighted and "Not assessed" left out', () {
      final p = AssessmentPoint(id: 'x', date: '2026-10-01', kind: 'initial', items: const [
        ItemResult(domain: 'milestones', item: 'walking', status: 'present'),
        ItemResult(domain: 'milestones', item: 'jumping', status: 'delayed'),
        ItemResult(domain: 'milestones', item: 'crawling', status: 'not_assessed'),
        ItemResult(domain: 'behaviour', item: 'tantrums', status: 'present', severity: 'mild'),
        ItemResult(domain: 'behaviour', item: 'spinning', status: 'present', severity: 'severe'),
        ItemResult(domain: 'behaviour', item: 'drowsy', status: 'absent'),
        ItemResult(domain: 'rom', item: 'shoulder', side: 'right', strength: 4),
        ItemResult(domain: 'rom', item: 'shoulder', side: 'left', strength: 3),
        ItemResult(domain: 'adl', item: 'feeding', status: 'needs_assistance'),
        ItemResult(domain: 'adl', item: 'bathing', status: 'not_applicable'),
      ]);
      expect(p.areas['development']!.percent, 50);
      expect(p.areas['development']!.developing, 1);
      final b = p.areas['behaviour']!;
      expect((b.expected, b.developing, b.notYet), (1, 1, 1));
      expect(p.areas['adl']!.assessed, 1);
      // Overall pools items (2 of 6 here); strength is never mixed in and stays on its 0–5 scale.
      expect(p.overall.assessed, 6);
      expect(p.value('overall'), closeTo(100 / 3, 0.001));
      expect(p.value('strength'), 3.5);
      expect(p.strengthGraded, 2);
    });

    test('a timeline row parses, and changes between assessments are listed item by item', () {
      AssessmentPoint row(String id, String walking, int grade, String dressing) => AssessmentPoint.of({
            'assessment_id': id,
            'assessment_date': id == 'a' ? '2026-07-05' : '2026-10-05',
            'kind': 'initial',
            'findings': [
              {'domain': 'milestones', 'item': 'walking', 'side': '', 'status': walking},
              {'domain': 'hand', 'item': 'pencil_dynamic_tripod', 'side': '', 'status': 'emerging'},
              {'domain': 'rom', 'item': 'wrist', 'side': 'left', 'strength': grade},
              {'domain': 'adl', 'item': 'other_x1', 'side': '', 'label': 'Brushing teeth', 'status': dressing},
            ],
          });
      final before = row('a', 'delayed', 3, 'independent'), after = row('b', 'present', 4, 'dependent');
      expect(after.areas['hand']!.developing, 1);
      final c = changesBetween(before, after);
      expect(c.map((x) => '${x.label}: ${x.from} → ${x.to} ${x.better}'), unorderedEquals([
        'Walking: Delayed → Present true',
        'Wrist (left): 3/5 → 4/5 true',
        'Brushing teeth: Independent → Dependent false',
      ]));
    });
  });

  group('autosave', () {
    late Directory tmp;
    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('nuvara_pending_test');
      PendingAssessments.folderOverride = tmp;
    });
    tearDown(() async {
      PendingAssessments.folderOverride = null;
      await tmp.delete(recursive: true);
    });

    test('a burst of changes is one save; changes during a save follow it, in order', () async {
      final sent = <int>[];
      final gate = Completer<void>();
      final e = AssessmentEditor(Assessment(id: 'a'), debounce: const Duration(milliseconds: 20), save: (id, rev, p) async {
        sent.add(rev);
        if (sent.length == 1) await gate.future;
        return rev + 1;
      });
      e.setText('child_name', 'A');
      e.setText('child_name', 'Ab');
      e.setText('child_name', 'Abc');
      await Future.delayed(const Duration(milliseconds: 60));
      expect(sent, [1]);
      expect(e.state, SaveState.saving);
      e.setText('felt_needs', 'More play');
      gate.complete();
      expect(await e.flush(), isTrue);
      expect(sent, [1, 2]);
      expect(e.a.rev, 3);
      expect(e.state, SaveState.saved);
      expect(e.unsaved, isFalse);
      e.dispose();
    });

    test('offline: the changes are kept on the device until a save gets through', () async {
      var online = false;
      final e = AssessmentEditor(Assessment(id: 'a2'), userId: 'u1', debounce: const Duration(milliseconds: 10), save: (id, rev, p) async {
        if (!online) throw const SocketException('Failed host lookup');
        return rev + 1;
      });
      e.setText('chief_complaints', 'Toe walking');
      expect(await e.flush(), isFalse);
      expect(e.state, SaveState.offline);
      final kept = await PendingAssessments.read('u1', 'a2');
      expect((kept!.payload['fields'] as Map)['chief_complaints'], 'Toe walking');
      expect(await PendingAssessments.ids('u1'), ['a2']);
      online = true;
      expect(await e.retry(), isTrue);
      expect(e.state, SaveState.saved);
      expect(await PendingAssessments.read('u1', 'a2'), isNull);
      e.dispose();
    });

    test('kept changes are sent or recovered one job at a time, never both at once', () async {
      final log = <String>[];
      final gate = Completer<void>();
      final first = PendingAssessments.exclusive('a9', () async {
        log.add('sync start');
        await gate.future;
        log.add('sync end');
        return 1;
      });
      final second = PendingAssessments.exclusive('a9', () async {
        log.add('open');
        return 2;
      });
      // Another assessment isn't held up.
      expect(await PendingAssessments.exclusive('other', () async => 3), 3);
      await Future.delayed(Duration.zero);
      expect(log, ['sync start']);
      gate.complete();
      expect(await first, 1);
      expect(await second, 2);
      expect(log, ['sync start', 'sync end', 'open']);
      // A failing job doesn't block the next one.
      await expectLater(PendingAssessments.exclusive('a9', () async => throw Exception('x')), throwsException);
      expect(await PendingAssessments.exclusive('a9', () async => 4), 4);
    });

    test('a save from another device stops autosave until a version is chosen', () async {
      var conflict = true;
      final e = AssessmentEditor(Assessment(id: 'a3', rev: 2), debounce: const Duration(milliseconds: 10), save: (id, rev, p) async {
        if (conflict) throw const AssessmentConflict();
        return rev + 1;
      });
      e.setText('informant', 'Mother');
      expect(await e.flush(), isFalse);
      expect(e.state, SaveState.conflict);
      // More typing doesn't try again behind the therapist's back.
      e.setText('informant', 'Mother and father');
      await Future.delayed(const Duration(milliseconds: 30));
      expect(e.state, SaveState.conflict);
      conflict = false;
      expect(await e.keepMine(7), isTrue);
      expect(e.a.rev, 8);
      expect(e.a.text('informant'), 'Mother and father');

      final theirs = Assessment(id: 'a3', rev: 9, fields: {'informant': 'Grandmother'});
      e.takeTheirs(theirs);
      expect(e.a.text('informant'), 'Grandmother');
      expect(e.unsaved, isFalse);
      e.dispose();
    });

    test('completing saves first and is refused while changes are stuck', () async {
      var fail = true;
      final e = AssessmentEditor(filled(), debounce: const Duration(milliseconds: 10), save: (id, rev, p) async {
        if (fail) throw Exception('nope');
        return rev + 1;
      });
      e.setText('felt_needs', 'Independence');
      await expectLater(e.complete((id, rev) async => rev + 1), throwsException);
      expect(e.a.status, 'in_progress');
      fail = false;
      await e.complete((id, rev) async => rev + 1);
      expect(e.a.status, 'completed');
      e.dispose();
    });

    test('read-only editors ignore changes', () {
      final e = AssessmentEditor(filled(), readOnly: true, save: (id, rev, p) async => fail('saved'));
      e.setText('child_name', 'X');
      expect(e.a.childName, 'Aarav Sharma');
      expect(e.unsaved, isFalse);
      e.dispose();
    });
  });

  group('screens', () {
    const sizes = [Size(320, 640), Size(412, 915), Size(768, 1024), Size(1366, 768), Size(1920, 1080)];

    testWidgets('every section, the review and the report render at every size', (tester) async {
      final store = demoStore(Role.admin);
      final failures = <String>[];
      for (final size in sizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        final e = AssessmentEditor(filled(), debounce: const Duration(days: 1), save: (id, rev, p) async => rev + 1);
        // Every conditional panel open: a behaviour present, a sensory concern, surgery, an "Others" ADL.
        e.a.put('surgery', 'yes');
        e.a.finding('sensory', 'tactile').status = 'concern';
        e.a.finding('adl', 'feeding').status = 'needs_assistance';
        e.a.finding('adl', '${Items.adlOtherPrefix}x1').setText('label', 'Brushing');
        await tester.pumpWidget(ChangeNotifierProvider.value(
          value: store,
          child: MaterialApp(theme: buildTheme(), home: AssessmentEditorView(e: e, onExit: () async {}, onCompleted: () {}, onDeleted: () {})),
        ));
        for (var i = 0; i <= sections.length; i++) {
          e.goTo(i);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          for (Object? x = tester.takeException(); x != null; x = tester.takeException()) {
            if ('$x'.contains('GoogleFonts') || '$x'.contains('google_fonts')) continue;
            failures.add('${size.width.toInt()}px ${i < sections.length ? sections[i].id : 'review'}: $x');
          }
        }
        // The completed report.
        e.readOnly = true;
        e.a.status = 'completed';
        await tester.pumpWidget(ChangeNotifierProvider.value(
          value: store,
          child: MaterialApp(theme: buildTheme(), home: AssessmentView(e: e, canEdit: true, justCompleted: true, onEdit: () {}, onDone: () {}, onChanged: () async {})),
        ));
        await tester.pump(const Duration(milliseconds: 600));
        for (Object? x = tester.takeException(); x != null; x = tester.takeException()) {
          if ('$x'.contains('GoogleFonts') || '$x'.contains('google_fonts')) continue;
          failures.add('${size.width.toInt()}px report: $x');
        }
        await tester.pumpWidget(const SizedBox());
        e.dispose();
      }
      tester.view.reset();
      expect(failures, isEmpty, reason: failures.join('\n\n'));
    });

    testWidgets('the progress chart renders for one, two and many assessments at every size', (tester) async {
      final failures = <String>[];
      for (final n in [0, 1, 2, 6]) {
        final store = demoStore(Role.parent);
        store.assessmentTimeline['c1'] = [
          for (var i = 0; i < n; i++)
            AssessmentPoint(id: 'p$i', date: addDays('2026-01-05', 45 * i), kind: i == 0 ? 'initial' : 'reassessment', items: [
              for (final (j, m) in Items.milestones.indexed) ItemResult(domain: 'milestones', item: m.key, status: j < 3 + i ? 'present' : 'delayed'),
              for (final b in Items.behaviour) ItemResult(domain: 'behaviour', item: b.key, status: b.key == 'tantrums' && i < 2 ? 'present' : 'absent', severity: 'moderate'),
              if (i > 0) for (final a in Items.adl) ItemResult(domain: 'adl', item: a.key, status: i > 2 ? 'independent' : 'needs_assistance'),
              ItemResult(domain: 'rom', item: 'elbow', side: 'right', strength: 3 + i % 3),
            ]),
        ];
        for (final size in sizes) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          await tester.pumpWidget(ChangeNotifierProvider.value(
            value: store,
            child: MaterialApp(theme: buildTheme(), home: Scaffold(body: ListView(padding: const EdgeInsets.all(16), children: [AssessmentProgressCard(child: store.child('c1')!)]))),
          ));
          await tester.pump(const Duration(milliseconds: 100));
          if (n >= 2) {
            // Read the first point, then switch the line to an area.
            await tester.tapAt(tester.getTopLeft(find.byType(CustomPaint).last) + const Offset(32, 60));
            await tester.tap(find.text('Daily living (ADL)').first);
            await tester.pump();
          }
          for (Object? x = tester.takeException(); x != null; x = tester.takeException()) {
            if ('$x'.contains('GoogleFonts') || '$x'.contains('google_fonts')) continue;
            failures.add('$n points ${size.width.toInt()}px: $x');
          }
        }
      }
      tester.view.reset();
      expect(failures, isEmpty, reason: failures.join('\n\n'));
    });

    testWidgets('one tap answers an item, a second tap clears it, and "Mark the rest" fills only empty ones', (tester) async {
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = demoStore(Role.admin);
      final e = AssessmentEditor(Assessment(id: 'a', fields: {'kind': 'initial', 'assessment_date': todayISO()}), debounce: const Duration(days: 1), save: (id, rev, p) async => rev + 1);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(theme: buildTheme(), home: AssessmentEditorView(e: e, onExit: () async {}, onCompleted: () {}, onDeleted: () {})),
      ));
      e.goTo(sectionIndex('behaviour'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Present').first);
      await tester.pump();
      expect(e.a.statusOf('behaviour', 'self_injury'), 'present');
      expect(find.text('Severity'), findsOneWidget);
      await tester.tap(find.text('Mark the rest'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Absent').last);
      await tester.pumpAndSettle();
      expect(e.a.statusOf('behaviour', 'self_injury'), 'present');
      expect(e.a.statusOf('behaviour', 'spinning'), 'absent');
      expect(sectionProgress(e.a, 'behaviour').complete, isTrue);
      // Tapping the chosen answer again clears it.
      await tester.tap(find.text('Present').first);
      await tester.pump();
      expect(e.a.statusOf('behaviour', 'self_injury'), isNull);
      await tester.pumpWidget(const SizedBox());
      e.dispose();
    });
  });
}
