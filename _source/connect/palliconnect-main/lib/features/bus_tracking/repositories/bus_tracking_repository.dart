import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/bus_tracking.dart';

class BusTrackingRepository {
  final SupabaseClient _client;

  BusTrackingRepository(this._client);

  /// The signed-in parent's child's bus/route, or null if the school hasn't
  /// assigned this student to a route yet (the common case) — the screen
  /// shows a real "not assigned" state rather than guessing.
  Future<StudentBusAssignment?> assignmentForStudent(String studentId) async {
    final transport = await _client
        .from('student_transport')
        .select()
        .eq('student_id', studentId)
        .maybeSingle();
    if (transport == null) return null;

    final routeId = transport['route_id'] as String;
    final stopId = transport['stop_id'] as String?;

    final routeRow = await _client.from('bus_routes').select().eq('id', routeId).maybeSingle();
    if (routeRow == null) return null;

    final (route, busRow) = await (
      getRoute(routeId, routeRow: routeRow),
      _client.from('buses').select().eq('id', routeRow['bus_id'] as String).maybeSingle(),
    ).wait;
    if (busRow == null) return null;

    return StudentBusAssignment(
      bus: BusInfo(
        id: busRow['id'] as String,
        busNumber: (busRow['bus_number'] ?? '') as String,
        driverName: (busRow['driver_name'] ?? '') as String,
        driverContact: (busRow['driver_contact'] ?? '') as String,
      ),
      route: route,
      stopId: stopId,
    );
  }

  static double _num(Object? v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

  /// Latest GPS fix for the bus, or null while none has been recorded —
  /// "no signal yet" is a normal state, not an error.
  Stream<BusLocation?> watchBusLocation(String busId) {
    return _client
        .from('bus_locations')
        .stream(primaryKey: ['id'])
        .eq('bus_id', busId)
        .order('recorded_at', ascending: false)
        .limit(1)
        .map((data) {
          if (data.isEmpty) return null;
          final row = data.first;
          return BusLocation(
            busId: '${row['bus_id']}',
            location: GeoPoint(_num(row['latitude']), _num(row['longitude'])),
            speedKmph: (row['speed_kmph'] as num?)?.toDouble(),
            recordedAt: DateTime.tryParse('${row['recorded_at']}')?.toLocal() ?? DateTime.now(),
          );
        });
  }

  /// [routeRow] lets [assignmentForStudent] avoid re-fetching a route it
  /// already has; omit it to fetch fresh.
  Future<BusRoute> getRoute(String routeId, {Map<String, dynamic>? routeRow}) async {
    final route = routeRow ?? await _client.from('bus_routes').select().eq('id', routeId).single();
    final stopsData =
        await _client.from('route_stops').select().eq('route_id', routeId).order('sequence_no');

    return BusRoute(
      id: '${route['id']}',
      routeName: '${route['route_name'] ?? ''}',
      stops: (stopsData as List).map((s) => BusStop(
        id: '${s['id']}',
        name: '${s['stop_name'] ?? ''}',
        location: GeoPoint(_num(s['latitude']), _num(s['longitude'])),
        sequence: (s['sequence_no'] as num?)?.toInt() ?? 0,
      )).toList(),
    );
  }
}
