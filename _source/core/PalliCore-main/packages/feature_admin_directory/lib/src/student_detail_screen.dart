import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart';
import 'directory_bloc.dart';
import 'student_form_screen.dart';
import 'archive/discontinue_actions.dart';
import 'attendance_history_screen.dart';
import 'attendance_profile_section.dart';
import 'student_file_section.dart';

class StudentDetailScreen extends StatelessWidget {
  final Student student;
  const StudentDetailScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(student.name),
        actions: [
          if (student.isActive) ...[
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: AppColors.warning),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<DirectoryBloc>(),
                    child: StudentFormScreen(student: student),
                  ),
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'issue') _confirmIssueParentLogin(context);
                if (value == 'reset') _confirmResetParentPassword(context);
                if (value == 'deactivate') _confirmDeactivate(context);
                if (value == 'transfer') {
                  _recordExit(context, StudentLifecycle.transferred);
                }
                if (value == 'discontinue') {
                  _recordExit(context, StudentLifecycle.discontinued);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'issue', child: Text('Issue parent login')),
                PopupMenuItem(value: 'reset', child: Text('Reset parent password')),
                // Deactivating pauses the parent login; the two below mean
                // the child has left and start the 30-day archive.
                PopupMenuItem(
                  value: 'deactivate',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text('Deactivate'),
                    subtitle: Text('Pause the parent login, keep them on the roll'),
                  ),
                ),
                PopupMenuItem(
                  value: 'transfer',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text('Transfer out'),
                    subtitle: Text('Moved to another school — archive for 30 days'),
                  ),
                ),
                PopupMenuItem(
                  value: 'discontinue',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text('Discontinue', style: TextStyle(color: AppColors.error)),
                    subtitle: Text('Withdrawn — archive for 30 days, then erase'),
                  ),
                ),
              ],
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: Text('Deactivated', style: TextStyle(color: AppColors.error))),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.studentCard.withOpacity(0.15),
              backgroundImage: student.photoUrl != null ? NetworkImage(student.photoUrl!) : null,
              child: student.photoUrl == null
                  ? const Icon(Icons.person_rounded, size: 50, color: AppColors.studentCard)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(student.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.onSurface(context))),
            const SizedBox(height: 24),
            _InfoCard(items: [
              _InfoItem(icon: Icons.badge_outlined, label: 'Register Number', value: student.admissionNo),
              _InfoItem(icon: Icons.tag, label: 'Roll Number', value: student.rollNumber),
              _InfoItem(icon: Icons.person, label: "Father's Name", value: student.fatherName),
              _InfoItem(icon: Icons.person_outline, label: "Mother's Name", value: student.motherName),
              _InfoItem(icon: Icons.phone, label: 'Contact', value: student.contactNumber),
              if (student.secondaryContactNumber != null)
                _InfoItem(icon: Icons.phone_android, label: 'Secondary Contact', value: student.secondaryContactNumber!),
              _InfoItem(icon: Icons.location_on_outlined, label: 'Address', value: student.address),
              _InfoItem(icon: Icons.class_rounded, label: 'Classroom', value: context.read<DirectoryBloc>().state is DirectoryLoaded
                  ? (context.read<DirectoryBloc>().state as DirectoryLoaded).classroomName(student.classroomId)
                  : (student.classroomId.isEmpty ? 'Not assigned' : student.classroomId)),
              _InfoItem(icon: Icons.currency_rupee, label: 'Annual Fees', value: '₹${student.fees.toStringAsFixed(0)}'),
              if (student.gender != null)
                _InfoItem(icon: Icons.wc_outlined, label: 'Gender', value: student.gender!.label),
              if ((student.bloodGroup ?? '').trim().isNotEmpty)
                _InfoItem(icon: Icons.bloodtype_outlined, label: 'Blood Group', value: student.bloodGroup!),
              if ((student.emergencyContact ?? '').trim().isNotEmpty)
                _InfoItem(icon: Icons.emergency_outlined, label: 'Emergency Contact', value: student.emergencyContact!),
              if ((student.emergencyContactAlt ?? '').trim().isNotEmpty)
                _InfoItem(icon: Icons.phone_forwarded_outlined, label: 'Alternative', value: student.emergencyContactAlt!),
              if (student.admissionDate != null)
                _InfoItem(icon: Icons.event_available_outlined, label: 'Admitted', value: _prettyDate(student.admissionDate!)),
            ]),
            const SizedBox(height: 20),
            StudentFileSection(student: student),
            const SizedBox(height: 20),
            AttendanceProfileSection(
              personId: student.id,
              personName: student.name,
              subject: AttendanceSubject.student,
            ),
          ],
        ),
        ),
      ),
    );
  }
}

extension on StudentDetailScreen {
  void _confirmIssueParentLogin(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Issue Parent Login'),
        content: Text('Creates a login for register number "${student.admissionNo}". '
            'A temporary password is generated — the parent will be asked to set their own on first sign-in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final tempPassword = await context.read<StudentRepository>().issueParentLogin(student.id);
                if (context.mounted) await _showTempPassword(context, tempPassword);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not issue login: $e')));
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _confirmResetParentPassword(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => VerificationDialog(
        title: 'Reset Parent Password',
        content: "This invalidates the parent's current password. They will be required "
            'to set a new one after signing in with the temporary password shown next.',
        confirmWord: 'RESET PASSWORD',
        actionLabel: 'Confirm Reset',
        onConfirm: () async {
          try {
            final tempPassword = await context.read<StudentRepository>().resetParentPassword(student.id);
            if (context.mounted) await _showTempPassword(context, tempPassword);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not reset password: $e')));
            }
          }
        },
      ),
    );
  }

  Future<void> _recordExit(BuildContext context, StudentLifecycle lifecycle) async {
    final navigator = Navigator.of(context);
    final archived = await DiscontinueActions.student(
      context,
      student,
      lifecycle: lifecycle,
    );
    if (archived && navigator.canPop()) navigator.pop();
  }

  void _confirmDeactivate(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => VerificationDialog(
        title: 'Deactivate Student',
        content: 'This revokes their parent login immediately and hides them from the '
            'active list. Their history stays intact — find them under Deactivated to '
            'reactivate or delete permanently.',
        confirmWord: 'DEACTIVATE',
        actionLabel: 'Deactivate',
        onConfirm: () {
          context.read<DirectoryBloc>().add(DeleteStudent(student.id));
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _showTempPassword(BuildContext context, String tempPassword) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Temporary password'),
        content: Row(
          children: [
            Expanded(
              child: SelectableText(tempPassword,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: tempPassword));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
              },
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
      ),
    );
  }
}

String _prettyDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class _InfoCard extends StatelessWidget {
  final List<_InfoItem> items;
  const _InfoCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final item = entry.value;
          final isLast = entry.key == items.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(item.icon, color: AppColors.accent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.label, style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(item.value, style: TextStyle(color: AppColors.onSurface(context), fontSize: 15, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast) const Divider(height: 1, color: AppColors.divider),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  const _InfoItem({required this.icon, required this.label, required this.value});
}
