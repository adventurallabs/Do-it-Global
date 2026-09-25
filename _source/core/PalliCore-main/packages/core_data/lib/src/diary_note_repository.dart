import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'remote_sync.dart';

class DiaryNoteRepository {
  DiaryNoteRepository(this.client);
  final SupabaseClient client;

  static final List<DiaryNote> _items = [];

  Future<List<DiaryNote>> getForClassroom(String classroomId) {
    return remoteOrLocal(
      () async {
        final rows = await client
            .from('diary_notes')
            .select()
            .eq('classroom_id', classroomId)
            .order('note_date', ascending: false)
            .limit(60);
        final list = (rows as List)
            .map((j) => DiaryNote.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _items.removeWhere((n) => n.classroomId == classroomId);
        _items.addAll(list);
        return list;
      },
      () => _items.where((n) => n.classroomId == classroomId).toList()
        ..sort((a, b) => b.noteDate.compareTo(a.noteDate)),
    );
  }

  Future<void> upsert(DiaryNote note) {
    return writeLocalThenRemote(
      () {
        _items.removeWhere((n) => n.id == note.id);
        _items.insert(0, note);
      },
      () => client.from('diary_notes').upsert(note.toJson()),
    );
  }

  Future<void> delete(String id) {
    return writeLocalThenRemote(
      () => _items.removeWhere((n) => n.id == id),
      () => client.from('diary_notes').delete().eq('id', id),
    );
  }
}
