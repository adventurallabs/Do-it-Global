import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_provider.dart';
import '../../core/data/parent_repository.dart';
import '../../shared/models/class_timetable.dart';
import '../../shared/models/event_notice.dart';
import '../../shared/models/event_entry.dart';
import '../../shared/models/event_result.dart';


/// The current child's class timetable (read-only).
/// Errors propagate (instead of reading as "no timetable") so the screen can
/// tell "offline — retry" apart from "the school hasn't published one".
final classTimetableProvider = FutureProvider<ClassTimetable?>((ref) async {
  final student = ref.watch(currentStudentProvider);
  if (student == null || student.classroomId.isEmpty) return null;
  return ref.read(parentRepositoryProvider).timetable(student.classroomId);
});

/// Event notices addressed to the current child.
final eventNoticesProvider = FutureProvider<List<EventNotice>>((ref) async {
  final student = ref.watch(currentStudentProvider);
  if (student == null) return const [];
  try {
    return await ref.read(parentRepositoryProvider).eventNotices(student.id);
  } catch (_) {
    return const [];
  }
});

final unseenEventCountProvider = Provider<int>((ref) {
  return ref.watch(eventNoticesProvider).maybeWhen(
        data: (list) => list.where((e) => !e.isSeen).length,
        orElse: () => 0,
      );
});

/// Results of the event rooms this child took part in, once the school has
/// submitted them. Empty is the normal state for most of the year, so a
/// failure here reads as "nothing yet" rather than breaking the screen.
final childEventResultsProvider = FutureProvider<List<ChildEventResult>>((ref) async {
  final student = ref.watch(currentStudentProvider);
  if (student == null) return const [];
  try {
    return await ref.read(parentRepositoryProvider).eventResults(student.id);
  } catch (_) {
    return const [];
  }
});

/// Events with at least one category this child's class has been opened to.
/// Empty is the normal state between events.
final openEventsProvider = FutureProvider<List<OpenEvent>>((ref) async {
  final student = ref.watch(currentStudentProvider);
  if (student == null) return const [];
  try {
    return await ref.read(parentRepositoryProvider).openEvents(student.id);
  } catch (_) {
    return const [];
  }
});

/// The categories of one event, with this child's standing in each.
final openCategoriesProvider =
    FutureProvider.family<List<OpenEventCategory>, String>((ref, eventId) async {
  final student = ref.watch(currentStudentProvider);
  if (student == null) return const [];
  return ref.read(parentRepositoryProvider).openCategories(
        eventId: eventId,
        studentId: student.id,
      );
});
