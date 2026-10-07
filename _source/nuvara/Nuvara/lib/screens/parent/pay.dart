import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../actions.dart';
import '../../models.dart';
import '../../payments/upi.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/bill.dart';
import '../../widgets/ui.dart';

// Paying a week's fee with UPI.
//
// 1. The server creates the payment: it decides the amount (what is still due), copies the active UPI ID
//    onto it and gives it a one-time reference. Nothing here can change those.
// 2. Android shows "Pay with" so the parent picks their UPI app; we wait for them to come back.
// 3. The UPI app's reply goes to the server, which checks it belongs to this payment and that its bank
//    reference was never used before. A fresh SUCCESS with a bank reference → paid with a receipt (the
//    admin still ticks it off against the bank later); a weaker answer → the admin verifies it first;
//    FAILURE → nothing owed changes.
// 4. No clear reply (app killed, no response, iPhone/desktop QR payment): the parent says whether they
//    paid. "Yes" + the UPI reference sends it to the admin to verify; "No" cancels it. Until then the
//    week can't be paid again, so nobody pays twice.

Future<void> payWeek(BuildContext context, Child kid, FeeWeek week) async {
  final store = context.read<AppStore>();
  UpiOrder order;
  try {
    order = await store.startUpiPayment(kid.id, week.monday);
  } on UnfinishedPayment catch (e) {
    if (context.mounted) await resolveUnfinished(context, e.paymentId);
    return;
  } catch (e) {
    if (context.mounted) toast(context, cleanError(e), error: true);
    return;
  }
  if (!context.mounted) return;
  final link = Upi.link(order, upiNote(kid.code, week.monday));
  final hasApp = Upi.canLaunch && await Upi.apps() > 0;
  if (!context.mounted) return;
  if (hasApp) {
    final go = await showSheet<bool>(context, builder: (_) => _ConfirmSheet(kid: kid, week: week, order: order));
    if (!context.mounted) return;
    if (go != true) {
      await store.cancelUpiPayment(order.id).catchError((_) {});
      return;
    }
    UpiReply reply;
    try {
      reply = await Upi.pay(link);
    } catch (_) {
      reply = (launched: false, response: null);
    }
    if (!context.mounted) return;
    if (!reply.launched) {
      await _qr(context, kid, order, link);
      return;
    }
    await _finish(context, kid, order, reply.response);
    return;
  }
  await _qr(context, kid, order, link);
}

/// The QR sheet, then: "I've paid" goes straight to entering the UPI reference; closing it without an answer
/// leaves the payment open, so say where to finish it.
Future<void> _qr(BuildContext context, Child kid, UpiOrder order, Uri link) async {
  final paid = await showSheet<bool>(context, builder: (_) => _QrSheet(kid: kid, order: order, link: link));
  if (!context.mounted) return;
  if (paid == true) {
    await resolveUnfinished(context, order.id, paid: true);
  } else if (paid == null) {
    toast(context, 'Tell us if you paid: Fees → Finish');
  }
}

Future<void> _finish(BuildContext context, Child kid, UpiOrder order, String? response) async {
  final store = context.read<AppStore>();
  PayStatus status;
  try {
    status = await store.completeUpiPayment(order.id, response, null);
  } catch (e) {
    if (context.mounted) toast(context, cleanError(e), error: true);
    return;
  }
  if (!context.mounted) return;
  switch (status) {
    case PayStatus.confirmed:
      final p = store.payments.where((x) => x.id == order.id).firstOrNull;
      await showSheet(context, builder: (_) => _DoneSheet(kid: kid, payment: p, amount: order.amount));
    case PayStatus.verifying:
      toast(context, 'Your UPI app says the payment was made. The centre will check it with the bank and your receipt will be ready soon.');
    case PayStatus.failed:
      final p = store.payments.where((x) => x.id == order.id).firstOrNull;
      toast(context, p?.note.isNotEmpty == true ? p!.note : 'The payment didn\'t go through. No money was taken for this attempt; you can try again.', error: true);
    case PayStatus.initiated:
      await resolveUnfinished(context, order.id);
    case PayStatus.cancelled || PayStatus.reversed:
      break;
  }
}

