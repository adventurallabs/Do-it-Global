import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_repository.dart';
import 'remote_sync.dart';

class MessageRepository extends BaseRepository<Message> {
  MessageRepository(SupabaseClient client) : super(client, 'messages');

  static final List<MessageThread> _threads = [];
  static final List<Message> _messages = [];

  // ---- threads -------------------------------------------------------------

  Future<List<MessageThread>> threadsForTeacher(String teacherId) {
    return remoteOrLocal(
      () async {
        final rows = await client
            .from('message_threads')
            .select()
            .eq('teacher_id', teacherId)
            .order('last_message_at', ascending: false);
        final list = (rows as List)
            .map((j) => MessageThread.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _cacheThreads(list);
        return list;
      },
      () => _threads.where((t) => t.teacherId == teacherId).toList()
        ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt)),
    );
  }

  Future<List<MessageThread>> threadsForParent(String parentId) {
    return remoteOrLocal(
      () async {
        final rows = await client
            .from('message_threads')
            .select()
            .eq('parent_id', parentId)
            .order('last_message_at', ascending: false);
        final list = (rows as List)
            .map((j) => MessageThread.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _cacheThreads(list);
        return list;
      },
      () => _threads.where((t) => t.parentId == parentId).toList(),
    );
  }

  Stream<List<MessageThread>> watchThreads(String teacherId) {
    try {
      return client
          .from('message_threads')
          .stream(primaryKey: ['id'])
          .eq('teacher_id', teacherId)
          .order('last_message_at', ascending: false)
          .map((rows) => rows
              .map((j) => MessageThread.fromJson(Map<String, dynamic>.from(j)))
              .toList());
    } catch (_) {
      return Stream.value(_threads.where((t) => t.teacherId == teacherId).toList());
    }
  }

  Future<MessageThread> ensureThread({
    required String studentId,
    required String classroomId,
    required String parentId,
    required String teacherId,
    String subject = '',
  }) async {
    final existing = _threads.firstWhere(
      (t) => t.studentId == studentId && t.parentId == parentId && t.teacherId == teacherId,
      orElse: () => MessageThread(
        id: '',
        studentId: studentId,
        lastMessageAt: DateTime.now(),
      ),
    );
    if (existing.id.isNotEmpty) return existing;

    final thread = MessageThread(
      id: 'th-${DateTime.now().millisecondsSinceEpoch}',
      studentId: studentId,
      classroomId: classroomId,
      parentId: parentId,
      teacherId: teacherId,
      subject: subject,
      lastMessageAt: DateTime.now(),
    );
    _threads.add(thread);
    try {
      final row = await client
          .from('message_threads')
          .upsert(thread.toJson(), onConflict: 'student_id,parent_id,teacher_id')
          .select()
          .single()
          .timeout(kRemoteTimeout);
      final saved = MessageThread.fromJson(Map<String, dynamic>.from(row));
      _cacheThreads([saved]);
      return saved;
    } catch (_) {
      return thread;
    }
  }

  // ---- messages ----------------------------------------------------------

  Future<List<Message>> messages(String threadId) {
    return remoteOrLocal(
      () async {
        final rows = await client
            .from('messages')
            .select()
            .eq('thread_id', threadId)
            .order('created_at');
        final list = (rows as List)
            .map((j) => Message.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        for (final m in list) {
          _messages.removeWhere((x) => x.id == m.id);
        }
        _messages.addAll(list);
        return list;
      },
      () => _messages.where((m) => m.threadId == threadId).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
    );
  }

  Stream<List<Message>> watchMessages(String threadId) {
    try {
      return client
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('thread_id', threadId)
          .order('created_at')
          .map((rows) => rows
              .map((j) => Message.fromJson(Map<String, dynamic>.from(j)))
              .toList()
            // Belt-and-suspenders: the realtime channel's own ordering isn't
            // guaranteed to stay correct as rows stream in incrementally —
            // always re-sort explicitly so messages never render grouped by
            // sender instead of true chronological order.
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt)));
    } catch (_) {
      return Stream.value(_messages.where((m) => m.threadId == threadId).toList());
    }
  }

  Future<void> sendMessage(Message message) {
    return writeLocalThenRemote(
      () {
        _messages.add(message);
        final i = _threads.indexWhere((t) => t.id == message.threadId);
        if (i >= 0) {
          final t = _threads[i];
          _threads[i] = MessageThread(
            id: t.id,
            studentId: t.studentId,
            classroomId: t.classroomId,
            parentId: t.parentId,
            teacherId: t.teacherId,
            subject: t.subject,
            lastMessageAt: message.createdAt,
            parentUnread: message.isFromParent ? t.parentUnread : t.parentUnread + 1,
            teacherUnread: message.isFromParent ? t.teacherUnread + 1 : t.teacherUnread,
          );
        }
      },
      () {
        // Let the database's own clock stamp `created_at` (its column
        // default) rather than trusting this device's clock — the parent
        // app already relies on the same server-side default, and mixing a
        // client-supplied timestamp with a server-generated one is exactly
        // how messages can end up sorted out of true chronological order.
        final json = message.toJson()..remove('created_at');
        return client.from('messages').insert(json);
      },
    );
  }

  Future<void> markThreadRead(String threadId, {required bool asTeacher}) async {
    final field = asTeacher ? 'teacher_unread' : 'parent_unread';
    try {
      await client.from('message_threads').update({field: 0}).eq('id', threadId).timeout(kRemoteTimeout);
    } catch (_) {}
    final i = _threads.indexWhere((t) => t.id == threadId);
    if (i >= 0) {
      final t = _threads[i];
      _threads[i] = MessageThread(
        id: t.id,
        studentId: t.studentId,
        classroomId: t.classroomId,
        parentId: t.parentId,
        teacherId: t.teacherId,
        subject: t.subject,
        lastMessageAt: t.lastMessageAt,
        parentUnread: asTeacher ? t.parentUnread : 0,
        teacherUnread: asTeacher ? 0 : t.teacherUnread,
      );
    }
  }

  void _cacheThreads(List<MessageThread> list) {
    for (final t in list) {
      _threads.removeWhere((x) => x.id == t.id);
      _threads.add(t);
    }
  }

  // ---- BaseRepository ---------------------------------------------------

  @override
  Future<List<Message>> getAll() async => List<Message>.from(_messages);

  @override
  Future<Message?> getById(String id) async {
    try {
      return _messages.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(Message item) => sendMessage(item);

  @override
  Future<void> delete(String id) {
    return writeLocalThenRemote(
      () => _messages.removeWhere((m) => m.id == id),
      () => client.from(tableName).delete().eq('id', id),
    );
  }
}
