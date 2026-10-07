import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../actions.dart';
import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/bill.dart';
import '../../widgets/ui.dart';
import 'child_form.dart' show fmtPlain;

/// Fees for every child, two ways:
/// * Outstanding: who still owes money, how much, and for which weeks (this week included). Fees can be
///   paid and recorded at any time, so this is the list to collect from.
/// * By week: one week at a time, everyone's bill and whether it is paid.
class FeesTab extends StatefulWidget {
  const FeesTab({super.key});

  @override
  State<FeesTab> createState() => _FeesTabState();
}

enum _View { outstanding, week }

enum _Who { owing, clear, all }

class _FeesTabState extends State<FeesTab> {
  _View view = _View.outstanding;
  _Who who = _Who.owing;
  String monday = weekStart(todayISO());
  FeeState? filter;
  String q = '';
  int _search = 0;

  void _clearSearch() => setState(() {
        q = '';
        filter = null;
        who = _Who.all;
        _search++;
      });

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final toVerify = store.paymentsToVerify.length;
    final toCheck = store.paymentsToReconcile.length;
    final header = <Widget>[
      TabHeader('Fees', subtitle: 'Weekly, for attended sessions · pay any time', actions: [
        IconButton(tooltip: 'UPI IDs', onPressed: () => context.push('/admin/fees/upi'), icon: const Icon(Icons.qr_code_2_rounded)),
      ]),
      if (toVerify > 0 || toCheck > 0)
        _Banner(
          icon: Icons.fact_check_outlined,
          tone: Tone.blue,
          text: [
            if (toVerify > 0) '${plural(toVerify, 'payment')} waiting for you to verify',
            if (toCheck > 0) '${plural(toCheck, 'UPI payment')} to tick off against the bank',
          ].join(' · '),
          action: 'Review',
          onTap: () => context.push('/admin/fees/verify'),
        ),
      if (store.activeUpi == null)
        _Banner(
          icon: Icons.qr_code_2_rounded,
          tone: Tone.amber,
          text: 'Add a UPI ID so families can pay from their phones.',
          action: 'Add UPI ID',
          onTap: () => context.push('/admin/fees/upi'),
        ),
      if (toVerify > 0 || toCheck > 0 || store.activeUpi == null) const SizedBox(height: 4),
      Segmented<_View>(
        value: view,
        expand: true,
        height: 42,
        options: [seg(_View.outstanding, 'Outstanding', Icons.pending_actions_rounded), seg(_View.week, 'By week', Icons.date_range_rounded)],
        onChanged: (v) => setState(() => view = v),
      ),
      const SizedBox(height: 14),
    ];
    return view == _View.outstanding ? _outstanding(context, store, header) : _byWeek(context, store, header);
  }

  // ---- outstanding -----------------------------------------------------------

  Widget _outstanding(BuildContext context, AppStore store, List<Widget> header) {
    final owing = {for (final o in store.owing) o.child.id: o};
    final total = owing.values.fold(0.0, (a, o) => a + o.due);
    final thisWeek = weekStart(todayISO());
    final overdue = owing.values.where((o) => o.weeks.any((w) => w.monday != thisWeek)).length;
    // Enrolled children, plus anyone who has left but still owes.
    final everyone = store.children.where((c) => c.active || owing.containsKey(c.id)).toList();
    bool include(Child c) => switch (who) { _Who.owing => owing.containsKey(c.id), _Who.clear => !owing.containsKey(c.id), _Who.all => true };
    // Most owed first, then by ID.
    final rows = everyone.where((c) => c.matches(q) && include(c)).toList()
      ..sort((a, b) {
        final d = (owing[b.id]?.due ?? 0).compareTo(owing[a.id]?.due ?? 0);
        return d != 0 ? d : a.no.compareTo(b.no);
      });
    final clear = everyone.length - owing.length;

    return PageList(
      onRefresh: store.refresh,
      itemCount: rows.length,
      itemBuilder: (_, i) => GroupedRow(
        index: i,
        count: rows.length,
        indent: 70,
        child: _OwingRow(child: rows[i], owing: owing[rows[i].id], onTap: () => context.push('/admin/fees/${rows[i].id}')),
      ),
      children: [
        ...header,
        HeroSurface(
          padding: const EdgeInsets.all(18),
          radius: 24,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Outstanding now', style: body(12.5, weight: FontWeight.w600, color: C.brand200)),
            Text(money(total), style: display(30, color: Colors.white).copyWith(fontFeatures: tnum)),
            const SizedBox(height: 10),
            Wrap(spacing: 14, runSpacing: 4, children: [
              Text('${plural(owing.length, 'child', 'children')} to collect from', style: body(12, weight: FontWeight.w700, color: Colors.white)),
              if (overdue > 0) Text('$overdue with earlier weeks unpaid', style: body(12, weight: FontWeight.w600, color: const Color(0xFFFCA5A5))),
              Text('$clear fully paid', style: body(12, weight: FontWeight.w600, color: C.brand100)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        SearchField(key: ValueKey(_search), hint: 'Search child by name or ID', onChanged: (v) => setState(() => q = v)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _FilterChip(label: 'To collect', count: owing.length, tone: Tone.red, active: who == _Who.owing, onTap: () => setState(() => who = _Who.owing)),
            _FilterChip(label: 'Fully paid', count: clear, tone: Tone.green, active: who == _Who.clear, onTap: () => setState(() => who = _Who.clear)),
            _FilterChip(label: 'Everyone', count: everyone.length, active: who == _Who.all, onTap: () => setState(() => who = _Who.all)),
          ]),
        ),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          q.trim().isEmpty && who == _Who.owing
              ? const EmptyState(icon: Icons.verified_rounded, title: 'Nothing to collect', hint: 'Every attended session is paid for.')
              : EmptyState(
                  icon: Icons.search_off_rounded,
                  title: q.trim().isEmpty ? 'No children here' : 'No child matches "${q.trim()}"',
                  action: btn('Show everyone', icon: Icons.close_rounded, onPressed: _clearSearch),
                ),
      ],
    );
  }

  // ---- by week ----------------------------------------------------------------

  Widget _byWeek(BuildContext context, AppStore store, List<Widget> header) {
    final rows = [
      for (final w in store.feeWeeks)
        if (w.monday == monday)
          if (store.child(w.childId) case final c?) (child: c, week: w),
    ];
    final count = {for (final s in FeeState.values) s: rows.where((r) => r.week.state == s).length};
    final shown = rows.where((r) => (filter == null || r.week.state == filter) && r.child.matches(q)).toList()
      ..sort((a, b) {
        final d = b.week.due.compareTo(a.week.due);
        return d != 0 ? d : a.child.no.compareTo(b.child.no);
      });
    final billed = rows.fold(0.0, (a, r) => a + r.week.amount);
    final paid = rows.fold(0.0, (a, r) => a + (r.week.paid > r.week.amount ? r.week.amount : r.week.paid));
    final verifying = rows.fold(0.0, (a, r) => a + r.week.verifying);
    final thisWeek = weekStart(todayISO());

    return PageList(
      onRefresh: store.refresh,
      itemCount: shown.length,
      itemBuilder: (_, i) => GroupedRow(
        index: i,
        count: shown.length,
        indent: 70,
        child: _FeeRow(child: shown[i].child, week: shown[i].week, onTap: () => context.push('/admin/fees/${shown[i].child.id}?week=$monday')),
      ),
      children: [
        ...header,
        WeekPicker(monday: monday, onChanged: (m) => setState(() => monday = m)),
        const SizedBox(height: 12),
        HeroSurface(
          padding: const EdgeInsets.all(18),
          radius: 24,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(monday == thisWeek ? 'Collected so far' : 'Collected', style: body(12.5, weight: FontWeight.w600, color: C.brand200)),
            Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, children: [
              Text(money(paid), style: display(30, color: Colors.white).copyWith(fontFeatures: tnum)),
              Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('of ${money(billed)} billed', style: body(13.5, weight: FontWeight.w600, color: C.brand200))),
            ]),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: billed == 0 ? 0 : (paid / billed).clamp(0, 1).toDouble(), minHeight: 8, backgroundColor: Colors.white.withValues(alpha: 0.12), color: C.sky),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 14, runSpacing: 4, children: [
              Text('${money((billed - paid - verifying).clamp(0, double.infinity))} still due', style: body(12, weight: FontWeight.w700, color: Colors.white)),
              if (verifying > 0) Text('${money(verifying)} verifying', style: body(12, weight: FontWeight.w600, color: C.brand100)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        SearchField(key: ValueKey(_search), hint: 'Search child by name or ID', onChanged: (v) => setState(() => q = v)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _FilterChip(label: 'All', count: rows.length, active: filter == null, onTap: () => setState(() => filter = null)),
            for (final s in const [FeeState.due, FeeState.partial, FeeState.verifying, FeeState.paid, FeeState.waiting, FeeState.running])
              if (count[s]! > 0 || filter == s) _FilterChip(label: s.label, count: count[s]!, tone: weekTone(s), active: filter == s, onTap: () => setState(() => filter = filter == s ? null : s)),
          ]),
        ),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No sessions in this week',
            hint: 'Bills are made from the sessions in the timetable and the attendance marked for them.',
            action: btn('Open timetable', icon: Icons.calendar_view_week_rounded, onPressed: () => context.push('/admin/timetable/$monday')),
          )
        else if (shown.isEmpty)
          EmptyState(
            icon: Icons.search_off_rounded,
            title: q.trim().isEmpty ? 'No children with this status' : 'No child matches "${q.trim()}"',
            action: btn('Show everyone', icon: Icons.close_rounded, onPressed: _clearSearch),
          ),
      ],
    );
  }
}

