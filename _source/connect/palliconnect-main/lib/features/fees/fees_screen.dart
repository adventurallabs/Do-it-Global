import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/auth/session_provider.dart';
import '../../core/data/parent_repository.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/localization/l10n_ext.dart';
import '../../core/utils/formatters.dart';
import '../../shared/models/fees.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/status_badge.dart';
import '../parent/parent_store.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class FeesScreen extends ConsumerStatefulWidget {
  const FeesScreen({super.key});

  @override
  ConsumerState<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends ConsumerState<FeesScreen> {
  late Razorpay _razorpay;
  double _lastAmount = 0;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final student = ref.read(currentStudentProvider);
    var recorded = false;
    if (student != null) {
      try {
        await ref.read(parentRepositoryProvider).recordOnlinePayment(
              studentId: student.id,
              amountInr: _lastAmount.round(),
              razorpayOrderId: response.orderId,
              razorpayPaymentId: response.paymentId,
            );
        await ref.read(sessionProvider.notifier).refresh();
        recorded = true;
      } catch (_) {}
    }
    if (!mounted) return;
    // The Razorpay charge itself already succeeded either way — never tell
    // the parent it failed. But if recordOnlinePayment didn't make it into
    // our own ledger, silently saying "Payment successful" would hide a real
    // money-tracking gap: the school's records wouldn't reflect a payment
    // the parent genuinely made. Give them the payment id as proof instead.
    if (recorded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment successful')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(
            'Payment received, but we couldn\'t update your fee record. '
            'Please contact the school office with payment ID ${response.paymentId ?? "(unavailable)"} to confirm.',
          ),
        ),
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: ${response.message ?? 'try again'}')),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {}

  void _startPayment(double amount) {
    _lastAmount = amount;
    // A real deployment creates the order via a Supabase Edge Function and
    // passes order_id here. Test key works for the client-only demo flow.
    final key = dotenv.maybeGet('RAZORPAY_KEY_ID') ?? 'rzp_test_1DP5mmOlF5G5ag';
    var options = {
      'key': key,
      'amount': (amount * 100).toInt(),
      'name': 'Greenwood International',
      'description': 'School Fees Payment',
      'prefill': {'contact': '9876543210', 'email': 'parent@example.com'},
      'external': {
        'wallets': ['paytm']
      }
    };
    _razorpay.open(options);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final account = ref.watch(studentFeesProvider);
    final year = ref.watch(currentStudentProvider)?.academicYear ?? '';
    
    if (account == null) {
      // Null while still loading, or genuinely no fee ledger/payments set up
      // for this student yet — either way an empty state reads correctly,
      // unlike a bare Scaffold that just looks broken.
      return Scaffold(
        appBar: AppBar(title: Text(l10n.feeDue)),
        body: AppEmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'No fee records yet',
          body: "The school hasn't set up fee details for this student yet.",
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.feeDue)),
      body: SafeArea(
        child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('${l10n.academicYear}: $year', style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          PremiumCard(
            child: Column(
              children: [
                _kv(context, l10n.total, formatInr(account.total)),
                _kv(context, l10n.paid, formatInr(account.paid)),
                const Divider(),
                _kv(context, l10n.remainingBalance, formatInr(account.remaining), emphasize: true),
                if (account.history.any((p) => p.status == PaymentStatus.pending)) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.warningSoft,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_bottom_rounded,
                            size: 16, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'A payment is awaiting confirmation from the school.',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.warning),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (account.remaining > 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _startPayment(account.remaining.toDouble()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                      ),
                      child: const Text('Pay Now'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...account.categories.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: PremiumCard(
                child: Row(
                  children: [
                    Expanded(child: Text(_categoryName(context, c.nameKey), style: theme.textTheme.titleMedium)),
                    Text('${formatInr(c.paid)} / ${formatInr(c.total)}', style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ),
          SectionHeader(title: l10n.paymentHistory),
          ...account.history.map((p) => _PaymentTile(record: p)),
        ],
        ),
      ),
    );
  }

  String _categoryName(BuildContext context, String key) {
    final l10n = context.l10n;
    return switch (key) {
      'tuition' => l10n.tuitionFee,
      'transport' => l10n.transportFee,
      'activity' => l10n.activityFee,
      _ => l10n.otherFees,
    };
  }

  Widget _kv(BuildContext context, String k, String v, {bool emphasize = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(k, style: theme.textTheme.bodyLarge)),
          Text(
            v,
            style: emphasize ? theme.textTheme.titleLarge : theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final PaymentRecord record;
  const _PaymentTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final (label, color, bg) = switch (record.status) {
      PaymentStatus.paid => (l10n.paymentSuccessful, AppColors.success, AppColors.successSoft),
      PaymentStatus.pending => (l10n.paymentPending, AppColors.warning, AppColors.warningSoft),
      PaymentStatus.processing => (l10n.paymentProcessing, AppColors.info, AppColors.infoSoft),
      PaymentStatus.failed => (l10n.paymentFailed, AppColors.error, AppColors.errorSoft),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PremiumCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat.yMMMd().format(record.date), style: theme.textTheme.titleMedium),
                  Text(formatInr(record.amount), style: theme.textTheme.headlineSmall),
                  if (record.status == PaymentStatus.paid)
                    Text('${l10n.receipt} ${record.receiptId}', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            StatusBadge(label: label, color: color, background: bg),
          ],
        ),
      ),
    );
  }
}
