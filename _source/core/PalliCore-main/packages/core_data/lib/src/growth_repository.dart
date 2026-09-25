import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'remote_sync.dart';

class GrowthRepository {
  GrowthRepository(this.client);
  final SupabaseClient client;

  static final List<GrowthObservation> _observations = [];
  static final List<GrowthSkill> _skills = [];

  Future<List<GrowthObservation>> observationsFor(String studentId) {
    return remoteOrLocal(
      () async {
        final rows = await client
            .from('growth_observations')
            .select()
            .eq('student_id', studentId)
            .order('date', ascending: false);
        final list = (rows as List)
            .map((j) =>
                GrowthObservation.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _observations.removeWhere((o) => o.studentId == studentId);
        _observations.addAll(list);
        return list;
      },
      () => _observations.where((o) => o.studentId == studentId).toList()
        ..sort((a, b) => b.date.compareTo(a.date)),
    );
  }

  Future<List<GrowthSkill>> skillsFor(String studentId) {
    return remoteOrLocal(
      () async {
        final rows = await client
            .from('growth_skills')
            .select()
            .eq('student_id', studentId);
        final list = (rows as List)
            .map((j) => GrowthSkill.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _skills.removeWhere((s) => s.studentId == studentId);
        _skills.addAll(list);
        return list;
      },
      () => _skills.where((s) => s.studentId == studentId).toList(),
    );
  }

  Future<void> upsertObservation(GrowthObservation obs) {
    return writeLocalThenRemote(
      () {
        _observations.removeWhere((o) => o.id == obs.id);
        _observations.insert(0, obs);
      },
      () => client.from('growth_observations').upsert(obs.toJson()),
    );
  }

  Future<void> deleteObservation(String id) {
    return writeLocalThenRemote(
      () => _observations.removeWhere((o) => o.id == id),
      () => client.from('growth_observations').delete().eq('id', id),
    );
  }

  Future<void> upsertSkill(GrowthSkill skill) {
    return writeLocalThenRemote(
      () {
        _skills.removeWhere(
            (s) => s.studentId == skill.studentId && s.name == skill.name);
        _skills.add(skill);
      },
      () => client
          .from('growth_skills')
          .upsert(skill.toJson(), onConflict: 'student_id,name'),
    );
  }
}