/// One child in the Outstanding list: what they owe in total and a chip for each unpaid week.
class _OwingRow extends StatelessWidget {
  final Child child;
  final ({Child child, double due, List<FeeWeek> weeks})? owing;
  final VoidCallback onTap;
  const _OwingRow({required this.child, required this.owing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final o = owing;
    final thisWeek = weekStart(todayISO());
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Avatar(child.name, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: NameWithId(child.name, child.code, style: body(14.5, weight: FontWeight.w600))),
                const SizedBox(width: 8),
                o == null
                    ? const StatusChip('Fully paid', tone: Tone.green)
                    : Text('${money(o.due)} due', style: body(14.5, weight: FontWeight.w800, color: C.clay600).copyWith(fontFeatures: tnum)),
              ]),
              if (o != null) ...[
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final w in o.weeks)
                    StatusChip(
                      '${w.monday == thisWeek ? 'This week' : 'Week of ${fmtDate(w.monday, 'd MMM')}'} · ${money(w.due)}${w.state == FeeState.partial ? ' left' : ''}',
                      tone: w.monday == thisWeek ? Tone.amber : Tone.red,
                      dot: false,
                    ),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Previous / next week, with a menu of recent weeks.
class WeekPicker extends StatelessWidget {
  final String monday;
  final ValueChanged<String> onChanged;
  const WeekPicker({super.key, required this.monday, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final thisWeek = weekStart(todayISO());
    final label = monday == thisWeek ? 'This week' : monday == addDays(thisWeek, -7) ? 'Last week' : 'Week of ${fmtDate(monday, 'd MMM')}';
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line), boxShadow: softShadow),
      child: Row(children: [
        IconButton(onPressed: monday.compareTo(addDays(thisWeek, -7 * AppStore.feeWeeksBack)) <= 0 ? null : () => onChanged(addDays(monday, -7)), icon: const Icon(Icons.chevron_left_rounded), tooltip: 'Previous week'),
        Expanded(
          child: Column(children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14.5, weight: FontWeight.w700)),
            Text(weekLabel(monday), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted).copyWith(fontFeatures: tnum)),
          ]),
        ),
        IconButton(onPressed: monday == thisWeek ? null : () => onChanged(addDays(monday, 7)), icon: const Icon(Icons.chevron_right_rounded), tooltip: 'Next week'),
      ]),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final Tone tone;
  final String text, action;
  final VoidCallback onTap;
  const _Banner({required this.icon, required this.tone, required this.text, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = toneColors(tone);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: c.bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(children: [
              Icon(icon, size: 19, color: c.fg),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: body(13, weight: FontWeight.w600, color: c.fg, height: 1.35))),
              TextButton(onPressed: onTap, style: TextButton.styleFrom(foregroundColor: c.fg), child: Text(action)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final Tone tone;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.count, required this.active, required this.onTap, this.tone = Tone.neutral});

  @override
  Widget build(BuildContext context) {
    final c = toneColors(tone);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: active,
        child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(color: active ? C.brand800 : Colors.white, borderRadius: BorderRadius.circular(99), border: Border.all(color: active ? C.brand800 : C.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (tone != Tone.neutral) ...[Container(width: 7, height: 7, decoration: BoxDecoration(color: c.fg, shape: BoxShape.circle)), const SizedBox(width: 6)],
            Text(label, style: body(13, weight: FontWeight.w700, color: active ? Colors.white : C.ink)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: active ? Colors.white.withValues(alpha: 0.18) : C.sand, borderRadius: BorderRadius.circular(99)),
              child: Text('$count', style: body(11, weight: FontWeight.w800, color: active ? Colors.white : C.muted)),
            ),
          ]),
        ),
        ),
      ),
    );
  }
}

