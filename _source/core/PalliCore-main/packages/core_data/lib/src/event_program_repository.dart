import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'remote_sync.dart';

/// Everything an event is made of below the event itself: its categories, the
/// teachers who head them, who is entered, the rooms they compete in and who
/// placed.
///
/// Writes throw rather than being swallowed. A teacher told "saved" when a
/// place was not recorded would find out on prize day, in front of the
/// school, and the database enforces the same rules again underneath (see
/// `20260924_event_categories_rooms_results.sql`).
class EventProgramRepository {
  final SupabaseClient client;

  EventProgramRepository(this.client);

  /// Ids are minted in tight loops — a whole class entered at once — and the
  /// clock does not always tick between iterations, so the timestamp alone
  /// collided and failed the insert. The counter makes each one distinct.
  static int _seq = 0;

  static String newId(String prefix) {
    _seq = (_seq + 1) & 0xFFFFF;
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return '${prefix}_${stamp}_${_seq.toRadixString(36)}';
  }

  // ---------------------------------------------------------- categories --
  Future<List<EventCategory>> categories({String? eventId}) async {
    var q = client.from('event_categories').select();
    if (eventId != null) q = q.eq('event_id', eventId);
    final rows = await q.order('name').timeout(kRemoteTimeout);
    return _list(rows, EventCategory.fromJson);
  }

  Future<void> saveCategory(EventCategory category) async {
    await client
        .from('event_categories')
        .upsert(category.toJson()..remove('created_at'))
        .timeout(kRemoteTimeout);
  }

  Future<void> deleteCategory(String categoryId) async {
    await client.from('event_categories').delete().eq('id', categoryId).timeout(kRemoteTimeout);
  }

  // --------------------------------------------------------------- heads --
  Future<List<EventCategoryHead>> heads({String? teacherId}) async {
    var q = client.from('event_category_heads').select('category_id, teacher_id');
    if (teacherId != null) q = q.eq('teacher_id', teacherId);
    final rows = await q.timeout(kRemoteTimeout);
    return _list(rows, EventCategoryHead.fromJson);
  }

  /// Replaces a category's heads in one go — the admin edits the whole list,
  /// not one name at a time.
  Future<void> setHeads(String categoryId, List<String> teacherIds) async {
    await client
        .from('event_category_heads')
        .delete()
        .eq('category_id', categoryId)
        .timeout(kRemoteTimeout);
    if (teacherIds.isEmpty) return;
    await client.from('event_category_heads').insert([
      for (final id in teacherIds.toSet()) {'category_id': categoryId, 'teacher_id': id},
    ]).timeout(kRemoteTimeout);
  }

  /// The categories this teacher heads. Empty means the events card stays off
  /// their dashboard entirely.
  Future<List<EventCategory>> categoriesHeadedBy(String teacherId) async {
    final mine = await heads(teacherId: teacherId);
    if (mine.isEmpty) return const [];
    final ids = {for (final h in mine) h.categoryId}.toList();
    final rows = await client
        .from('event_categories')
        .select()
        .inFilter('id', ids)
        .order('name')
        .timeout(kRemoteTimeout);
    return _list(rows, EventCategory.fromJson);
  }

  // --------------------------------------------------------- open to ----
  /// The classrooms a category is open to, keyed by category. This is the
  /// only thing that puts a category in front of a family.
  Future<Map<String, Set<String>>> openClassrooms({String? categoryId}) async {
    var q = client.from('event_category_classrooms').select('category_id, classroom_id');
    if (categoryId != null) q = q.eq('category_id', categoryId);
    final rows = await q.timeout(kRemoteTimeout);
    final out = <String, Set<String>>{};
    for (final r in rows as List) {
      final m = r as Map;
      out.putIfAbsent(m['category_id'] as String, () => {}).add(m['classroom_id'] as String);
    }
    return out;
  }

