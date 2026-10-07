import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../payments/receipt.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import 'ui.dart';

String weekRange(String monday) => '${fmtDate(monday, 'd MMM')} – ${fmtDate(addDays(monday, 6), 'd MMM')}';

/// One week's bill laid out like an invoice: per therapy, sessions allocated and attended, the fee per
/// session and the amount; then the week total, what's paid or being verified, and what's due.
class WeekBill extends StatelessWidget {
  final FeeWeek week;

  /// Shown under the totals (e.g. the Pay button).
  final Widget? footer;
  final bool initiallyOpen;
  const WeekBill(this.week, {super.key, this.footer, this.initiallyOpen = true});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final w = week;
    final monday = weekStart(todayISO());
    final thisWeek = w.monday == monday;
    final ahead = w.monday.compareTo(monday) > 0;
    final nextWeek = w.monday == addDays(monday, 7);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('bill-${w.childId}-${w.monday}'),
          initiallyExpanded: initiallyOpen,
          tilePadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(thisWeek ? 'This week · ${weekRange(w.monday)}' : (nextWeek ? 'Next week · ${weekRange(w.monday)}' : weekRange(w.monday)), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15, weight: FontWeight.w700)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              StatusChip(w.state.label, tone: weekTone(w.state)),
              Text('${w.attended} of ${w.allocated} attended · ${money(w.amount)}', style: body(12, color: C.muted).copyWith(fontFeatures: tnum)),
            ]),
          ),
          children: [
            const SizedBox(height: 4),
            _Header(),
            for (final l in w.lines) _LineRow(line: l, therapy: store.therapy(l.therapyId), rateNow: store.rateOf(w.childId, l.therapyId)),
            const Divider(height: 20),
            _Total('Sessions allocated', '${w.allocated}'),
            _Total('Attended (present or late)', '${w.attended}'),
            if (w.absent > 0) _Total('Absent · not charged', '${w.absent}'),
            if (w.unmarked > 0) _Total('Waiting for attendance', '${w.unmarked}', color: C.amber),
            if (w.upcoming > 0) _Total('Still to come', '${w.upcoming}'),
            const Divider(height: 20),
            _Total(w.closed ? 'Week total' : 'Total so far', money(w.amount), strong: true),
            if (w.paid > 0) _Total('Paid', '− ${money(w.paid)}', color: C.green),
            if (w.verifying > 0) _Total('Being verified', '− ${money(w.verifying)}', color: C.blue),
            if (w.credit > 0) _Total('Paid beyond the bill (credit)', money(w.credit), color: C.green),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: Text(w.closed ? 'Due' : 'Due now', style: body(15, weight: FontWeight.w800))),
              Text(money(w.due), style: display(22, color: w.due > 0 ? C.clay600 : C.green).copyWith(fontFeatures: tnum)),
            ]),
            if (!w.closed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  ahead
                      ? 'Nothing to pay yet: ${nextWeek ? "next week's" : "that week's"} sessions are added to the bill as they are attended.'
                      : w.upcoming > 0
                          ? 'Sessions attended ${thisWeek ? 'later this week' : 'later'} are added as they happen. You can pay what is due at any time.'
                          : 'Some sessions are still waiting for attendance; they are added once marked.',
                  style: body(12, color: C.muted, height: 1.4),
                ),
              ),
            if (footer != null) ...[const SizedBox(height: 14), footer!],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = body(11, weight: FontWeight.w800, color: C.muted).copyWith(letterSpacing: 0.4);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Expanded(flex: 5, child: Text('THERAPY', style: s)),
        Expanded(flex: 3, child: Text('ATTENDED', textAlign: TextAlign.center, style: s)),
        Expanded(flex: 4, child: Text('AMOUNT', textAlign: TextAlign.end, style: s)),
      ]),
    );
  }
}

class _LineRow extends StatelessWidget {
  final FeeLine line;
  final Therapy? therapy;
  final double rateNow;
  const _LineRow({required this.line, required this.therapy, required this.rateNow});