class _FeeRow extends StatelessWidget {
  final Child child;
  final FeeWeek week;
  final VoidCallback onTap;
  const _FeeRow({required this.child, required this.week, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final w = week;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(children: [
          Avatar(child.name, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              NameWithId(child.name, child.code, style: body(14.5, weight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text('${w.attended} of ${w.allocated} sessions · ${money(w.amount)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted).copyWith(fontFeatures: tnum)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 130), child: StatusChip.fee(w.state)),
            if (w.due > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${money(w.due)} due', style: body(11.5, weight: FontWeight.w700, color: C.clay600))),
          ]),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// One child's weekly bills and payments, newest first.
class FeeDetailScreen extends StatelessWidget {
  final String childId;
  final String? week;
  const FeeDetailScreen(this.childId, {super.key, this.week});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final c = store.child(childId);
    if (c == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: EmptyState(icon: Icons.person_off_outlined, title: 'Child not found', hint: 'They may have been removed.', action: btn('Back to fees', icon: Icons.arrow_back_rounded, onPressed: () => context.go('/admin/fees'))),
        ),
      );
    }
    final bills = store.billsOf(c.id).where((w) => w.allocated > 0 || w.paid > 0 || w.verifying > 0).toList();
    final due = store.dueTotal(c.id);
    final unpaid = store.dueBills(c.id);
    final pays = store.paymentsOf(c.id).where((p) => p.status != PayStatus.cancelled).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Fee details')),
      body: PageList(
        onRefresh: store.refresh,
        children: [
          AppCard(
            onTap: () => context.push('/admin/children/${c.id}'),
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Avatar(c.name, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  NameWithId(c.name, c.code),
                  Text(c.therapies.map((t) => '${store.therapyName(t.therapyId)} ${money(store.rateOf(c.id, t.therapyId))}').join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted)),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: C.muted),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Text(due > 0 ? '${money(due)} due' : 'Nothing due', style: display(24, color: due > 0 ? C.clay600 : C.green).copyWith(fontFeatures: tnum))),
            if (due > 0) Text('${plural(unpaid.length, 'week')} unpaid', style: body(13, color: C.muted)),
          ]),
          if (unpaid.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final w in unpaid)
                StatusChip('${w.monday == weekStart(todayISO()) ? 'This week' : 'Week of ${fmtDate(w.monday, 'd MMM')}'} · ${money(w.due)}', tone: w.monday == weekStart(todayISO()) ? Tone.amber : Tone.red, dot: false),
            ]),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => showCollectSheet(context, c),
              icon: const Icon(Icons.add_card_rounded, size: 19),
              label: Text(unpaid.length == 1 ? 'Record payment' : 'Record payment · oldest weeks first'),
            ),
          ],
          const SizedBox(height: 16),
          const SectionTitle('Weekly bills'),
          if (bills.isEmpty)
            const EmptyState(icon: Icons.receipt_long_outlined, title: 'No bills yet', hint: 'Bills appear once sessions are scheduled.')
          else
            for (final w in bills)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: WeekBill(
                  w,
                  initiallyOpen: week == null ? w == bills.first || w.payable : w.monday == week,
                  footer: w.due > 0
                      ? Align(alignment: Alignment.centerLeft, child: btn('Record payment for this week', icon: Icons.add_card_rounded, kind: 'soft', onPressed: () => showPaymentSheet(context, c, w)))
                      : null,
                ),
              ),
          const SizedBox(height: 14),
          SectionTitle('Payments', hint: pays.isEmpty ? 'Nothing received yet' : plural(pays.length, 'payment')),
          if (pays.isNotEmpty)
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < pays.length; i++) ...[if (i > 0) const Divider(indent: 64), PaymentTile(pays[i], trailing: ReviewActions(pays[i]))],
              ]),
            ),
        ],
      ),
    );
  }
}

