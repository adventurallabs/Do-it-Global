import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

/// Teacher-side inbox for parent conversations.
class TeacherMessagesScreen extends StatefulWidget {
  final String teacherId;
  const TeacherMessagesScreen({super.key, required this.teacherId});

  @override
  State<TeacherMessagesScreen> createState() => _TeacherMessagesScreenState();
}

class _TeacherMessagesScreenState extends State<TeacherMessagesScreen> {
  List<MessageThread> _threads = [];
  Map<String, String> _studentNames = {};
  bool _loading = true;
  StreamSubscription<dynamic>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = context
        .read<MessageRepository>()
        .watchThreads(widget.teacherId)
        .listen((threads) {
      if (mounted) setState(() => _threads = threads);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final threads =
        await context.read<MessageRepository>().threadsForTeacher(widget.teacherId);
    final students = await context.read<StudentRepository>().getAll();
    if (!mounted) return;
    setState(() {
      _threads = threads;
      _studentNames = {for (final s in students) s.id: s.name};
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SoftPageHeader(
              title: 'Messages',
              subtitle: 'Conversations with parents',
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _threads.isEmpty
                      ? const EmptyState(
                          icon: Icons.forum_outlined,
                          title: 'No conversations yet',
                          subtitle: 'Parent messages for your class will appear here.',
                        )
                      : RefreshIndicator(
                          color: AppColors.accent,
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                            itemCount: _threads.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final thread = _threads[index];
                              final name = _studentNames[thread.studentId] ?? 'Student';
                              return AnimatedListItem(
                                index: index,
                                child: SoftSurface(
                                  depth: SoftDepth.one,
                                  borderRadius: BorderRadius.circular(18),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  onTap: () => _openThread(thread, name),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor:
                                            AppColors.studentCard.withValues(alpha: 0.16),
                                        child: Text(
                                          name.isNotEmpty ? name[0] : '?',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.studentCard),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Parent of $name',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15)),
                                            const SizedBox(height: 2),
                                            Text(
                                              thread.subject.isEmpty
                                                  ? 'Tap to open the conversation'
                                                  : thread.subject,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  color: AppColors.onSurfaceMuted(context),
                                                  fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (thread.teacherUnread > 0)
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: AppColors.accent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            '${thread.teacherUnread}',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _openThread(MessageThread thread, String studentName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessageThreadScreen(
          thread: thread,
          teacherId: widget.teacherId,
          studentName: studentName,
        ),
      ),
    ).then((_) => _load());
  }
}

class MessageThreadScreen extends StatefulWidget {
  final MessageThread thread;
  final String teacherId;
  final String studentName;

  const MessageThreadScreen({
    super.key,
    required this.thread,
    required this.teacherId,
    required this.studentName,
  });

  @override
  State<MessageThreadScreen> createState() => _MessageThreadScreenState();
}

class _MessageThreadScreenState extends State<MessageThreadScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  List<Message> _messages = [];
  bool _loading = true;
  StreamSubscription<dynamic>? _sub;

  MessageRepository get _repo => context.read<MessageRepository>();

  @override
  void initState() {
    super.initState();
    _load();
    _repo.markThreadRead(widget.thread.id, asTeacher: true);
    _sub = _repo.watchMessages(widget.thread.id).listen((messages) {
      if (mounted && messages.isNotEmpty) {
        setState(() => _messages = _sorted(messages));
        _jumpToBottom();
      }
    }, onError: (_) {});
  }

  List<Message> _sorted(List<Message> messages) =>
      [...messages]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Future<void> _load() async {
    final messages = await _repo.messages(widget.thread.id);
    if (!mounted) return;
    setState(() {
      _messages = _sorted(messages);
      _loading = false;
    });
    _jumpToBottom();
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final message = Message(
      id: 'm-${DateTime.now().millisecondsSinceEpoch}',
      threadId: widget.thread.id,
      senderRole: MessageSenderRole.teacher,
      senderId: widget.teacherId,
      body: text,
      createdAt: DateTime.now(),
    );
    _controller.clear();
    setState(() => _messages = _sorted([..._messages, message]));
    _jumpToBottom();
    await _repo.sendMessage(message);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Parent of ${widget.studentName}')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const EmptyState(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'No messages yet',
                        subtitle: 'Start the conversation below.',
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final m = _messages[index];
                          final mine = !m.isFromParent;
                          return Align(
                            alignment:
                                mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              decoration: BoxDecoration(
                                color: mine
                                    ? AppColors.accent
                                    : AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (m.kind == MessageKind.leaveRequest ||
                                      m.kind == MessageKind.lateInfo ||
                                      m.kind == MessageKind.absentInfo)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        _kindLabel(m.kind),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: mine
                                              ? Colors.white70
                                              : AppColors.onSurfaceHint(context),
                                        ),
                                      ),
                                    ),
                                  Text(
                                    m.body,
                                    style: TextStyle(
                                      color: mine
                                          ? Colors.white
                                          : AppColors.onSurface(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Message the parent',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _kindLabel(MessageKind kind) => switch (kind) {
        MessageKind.leaveRequest => 'Leave request',
        MessageKind.lateInfo => 'Running late',
        MessageKind.absentInfo => 'Absence notice',
        _ => '',
      };
}
