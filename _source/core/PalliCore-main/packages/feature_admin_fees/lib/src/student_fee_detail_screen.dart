import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'fee_bloc.dart';
import 'fee_status_style.dart';

class StudentFeeDetailScreen extends StatelessWidget {
  final String studentId;

  const StudentFeeDetailScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FeeBloc, FeeState>(
      builder: (context, state) {
        if (state is FeeError) {
          return Scaffold(
            body: EmptyState(
              icon: Icons.cloud_off_rounded,
              title: "Couldn't load fees",
              subtitle: 'Check your connection and try again.',
              actionLabel: 'Retry',
              onAction: () => context.read<FeeBloc>().add(LoadFees()),
            ),
          );
        }
        if (state is! FeesLoaded) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final student = state.studentById(studentId);
        if (student == null) {
          return const Scaffold(body: Center(child: Text('Student not found')));
        }
        final classroom = state.classroomById(student.classroomId);
        final ledger = state.ledgerFor(student.id);
        return Scaffold(
          appBar: AppBar(title: Text(student.name)),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _recordPayment(context, student, ledger, state.events),
            icon: const Icon(Icons.add_card_rounded),
            label: const Text('Record payment'),
            shape: const StadiumBorder(),
          ),
          body: SafeArea(
            child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(20),
      child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            student.name,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                        ),
                        StatusPill(
                          label: ledger.statusLabel,
                          color: feeStatusColor(ledger.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Roll ${student.rollNumber} · ${classroom?.displayName ?? 'Unassigned'}',
                      style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Parents: ${student.fatherName} / ${student.motherName}',
                      style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 12),
                    ),
                    Text(
                      'Contact: ${student.contactNumber}',
                      style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 12),
                    ),
                    const SizedBox(height: 18),
                    _amountRow(context, 'Annual tuition', ledger.tuitionPaid, ledger.tuitionDue),
                    _amountRow(context, 'Event fees', ledger.eventPaid, ledger.eventDue),
                    const Divider(color: AppColors.divider),
                    _amountRow(context, 'Overall', ledger.totalPaid, ledger.totalDue, emphasize: true),
                    const SizedBox(height: 8),
                    Text(
                      'Balance ₹${ledger.totalBalance.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: ledger.totalBalance <= 0 ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Payment history',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 10),
              if (ledger.payments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('No payments recorded yet.', style: TextStyle(color: AppColors.onSurfaceHint(context))),
                )
              else
                ...ledger.payments.map((payment) {
                  return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(14),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
                      children: [
                        Icon(
                          payment.kind == FeeKind.event ? Icons.event_rounded : Icons.school_rounded,
                          color: AppColors.feeCard,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                payment.kind == FeeKind.event ? 'Event fee' : 'Tuition',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                [
                                  _pretty(payment.paidOn),
                                  payment.methodLabel,
                                  if (payment.note.isNotEmpty) payment.note,
                                ].join(' · '),
                                style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${payment.amount.toStringAsFixed(0)}',
                              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.onSurface(context)),
                            ),
                            if (payment.isPending)
                              const Text('Pending',
                                  style: TextStyle(
                                      color: AppColors.warning,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600))
                            else if (payment.isOnline)
                              const Text('Online',
                                  style: TextStyle(
                                      color: AppColors.success,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
            ),
          ),
        );
      },
    );
  }

  Widget _amountRow(BuildContext context, String label, double paid, double due, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: emphasize ? AppColors.onSurface(context) : AppColors.onSurfaceMuted(context),
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '₹${paid.toStringAsFixed(0)} / ₹${due.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: emphasize ? AppColors.onSurface(context) : AppColors.onSurfaceMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _recordPayment(
    BuildContext context,
    Student student,
    StudentFeeLedger ledger,
    List<SchoolEvent> events,
  ) async {
    final amountController = TextEditingController(
      text: ledger.tuitionBalance > 0 ? ledger.tuitionBalance.toStringAsFixed(0) : '',
    );
    final noteController = TextEditingController();
    var kind = ledger.tuitionBalance > 0 ? FeeKind.tuition : FeeKind.event;
    String? eventId;
    final eventOptions = events.where((e) => e.requiresFee).toList();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 24),
          child: StatefulBuilder(
            builder: (context, setModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Record payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<FeeKind>(
                    value: kind,
                    items: const [
                      DropdownMenuItem(value: FeeKind.tuition, child: Text('Annual tuition')),
                      DropdownMenuItem(value: FeeKind.event, child: Text('Event fee')),
                    ],
                    onChanged: (val) => setModal(() => kind = val ?? FeeKind.tuition),
                    decoration: const InputDecoration(labelText: 'Payment type'),
                  ),
                  if (kind == FeeKind.event) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: eventId,
                      items: eventOptions
                          .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
                          .toList(),
                      onChanged: (val) => setModal(() => eventId = val),
                      decoration: const InputDecoration(labelText: 'Event'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount (₹)',
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: const Text('Save payment'),
                    ),
                  ),
                ],
              );
            },
          ),
          ),
        );
      },
    );

    if (saved != true || !context.mounted) return;
    final amount = double.tryParse(amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    context.read<FeeBloc>().add(
          RecordFeePayment(
            FeePayment(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              studentId: student.id,
              amount: amount,
              paidOn: DateTime.now(),
              kind: kind,
              eventId: kind == FeeKind.event ? eventId : null,
              note: noteController.text.trim(),
            ),
          ),
        );
  }

  String _pretty(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