/// Confirm / reject a payment waiting for verification, or reverse a confirmed one that turns out to be invalid.
class ReviewActions extends StatelessWidget {
  final Payment payment;
  const ReviewActions(this.payment, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final store = context.read<AppStore>();
    Future<void> run(String action, String done, {String note = ''}) async {
      try {
        await store.reviewPayment(p, action, note: note);
        if (context.mounted) toast(context, done);
      } catch (e) {
        if (context.mounted) toast(context, cleanError(e), error: true);
      }
    }

    final small = TextButton.styleFrom(minimumSize: const Size(0, 44));
    // The family may still be in their UPI app: like [AppStore.paymentsToVerify], wait 30 minutes before asking.
    if (p.status == PayStatus.initiated && !store.paymentsToVerify.contains(p)) {
      return const Tooltip(message: 'The family started this UPI payment less than 30 minutes ago', child: StatusChip('In progress', tone: Tone.blue));
    }
    if (p.status == PayStatus.verifying || p.status == PayStatus.initiated) {
      return Wrap(spacing: 4, children: [
        TextButton.icon(
          style: small,
          icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
          label: const Text('Received'),
          onPressed: () async {
            final ok = await confirm(context,
                title: 'Confirm ${money(p.amount)}?',
                message: '${_matchHint(p)} Only confirm once you can see it in the centre\'s account. A receipt is issued to the family.',
                action: 'Confirm',
                danger: false);
            if (ok) await run('confirm', 'Payment confirmed');
          },
        ),
        TextButton.icon(
          style: small.copyWith(foregroundColor: const WidgetStatePropertyAll(C.red)),
          icon: const Icon(Icons.block_rounded, size: 18),
          label: const Text('Not received'),
          onPressed: () async {
            final note = await askNote(context, title: 'Not received?', hint: 'Tell the family why (optional)', action: 'Reject payment');
            if (note != null) await run('reject', 'Payment rejected; the week is due again', note: note);
          },
        ),
      ]);
    }
    if (p.status == PayStatus.confirmed && p.method == 'UPI') {
      return Wrap(spacing: 4, children: [
        if (p.unreconciled)
          TextButton.icon(
            style: small,
            icon: const Icon(Icons.verified_outlined, size: 18),
            label: const Text('Seen in bank'),
            onPressed: () async {
              final ok = await confirm(context,
                  title: 'Seen ${money(p.amount)} in the bank?',
                  message: '${_matchHint(p)} Tick it off once you have found it in the centre\'s account.',
                  action: 'Seen in bank',
                  danger: false);
              if (ok) await run('reconcile', 'Marked as seen in the bank');
            },
          ),
        TextButton.icon(
          style: small.copyWith(foregroundColor: const WidgetStatePropertyAll(C.muted)),
          icon: const Icon(Icons.undo_rounded, size: 18),
          label: const Text('Reverse'),
          onPressed: () async {
            final note = await askNote(context,
                title: 'Reverse this payment?',
                hint: 'Why? For example: not in the bank statement',
                action: 'Reverse',
                message: 'Use this if the money never reached the centre. The receipt stops working and the week becomes due again.',
                required: true);
            if (note != null) await run('reverse', 'Payment reversed', note: note);
          },
        ),
      ]);
    }
    return const SizedBox.shrink();
  }
}

