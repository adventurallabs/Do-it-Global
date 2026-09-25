import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/session_provider.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/localization/l10n_ext.dart';
import '../../shared/widgets/branded_logo.dart';
import '../../shared/widgets/premium_card.dart';

/// Register number + password — the only way into PalliConnect. There is no
/// demo/guest mode: every screen behind this one reads real school data.
///
/// Sits on the same BrandAtmosphere as the rest of the app; the badge flies
/// in from the splash and the rest settles in with a short stagger.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _regC = TextEditingController();
  final _passwordC = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();

  @override
  void dispose() {
    _intro.dispose();
    _regC.dispose();
    _passwordC.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    FocusScope.of(context).unfocus();
    if (_regC.text.trim().isEmpty || _passwordC.text.isEmpty) {
      setState(() => _error = context.l10n.enterRegisterAndPassword);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await ref.read(sessionProvider.notifier).signIn(_regC.text, _passwordC.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });
  }

  Widget _stagger(int i, Widget child) {
    final a = CurvedAnimation(
      parent: _intro,
      curve: Interval((i * 0.15).clamp(0, 0.6), (0.45 + i * 0.15).clamp(0, 1), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: a,
      builder: (context, c) => Opacity(
        opacity: a.value,
        child: Transform.translate(offset: Offset(0, 18 * (1 - a.value)), child: c),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Scaffold(
      // transparent: the app-wide BrandAtmosphere shows through, exactly like
      // every screen after login
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrandedLogo(size: 92, heroTag: BrandedLogo.heroTagSplash),
                    const SizedBox(height: AppSpacing.md),
                    _stagger(
                      0,
                      Column(
                        children: [
                          const BrandWordmark(fontSize: 28),
                          const SizedBox(height: 6),
                          Text(
                            l10n.appTagline,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _stagger(
                      1,
                      PremiumCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(l10n.parentLogin, style: theme.textTheme.titleLarge),
                            const SizedBox(height: 4),
                            Text(l10n.parentLoginHelp, style: theme.textTheme.bodySmall),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _regC,
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username],
                              onSubmitted: (_) => _passwordFocus.requestFocus(),
                              decoration: InputDecoration(
                                labelText: l10n.registerNumber,
                                prefixIcon: const Icon(Icons.badge_outlined),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _passwordC,
                              focusNode: _passwordFocus,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onSubmitted: (_) => _loading ? null : _onSubmit(),
                              decoration: InputDecoration(
                                labelText: l10n.passwordLabel,
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _obscure ? l10n.showPassword : l10n.hidePassword,
                                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _error == null
                                  ? const SizedBox(height: 20, width: double.infinity)
                                  : Container(
                                      key: ValueKey(_error),
                                      width: double.infinity,
                                      margin: const EdgeInsets.symmetric(vertical: 14),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.error),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _error!,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: AppColors.error,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                            FilledButton(
                              onPressed: _loading ? null : _onSubmit,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                ),
                              ),
                              child: _loading
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(l10n.signingIn),
                                      ],
                                    )
                                  : Text(l10n.loginButton),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
