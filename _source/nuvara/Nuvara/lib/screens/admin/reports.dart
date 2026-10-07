import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/ui.dart';
import 'sessions.dart' show showSessionSheet;

/// Session reports still to be written: every attended session whose therapist hasn't rated it yet,
/// grouped by therapist, oldest first. Only therapists write reports; from here the admin can see who is
/// behind and message them.
class PendingReportsScreen extends StatelessWidget {
  const PendingReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final byTherapist = <String, List<PendingReport>>{};
    for (final r in store.pendingReports) {
      (byTherapist[r.therapistId] ??= []).add(r);
    }
    final groups = byTherapist.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
    return Scaffold(
      appBar: AppBar(title: const Text('Pending reports')),
      body: PageList(
        onRefresh: store.refresh,
        children: [
          Text(
            'After each session a child attends, the therapist rates how it went (0–10) and writes a few words. '
            'Parents see these on their child\'s progress. These sessions are still waiting for that report.',
            style: body(13, color: C.muted, height: 1.45),
          ),
          const SizedBox(height: 16),
          if (groups.isEmpty)
            const EmptyState(icon: Icons.verified_rounded, title: 'All reports are in', hint: 'Every attended session has its report.')
          else
            for (final g in groups) ...[
              _TherapistGroup(therapistId: g.key, reports: g.value),
              const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }
}

class _TherapistGroup extends StatelessWidget {
  final String therapistId;
  final List<PendingReport> reports;
  const _TherapistGroup({required this.therapistId, required this.reports});

  Future<void> _open(BuildContext context, PendingReport r) async {
    final store = context.read<AppStore>();
    try {
      await store.loadWeek(weekStart(r.date));
    } catch (e) {
      if (context.mounted) toast(context, cleanError(e), error: true);
      return;
    }
    if (context.mounted) showSessionSheet(context, r.sessionId);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final t = store.therapist(therapistId);
    final oldest = reports.first.date;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
          child: Row(children: [
            Avatar(t?.name ?? '?', size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                NameWithId(t?.name ?? 'Therapist', t?.code ?? '', style: body(14.5, weight: FontWeight.w700)),
                Text('${plural(reports.length, 'report')} pending · oldest ${const {'Today', 'Yesterday'}.contains(relDay(oldest)) ? relDay(oldest).toLowerCase() : relDay(oldest)}', style: body(12, color: C.amber, weight: FontWeight.w600)),
              ]),
            ),
            IconButton(
              tooltip: 'Message ${t?.first ?? 'therapist'}',
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              onPressed: () => context.push('/admin/messages/therapists/$therapistId'),
            ),
          ]),
        ),
        const Divider(height: 1),
        for (var i = 0; i < reports.length && i < 8; i++) ...[
          if (i > 0) const Divider(indent: 14, endIndent: 14),
          InkWell(
            onTap: () => _open(context, reports[i]),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              child: Row(children: [
                SizedBox(width: 76, child: Text(fmtDate(reports[i].date, 'EEE, d MMM'), style: body(12, weight: FontWeight.w800))),
                Expanded(
                  child: Text(
                    '${store.child(reports[i].childId)?.name ?? 'Child'} · ${reports[i].sessionName} · ${fmtTime(reports[i].start)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(13),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 18, color: C.muted),
              ]),
            ),
          ),
        ],
        if (reports.length > 8) Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 12), child: Text('and ${reports.length - 8} more', style: body(12, color: C.muted))),
      ]),
    );
  }
}