/// How to find a UPI payment in the centre's bank or UPI app.
String _matchHint(Payment p) => [
      'Look for ${money(p.amount)}${p.payeeVpa == null ? '' : ' to ${p.payeeVpa}'}',
      if (p.utr != null) 'with UPI reference (UTR) ${p.utr},',
      if (p.utr == null && p.upiTxnId != null) 'with UPI transaction ID ${p.upiTxnId},',
      'or "${p.txnRef}" at the start of the note.',
    ].join(' ');

/// A short text answer in a dialog; null when cancelled.
Future<String?> askNote(BuildContext context, {required String title, required String hint, required String action, String? message, bool required = false}) =>
    showDialog<String>(context: context, builder: (_) => _NoteDialog(title: title, hint: hint, action: action, message: message, required: required));

/// The dialog owns its text controller, so it is disposed only after the exit animation stops rebuilding the field.
class _NoteDialog extends StatefulWidget {
  final String title, hint, action;
  final String? message;
  final bool required;
  const _NoteDialog({required this.title, required this.hint, required this.action, required this.message, required this.required});

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final c = TextEditingController();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title, style: display(21)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (widget.message != null) ...[Text(widget.message!, style: body(14, color: C.muted, height: 1.4)), const SizedBox(height: 12)],
          TextField(controller: c, autofocus: true, maxLength: 300, minLines: 1, maxLines: 3, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: widget.hint, counterText: '')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: widget.required && c.text.trim().isEmpty ? null : () => Navigator.pop(context, c.text.trim()), child: Text(widget.action)),
        ],
      );
}

// ---------------------------------------------------------------------------

