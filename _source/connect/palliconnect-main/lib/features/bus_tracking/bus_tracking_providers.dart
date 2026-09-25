import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_provider.dart';
import '../../core/network/supabase_service.dart';
import '../../shared/models/bus_tracking.dart';
import 'repositories/bus_tracking_repository.dart';

final busTrackingRepositoryProvider = Provider<BusTrackingRepository?>((ref) {
  return SupabaseService.isReady ? BusTrackingRepository(SupabaseService.client) : null;
});

/// The current child's bus/route assignment, or null if none is set up yet.
/// Errors propagate as AsyncValue.error — deliberately not swallowed, so the
/// screen can show a real retry affordance instead of a silent empty state.
final studentBusAssignmentProvider = FutureProvider<StudentBusAssignment?>((ref) async {
  final student = ref.watch(currentStudentProvider);
  final repo = ref.watch(busTrackingRepositoryProvider);
  if (student == null || repo == null) return null;
  return repo.assignmentForStudent(student.id);
});

/// Live location of the assigned bus; null until the bus reports a position.
final busLocationProvider = StreamProvider<BusLocation?>((ref) {
  final assignment = ref.watch(studentBusAssignmentProvider).valueOrNull;
  final repo = ref.watch(busTrackingRepositoryProvider);
  if (assignment == null || repo == null) return Stream.value(null);
  return repo.watchBusLocation(assignment.bus.id);
});
