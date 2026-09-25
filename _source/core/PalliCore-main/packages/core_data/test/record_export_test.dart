import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter_test/flutter_test.dart';

const _sheet = ExportSheet(
  name: 'Staff',
  headers: ['Name', 'Note'],
  rows: [
    ['Anitha', 'Resigned, effective this term'],
  ],
);

String _csv(List<ExportSheet> sheets) => utf8.decode(RecordExport.toCsv(sheets));

Archive _open(List<ExportSheet> sheets) => ZipDecoder().decodeBytes(RecordExport.toXlsx(sheets));

String _part(Archive archive, String path) =>
    utf8.decode(archive.files.firstWhere((f) => f.name == path).content as List<int>);

void main() {
  group('CSV', () {
    test('starts with a UTF-8 BOM so Excel reads names correctly', () {
      // Checked on the bytes, not the decoded string: Dart's UTF-8 decoder
      // swallows a leading BOM, so decoding first would always pass.
      expect(RecordExport.toCsv([_sheet]).take(3), [0xEF, 0xBB, 0xBF]);
    });

    test('quotes commas, quotes and newlines', () {
      final out = _csv([
        const ExportSheet(
          name: 'S',
          headers: ['A'],
          rows: [
            ['Kumar, R "Kumi"\nSecond line'],
          ],
        )
      ]);
      expect(out, contains('"Kumar, R ""Kumi""\nSecond line"'));
    });

    test('defuses a cell Excel would run as a formula', () {
      final out = _csv([
        const ExportSheet(name: 'S', headers: ['A'], rows: [
          ['=1+1'],
          ['-Kumar'],
        ])
      ]);
      expect(out, contains("'=1+1"));
      expect(out, contains("'-Kumar"));
    });

    test('labels each block when there is more than one sheet', () {
      final out = _csv([
        _sheet,
        const ExportSheet(name: 'Marks', headers: ['Subject'], rows: [
          ['Science']
        ]),
      ]);
      expect(out, contains('# Staff'));
      expect(out, contains('# Marks'));
      expect(out, contains('Science'));
    });
  });

  group('xlsx', () {
    test('writes the parts Excel needs to open the file', () {
      final archive = _open([_sheet]);
      final names = archive.files.map((f) => f.name).toSet();
      expect(
        names,
        containsAll([
          '[Content_Types].xml',
          '_rels/.rels',
          'xl/workbook.xml',
          'xl/_rels/workbook.xml.rels',
          'xl/styles.xml',
          'xl/worksheets/sheet1.xml',
        ]),
      );
    });

    test('carries the values as inline strings', () {
      final sheet = _part(_open([_sheet]), 'xl/worksheets/sheet1.xml');
      expect(sheet, contains('Anitha'));
      expect(sheet, contains('Resigned, effective this term'));
      expect(sheet, contains('t="inlineStr"'));
      // Header row is bold (style 1) and frozen.
      expect(sheet, contains('s="1"'));
      expect(sheet, contains('state="frozen"'));
    });

    test('escapes XML rather than breaking the workbook', () {
      final sheet = _part(
        _open([
          const ExportSheet(name: 'S', headers: ['A'], rows: [
            ['R & D <note> "x"'],
          ])
        ]),
        'xl/worksheets/sheet1.xml',
      );
      expect(sheet, contains('R &amp; D &lt;note&gt;'));
      expect(sheet, isNot(contains('<note>')));
    });

    test('drops control characters Excel would refuse', () {
      final sheet = _part(
        _open([
          const ExportSheet(name: 'S', headers: ['A'], rows: [
            ['bad\u0001char'],
          ])
        ]),
        'xl/worksheets/sheet1.xml',
      );
      expect(sheet, contains('badchar'));
    });

    test('one worksheet part and one relationship per sheet', () {
      final archive = _open([
        _sheet,
        const ExportSheet(name: 'Marks', headers: ['Subject'], rows: [
          ['Science']
        ]),
        const ExportSheet(name: 'Attendance', headers: ['Date'], rows: [
          ['2026-09-21']
        ]),
      ]);
      final names = archive.files.map((f) => f.name).toSet();
      expect(names, containsAll(['xl/worksheets/sheet3.xml']));
      final workbook = _part(archive, 'xl/workbook.xml');
      expect(workbook, contains('name="Staff"'));
      expect(workbook, contains('name="Attendance"'));
      expect(_part(archive, 'xl/_rels/workbook.xml.rels'), contains('sheet3.xml'));
    });

    test('never emits two sheets with the same name', () {
      final workbook = _part(
        _open([
          const ExportSheet(name: 'Data', headers: ['A'], rows: [
            ['1']
          ]),
          const ExportSheet(name: 'Data', headers: ['A'], rows: [
            ['2']
          ]),
        ]),
        'xl/workbook.xml',
      );
      expect(workbook, contains('name="Data"'));
      expect(workbook, contains('name="Data 2"'));
    });

    test('trims a sheet name Excel would reject', () {
      final workbook = _part(
        _open([
          ExportSheet(name: 'A' * 40, headers: const ['x'], rows: const [
            ['y']
          ]),
        ]),
        'xl/workbook.xml',
      );
      expect(workbook, contains('name="${'A' * 31}"'));
    });
  });

  group('fileName', () {
    test('slugs the subject and keeps the extension', () {
      expect(RecordExport.fileName('Anitha  Kumar', '20260921', 'xlsx'),
          'anitha-kumar-20260921.xlsx');
      expect(RecordExport.fileName('!!!', '20260921', 'csv'), 'record-20260921.csv');
    });
  });
}