/// Payments the admin has to check: UPI payments the app couldn't confirm (the parent gave a reference),
/// attempts left unfinished, and recent payments the UPI app confirmed, for a final look.
class PaymentsReviewScreen extends StatelessWidget {
  const PaymentsReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final waiting = store.paymentsToVerify;
    final unchecked = store.paymentsToReconcile;
    final recent = store.payments.where((p) => p.confirmed && p.verifiedBy == 'upi_app' && !p.unreconciled).take(20).toList();
    Widget group(List<Payment> list) => AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (var i = 0; i < list.length; i++) ...[
              if (i > 0) const Divider(indent: 64),
              PaymentTile(list[i], showChild: true, trailing: ReviewActions(list[i]), onTap: () => context.push('/admin/fees/${list[i].childId}?week=${list[i].monday}')),
            ],
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Verify payments')),
      body: PageList(
        onRefresh: store.refresh,
        children: [
          Text(
            'Before confirming, find the amount and UPI reference (UTR) in the centre\'s bank or UPI app. Confirming issues a receipt; rejecting makes the week due again.',
            style: body(13, color: C.muted, height: 1.45),
          ),
          const SizedBox(height: 16),
          SectionTitle('Waiting for you', hint: waiting.isEmpty ? null : plural(waiting.length, 'payment')),
          if (waiting.isEmpty) const EmptyState(icon: Icons.verified_rounded, title: 'All caught up', hint: 'Nothing is waiting for verification.') else group(waiting),
          const SizedBox(height: 22),
          SectionTitle('Check against the bank', hint: unchecked.isEmpty ? null : plural(unchecked.length, 'payment')),
          Text(
            'The family\'s UPI app said these were paid, so receipts were issued. Find each one in the centre\'s bank or UPI app '
            '(match the UTR, or the reference at the start of the note) and tick it off. Reverse any that never arrived.',
            style: body(12.5, color: C.muted, height: 1.45),
          ),
          const SizedBox(height: 10),
          if (unchecked.isEmpty) Text('Nothing to check.', style: body(13, color: C.muted)) else group(unchecked),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 22),
            const SectionTitle('Recently checked'),
            group(recent),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// The UPI IDs families pay to. One is active; payments already started keep the ID they were given, so
/// switching here never redirects or breaks a payment in progress.
class UpiSettingsScreen extends StatelessWidget {
  const UpiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final list = store.upiAccounts.where((a) => !a.archived).toList();
    final archived = store.upiAccounts.where((a) => a.archived).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('UPI IDs')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-upi',
        onPressed: () => showUpiSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add UPI ID'),
        backgroundColor: C.brand700,
        foregroundColor: Colors.white,
      ),
      body: PageList(
        onRefresh: store.refresh,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          Text('Families pay to the active UPI ID from their own UPI app (no gateway, no fees). Switching takes effect for new payments only.', style: body(13, color: C.muted, height: 1.45)),
          const SizedBox(height: 16),
          if (list.isEmpty)
            EmptyState(icon: Icons.qr_code_2_rounded, title: 'No UPI ID yet', hint: 'Add the centre\'s UPI ID, e.g. nuvara@okaxis, and the name shown to payers.', action: btn('Add UPI ID', icon: Icons.add_rounded, kind: 'filled', onPressed: () => showUpiSheet(context)))
          else
            for (final a in list) Padding(padding: const EdgeInsets.only(bottom: 10), child: _UpiCard(a)),
          if (archived.isNotEmpty) ...[
            const SizedBox(height: 14),
            const SectionTitle('Archived', hint: 'Kept because past payments went to them'),
            for (final a in archived) Padding(padding: const EdgeInsets.only(bottom: 10), child: Opacity(opacity: 0.6, child: _UpiCard(a))),
          ],
        ],
      ),
    );
  }
}

class _UpiCard extends StatelessWidget {
  final UpiAccount a;
  const _UpiCard(this.a);

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    Future<void> run(Future<void> Function() job, String done) async {
      try {
        await job();
        if (context.mounted) toast(context, done);
      } catch (e) {
        if (context.mounted) toast(context, cleanError(e), error: true);
      }
    }

    return AppCard(
      border: a.active ? C.brand400 : C.line,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconTile(Icons.qr_code_2_rounded, color: a.active ? C.brand700 : C.muted, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.vpa, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15, weight: FontWeight.w700)),
              Text([a.payeeName, a.kind.label, if (a.label.isNotEmpty) a.label].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, color: C.muted)),
            ]),
          ),
          if (a.active) const StatusChip('Active', tone: Tone.green) else if (a.archived) const StatusChip('Archived'),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (!a.active)
            btn('Make active', icon: Icons.check_circle_outline_rounded, kind: 'soft', onPressed: () async {
              final ok = await confirm(context, title: 'Receive payments on ${a.vpa}?', message: 'New payments will go to this UPI ID. Payments already in progress keep going to the ID they started with.', action: 'Make active', danger: false);
              if (ok) await run(() => store.setActiveUpi(a.id), '${a.vpa} is now active');
            }),
          btn('Edit', icon: Icons.edit_outlined, kind: 'text', onPressed: () => showUpiSheet(context, account: a)),
          if (!a.active && !a.archived)
            btn('Remove', icon: Icons.delete_outline_rounded, kind: 'text', onPressed: () async {
              final ok = await confirm(context, title: 'Remove ${a.vpa}?', message: 'If it has received payments it is archived instead, so their records stay complete.', action: 'Remove');
              if (ok) await run(() => store.removeUpiAccount(a), 'UPI ID removed');
            }),
        ]),
      ]),
    );
  }
}

Future<void> showUpiSheet(BuildContext context, {UpiAccount? account}) => showSheet(context, builder: (_) => _UpiSheet(account));

class _UpiSheet extends StatefulWidget {
  final UpiAccount? account;
  const _UpiSheet(this.account);

  @override
  State<_UpiSheet> createState() => _UpiSheetState();
}

class _UpiSheetState extends State<_UpiSheet> {
  late final vpa = TextEditingController(text: widget.account?.vpa ?? '');
  late final name = TextEditingController(text: widget.account?.payeeName ?? 'Nuvara');
  late final label = TextEditingController(text: widget.account?.label ?? '');
  late final mcc = TextEditingController(text: widget.account?.merchantCode ?? '');
  late UpiKind kind = widget.account?.kind ?? UpiKind.personal;
  bool tried = false;