/// "Did the money leave your account?" for an attempt whose outcome we don't know.
/// [paid]: they already said they paid, so it opens on entering the UPI reference.
Future<void> resolveUnfinished(BuildContext context, String paymentId, {bool paid = false}) => showSheet(context, builder: (_) => _UnfinishedSheet(paymentId, paid: paid));

class _ConfirmSheet extends StatelessWidget {
  final Child kid;
  final FeeWeek week;
  final UpiOrder order;
  const _ConfirmSheet({required this.kid, required this.week, required this.order});

  @override
  Widget build(BuildContext context) => SheetBody(
        title: 'Pay ${money(order.amount)}',
        subtitle: '${kid.first} · week of ${weekRange(week.monday)}',
        footer: [
          btn('Cancel', onPressed: () => Navigator.pop(context, false)),
          btn('Choose UPI app', icon: Icons.arrow_forward_rounded, kind: 'filled', onPressed: () => Navigator.pop(context, true)),
        ],
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _PayeeBox(order: order),
          const SizedBox(height: 14),
          Text(
            '${week.attended} of ${week.allocated} sessions attended${week.closed ? '' : ' so far'}. Your UPI app will show this amount and payee; check them before entering your PIN.',
            style: body(13, color: C.muted, height: 1.45),
          ),
          const SizedBox(height: 10),
          Text('Come back to Nuvara after paying so we can confirm it.', style: body(13, weight: FontWeight.w600, color: C.brand700)),
        ]),
      );
}

class _PayeeBox extends StatelessWidget {
  final UpiOrder order;
  const _PayeeBox({required this.order});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.brand50, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KV('Paying to', order.name, icon: Icons.storefront_outlined),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: KV('UPI ID', order.vpa, icon: Icons.qr_code_2_rounded)),
            IconButton(
              tooltip: 'Copy UPI ID',
              icon: const Icon(Icons.copy_rounded, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: order.vpa));
                toast(context, 'UPI ID copied');
              },
            ),
          ]),
          const SizedBox(height: 10),
          KV('Reference', order.txnRef, icon: Icons.tag_rounded),
        ]),
      );
}

/// iPhone, desktop or no UPI app: scan the QR with any UPI app (or pay the UPI ID), then give us the reference.
class _QrSheet extends StatefulWidget {
  final Child kid;
  final UpiOrder order;
  final Uri link;
  const _QrSheet({required this.kid, required this.order, required this.link});

  @override
  State<_QrSheet> createState() => _QrSheetState();
}

class _QrSheetState extends State<_QrSheet> {
  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return SheetBody(
      title: 'Pay ${money(o.amount)}',
      subtitle: 'Scan with any UPI app',
      footer: [
        btn('I didn\'t pay', onPressed: () async {
          final nav = Navigator.of(context);
          await context.read<AppStore>().cancelUpiPayment(o.id).catchError((_) {});
          nav.pop(false);
        }),
        btn('I\'ve paid', icon: Icons.check_rounded, kind: 'filled', onPressed: () => Navigator.pop(context, true)),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
            child: QrImageView(data: widget.link.toString(), size: 210, backgroundColor: Colors.white, semanticsLabel: 'UPI payment QR code'),
          ),
        ),
        const SizedBox(height: 16),
        _PayeeBox(order: o),
        const SizedBox(height: 12),
        Text('Pay exactly ${money(o.amount)}. Afterwards tap "I\'ve paid" and enter the UPI reference number (UTR) from your UPI app.', style: body(12.5, color: C.muted, height: 1.45)),
      ]),
    );
  }
}

class _UnfinishedSheet extends StatefulWidget {
  final String paymentId;
  final bool paid;
  const _UnfinishedSheet(this.paymentId, {this.paid = false});

  @override
  State<_UnfinishedSheet> createState() => _UnfinishedSheetState();
}

class _UnfinishedSheetState extends State<_UnfinishedSheet> {
  final utr = TextEditingController();
  late bool paid = widget.paid;

