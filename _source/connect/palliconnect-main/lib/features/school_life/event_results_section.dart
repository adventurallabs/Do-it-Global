import 'package:event_certificates/event_certificates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../shared/models/event_result.dart';
import '../../shared/widgets/premium_card.dart';
import '../../core/auth/session_provider.dart';
import 'school_life_providers.dart';

/// How the child did, and the button that makes their certificate.
///
/// Nothing is downloaded from the school: the certificate is drawn here, on
/// this phone, from the result and the layout the school chose. That is why
/// it can be fetched again any time without the school storing a file for
/// every child.
class EventResultsSection extends ConsumerWidget {
  const EventResultsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(childEventResultsProvider).valueOrNull ?? const [];
    if (results.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSpacing.sm),
          child: Text(
            'Event results',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        for (final r in results)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _ResultCard(result: r),
          ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _ResultCard extends ConsumerStatefulWidget {
  final ChildEventResult result;
  const _ResultCard({required this.result});

  @override
  ConsumerState<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends ConsumerState<_ResultCard> {
  bool _busy = false;

  Future<void> _download() async {
    final r = widget.result;
    setState(() => _busy = true);
    try {
      final school = ref.read(currentSchoolProvider);
      final student = ref.read(currentStudentProvider);
      final logo = await loadSchoolLogo(school?.logoUrl ?? '');
      final data = CertificateData(
        schoolName: school?.name ?? '',
        schoolLogo: logo,
        eventName: r.eventName,
        categoryName: r.categoryName,
        roomName: r.roomName,
        studentName: student?.fullName.trim() ?? '',
        // The class they represented on the day, falling back to the one they
        // are in now if the lookup was not readable.
        classLabel: r.classLabel.isNotEmpty
            ? r.classLabel
            : [student?.className ?? '', student?.sectionName ?? '']
                .where((s) => s.trim().isNotEmpty)
                .join(' '),
        tier: r.isWinner ? CertificateTier.winner : CertificateTier.runner,
        position: r.position,
        awardedOn: r.submittedAt ?? r.eventDate,
      );
      final bytes = await buildCertificatePdf(
        layout: layoutById(r.certificateLayoutId),
        data: data,
      );
      await shareCertificate(bytes: bytes, fileName: data.suggestedFileName);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text("Couldn't make the certificate. Please try again."),
          ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final theme = Theme.of(context);
    final medal = switch (r.position) {
      1 => const Color(0xFFC9A227),
      2 => const Color(0xFFA8B3BD),
      3 => const Color(0xFFC08552),
      _ => AppColors.defaultAccent,
    };
    return PremiumCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: medal.withValues(alpha: r.isWinner ? 0.18 : 0.10),
                    shape: BoxShape.circle,
                    border: Border.all(color: medal.withValues(alpha: 0.45), width: 1.3),
                  ),
                  child: r.isWinner
                      ? Text(r.ordinal,
                          style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w900, color: medal))
                      : Icon(Icons.military_tech_outlined, size: 22, color: medal),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.categoryName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        '${r.eventName}${r.roomName.isEmpty ? '' : ' · ${r.roomName}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: medal.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                r.isWinner
                    ? 'Winner · ${r.placeLabel} of ${r.prizeCount}'
                    : '${r.placeLabel} · took part',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700, color: medal),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (r.hasCertificate)
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _download,
                  icon: _busy
                      ? const SizedBox(
                          width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_rounded, size: 19),
                  label: Text(_busy ? 'Preparing…' : 'Download certificate'),
                ),
              )
            else
              Text(
                'The school has not released certificates for this yet.',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