  @override
  Widget build(BuildContext context) {
    final l = line;
    final rates = l.rates.isEmpty
        ? '${money(rateNow)} per session'
        : l.rates.length == 1
            ? '${l.rates.first.count} × ${money(l.rates.first.rate)}'
            : l.rates.map((r) => '${r.count} × ${money(r.rate)}').join(' + ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 5,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: therapy?.color ?? C.muted, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Expanded(child: Text(therapy?.name ?? 'Therapy', maxLines: 2, overflow: TextOverflow.ellipsis, style: body(13.5, weight: FontWeight.w700))),
            ]),
            Padding(padding: const EdgeInsets.only(left: 15, top: 2), child: Text(rates, style: body(11.5, color: C.muted).copyWith(fontFeatures: tnum))),
          ]),
        ),
        Expanded(
          flex: 3,
          child: Text('${l.attended} / ${l.allocated}', textAlign: TextAlign.center, style: body(13.5, weight: FontWeight.w600).copyWith(fontFeatures: tnum)),
        ),
        Expanded(flex: 4, child: Text(money(l.amount), textAlign: TextAlign.end, style: body(13.5, weight: FontWeight.w700).copyWith(fontFeatures: tnum))),
      ]),
    );
  }
}

class _Total extends StatelessWidget {
  final String label, value;
  final bool strong;
  final Color? color;
  const _Total(this.label, this.value, {this.strong = false, this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: body(13, weight: strong ? FontWeight.w800 : FontWeight.w500, color: strong ? C.ink : C.muted))),
          Text(value, style: body(13.5, weight: strong ? FontWeight.w800 : FontWeight.w600, color: color ?? C.ink).copyWith(fontFeatures: tnum)),
        ]),
      );
}

IconData methodIcon(String method) => switch (method.toLowerCase()) {
      'upi' => Icons.qr_code_2_rounded,
      'cash' => Icons.payments_outlined,
      'card' => Icons.credit_card_rounded,
      'bank transfer' => Icons.account_balance_outlined,
      'cheque' => Icons.receipt_outlined,
      _ => Icons.receipt_long_outlined,
    };

/// One payment: amount, week, method and reference, its status, and the receipt once confirmed.
class PaymentTile extends StatelessWidget {
  final Payment payment;
  final bool showChild;

  /// Admin actions (confirm / reject / reverse) go here.
  final Widget? trailing;
  final VoidCallback? onTap;
  const PaymentTile(this.payment, {super.key, this.showChild = false, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final p = payment;
    final c = toneColors(payTone(p.status));
    final details = [
      'Week of ${fmtDate(p.monday, 'd MMM')}',
      p.method,
      if (p.utr != null) 'UTR ${p.utr}',
      if (p.receiptNo != null) p.receiptCode,
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(12)), child: Icon(methodIcon(p.method), size: 19, color: c.fg)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  showChild ? '${store.child(p.childId)?.name ?? 'Child'} · ${money(p.amount)}' : money(p.amount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: body(14.5, weight: FontWeight.w700).copyWith(fontFeatures: tnum),
                ),
                Text(details, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted)),
                Text(fmtDateTime(p.resolvedAt ?? p.createdAt), style: body(11.5, color: C.muted)),
              ]),
            ),
            const SizedBox(width: 8),
            StatusChip(p.status == PayStatus.confirmed && p.verifiedBy == 'upi_app' ? 'Paid · UPI' : p.status.label, tone: payTone(p.status)),
          ]),
          if (p.note.isNotEmpty && p.status != PayStatus.confirmed)
            Padding(padding: const EdgeInsets.only(left: 50, top: 6), child: Text(p.note, style: body(12, color: C.muted, height: 1.35))),
          if (p.confirmed || trailing != null)
            Padding(
              padding: const EdgeInsets.only(left: 42, top: 6),
              child: Wrap(spacing: 4, runSpacing: 4, children: [
                if (p.confirmed) ReceiptButton(p),
                ?trailing,
              ]),
            ),
        ]),
      ),
    );
  }
}

/// Builds the receipt from the database and opens the save / share dialog.
class ReceiptButton extends StatefulWidget {
  final Payment payment;
  final bool filled;
  const ReceiptButton(this.payment, {super.key, this.filled = false});

  @override
  State<ReceiptButton> createState() => _ReceiptButtonState();
}

class _ReceiptButtonState extends State<ReceiptButton> {
  bool busy = false;

  Future<void> _go() async {
    setState(() => busy = true);
    try {
      await downloadReceipt(context.read<AppStore>(), widget.payment.id);
    } catch (e) {
      if (mounted) toast(context, cleanError(e), error: true);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final icon = busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_rounded, size: 18);
    return widget.filled
        ? FilledButton.icon(onPressed: busy ? null : _go, icon: icon, label: const Text('Download receipt'))
        : TextButton.icon(
            onPressed: busy ? null : _go,
            style: TextButton.styleFrom(minimumSize: const Size(0, 34), visualDensity: VisualDensity.compact),
            icon: icon,
            label: const Text('Receipt'),
          );
  }
}
