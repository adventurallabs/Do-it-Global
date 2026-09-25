import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart';
import 'directory_bloc.dart';
import 'teacher_form_screen.dart';
import 'archive/discontinue_actions.dart';
import 'attendance_history_screen.dart';
import 'attendance_profile_section.dart';
import 'teacher_file_section.dart';

class TeacherDetailScreen extends StatelessWidget {
  final Teacher teacher;
  const TeacherDetailScreen({super.key, required this.teacher});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(teacher.name),
        actions: [
          if (teacher.isActive) ...[
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: AppColors.warning),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<DirectoryBloc>(),
                    child: TeacherFormScreen(teacher: teacher),
                  ),
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'reset') _confirmResetPassword(context);
                if (value == 'deactivate') _confirmDeactivate(context);
                if (value == 'discontinue') _discontinue(context);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'reset', child: Text('Reset password')),
                // Deactivating pauses a login; discontinuing ends the
                // relationship and starts the 30-day archive. Both are
                // offered, worded so the difference is obvious.
                PopupMenuItem(
                  value: 'deactivate',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text('Deactivate'),
                    subtitle: Text('Pause their login, keep them on staff'),
                  ),
                ),
                PopupMenuItem(
                  value: 'discontinue',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text('Discontinue', style: TextStyle(color: AppColors.error)),
                    subtitle: Text('They have left — archive for 30 days, then erase'),
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
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.teacherCard.withOpacity(0.15),
              backgroundImage: teacher.photoUrl != null ? NetworkImage(teacher.photoUrl!) : null,
              child: teacher.photoUrl == null
                  ? const Icon(Icons.school_rounded, size: 50, color: AppColors.teacherCard)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(teacher.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.onSurface(context))),
            const SizedBox(height: 24),
            SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      child: Column(
                children: [
                  _row(context, Icons.school, 'Qualification', teacher.qualification),
                  const Divider(height: 1, color: AppColors.divider),
                  _row(context, Icons.phone, 'Contact', teacher.contactNumber),
                  const Divider(height: 1, color: AppColors.divider),
                  _row(context, Icons.location_on_outlined, 'Address', teacher.address),
                  const Divider(height: 1, color: AppColors.divider),
                  _row(context, Icons.currency_rupee, 'Salary', '₹${teacher.salary.toStringAsFixed(0)}/month'),
                  if (teacher.gender != null) ...[
                    const Divider(height: 1, color: AppColors.divider),
                    _row(context, Icons.wc_outlined, 'Gender', teacher.gender!.label),
                  ],
                  if ((teacher.emergencyContact ?? '').trim().isNotEmpty) ...[
                    const Divider(height: 1, color: AppColors.divider),
                    _row(context, Icons.emergency_outlined, 'Emergency Contact', teacher.emergencyContact!),
                  ],
                  if (teacher.joinDate != null) ...[
                    const Divider(height: 1, color: AppColors.divider),
                    _row(context, Icons.event_available_outlined, 'Joined', _prettyJoin(teacher.joinDate!)),
                  ],
                  if (teacher.classroomId != null) ...[
                    const Divider(height: 1, color: AppColors.divider),
                    _row(context, Icons.class_rounded, 'Class Teacher Of', teacher.classroomId!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            TeacherFileSection(teacher: teacher),
            const SizedBox(height: 20),
            AttendanceProfileSection(
              personId: teacher.id,
              personName: teacher.name,
              subject: AttendanceSubject.staff,
            ),
          ],
        ),
        ),
      ),
    );
  }

  void _confirmResetPassword(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => VerificationDialog(
        title: 'Reset Password',
        content: 'This invalidates ${teacher.name}\'s current password. They will be required '
            'to set a new one after signing in with the temporary password shown next.',
        confirmWord: 'RESET PASSWORD',
        actionLabel: 'Confirm Reset',
        onConfirm: () async {
          try {
            final tempPassword = await context.read<TeacherRepository>().resetPassword(teacher.id);
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

  void _confirmDeactivate(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => VerificationDialog(
        title: 'Deactivate Staff',
        content: 'This revokes ${teacher.name}\'s login immediately and hides them from the '
            'active list. Their history stays intact — find them under Deactivated to '
            'reactivate or delete permanently.',
        confirmWord: 'DEACTIVATE',
        actionLabel: 'Deactivate',
        onConfirm: () {
          context.read<DirectoryBloc>().add(DeleteTeacher(teacher.id));
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _discontinue(BuildContext context) async {
    final navigator = Navigator.of(context);
    final archived = await DiscontinueActions.staff(context, teacher);
    if (archived && navigator.canPop()) navigator.pop();
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

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(color: AppColors.onSurface(context), fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _prettyJoin(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
