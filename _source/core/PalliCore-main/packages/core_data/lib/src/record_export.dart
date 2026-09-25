import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// A table ready to be written out: a header row and the rows under it.
class ExportSheet {
  final String name;
  final List<String> headers;
  final List<List<String>> rows;

  const ExportSheet({required this.name, required this.headers, required this.rows});

  bool get isEmpty => rows.isEmpty;
}

/// Turns a leaver's file into a spreadsheet the school can keep after the
/// record itself is erased.
///
/// Both formats are written by hand rather than pulled in as a dependency:
/// an .xlsx is a zip of a handful of XML parts, and `archive` is already in
/// the tree. That keeps the export working offline and on every platform.
class RecordExport {
  RecordExport._();

  /// UTF-8 byte-order mark. Written as an escape rather than a literal
  /// character, so an editor that strips BOMs cannot quietly remove it.
  static const _bom = '\u{FEFF}';

  /// RFC 4180 CSV. Opens directly in Excel, Numbers and Sheets.
  ///
  /// The BOM is deliberate: without it Excel on Windows reads the file as
  /// the system codepage and mangles every non-ASCII name. Several sheets
  /// become several labelled blocks, since CSV has no notion of tabs.
  static Uint8List toCsv(List<ExportSheet> sheets) {
    final buffer = StringBuffer(_bom);
    for (var i = 0; i < sheets.length; i++) {
      final sheet = sheets[i];
      if (i > 0) buffer.writeln();
      if (sheets.length > 1) buffer.writeln(_csvCell('# ${sheet.name}'));
      buffer.writeln(sheet.headers.map(_csvCell).join(','));
      for (final row in sheet.rows) {
        buffer.writeln(row.map(_csvCell).join(','));
      }
    }
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  static String _csvCell(String value) {
    // A leading =, +, - or @ makes Excel treat the cell as a formula. Names
    // and notes are data, so they are prefixed out of harm's way.
    final safe = value.startsWith(RegExp(r'[=+\-@]')) ? "'$value" : value;
    if (safe.contains(RegExp(r'[",\n\r]'))) {
      return '"${safe.replaceAll('"', '""')}"';
    }
    return safe;
  }

  /// A real .xlsx workbook — one sheet, a bold frozen header row, and every
  /// cell written as an inline string so no shared-string table is needed.
  static Uint8List toXlsx(List<ExportSheet> sheets) {
    final used = sheets.isEmpty
        ? [const ExportSheet(name: 'Sheet1', headers: [], rows: [])]
        : sheets;
    final archive = Archive();
    void add(String path, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    add('[Content_Types].xml', _contentTypes(used.length));
    add('_rels/.rels', _rootRels);
    add('xl/workbook.xml', _workbook(used));
    add('xl/_rels/workbook.xml.rels', _workbookRels(used.length));
    add('xl/styles.xml', _styles);
    for (var i = 0; i < used.length; i++) {
      add('xl/worksheets/sheet${i + 1}.xml', _worksheet(used[i]));
    }

    final zipped = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipped);
  }

  /// "Anita Kumar" -> "anita-kumar-staff-record.xlsx"
  static String fileName(String subject, String suffix, String extension) {
    final slug = subject
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final base = slug.isEmpty ? 'record' : slug;
    return '$base-$suffix.$extension';
  }

  // ---------------------------------------------------------------------------
  // xlsx parts
  // ---------------------------------------------------------------------------

  static String _contentTypes(int sheetCount) {
    final overrides = StringBuffer();
    for (var i = 1; i <= sheetCount; i++) {
      overrides.write(
          '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>');
    }
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '$overrides'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '</Types>';
  }

  static const _rootRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';

  static String _workbookRels(int sheetCount) {
    final rels = StringBuffer();
    for (var i = 1; i <= sheetCount; i++) {
      rels.write(
          '<Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$i.xml"/>');
    }
    rels.write(
        '<Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>');
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '$rels</Relationships>';
  }

  /// Two fonts (normal, bold) and two cell formats — index 1 is the bold
  /// header style the worksheet references.
  static const _styles = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>
<fills count="1"><fill><patternFill patternType="none"/></fill></fills>
<borders count="1"><border/></borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>
</styleSheet>''';

  static String _workbook(List<ExportSheet> sheets) {
    final entries = StringBuffer();
    final seen = <String>{};
    for (var i = 0; i < sheets.length; i++) {
      var name = _safeSheetName(sheets[i].name);
      // Excel refuses a workbook with two sheets of the same name.
      var suffix = 2;
      while (!seen.add(name.toLowerCase())) {
        name = _safeSheetName('${sheets[i].name} $suffix');
        suffix++;
      }
      entries.write('<sheet name="${_xmlEscape(name)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>');
    }
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheets>$entries</sheets></workbook>';
  }

  static String _worksheet(ExportSheet sheet) {
    final buffer = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
      ..write('<sheetViews><sheetView workbookViewId="0">')
      ..write('<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>')
      ..write('</sheetView></sheetViews>')
      ..write('<cols>')
      ..write('<col min="1" max="1" width="26" customWidth="1"/>')
      ..write('<col min="2" max="${sheet.headers.length.clamp(2, 64)}" width="34" customWidth="1"/>')
      ..write('</cols><sheetData>');

    buffer.write(_row(1, sheet.headers, styleIndex: 1));
    for (var i = 0; i < sheet.rows.length; i++) {
      buffer.write(_row(i + 2, sheet.rows[i]));
    }
    buffer.write('</sheetData></worksheet>');
    return buffer.toString();
  }

  static String _row(int rowIndex, List<String> cells, {int styleIndex = 0}) {
    final buffer = StringBuffer('<row r="$rowIndex">');
    for (var i = 0; i < cells.length; i++) {
      final ref = '${_columnName(i)}$rowIndex';
      final style = styleIndex == 0 ? '' : ' s="$styleIndex"';
      buffer
        ..write('<c r="$ref"$style t="inlineStr"><is><t xml:space="preserve">')
        ..write(_xmlEscape(cells[i]))
        ..write('</t></is></c>');
    }
    return (buffer..write('</row>')).toString();
  }

  /// 0 -> A, 25 -> Z, 26 -> AA
  static String _columnName(int index) {
    var n = index;
    final out = StringBuffer();
    do {
      out.write(String.fromCharCode(65 + (n % 26)));
      n = n ~/ 26 - 1;
    } while (n >= 0);
    return String.fromCharCodes(out.toString().codeUnits.reversed);
  }

  /// Excel rejects a sheet name over 31 characters or containing : \\ / ? * [ ]
  static String _safeSheetName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[:\\/?*\[\]]'), ' ').trim();
    if (cleaned.isEmpty) return 'Sheet1';
    return cleaned.length <= 31 ? cleaned : cleaned.substring(0, 31);
  }

  static String _xmlEscape(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      // Control characters are illegal in XML 1.0 and make Excel refuse the
      // whole workbook, so they are dropped rather than escaped.
      if (rune < 0x20 && rune != 0x09 && rune != 0x0A && rune != 0x0D) continue;
      buffer.write(switch (rune) {
        0x26 => '&amp;',
        0x3C => '&lt;',
        0x3E => '&gt;',
        0x22 => '&quot;',
        0x27 => '&apos;',
        _ => String.fromCharCode(rune),
      });
    }
    return buffer.toString();
  }
}
