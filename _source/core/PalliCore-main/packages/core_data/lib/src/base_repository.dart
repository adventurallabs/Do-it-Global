import 'package:supabase_flutter/supabase_flutter.dart';

abstract class BaseRepository<T> {
  final SupabaseClient client;
  final String tableName;

  BaseRepository(this.client, this.tableName);

  Future<List<T>> getAll();
  Future<T?> getById(String id);
  Future<void> upsert(T item);
  Future<void> delete(String id);
}
