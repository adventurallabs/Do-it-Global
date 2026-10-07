import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../store.dart';
import '../util.dart';
import '../widgets/brand.dart' show nuvaraMarkSvg;
import 'catalog.dart';
import 'model.dart';
import 'report.dart';

/// Opens the print dialog (desktop) or the share sheet (phones) with the assessment as a PDF report.
Future<void> shareAssessmentPdf(AppStore store, Assessment a, {String? childCode}) async {
  final bytes = await buildAssessmentPdf(a, therapist: a.therapistId == null ? '' : store.therapistName(a.therapistId), childCode: childCode);
  final name = 'Nuvara-OT-Assessment-${(childCode ?? a.childName).replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')}-${a.date}.pdf';
  final desktop = !kIsWeb && const {TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux}.contains(defaultTargetPlatform);
  if (desktop || kIsWeb) {
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
  } else {
    await Printing.sharePdf(bytes: bytes, filename: name, subject: 'Pediatric OT Assessment — ${a.childName}');
  }
}

Future<Uint8List> buildAssessmentPdf(Assessment a, {required String therapist, String? childCode}) async {
  pw.Font? regular, bold;
  try {
    regular = pw.Font.ttf(await rootBundle.load('assets/google_fonts/PlusJakartaSans-Regular.ttf'));
    bold = pw.Font.ttf(await rootBundle.load('assets/google_fonts/PlusJakartaSans-Bold.ttf'));
  } catch (_) {
    regular = bold = null;
  }
  final navy = PdfColor.fromInt(0xFF010039), orange = PdfColor.fromInt(0xFFEA501E), muted = PdfColor.fromInt(0xFF62667F), line = PdfColor.fromInt(0xFFE5E7F1), tint = PdfColor.fromInt(0xFFEFF0FA);
  PdfColor mood(Mood m) => switch (m) {
        Mood.good => PdfColor.fromInt(0xFF107443),
        Mood.watch => PdfColor.fromInt(0xFFA35A00),
        Mood.concern => PdfColor.fromInt(0xFFC0263D),
        Mood.info => PdfColor.fromInt(0xFF1772B5),
        Mood.neutral => muted,
      };
  final small = pw.TextStyle(fontSize: 8.5, color: muted);
  final label = pw.TextStyle(fontSize: 9, color: muted, fontWeight: pw.FontWeight.bold);

  pw.Widget block(RBlock b) => switch (b) {
        RText(:final label, :final value) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.SizedBox(width: 140, child: pw.Text(label, style: pw.TextStyle(fontSize: 9.5, color: muted, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.5))),
            ]),
          ),
        RItem(:final label, :final answer, mood: final m, :final details) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.SizedBox(width: 140, child: pw.Text(label, style: const pw.TextStyle(fontSize: 10))),
              pw.SizedBox(width: 110, child: pw.Text(answer, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: mood(m)))),
              pw.Expanded(child: pw.Text(details.join(' · '), style: pw.TextStyle(fontSize: 9.5, color: muted))),
            ]),
          ),
        RHeading(:final text) => pw.Padding(padding: const pw.EdgeInsets.only(top: 8, bottom: 3), child: pw.Text(text.toUpperCase(), style: label.copyWith(letterSpacing: 0.8))),
        RTable(:final head, :final rows) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.TableHelper.fromTextArray(
              border: pw.TableBorder(horizontalInside: pw.BorderSide(color: line), bottom: pw.BorderSide(color: line)),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
              headerDecoration: pw.BoxDecoration(color: tint),
              cellStyle: const pw.TextStyle(fontSize: 9),
              columnWidths: {0: const pw.FlexColumnWidth(1.7)},
              headers: head,
              data: [for (final r in rows) [for (final (i, x) in r.indexed) i > 0 && x.isEmpty ? '—' : x]],
            ),
          ),
        REntries(:final entries) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            for (final (i, x) in entries.indexed)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.SizedBox(width: 18, child: pw.Text('${i + 1}.', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: navy))),
                  pw.Expanded(
                    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text(x.title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      if (x.body.isNotEmpty) pw.Text('${x.meta}: ${x.body}', style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.5)) else if (x.meta.isNotEmpty) pw.Text(x.meta, style: small),
                    ]),
                  ),
                ]),
              ),
          ]),
        RNone(:final text) => pw.Text(text, style: pw.TextStyle(fontSize: 9.5, color: muted)),
      };

  final dob = a.pick('dob');
  final meta = [
    ('Child', '${a.childName}${childCode == null ? '' : '  ($childCode)'}'),
    ('Date of assessment', fmtDate(a.date, 'd MMM yyyy')),
    ('Assessment type', labelOf(Answers.kind, a.kind) ?? ''),
    ('Therapist', therapist),
    if (dob != null) ('Age at assessment', ageAt(dob, a.date)),
    ('Status', labelOf(Answers.status, a.status) ?? a.status),
  ];

  final doc = pw.Document(title: 'Pediatric OT Assessment — ${a.childName}', author: 'Nuvara', theme: pw.ThemeData.withFont(base: regular, bold: bold));
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 32),
    header: (ctx) => ctx.pageNumber == 1
        ? pw.SizedBox()
        : pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Row(children: [
              pw.Text('Pediatric OT Assessment · ${a.childName}', style: small),
              pw.Spacer(),
              pw.Text(fmtDate(a.date, 'd MMM yyyy'), style: small),
            ]),
          ),
    footer: (ctx) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10),
      child: pw.Row(children: [
        pw.Expanded(child: pw.Text('Confidential clinical record · Generated ${DateFormat('d MMM yyyy, h:mm a').format(DateTime.now())}', style: small)),
        pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: small),
      ]),
    ),
    build: (ctx) => [
      pw.Container(
        padding: const pw.EdgeInsets.all(18),
        decoration: pw.BoxDecoration(color: navy, borderRadius: pw.BorderRadius.circular(12)),
        child: pw.Row(children: [
          pw.SizedBox(width: 30, height: 34, child: pw.SvgImage(svg: nuvaraMarkSvg())),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('nuvara.', style: pw.TextStyle(color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Container(margin: const pw.EdgeInsets.only(top: 3), width: 24, height: 3, decoration: pw.BoxDecoration(color: orange, borderRadius: pw.BorderRadius.circular(2))),
            ]),
          ),
          pw.Text('PEDIATRIC OT ASSESSMENT', style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
        ]),
      ),
      pw.SizedBox(height: 14),
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: line), borderRadius: pw.BorderRadius.circular(10)),
        child: pw.Wrap(spacing: 18, runSpacing: 8, children: [
          for (final (k, v) in meta)
            pw.SizedBox(
              width: 150,
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(k.toUpperCase(), style: label.copyWith(fontSize: 7.5, letterSpacing: 0.6)),
                pw.SizedBox(height: 2),
                pw.Text(v.isEmpty ? '—' : v, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
              ]),
            ),
        ]),
      ),
      for (final (i, s) in buildReport(a).indexed) ...[
        pw.SizedBox(height: 14),
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 4),
          decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: orange, width: 1.2))),
          child: pw.Text('${i + 1}. ${s.def.title}', style: pw.TextStyle(fontSize: 12.5, fontWeight: pw.FontWeight.bold, color: navy)),
        ),
        pw.SizedBox(height: 4),
        for (final b in s.blocks) block(b),
      ],
      pw.SizedBox(height: 28),
      pw.Row(children: [
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Container(height: 0.8, width: 170, color: line), pw.SizedBox(height: 4), pw.Text('Therapist: $therapist', style: small)])),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Container(height: 0.8, width: 170, color: line), pw.SizedBox(height: 4), pw.Text('Date', style: small)]),
      ]),
    ],
  ));
  return doc.save();
}