  @override
  void dispose() {
    vpa.dispose();
    name.dispose();
    label.dispose();
    mcc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final a = widget.account;
    final vpaErr = tried && !validVpa(vpa.text) ? 'Enter a UPI ID like centre@okaxis' : null;
    final nameErr = tried && name.text.trim().isEmpty ? 'Enter the name payers see' : null;
    final mccOk = kind != UpiKind.merchant || mcc.text.trim().isEmpty || validMcc(mcc.text);
    final mccErr = tried && !mccOk ? '4 digits, e.g. 8099' : null;
    return SheetBody(
      title: a == null ? 'Add UPI ID' : 'Edit UPI ID',
      subtitle: a == null && store.activeUpi == null ? 'It becomes the active one' : null,
      footer: [
        btn('Cancel', onPressed: () => Navigator.pop(context)),
        ActionButton('Save', icon: Icons.check_rounded, onPressed: () async {
          setState(() => tried = true);
          if (!validVpa(vpa.text) || name.text.trim().isEmpty || !mccOk) throw Exception('Fill in the highlighted fields.');
          final nav = Navigator.of(context);
          await store.saveUpiAccount(id: a?.id, vpa: vpa.text, payeeName: name.text, label: label.text, kind: kind, merchantCode: mcc.text);
          nav.pop();
          return a == null ? 'UPI ID added' : 'UPI ID updated';
        }),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Field('UPI ID', child: TextField(controller: vpa, autocorrect: false, keyboardType: TextInputType.emailAddress, style: body(15), onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: 'centre@okaxis', errorText: vpaErr))),
        const SizedBox(height: 14),
        Field('Name shown to payers', child: TextField(controller: name, textCapitalization: TextCapitalization.words, style: body(15), onChanged: (_) => setState(() {}), decoration: InputDecoration(errorText: nameErr))),
        const SizedBox(height: 14),
        Field('Label', optional: true, child: TextField(controller: label, style: body(15), decoration: const InputDecoration(hintText: 'e.g. HDFC current account'))),
        const SizedBox(height: 20),
        const Overline('Type of UPI ID'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in UpiKind.values) TogglePill(k.label, active: kind == k, onTap: () => setState(() => kind = k)),
        ]),
        const SizedBox(height: 8),
        Text(
          kind == UpiKind.personal
              ? 'An ordinary UPI ID from GPay, PhonePe, BHIM, Paytm or a bank app. Families pay it like sending money to a person.'
              : 'A business UPI ID from a merchant/business app or a bank\'s merchant service (it shows as a verified business when paid). '
                  'Payments carry this payment\'s reference, so they match exactly. Choosing this for a personal UPI ID makes payments fail.',
          style: body(12, color: C.muted, height: 1.4),
        ),
        if (kind == UpiKind.merchant) ...[
          const SizedBox(height: 14),
          Field(
            'Merchant category code',
            optional: true,
            child: TextField(
              controller: mcc,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              style: body(15),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: 'From your bank, e.g. 8099', errorText: mccErr),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text('Use a UPI ID linked to the centre\'s bank account. Test it with a ₹1 payment before making it active.', style: body(12, color: C.muted, height: 1.4)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------

Future<void> showPaymentSheet(BuildContext context, Child child, FeeWeek week) => showSheet(context, builder: (_) => _PaymentSheet(child: child, week: week));

/// Money received at the centre (cash, bank transfer, ...) for one week.
class _PaymentSheet extends StatefulWidget {
  final Child child;
  final FeeWeek week;
  const _PaymentSheet({required this.child, required this.week});

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  static const methods = ['Cash', 'UPI', 'Card', 'Bank transfer', 'Cheque'];
  late final amount = TextEditingController(text: fmtPlain(_remaining(context.read<AppStore>())));
  final note = TextEditingController();
  String method = 'Cash';
  String paidOn = todayISO();

  double _remaining(AppStore store) => store.bill(widget.child.id, widget.week.monday)?.due ?? widget.week.due;

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final remaining = _remaining(store);
    final value = parseMoney(amount.text);
    final error = value == null || value <= 0 ? 'Enter an amount' : (value > remaining + 0.001 ? 'Only ${money(remaining)} is due' : null);
    final after = value == null ? remaining : remaining - value;
    return SheetBody(
      title: 'Record payment',
      subtitle: '${widget.child.name} · week of ${fmtDate(widget.week.monday, 'd MMM')}',
      footer: [
        btn('Cancel', onPressed: () => Navigator.pop(context)),
        ActionButton('Save payment', icon: Icons.check_rounded, onPressed: error != null
            ? null
            : () async {
                final nav = Navigator.of(context);
                await store.recordPayment(childId: widget.child.id, monday: widget.week.monday, amount: value!, method: method, note: note.text, paidOn: paidOn);
                nav.pop();
                return '${money(value)} recorded';
              }),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Field('Amount', child: MoneyField(controller: amount, autofocus: true, error: amount.text.isEmpty ? null : error, onChanged: (_) => setState(() {}))),
        if (error == null) ...[
          const SizedBox(height: 8),
          Text(after <= 0.005 ? 'This settles the week in full.' : '${money(after)} will still be due.', style: body(12.5, weight: FontWeight.w600, color: after <= 0.005 ? C.green : C.amber)),
        ],
        const SizedBox(height: 20),
        const Overline('Paid by'),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final m in methods) TogglePill(m, active: method == m, onTap: () => setState(() => method = m))]),
        const SizedBox(height: 20),
        Field(
          'Date received',
          child: PickerField(
            text: fmtDate(paidOn, 'EEE, d MMM yyyy'),
            icon: Icons.calendar_today_rounded,
            onTap: () async {
              final d = await pickDate(context, initial: paidOn, last: DateTime.now());
              if (d != null) setState(() => paidOn = d);
            },
          ),
        ),
        const SizedBox(height: 16),
        Field('Note', optional: true, child: TextField(controller: note, style: body(15), decoration: const InputDecoration(hintText: 'e.g. cheque number'))),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------

Future<void> showCollectSheet(BuildContext context, Child child) => showSheet(context, builder: (_) => _CollectSheet(child: child));

/// Money received for a child, any time: it settles their oldest unpaid weeks first, this week included.
class _CollectSheet extends StatefulWidget {
  final Child child;
  const _CollectSheet({required this.child});

  @override
  State<_CollectSheet> createState() => _CollectSheetState();
}

class _CollectSheetState extends State<_CollectSheet> {
  late final amount = TextEditingController(text: fmtPlain(context.read<AppStore>().dueTotal(widget.child.id)));
  final note = TextEditingController();
  String method = 'Cash';
  String paidOn = todayISO();

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final weeks = store.dueBills(widget.child.id);
    final total = weeks.fold(0.0, (a, w) => a + w.due);
    final value = parseMoney(amount.text);
    final error = value == null || value <= 0 ? 'Enter an amount' : (value > total + 0.001 ? 'Only ${money(total)} is due' : null);
    // How the amount is split, oldest week first (the database does the same).
    var left = value ?? 0;
    final split = <({FeeWeek week, double part})>[];
    for (final w in weeks) {
      if (left <= 0.005) break;
      final part = left < w.due ? left : w.due;
      split.add((week: w, part: part));
      left -= part;
    }
    return SheetBody(
      title: 'Record payment',
      subtitle: '${widget.child.name} · ${money(total)} due',
      footer: [
        btn('Cancel', onPressed: () => Navigator.pop(context)),
        ActionButton('Save payment', icon: Icons.check_rounded, onPressed: error != null
            ? null
            : () async {
                final nav = Navigator.of(context);
                final n = await store.recordChildPayment(childId: widget.child.id, amount: value!, method: method, note: note.text, paidOn: paidOn);
                nav.pop();
                return '${money(value)} recorded${n > 1 ? ' across ${plural(n, 'week')}' : ''}';
              }),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Field('Amount', child: MoneyField(controller: amount, autofocus: true, error: amount.text.isEmpty ? null : error, onChanged: (_) => setState(() {}))),
        if (error == null && split.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final x in split)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Icon(x.part >= x.week.due - 0.005 ? Icons.check_circle_rounded : Icons.timelapse_rounded, size: 16, color: x.part >= x.week.due - 0.005 ? C.green : C.amber),
                const SizedBox(width: 8),
                Expanded(child: Text(x.week.monday == weekStart(todayISO()) ? 'This week (so far)' : 'Week of ${fmtDate(x.week.monday, 'd MMM')}', style: body(13))),
                Text(x.part >= x.week.due - 0.005 ? money(x.part) : '${money(x.part)} of ${money(x.week.due)}', style: body(13, weight: FontWeight.w700).copyWith(fontFeatures: tnum)),
              ]),
            ),
          const SizedBox(height: 4),
          Text(total - (value ?? 0) <= 0.005 ? 'This settles everything due.' : '${money(total - value!)} will still be due.', style: body(12.5, weight: FontWeight.w600, color: total - (value ?? 0) <= 0.005 ? C.green : C.amber)),
        ],
        const SizedBox(height: 20),
        const Overline('Paid by'),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final m in _PaymentSheetState.methods) TogglePill(m, active: method == m, onTap: () => setState(() => method = m))]),
        const SizedBox(height: 20),
        Field(
          'Date received',
          child: PickerField(
            text: fmtDate(paidOn, 'EEE, d MMM yyyy'),
            icon: Icons.calendar_today_rounded,
            onTap: () async {
              final d = await pickDate(context, initial: paidOn, last: DateTime.now());
              if (d != null) setState(() => paidOn = d);
            },
          ),
        ),
        const SizedBox(height: 16),
        Field('Note', optional: true, child: TextField(controller: note, style: body(15), decoration: const InputDecoration(hintText: 'e.g. cheque number'))),
      ]),
    );
  }
}
