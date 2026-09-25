import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_provider.dart';
import '../../core/data/parent_repository.dart';
import '../../shared/models/message.dart';

class MessageState {
  final List<Message> messages;
  final bool isLoading;
  final bool hasError;
  final String? threadId;
  final int unreadCount;

  const MessageState({
    this.messages = const [],
    this.isLoading = false,
    this.hasError = false,
    this.threadId,
    this.unreadCount = 0,
  });

  MessageState copyWith({
    List<Message>? messages,
    bool? isLoading,
    bool? hasError,
    String? threadId,
    int? unreadCount,
  }) {
    return MessageState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      threadId: threadId ?? this.threadId,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class MessageNotifier extends StateNotifier<MessageState> {
  MessageNotifier(this._ref) : super(const MessageState(isLoading: true)) {
    _init();
  }

  final Ref _ref;
  StreamSubscription<dynamic>? _sub;

  ParentRepository get _repo => _ref.read(parentRepositoryProvider);

  Future<void> _init() async {
    _ref.listen(currentStudentProvider, (_, next) {
      if (next != null) _loadFor(next.id, next.classroomId);
    }, fireImmediately: true);
  }

  Map<String, LeaveRequest> _leaveById = {};

  Future<void> _loadFor(String studentId, String classroomId) async {
    _sub?.cancel();
    state = state.copyWith(isLoading: true, hasError: false);
    try {
      final thread = await _repo.ensureThread(
        studentId: studentId,
        classroomId: classroomId,
      );
      if (thread == null) {
        state = const MessageState(isLoading: false, hasError: true);
        return;
      }
      final threadId = thread['id'] as String;
      await _refreshLeaveMap(studentId);
      final rows = await _repo.threadMessages(threadId);
      state = MessageState(
        messages: rows.map(_fromRow).toList(),
        isLoading: false,
        threadId: threadId,
        unreadCount: (thread['parent_unread'] as int?) ?? 0,
      );
      // Read status is only cleared once the parent actually opens the
      // Messages screen (see MessageNotifier.markRead), not just because
      // this data silently synced in the background.
      _sub = _repo.watchThreadMessages(threadId).listen((rows) async {
        await _refreshLeaveMap(studentId);
        final unread = await _repo.threadUnreadForParent(threadId);
        state = state.copyWith(messages: rows.map(_fromRow).toList(), unreadCount: unread);
      }, onError: (_) {});
    } catch (_) {
      state = const MessageState(isLoading: false, hasError: true);
    }
  }

  Future<void> _refreshLeaveMap(String studentId) async {
    try {
      final rows = await _repo.leaveRequests(studentId);
      _leaveById = {
        for (final r in rows)
          r['id'] as String: LeaveRequest(
            id: r['id'] as String,
            reason: (r['reason'] ?? '') as String,
            duration: _leaveDuration(r),
            date: DateTime.tryParse('${r['from_date']}'),
            fromDate: DateTime.tryParse('${r['from_date']}'),
            toDate: r['to_date'] != null ? DateTime.tryParse('${r['to_date']}') : null,
            status: _leaveStatus(r['status'] as String?),
            createdAt: DateTime.tryParse('${r['created_at']}') ?? DateTime.now(),
          ),
      };
    } catch (_) {}
  }

  static int _leaveDuration(Map<String, dynamic> r) {
    final from = DateTime.tryParse('${r['from_date']}');
    final to = r['to_date'] != null ? DateTime.tryParse('${r['to_date']}') : null;
    if (from == null || to == null) return 1;
    return to.difference(from).inDays + 1;
  }

  static LeaveStatus _leaveStatus(String? s) => switch (s) {
        'under_review' => LeaveStatus.review,
        'approved' => LeaveStatus.granted,
        'rejected' => LeaveStatus.rejected,
        _ => LeaveStatus.requested,
      };

  /// Returns an error message on failure (and rolls back the optimistic
  /// bubble), or null on success. The caller shows the error via a SnackBar
  /// — a bubble that silently stays in the list despite never having sent
  /// would tell the parent their message reached the teacher when it didn't.
  Future<String?> sendMessage(
    String text, {
    MessageType type = MessageType.text,
    LeaveRequest? leaveRequest,
    String? attachmentName,
    int? attachmentSize,
  }) async {
    final threadId = state.threadId;
    if (threadId == null) return 'messages_unavailable';

    final optimistic = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: 'parent',
      receiverId: 'teacher',
      text: text,
      createdAt: DateTime.now(),
      type: type,
      leaveRequest: leaveRequest,
      attachmentName: attachmentName,
      attachmentSize: attachmentSize,
    );
    state = state.copyWith(messages: [...state.messages, optimistic]);

    String? leaveId;
    final student = _ref.read(currentStudentProvider);
    if (leaveRequest != null && student != null) {
      try {
        leaveId = await _repo.createLeaveRequest(
          studentId: student.id,
          kind: 'leave',
          fromDate: leaveRequest.date ?? leaveRequest.fromDate ?? DateTime.now(),
          toDate: leaveRequest.toDate,
          reason: leaveRequest.reason,
        );
      } catch (_) {}
    } else if (type == MessageType.infoLeave && student != null) {
      leaveId = await _tryQuickLeave(student.id, 'absent_info', text);
    } else if (type == MessageType.infoLate && student != null) {
      leaveId = await _tryQuickLeave(student.id, 'late_info', text);
    }

    try {
      await _repo.sendMessage(
        threadId: threadId,
        body: text,
        kind: _kindName(type),
        attachmentName: attachmentName,
        attachmentSize: attachmentSize,
        leaveRequestId: leaveId,
      );
      return null;
    } catch (_) {
      state = state.copyWith(
        messages: state.messages.where((m) => m.id != optimistic.id).toList(),
      );
      return 'message_send_failed';
    }
  }

  Future<String?> _tryQuickLeave(String studentId, String kind, String reason) async {
    try {
      return await _repo.createLeaveRequest(
        studentId: studentId,
        kind: kind,
        fromDate: DateTime.now(),
        reason: reason,
      );
    } catch (_) {
      return null;
    }
  }

  Message _fromRow(Map<String, dynamic> r) {
    final fromParent = r['sender_role'] == 'parent';
    final leaveId = r['leave_request_id'] as String?;
    return Message(
      id: r['id'] as String,
      senderId: fromParent ? 'parent' : 'teacher',
      receiverId: fromParent ? 'teacher' : 'parent',
      text: (r['body'] ?? '') as String,
      createdAt: DateTime.tryParse('${r['created_at']}') ?? DateTime.now(),
      type: _kindFromName(r['kind'] as String?),
      leaveRequest: leaveId != null ? _leaveById[leaveId] : null,
      attachmentName: r['attachment_name'] as String?,
      attachmentSize: r['attachment_size'] as int?,
    );
  }

  static MessageType _kindFromName(String? s) => switch (s) {
        'leave_request' => MessageType.leaveRequest,
        'late_info' => MessageType.infoLate,
        'absent_info' => MessageType.infoLeave,
        'document' => MessageType.document,
        _ => MessageType.text,
      };

  static String _kindName(MessageType t) => switch (t) {
        MessageType.leaveRequest => 'leave_request',
        MessageType.infoLate => 'late_info',
        MessageType.infoLeave => 'absent_info',
        MessageType.document => 'document',
        MessageType.text => 'text',
      };

  /// Call when the parent actually opens the Messages screen — clears the
  /// unread badge immediately (optimistic) and persists it server-side.
  Future<void> markRead() async {
    final threadId = state.threadId;
    if (threadId == null || state.unreadCount == 0) return;
    state = state.copyWith(unreadCount: 0);
    try {
      await _repo.markThreadRead(threadId);
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final messageProvider = StateNotifierProvider<MessageNotifier, MessageState>((ref) {
  return MessageNotifier(ref);
});

final unreadMessageCountProvider = Provider<int>((ref) => ref.watch(messageProvider).unreadCount);

final studentMessagesProvider = Provider.family<List<Message>, String>((ref, studentId) {
  return ref.watch(messageProvider).messages;
});
