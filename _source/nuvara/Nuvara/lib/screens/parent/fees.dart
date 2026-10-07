import 'package:flutter/material.dart';

import '../../models.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/bill.dart';
import '../../widgets/ui.dart';
import 'kit.dart';
import 'pay.dart';

/// Fees are weekly: each week is billed for the sessions the child attended, at their fee per session for
/// each therapy. What is due can be paid with UPI right here at any time, also in the middle of a week.
class ParentFees extends StatelessWidget {
  const ParentFees({super.key});

  @override
  Widget build(BuildContext context) => ChildScope(
        builder: (context, store, kid) {
          if (kid == null) {
            return PageList(onRefresh: store.refresh, children: [const TabHeader('Fees'), const EmptyState(icon: Icons.receipt_long_outlined, title: noChildTitle, hint: noChildHint)]);
          }
          final bills = store.billsOf(kid.id).where((w) => w.allocated > 0 || w.paid > 0 || w.verifying > 0).toList();
          final thisWeek = weekStart(todayISO());
          final due = bills.where((w) => w.payable).toList()..sort((a, b) => a.monday.compareTo(b.monday));
          final current = bills.where((w) => w.monday == thisWeek && !w.payable).toList();
          // Weeks still ahead (next week's planned sessions) get their own section, not "Earlier weeks".
          final ahead = bills.where((w) => w.monday.compareTo(thisWeek) > 0 && !w.payable).toList()..sort((a, b) => a.monday.compareTo(b.monday));
          final settled = bills.where((w) => w.monday.compareTo(thisWeek) < 0 && !w.payable).toList();
          final total = due.fold(0.0, (a, w) => a + w.due);
          final unfinished = store.paymentsOf(kid.id).where((p) => p.status == PayStatus.initiated).toList();
          final verifying = bills.fold(0.0, (a, w) => a + w.verifying);
          final history = store.paymentsOf(kid.id).where((p) => p.status != PayStatus.cancelled && p.status != PayStatus.initiated).toList();

          return PageList(
            onRefresh: store.refresh,
            children: [
              TabHeader('Fees', subtitle: "${kid.first}'s weekly fees"),
              const ChildSwitcher(),
              _Hero(total: total, weeks: due.length, verifying: verifying, empty: bills.isEmpty, name: kid.first, onPay: due.isEmpty ? null : () => payWeek(context, kid, due.first)),
              for (final p in unfinished) ...[
                const SizedBox(height: 12),
                _Notice(
                  icon: Icons.hourglass_top_rounded,
                  tone: Tone.amber,
                  text: 'You started paying ${money(p.amount)} for the week of ${fmtDate(p.monday, 'd MMM')}. Tell us whether it went through.',
                  action: 'Finish',
                  onTap: () => resolveUnfinished(context, p.id),
                ),
              ],
              if (due.isNotEmpty) ...[
                const SizedBox(height: 24),
                SectionTitle('To pay', hint: due.length == 1 ? null : 'Oldest first'),
                for (final w in due)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: WeekBill(
                      w,
                      footer: FilledButton.icon(
                        onPressed: () => payWeek(context, kid, w),
                        icon: const Icon(Icons.qr_code_2_rounded, size: 19),
                        label: Text('Pay ${money(w.due)} with UPI'),
                      ),
                    ),
                  ),
              ],
              if (current.isNotEmpty) ...[
                const SizedBox(height: 18),
                const SectionTitle('This week', hint: 'Added as sessions are attended'),
                for (final w in current) Padding(padding: const EdgeInsets.only(bottom: 10), child: WeekBill(w)),
              ],
              if (ahead.isNotEmpty) ...[
                const SizedBox(height: 18),
                SectionTitle(ahead.every((w) => w.monday == addDays(thisWeek, 7)) ? 'Next week' : 'Coming weeks', hint: 'Planned · nothing to pay yet'),
                for (final w in ahead) Padding(padding: const EdgeInsets.only(bottom: 10), child: WeekBill(w, initiallyOpen: false)),
              ],
              if (settled.isNotEmpty) ...[
                const SizedBox(height: 18),
                const SectionTitle('Earlier weeks'),
                for (final w in settled) Padding(padding: const EdgeInsets.only(bottom: 10), child: WeekBill(w, initiallyOpen: false)),
              ],
              const SizedBox(height: 18),
              SectionTitle('Payment history', hint: history.isEmpty ? null : 'Tap Receipt to download'),
              if (history.isEmpty)
                Text('No payments yet.', style: body(13.5, color: C.muted))
              else
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (var i = 0; i < history.length; i++) ...[if (i > 0) const Divider(indent: 64), PaymentTile(history[i])],
                  ]),
                ),
              const SizedBox(height: 18),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.storefront_outlined, size: 16, color: C.muted),
                const SizedBox(width: 8),
                Expanded(child: Text('Paid at the centre? It shows here once recorded, with a receipt.', style: body(12.5, color: C.muted, height: 1.4))),
              ]),
              const SizedBox(height: 4),
              MessageLink('Question about fees?', kid: kid),
            ],
          );
        },
      );
}

class _Hero extends StatelessWidget {
  final double total, verifying;
  final int weeks;

  /// No bills at all yet (a new family): says so instead of "All settled".
  final bool empty;
  final String name;
  final VoidCallback? onPay;
  const _Hero({required this.total, required this.weeks, required this.verifying, required this.empty, required this.name, required this.onPay});

  @override
  Widget build(BuildContext context) => HeroPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          heroOverline(total > 0 ? 'Due now' : (verifying > 0 ? 'Being verified' : (empty ? 'No fees yet' : 'All settled'))),
          const SizedBox(height: 10),
          fit(Text(total > 0 ? money(total) : 'Nothing due', style: display(38, color: Colors.white, height: 1.05).copyWith(fontFeatures: tnum))),
          const SizedBox(height: 4),
          Text(
            total > 0
                ? 'for ${plural(weeks, 'week')} · pay any time'
                : verifying > 0
                    ? '${money(verifying)} is being verified by the centre.'
                    : empty
                        ? "Fees appear here once $name's sessions start."
                        : 'Thank you. Every attended session is paid for.',
            style: body(13.5, weight: FontWeight.w600, color: C.brand100),
          ),
          if (onPay != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onPay,
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: C.brand900),
              icon: const Icon(Icons.qr_code_2_rounded, size: 19),
              label: Text(weeks == 1 ? 'Pay with UPI' : 'Pay the oldest week first'),
            ),
          ],
        ]),
      );
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final Tone tone;
  final String text, action;
  final VoidCallback onTap;
  const _Notice({required this.icon, required this.tone, required this.text, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = toneColors(tone);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(icon, size: 18, color: c.fg),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: body(13, weight: FontWeight.w600, color: c.fg, height: 1.4))),
        TextButton(onPressed: onTap, style: TextButton.styleFrom(foregroundColor: c.fg), child: Text(action)),
      ]),
    );
  }
}
