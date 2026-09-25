import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../shared/models/message.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/premium_card.dart';
import '../../core/auth/session_provider.dart';
import '../../core/localization/l10n_ext.dart';
import 'message_store.dart';
import 'widgets/leave_request_form.dart';

class MessageScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  const MessageScreen({super.key, this.onBack});

  @override
  ConsumerState<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends ConsumerState<MessageScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showInfoDialog(BuildContext context) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.aboutMessagesTitle),
        content: Text(l10n.aboutMessagesContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSendError(String? errorCode) {
    if (errorCode == null || !mounted) return;
    final l10n = context.l10n;
    final text = errorCode == 'messages_unavailable' ? l10n.messagesUnavailable : l10n.messageSendFailed;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final student = ref.watch(currentStudentProvider);
    final messageState = ref.watch(messageProvider);
    final messages = messageState.messages;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
        title: Text(l10n.studentTeacher(student?.firstName ?? 'Student')),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildQuickActions(context),
          Expanded(
            child: messageState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : messageState.hasError
                    ? AppEmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: l10n.messagesUnavailable,
                        body: '',
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMe = message.senderId == 'parent';
                          return _buildMessageBubble(context, message, isMe);
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: _buildInputArea(context),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.08))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: _QuickActionButton(
              icon: Icons.calendar_today_outlined,
              label: l10n.requestLeave,
              onTap: () => _showLeaveForm(context),
            ),
          ),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.emergency_outlined,
              label: l10n.informLeave,
              onTap: () => _showQuickReasonPrompt(context, MessageType.infoLeave),
            ),
          ),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.timer_outlined,
              label: l10n.informLate,
              onTap: () => _showQuickReasonPrompt(context, MessageType.infoLate),
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickReasonPrompt(BuildContext context, MessageType type) {
    final l10n = context.l10n;
    final title = type == MessageType.infoLeave ? l10n.informLeave : l10n.informLate;
    final hint = type == MessageType.infoLeave ? l10n.leaveReason : l10n.lateReason;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isNotEmpty) {
                final text = type == MessageType.infoLeave 
                  ? '${l10n.informLeave}. ${l10n.leaveReason}: $reason'
                  : '${l10n.informLate}. ${l10n.lateReason}: $reason';
                ref.read(messageProvider.notifier).sendMessage(text, type: type).then(_showSendError);
                Navigator.pop(context);
                _scrollToBottom();
              }
            },
            child: Text(l10n.send),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, Message message, bool isMe) {
    final theme = Theme.of(context);
    
    if (message.type == MessageType.leaveRequest && message.leaveRequest != null) {
      return _buildLeaveRequestBubble(context, message.leaveRequest!, isMe);
    }

    if (message.type == MessageType.document) {
      return _buildDocumentBubble(context, message, isMe);
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('hh:mm a').format(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: (isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant).withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentBubble(BuildContext context, Message message, bool isMe) {
    final theme = Theme.of(context);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        width: 220,
        child: PremiumCard(
          color: isMe ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.insert_drive_file_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.attachmentName ?? 'Document',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${((message.attachmentSize ?? 0) / 1024).toStringAsFixed(1)} KB',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveRequestBubble(BuildContext context, LeaveRequest request, bool isMe) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final statusColor = switch (request.status) {
      LeaveStatus.requested => AppColors.info,
      LeaveStatus.review => AppColors.warning,
      LeaveStatus.granted => AppColors.success,
      LeaveStatus.rejected => AppColors.error,
    };

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        width: MediaQuery.of(context).size.width * 0.8,
        child: PremiumCard(
          color: theme.colorScheme.surface,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: statusColor),
                    const SizedBox(width: 8),
                    Text(
                      l10n.requestLeave,
                      style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        request.status.name.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow(Icons.help_outline, l10n.leaveReason, request.reason),
                    const SizedBox(height: 8),
                    _infoRow(
                      Icons.schedule, 
                      l10n.duration, 
                      request.duration == 1 
                          ? DateFormat('MMM d, yyyy', Localizations.localeOf(context).toString()).format(request.date!)
                          : '${DateFormat('MMM d', Localizations.localeOf(context).toString()).format(request.fromDate!)} - ${DateFormat('MMM d', Localizations.localeOf(context).toString()).format(request.toDate!)} (${request.duration} ${l10n.daysLabel})'
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputArea(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isDark = theme.brightness == Brightness.dark;
    final fill = isDark
        ? AppColors.surfaceDark.withValues(alpha: 0.92)
        : AppColors.ice;

    return Material(
      color: isDark ? AppColors.ink : AppColors.offWhite,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: l10n.selectDocument,
              onPressed: () => _pickDocument(context),
              icon: Icon(Icons.attach_file_rounded, color: theme.colorScheme.primary),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l10n.typeMessage,
                  filled: true,
                  fillColor: fill,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: AppColors.skyBlue.withValues(alpha: isDark ? 0.22 : 0.35),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.2),
                  ),
                ),
                onSubmitted: (_) => _sendText(),
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: IconButton.filled(
                tooltip: l10n.send,
                onPressed: _sendText,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.send_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendText() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    ref.read(messageProvider.notifier).sendMessage(text).then(_showSendError);
    _controller.clear();
    _scrollToBottom();
  }

  Future<void> _pickDocument(BuildContext context) async {
    final l10n = context.l10n;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        withData: false,
      );
      if (!mounted) return;
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      const maxBytes = 2 * 1024 * 1024;
      if (file.size > maxBytes) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(content: Text(l10n.fileTooLarge)),
        );
        return;
      }

      ref.read(messageProvider.notifier).sendMessage(
            l10n.uploadedDocument,
            type: MessageType.document,
            attachmentName: file.name,
            attachmentSize: file.size,
          ).then(_showSendError);
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text(l10n.filePickFailed)),
      );
    }
  }

  void _showLeaveForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: LeaveRequestForm(
          onSubmit: (request) {
            ref.read(messageProvider.notifier).sendMessage(
              'Submitted a leave request for ${request.duration == 1 ? '1 day' : '${request.duration} days'}.',
              type: MessageType.leaveRequest,
              leaveRequest: request,
            ).then(_showSendError);
            _scrollToBottom();
          },
        ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