  /// Opens or closes one classroom. Closing does not remove anyone already
  /// entered — it only stops new families joining.
  Future<void> setClassroomOpen({
    required String categoryId,
    required String classroomId,
    required bool open,
    required String byTeacher,
  }) async {
    if (open) {
      await client.from('event_category_classrooms').upsert({
        'category_id': categoryId,
        'classroom_id': classroomId,
        'opened_by': byTeacher,
      }).timeout(kRemoteTimeout);
    } else {
      await client
          .from('event_category_classrooms')
          .delete()
          .eq('category_id', categoryId)
          .eq('classroom_id', classroomId)
          .timeout(kRemoteTimeout);
    }
  }

  // -------------------------------------------------------- participants --
  Future<List<EventParticipant>> participants(String categoryId) async {
    final rows = await client
        .from('event_participants')
        .select()
        .eq('category_id', categoryId)
        .timeout(kRemoteTimeout);
    return _list(rows, EventParticipant.fromJson);
  }

  /// Enters a set of students from one classroom. Re-adding someone already
  /// entered is a no-op rather than an error — the picker shows them ticked,
  /// and a double tap should not fail the whole save.
  Future<void> addParticipants({
    required String categoryId,
    required String classroomId,
    required List<String> studentIds,
    required String addedBy,
  }) async {
    if (studentIds.isEmpty) return;
    await client.from('event_participants').upsert(
      [
        for (final id in studentIds.toSet())
          {
            'id': newId('ep'),
            'category_id': categoryId,
            'student_id': id,
            'classroom_id': classroomId,
            'added_by': addedBy,
          },
      ],
      onConflict: 'category_id,student_id',
      ignoreDuplicates: true,
    ).timeout(kRemoteTimeout);
  }

  Future<void> removeParticipants(List<String> participantIds) async {
    if (participantIds.isEmpty) return;
    await client
        .from('event_participants')
        .delete()
        .inFilter('id', participantIds)
        .timeout(kRemoteTimeout);
  }

  // --------------------------------------------------------------- rooms --
  Future<List<EventRoom>> rooms(String categoryId) async {
    final rows = await client
        .from('event_rooms')
        .select()
        .eq('category_id', categoryId)
        .order('created_at')
        .timeout(kRemoteTimeout);
    return _list(rows, EventRoom.fromJson);
  }

