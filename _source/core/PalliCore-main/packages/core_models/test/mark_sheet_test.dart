import 'package:core_models/core_models.dart';
import 'package:flutter_test/flutter_test.dart';

Mark _m(
  String student,
  double score, {
  String subject = 'Science',
  String test = 'Unit test',
  String examId = '',
  double outOf = 50,
  DateTime? date,
}) =>
    Mark(
      id: '${student}_${subject}_${test}_${examId}',
      studentId: student,
      subject: subject,
      score: score,
      totalMarks: outOf,
      testType: test,
      date: date ?? DateTime(2026, 9, 18, 10),
      updatedBy: 'sci-teacher',
      examId: examId,
    );

void main() {
  group('group', () {
    test('one test of one subject on one day becomes one sheet', () {
      final sheets = MarkSheet.group([
        _m('s1', 40),
        _m('s2', 30),
        _m('s3', 25),
      ]);
      expect(sheets, hasLength(1));
      expect(sheets.single.entered, 3);
      expect(sheets.single.subject, 'Science');
      expect(sheets.single.totalMarks, 50);
    });

    test('different subjects, tests, days and exams stay apart', () {
      final sheets = MarkSheet.group([
        _m('s1', 40),
        _m('s1', 40, subject: 'English'),
        _m('s1', 40, test: 'Quiz'),
        _m('s1', 40, date: DateTime(2026, 9, 19)),
        _m('s1', 40, examId: 'ex1'),
      ]);
      expect(sheets, hasLength(5));
    });

    test('the same test recorded at two clock times on one day stays one sheet', () {
      final sheets = MarkSheet.group([
        _m('s1', 40, date: DateTime(2026, 9, 18, 9)),
        _m('s2', 20, date: DateTime(2026, 9, 18, 17)),
      ]);
      expect(sheets, hasLength(1));
      expect(sheets.single.entered, 2);
    });

    test('newest day first', () {
      final sheets = MarkSheet.group([
        _m('s1', 10, date: DateTime(2026, 9, 10)),
        _m('s1', 10, date: DateTime(2026, 9, 20)),
      ]);
      expect(sheets.first.date.day, 20);
    });
  });

  group('statistics', () {
    test('average, highest and lowest read off the sheet', () {
      final sheet = MarkSheet.group([
        _m('s1', 50),
        _m('s2', 25),
        _m('s3', 0),
      ]).single;
      expect(sheet.averagePercent, 50);
      expect(sheet.highest, 50);
      expect(sheet.lowest, 0);
    });

    test('a mistyped maximum on one row does not redefine the test', () {
      final sheet = MarkSheet.group([
        _m('s1', 40),
        _m('s2', 30),
        _m('s3', 25, outOf: 500),
      ]).single;
      expect(sheet.totalMarks, 50);
      expect(sheet.hasMixedTotals, isTrue);
    });

    test('a zero maximum never divides by zero', () {
      final sheet = MarkSheet.group([_m('s1', 0, outOf: 0)]).single;
      expect(sheet.averagePercent, isNull);
    });
  });

  test('forStudent finds the row the table needs to pre-fill', () {
    final sheet = MarkSheet.group([_m('s1', 40), _m('s2', 30)]).single;
    expect(sheet.forStudent('s2')?.score, 30);
    expect(sheet.forStudent('nobody'), isNull);
  });

  test('an exam-linked sheet is flagged so it can be filed under a report card', () {
    final sheet = MarkSheet.group([_m('s1', 40, examId: 'ex1', test: 'Mid Term')]).single;
    expect(sheet.isExam, isTrue);
    expect(MarkSheet.group([_m('s1', 40)]).single.isExam, isFalse);
  });
}
