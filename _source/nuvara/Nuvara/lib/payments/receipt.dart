import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models.dart';
import '../store.dart';
import '../util.dart';
import '../widgets/brand.dart' show nuvaraMarkSvg;

/// Receipts are never stored as files. Each download reads the payment and that week's bill fresh from
/// the database and draws the PDF from them, so a receipt always matches the records (and a reversed
/// payment can't produce one).
Future<void> downloadReceipt(AppStore store, String paymentId) async {
  final row = await store.db.from('fee_payments').select().eq('id', paymentId).single();
  final p = Payment(row);
  if (!p.confirmed) throw Exception(p.status == PayStatus.reversed ? 'This payment was reversed, so it has no receipt.' : 'A receipt is ready once the payment is confirmed.');
  final weeks = await store.db.rpc('fee_weeks', params: {'p_from': p.monday, 'p_to': addDays(p.monday, 6), 'p_child': p.childId});
  final week = [for (final m in (weeks as List).cast<Json>()) FeeWeek(m)].firstOrNull;
  final others = (await store.db.from('fee_payments').select().eq('child_id', p.childId).eq('week_start', p.monday).eq('status', 'confirmed'))
      .map(Payment.new)
      .toList();
  final bytes = await buildReceipt(store, p, week, others);
  final name = 'Nuvara-Receipt-${p.receiptCode}.pdf';
  final desktop = !kIsWeb && const {TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux}.contains(defaultTargetPlatform);
  if (desktop) {
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
  } else {
    await Printing.sharePdf(bytes: bytes, filename: name, subject: 'Nuvara fee receipt ${p.receiptCode}');
  }
}