  @override
  void dispose() {
    utr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = store.payments.where((x) => x.id == widget.paymentId).firstOrNull;
    if (p == null || p.status != PayStatus.initiated) {
      return SheetBody(
        title: 'Payment settled',
        footer: [btn('Close', kind: 'filled', onPressed: () => Navigator.pop(context))],
        child: Text(p == null ? 'This payment is no longer open.' : 'This payment is now: ${p.status.label}.', style: body(14, color: C.muted)),
      );
    }
    final ok = validUtr(utr.text);
    return SheetBody(
      title: 'Did the payment go through?',
      subtitle: '${money(p.amount)} · started ${fmtDateTime(p.createdAt)}',
      footer: paid
          ? [
              btn('Back', onPressed: () => setState(() => paid = false)),
              ActionButton('Send to the centre', icon: Icons.send_rounded, onPressed: !ok
                  ? null
                  : () async {
                      final nav = Navigator.of(context);
                      await store.submitUpiReference(p.id, cleanUtr(utr.text));
                      nav.pop();
                      return 'Thank you. The centre will confirm it and your receipt will be ready.';
                    }),
            ]
          : [
              ActionButton('No, I didn\'t pay', kind: 'outlined', onPressed: () async {
                final nav = Navigator.of(context);
                await store.cancelUpiPayment(p.id);
                nav.pop();
                return 'Cancelled. You can pay again whenever you like.';
              }),
              btn('Yes, I paid', icon: Icons.check_rounded, kind: 'filled', onPressed: () => setState(() => paid = true)),
            ],
      child: paid
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Open your UPI app\'s history, find this payment of ${money(p.amount)} and copy its UPI reference number (also called UTR or transaction ID, usually 12 digits).', style: body(13, color: C.muted, height: 1.45)),
              const SizedBox(height: 14),
              Field(
                'UPI reference number',
                child: TextField(
                  controller: utr,
                  autofocus: true,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]')), LengthLimitingTextInputFormatter(40)],
                  onChanged: (_) => setState(() {}),
                  style: body(15, weight: FontWeight.w600).copyWith(fontFeatures: tnum, letterSpacing: 0.6),
                  decoration: InputDecoration(hintText: 'e.g. 412345678901', errorText: utr.text.isNotEmpty && !ok ? 'Letters and numbers only, at least 6' : null),
                ),
              ),
              const SizedBox(height: 10),
              Text('The centre checks it against their account before issuing your receipt.', style: body(12, color: C.muted)),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('We didn\'t get a clear answer from your UPI app. Check your UPI app or bank: did ${money(p.amount)} leave your account for ${p.payeeVpa ?? 'the centre'}?', style: body(13.5, height: 1.45)),
              const SizedBox(height: 12),
              Text('Until you tell us, this week can\'t be paid again, so you won\'t pay twice by mistake.', style: body(12.5, color: C.muted, height: 1.4)),
            ]),
    );
  }
}

class _DoneSheet extends StatelessWidget {
  final Child kid;
  final Payment? payment;
  final double amount;
  const _DoneSheet({required this.kid, required this.payment, required this.amount});

  @override
  Widget build(BuildContext context) => SheetBody(
        title: 'Payment successful',
        subtitle: '${money(amount)} for ${kid.first}',
        footer: [
          btn('Done', onPressed: () => Navigator.pop(context)),
          if (payment != null) ReceiptButton(payment!, filled: true),
        ],
        child: Column(children: [
          Container(width: 72, height: 72, decoration: const BoxDecoration(color: C.greenBg, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, size: 40, color: C.green)),
          const SizedBox(height: 14),
          if (payment != null) ...[
            Text('Receipt ${payment!.receiptCode}', style: body(14, weight: FontWeight.w700)),
            if (payment!.utr != null) Text('UPI reference ${payment!.utr}', style: body(12.5, color: C.muted)),
          ],
          const SizedBox(height: 8),
          Text('You can download the receipt any time from Fees → Payment history.', textAlign: TextAlign.center, style: body(12.5, color: C.muted)),
        ]),
      );
}
