import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/auth/session_provider.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/localization/l10n_ext.dart';
import '../../core/navigation/app_routes.dart';
import '../../shared/widgets/digital_id_card.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/student_switcher.dart';
import '../parent/parent_store.dart';
import '../fees/fees_screen.dart';
import '../../shared/models/fees.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final student = ref.watch(currentStudentProvider);
    final school = ref.watch(currentSchoolProvider);
    final locale = ref.watch(localeProvider);
    final fees = ref.watch(studentFeesProvider);

    if (student == null || school == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabProfile),
        actions: [
          _LanguageToggle(
            currentLocale: locale,
            onChanged: (v) => ref.read(localeProvider.notifier).state = v,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: l10n.signOut,
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.signOutConfirmTitle),
                  content: Text(l10n.signOutConfirmBody),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.signOut)),
                  ],
                ),
              );
              if (ok == true) ref.read(sessionProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 108),
          children: [
            const StudentSwitcherHeader(),
            const SizedBox(height: AppSpacing.md),
            DigitalStudentIdCard(
              student: student,
              school: school,
              onTap: () => showDialog(
                context: context,
                builder: (context) => DigitalStudentIdCard(
                  student: student,
                  school: school,
                  expanded: true,
                ),
              ),
            ),
            
            if (fees != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _ProfileFeeCard(fees: fees),
            ],

            const SizedBox(height: AppSpacing.lg),
            Text(l10n.studentInformation, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            PremiumCard(
              child: Column(
                children: [
                  _row(context, l10n.schoolIdentity, school.name),
                  _row(context, l10n.admissionNo, student.admissionNo),
                  if (student.rollNo.isNotEmpty) _row(context, l10n.rollNo, student.rollNo),
                  _row(context, l10n.classLabelTitle, student.classLabel),
                  if (student.classTeacher != null) _row(context, l10n.classTeacher, student.classTeacher!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String k, String v) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(k, style: theme.textTheme.bodySmall)),
          Flexible(child: Text(v, style: theme.textTheme.titleSmall, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  final Locale currentLocale;
  final ValueChanged<Locale> onChanged;

  const _LanguageToggle({required this.currentLocale, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isTamil = currentLocale.languageCode == 'ta';
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleItem(
            label: 'EN',
            selected: !isTamil,
            onTap: () => onChanged(const Locale('en')),
          ),
          _ToggleItem(
            label: 'தமிழ்',
            selected: isTamil,
            onTap: () => onChanged(const Locale('ta')),
          ),
        ],
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleItem({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ProfileFeeCard extends StatelessWidget {
  final FeeAccount fees;

  const _ProfileFeeCard({required this.fees});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.schoolFees, style: theme.textTheme.titleMedium),
              const Spacer(),
              if (!fees.hasDue)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    l10n.feesPaid,
                    style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _feeItem(l10n.totalFees, currencyFormat.format(fees.total)),
              _feeItem(l10n.amountPaid, currencyFormat.format(fees.paid), color: Colors.green),
              _feeItem(l10n.amountDue, currencyFormat.format(fees.remaining), color: fees.hasDue ? Colors.red : null),
            ],
          ),
          if (fees.hasDue) ...[
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () => AppRoutes.push(context, const FeesScreen()),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.payNow),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => AppRoutes.push(context, const FeesScreen()),
              child: Center(child: Text(l10n.viewDetails)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _feeItem(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