Future<Uint8List> buildReceipt(AppStore store, Payment p, FeeWeek? week, List<Payment> confirmedThatWeek) async {
  // The app's own bundled font (it has the rupee sign), so receipts look like the app and work offline.
  // If it can't be read for any reason, the PDF's built-in font is used with "Rs.".
  pw.Font? regular, bold;
  try {
    regular = pw.Font.ttf(await rootBundle.load('assets/google_fonts/PlusJakartaSans-Regular.ttf'));
    bold = pw.Font.ttf(await rootBundle.load('assets/google_fonts/PlusJakartaSans-Bold.ttf'));
  } catch (_) {
    regular = bold = null;
  }
  final rupee = regular == null ? 'Rs. ' : '₹';
  String amt(num n) => '$rupee${NumberFormat('#,##,##0.00', 'en_IN').format(n)}';

  final child = store.child(p.childId);
  final navy = PdfColor.fromInt(0xFF010039), orange = PdfColor.fromInt(0xFFEA501E), muted = PdfColor.fromInt(0xFF6A6E88), line = PdfColor.fromInt(0xFFE5E7F1);
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);
  final sunday = addDays(p.monday, 6);
  final paidBefore = confirmedThatWeek.where((x) => x.id != p.id && (x.receiptNo ?? 0) < (p.receiptNo ?? 0)).fold(0.0, (a, x) => a + x.amount);
  final total = week?.amount ?? 0;
  final balance = total - paidBefore - p.amount;

  pw.Widget kv(String k, String v, {bool strong = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(children: [
          pw.Expanded(child: pw.Text(k, style: pw.TextStyle(color: strong ? PdfColors.black : muted, fontWeight: strong ? pw.FontWeight.bold : null))),
          pw.Text(v, style: pw.TextStyle(fontWeight: strong ? pw.FontWeight.bold : null)),
        ]),
      );

  final doc = pw.Document(title: 'Receipt ${p.receiptCode}', author: 'Nuvara', theme: theme);
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(40),
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Container(
        padding: const pw.EdgeInsets.all(20),
        decoration: pw.BoxDecoration(color: navy, borderRadius: pw.BorderRadius.circular(12)),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.SizedBox(width: 34, height: 38, child: pw.SvgImage(svg: nuvaraMarkSvg())),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('nuvara.', style: pw.TextStyle(color: PdfColors.white, fontSize: 24, fontWeight: pw.FontWeight.bold, letterSpacing: -0.5)),
              pw.Container(margin: const pw.EdgeInsets.only(top: 4), width: 28, height: 3, decoration: pw.BoxDecoration(color: orange, borderRadius: pw.BorderRadius.circular(2))),
            ]),
          ),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('FEE RECEIPT', style: pw.TextStyle(color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
            pw.SizedBox(height: 4),
            pw.Text(p.receiptCode, style: pw.TextStyle(color: PdfColor.fromInt(0xFF8FD0EF), fontSize: 11)),
          ]),
        ]),
      ),
      pw.SizedBox(height: 22),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('RECEIVED FOR', style: pw.TextStyle(color: muted, fontSize: 9, letterSpacing: 1)),
            pw.SizedBox(height: 4),
            pw.Text(child?.name ?? 'Child', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            pw.Text('Child ID ${child?.code ?? ''}', style: pw.TextStyle(color: muted)),
            if (child != null && (child.motherName.isNotEmpty || child.fatherName.isNotEmpty))
              pw.Text('Parent: ${child.motherName.isNotEmpty ? child.motherName : child.fatherName}', style: pw.TextStyle(color: muted)),
          ]),
        ),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('WEEK', style: pw.TextStyle(color: muted, fontSize: 9, letterSpacing: 1)),
          pw.SizedBox(height: 4),
          pw.Text('${fmtDate(p.monday, 'd MMM')} – ${fmtDate(sunday, 'd MMM yyyy')}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Paid on ${fmtDate(p.when, 'd MMM yyyy')}', style: pw.TextStyle(color: muted)),
        ]),
      ]),
      pw.SizedBox(height: 22),
      pw.Text('SESSIONS THIS WEEK', style: pw.TextStyle(color: muted, fontSize: 9, letterSpacing: 1)),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        border: pw.TableBorder(horizontalInside: pw.BorderSide(color: line), bottom: pw.BorderSide(color: line)),
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
        headerDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFEFF0FA)),
        cellStyle: const pw.TextStyle(fontSize: 10),
        cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.center, 2: pw.Alignment.center, 3: pw.Alignment.centerRight, 4: pw.Alignment.centerRight},
        headers: ['Therapy', 'Allocated', 'Attended', 'Fee per session', 'Amount'],
        data: [
          for (final l in week?.lines ?? const <FeeLine>[])
            [
              store.therapyName(l.therapyId),
              '${l.allocated}',
              '${l.attended}',
              l.rates.isEmpty ? '—' : l.rates.map((r) => l.rates.length == 1 ? amt(r.rate) : '${amt(r.rate)} × ${r.count}').join(' + '),
              amt(l.amount),
            ],
        ],
      ),
      pw.SizedBox(height: 14),
      pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: line), borderRadius: pw.BorderRadius.circular(10)),
        child: pw.Column(children: [
          kv('Sessions attended', '${week?.attended ?? 0} of ${week?.allocated ?? 0}'),
          kv('Week total', amt(total)),
          if (paidBefore > 0) kv('Paid earlier', '− ${amt(paidBefore)}'),
          pw.Divider(color: line),
          kv('Amount received', amt(p.amount), strong: true),
          kv('Balance for this week', amt(balance < 0.005 ? 0 : balance)),
        ]),
      ),
      pw.SizedBox(height: 18),
      pw.Text('PAYMENT', style: pw.TextStyle(color: muted, fontSize: 9, letterSpacing: 1)),
      pw.SizedBox(height: 6),
      kv('Method', p.method),
      if (p.payeeVpa != null) kv('Paid to', '${p.payeeName ?? ''} · ${p.payeeVpa}'),
      if (p.utr != null) kv('UPI reference (UTR)', p.utr!),
      kv('Transaction ID', p.txnRef),
      kv('Confirmed by', p.verifiedBy == 'upi_app' ? 'UPI app confirmation' : 'The centre'),
      if (p.note.isNotEmpty) kv('Note', p.note),
      pw.Spacer(),
      pw.Divider(color: line),
      pw.Text(
        'Generated on ${DateFormat('d MMM yyyy, h:mm a').format(DateTime.now())} from the centre\'s records. '
        'This is a computer-generated receipt and does not need a signature.',
        style: pw.TextStyle(color: muted, fontSize: 8.5),
      ),
    ]),
  ));
  return doc.save();
}
