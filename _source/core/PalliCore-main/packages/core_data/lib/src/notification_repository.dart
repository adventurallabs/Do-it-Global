import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_repository.dart';
import 'remote_sync.dart';

class NotificationRepository extends BaseRepository<AppNotification> {
  NotificationRepository(SupabaseClient client) : super(client, 'notifications');

  static final List<AppNotification> _items = [];

  static String _roleValue(NotificationRecipientRole role) => switch (role) {
        NotificationRecipientRole.parent => 'parent',
        NotificationRecipientRole.teacher => 'teacher',
        NotificationRecipientRole.admin => 'admin',
      };

  @override
  Future<List<AppNotification>> getAll() async => List<AppNotification>.from(_items);

  Future<List<AppNotification>> forRecipient(
    NotificationRecipientRole role,
    String recipientId,
  ) {
    return remoteOrLocal(
      () async {
        final rows = await client
            .from(tableName)
            .select()
            .eq('recipient_role', _roleValue(role))
            .eq('recipient_id', recipientId)
            .order('created_at', ascending: false)
            .limit(80);
        final list = (rows as List)
            .map((j) =>
                AppNotification.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _merge(list);
        return list;
      },
      () => _items
          .where((n) => n.recipientRole == role && n.recipientId == recipientId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
  }

  Stream<List<AppNotification>> watch(
    NotificationRecipientRole role,
    String recipientId,
  ) {
    try {
      return client
          .from(tableName)
          .stream(primaryKey: ['id'])
          .eq('recipient_id', recipientId)
          .order('created_at', ascending: false)
          .map((rows) => rows
              .map((j) => AppNotification.fromJson(Map<String, dynamic>.from(j)))
              .where((n) => n.recipientRole == role)
              .toList());
    } catch (_) {
      return Stream.value(const []);
    }
  }

  /// Unread count for the general notification bell — excludes `message`
  /// kind rows, which get their own badge on the Messages tab instead
  /// (driven by `MessageThread.teacherUnread`/`parentUnread`).
  Future<int> unreadCount(
    NotificationRecipientRole role,
    String recipientId,
  ) async {
    final list = await forRecipient(role, recipientId);
    return list.where((n) => !n.isRead && n.kind != NotificationKind.message).length;
  }

  Future<void> markRead(String id) async {
    final i = _items.indexWhere((n) => n.id == id);
    if (i >= 0 && !_items[i].isRead) {
      _items[i] = AppNotification(
        id: _items[i].id,
        recipientRole: _items[i].recipientRole,
        recipientId: _items[i].recipientId,
        studentId: _items[i].studentId,
        kind: _items[i].kind,
        title: _items[i].title,
        body: _items[i].body,
        deepLink: _items[i].deepLink,
        isImportant: _items[i].isImportant,
        grouped: _items[i].grouped,
        groupCount: _items[i].groupCount,
        createdAt: _items[i].createdAt,
        readAt: DateTime.now(),
      );
    }
    try {
      await client
          .from(tableName)
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('id', id)
          .timeout(kRemoteTimeout);
    } catch (_) {}
  }

  Future<void> markAllRead(
    NotificationRecipientRole role,
    String recipientId,
  ) async {
    // One update .in_() the matching ids instead of a round trip per
    // notification — same rows written, a single request.
    final now = DateTime.now();
    final ids = <String>[];
    for (var i = 0; i < _items.length; i++) {
      final n = _items[i];
      if (n.recipientRole == role && n.recipientId == recipientId && !n.isRead) {
        ids.add(n.id);
        _items[i] = AppNotification(
          id: n.id,
          recipientRole: n.recipientRole,
          recipientId: n.recipientId,
          studentId: n.studentId,
          kind: n.kind,
          title: n.title,
          body: n.body,
          deepLink: n.deepLink,
          isImportant: n.isImportant,
          grouped: n.grouped,
          groupCount: n.groupCount,
          createdAt: n.createdAt,
          readAt: now,
        );
      }
    }
    if (ids.isEmpty) return;
    try {
      await client
          .from(tableName)
          .update({'read_at': now.toIso8601String()})
          .inFilter('id', ids)
          .timeout(kRemoteTimeout);
    } catch (_) {}
  }

  void _merge(List<AppNotification> list) {
    for (final n in list) {
      _items.removeWhere((x) => x.id == n.id);
      _items.add(n);
    }
  }

  @override
  Future<AppNotification?> getById(String id) async {
    try {
      return _items.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(AppNotification item) {
    return writeLocalThenRemote(
      () => _merge([item]),
      () => client.from(tableName).upsert(item.toJson()),
    );
  }

  @override
  Future<void> delete(String id) {
    return writeLocalThenRemote(
      () => _items.removeWhere((n) => n.id == id),
      () => client.from(tableName).delete().eq('id', id),
    );
  }
}
