import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_repository.dart';
import 'remote_sync.dart';

class AnnouncementRepository extends BaseRepository<Announcement> {
  AnnouncementRepository(SupabaseClient client) : super(client, 'announcements');

  static final List<Announcement> _items = [
    Announcement(
      id: 'a1',
      title: 'Welcome Back to School',
      content: 'We are excited to welcome everyone back for the new academic year. Please check the updated timetables.',
      target: AnnouncementTarget.overall,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    ),
    Announcement(
      id: 'a2',
      title: 'Staff Meeting',
      content: 'All teachers are requested to attend the staff meeting on Friday at 4 PM in the conference hall.',
      target: AnnouncementTarget.teachers,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      expiresAt: DateTime.now().add(const Duration(days: 3)),
    ),
  ];

  @override
  Future<List<Announcement>> getAll() {
    return remoteOrLocal(
      () async {
        final response = await client.from(tableName).select();
        final remote = (response as List).map((json) => Announcement.fromJson(json)).toList();
        if (remote.isNotEmpty) {
          _items
            ..clear()
            ..addAll(remote);
        }
        return List<Announcement>.from(_items);
      },
      () => List<Announcement>.from(_items),
    );
  }

  @override
  Future<Announcement?> getById(String id) async {
    try {
      return _items.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(Announcement item) {
    return writeLocalThenRemote(() {
      final index = _items.indexWhere((a) => a.id == item.id);
      if (index >= 0) {
        _items[index] = item;
      } else {
        _items.add(item);
      }
    }, () => client.from(tableName).upsert(item.toJson()));
  }

  @override
  Future<void> delete(String id) {
    return writeLocalThenRemote(
      () => _items.removeWhere((a) => a.id == id),
      () => client.from(tableName).delete().eq('id', id),
    );
  }

  Future<List<Announcement>> getActiveAnnouncements(AnnouncementTarget target) async {
    final now = DateTime.now();
    return _items
        .where((a) => (a.target == target || a.target == AnnouncementTarget.overall) && a.expiresAt.isAfter(now))
        .toList();
  }
}