  Future<EventRoom?> room(String roomId) async {
    final row = await client
        .from('event_rooms')
        .select()
        .eq('id', roomId)
        .maybeSingle()
        .timeout(kRemoteTimeout);
    return row == null ? null : EventRoom.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> saveRoom(EventRoom room) async {
    final json = room.toJson()
      ..remove('created_at')
      ..remove('started_at')
      ..remove('submitted_at');
    await client.from('event_rooms').upsert(json).timeout(kRemoteTimeout);
  }

  Future<void> deleteRoom(String roomId) async {
    await client.from('event_rooms').delete().eq('id', roomId).timeout(kRemoteTimeout);
  }

  /// Participant ids in a room, in the order they were added.
  Future<List<String>> roomParticipantIds(String roomId) async {
    final rows = await client
        .from('event_room_participants')
        .select('participant_id')
        .eq('room_id', roomId)
        .order('added_at')
        .timeout(kRemoteTimeout);
    return [for (final r in rows as List) (r as Map)['participant_id'] as String];
  }

  /// Replaces a room's line-up. Only possible while the room is a draft —
  /// the database refuses once it has started.
  Future<void> setRoomParticipants(String roomId, List<String> participantIds) async {
    final current = (await roomParticipantIds(roomId)).toSet();
    final wanted = participantIds.toSet();
    final remove = current.difference(wanted).toList();
    final add = wanted.difference(current).toList();
    if (remove.isNotEmpty) {
      await client
          .from('event_room_participants')
          .delete()
          .eq('room_id', roomId)
          .inFilter('participant_id', remove)
          .timeout(kRemoteTimeout);
    }
    if (add.isNotEmpty) {
      await client.from('event_room_participants').insert([
        for (final id in add) {'room_id': roomId, 'participant_id': id},
      ]).timeout(kRemoteTimeout);
    }
  }

  /// Locks the line-up and opens the room for places.
  /// Locks the line-up. [prizeCount] is 0 for a non-competitive category —
  /// it starts and finishes without a podium.
  Future<void> startRoom(String roomId, {int? prizeCount}) async {
    await client
        .from('event_rooms')
        .update({
          'status': 'started',
          if (prizeCount != null) 'prize_count': prizeCount,
        })
        .eq('id', roomId)
        .timeout(kRemoteTimeout);
  }

  Future<void> setPrizeCount(String roomId, int prizeCount) async {
    await client
        .from('event_rooms')
        .update({'prize_count': prizeCount})
        .eq('id', roomId)
        .timeout(kRemoteTimeout);
  }

  // ------------------------------------------------------------- results --
  Future<List<EventResult>> results(String roomId) async {
    final rows = await client
        .from('event_results')
        .select('room_id, position, participant_id')
        .eq('room_id', roomId)
        .order('position')
        .timeout(kRemoteTimeout);
    return _list(rows, EventResult.fromJson);
  }

  Future<List<EventResult>> resultsForRooms(List<String> roomIds) async {
    if (roomIds.isEmpty) return const [];
    final rows = await client
        .from('event_results')
        .select('room_id, position, participant_id')
        .inFilter('room_id', roomIds)
        .order('position')
        .timeout(kRemoteTimeout);
    return _list(rows, EventResult.fromJson);
  }

  /// Writes the places as they stand. Called while the room is running, so a
  /// half-assigned board survives the head backing out of the screen.
  ///
  /// One RPC, one transaction. Doing it as "delete them all, then insert the
  /// new ones" meant two round trips from a phone: losing the network in
  /// between left the room with no places at all, mid-ceremony, under a
  /// screen that said they were saved. A refused save now leaves the previous
  /// podium exactly where it was.
  Future<void> saveResults({
    required String roomId,
    required Map<int, String> byPosition,
    required String recordedBy,
  }) async {
    await client.rpc('set_event_results', params: {
      'p_room': roomId,
      'p_positions': {for (final e in byPosition.entries) '${e.key}': e.value},
      'p_by': recordedBy,
    }).timeout(kRemoteTimeout);
  }

  /// The point of no return: the places become the result of record.
  Future<void> submitRoom(String roomId) async {
    await client
        .from('event_rooms')
        .update({'status': 'submitted'})
        .eq('id', roomId)
        .timeout(kRemoteTimeout);
  }

  // -------------------------------------------------------- certificates --
  Future<List<EventCertificate>> certificates(List<String> roomIds) async {
    if (roomIds.isEmpty) return const [];
    final rows = await client
        .from('event_certificates')
        .select('room_id, layout_id, published_at')
        .inFilter('room_id', roomIds)
        .timeout(kRemoteTimeout);
    return _list(rows, EventCertificate.fromJson);
  }

  /// Publishing does not make a file. It records which layout the parents'
  /// copies should be drawn from.
  /// [publishedBy] is taken from the signed-in account rather than passed in:
  /// the caller had no admin identity to hand and was sending the *school's*
  /// name, which made the audit column say nothing about who did it.
  Future<void> publishCertificates({
    required String roomId,
    required String layoutId,
  }) async {
    await client.from('event_certificates').upsert({
      'room_id': roomId,
      'layout_id': layoutId,
      'published_by': client.auth.currentUser?.id,
      'published_at': DateTime.now().toUtc().toIso8601String(),
    }).timeout(kRemoteTimeout);
  }

  static String describeError(Object error) {
    if (error is PostgrestException) {
      final msg = error.message.trim();
      if (msg.isNotEmpty) return msg;
    }
    final text = error.toString();
    if (text.contains('TimeoutException') || text.contains('SocketException')) {
      return "Couldn't reach the school server. Check your connection and try again.";
    }
    return 'Something went wrong. Please try again.';
  }

  static List<T> _list<T>(Object? rows, T Function(Map<String, dynamic>) fromJson) =>
      (rows as List).map((j) => fromJson(Map<String, dynamic>.from(j as Map))).toList();
}
