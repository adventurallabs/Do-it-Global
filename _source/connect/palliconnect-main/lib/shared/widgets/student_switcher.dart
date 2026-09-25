import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/account_store.dart';
import '../../core/auth/session_provider.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_motion.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/localization/l10n_ext.dart';
import '../../core/navigation/app_routes.dart';
import '../../features/auth/login_screen.dart';
import '../models/student.dart';
import 'student_avatar.dart';

class StudentSwitcherHeader extends ConsumerWidget {
  const StudentSwitcherHeader({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final student = ref.watch(currentStudentProvider);
    if (student == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => showStudentSwitcher(context),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xs,
          horizontal: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.55),
          border: Border.all(
            color: AppColors.skyBlue.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          children: [
            StudentAvatar(student: student, radius: compact ? 16 : 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AnimatedSwitcher(
                duration: AppMotion.fast,
                // Fade *through*: the old child's name is gone before the new
                // one appears, so the two never print over each other.
                switchInCurve: const Interval(0.5, 1, curve: Curves.easeOut),
                switchOutCurve: const Interval(0.5, 1, curve: Curves.easeIn),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.centerLeft,
                  children: [...previous, ?current],
                ),
                child: Column(
                  key: ValueKey(student.id),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            student.fullName,
                            style: compact
                                ? theme.textTheme.titleSmall
                                : theme.textTheme.titleLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_down, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      ],
                    ),
                    Text(student.classLabel, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showStudentSwitcher(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const StudentSwitcherSheet(),
  );
}

/// Instagram-style account switching: lists every register-number login
/// saved on this device (not just the current child) and swaps the active
/// Supabase session without asking for a password again.
class StudentSwitcherSheet extends ConsumerStatefulWidget {
  const StudentSwitcherSheet({super.key});

  @override
  ConsumerState<StudentSwitcherSheet> createState() => _StudentSwitcherSheetState();
}

class _StudentSwitcherSheetState extends ConsumerState<StudentSwitcherSheet> {
  late Future<List<SavedAccount>> _accounts;

  @override
  void initState() {
    super.initState();
    _accounts = ref.read(sessionProvider.notifier).savedAccounts();
  }

  Future<void> _switch(SavedAccount account) async {
    final error = await ref.read(sessionProvider.notifier).switchToAccount(account);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      setState(() => _accounts = ref.read(sessionProvider.notifier).savedAccounts());
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = ref.watch(currentStudentProvider);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.switchStudent, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            FutureBuilder<List<SavedAccount>>(
              future: _accounts,
              builder: (context, snapshot) {
                final accounts = snapshot.data ?? const [];
                if (accounts.isEmpty && current != null) {
                  return _StudentTile(student: current, selected: true, onTap: () {});
                }
                return Column(
                  children: accounts
                      .map((a) => _AccountTile(
                            account: a,
                            selected: current?.admissionNo == a.registerNumber,
                            onTap: () => _switch(a),
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(Icons.add, color: theme.colorScheme.primary),
              ),
              title: Text(l10n.addStudent, style: theme.textTheme.titleMedium),
              onTap: () {
                Navigator.pop(context);
                AppRoutes.push(context, const LoginScreen());
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final SavedAccount account;
  final bool selected;
  final VoidCallback onTap;

  const _AccountTile({required this.account, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
        child: Text(account.studentName.isNotEmpty ? account.studentName[0].toUpperCase() : '?'),
      ),
      title: Text(account.studentName, style: theme.textTheme.titleMedium),
      subtitle: Text('Reg: ${account.registerNumber}', style: theme.textTheme.bodySmall),
      trailing: selected
          ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
          : const SizedBox(width: 24),
    );
  }
}

class _StudentTile extends StatelessWidget {
  final Student student;
  final bool selected;
  final VoidCallback onTap;

  const _StudentTile({
    required this.student,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: StudentAvatar(student: student, radius: 22),
      title: Text(student.fullName, style: theme.textTheme.titleMedium),
      subtitle: Text(student.classLabel, style: theme.textTheme.bodySmall),
      trailing: selected
          ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
          : const SizedBox(width: 24),
    );
  }
}
