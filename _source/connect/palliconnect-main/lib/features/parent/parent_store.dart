import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/data/parent_repository.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/network/supabase_service.dart';
import '../../../shared/models/activity.dart';
import '../../../shared/models/app_notification.dart';
import '../../../shared/models/attendance.dart';
import '../../../shared/models/attention.dart';
import '../profile/profile_gaps_provider.dart';
import '../../../shared/models/diary_item.dart';
import '../../../shared/models/fees.dart';
import '../../../shared/models/growth.dart';
import '../../../shared/models/homework.dart';
import '../../../shared/models/marks.dart';
import '../../../shared/models/school_day.dart';

/// One in-memory bundle of everything the parent screens read, keyed by
/// student id. Populated per student from Supabase once the parent is signed
/// in — empty until then, never placeholder content.
class ParentStore {
  const ParentStore({
    this.homework = const {},
    this.announcements = const {},
    this.attendance = const {},
    this.marks = const {},
    this.activities = const {},
    this.diary = const {},
    this.fees = const {},
    this.notifications = const {},
    this.growth = const {},
    this.stars = const {},
    this.schoolDay = const {},
    this.remoteStudents = const {},
    required this.lastSyncedAt,
  });

  final Map<String, List<HomeworkItem>> homework;
  final Map<String, List<Announcement>> announcements;
  final Map<String, AttendanceSummary> attendance;
  final Map<String, List<ExamResult>> marks;
  final Map<String, List<SchoolActivity>> activities;
  final Map<String, List<DiaryDayEntry>> diary;
  final Map<String, FeeAccount?> fees;
  final Map<String, List<AppNotification>> notifications;
  final Map<String, GrowthProfile?> growth;
  final Map<String, StarSummary> stars;
  final Map<String, SchoolDaySnapshot?> schoolDay;

  /// student ids whose data has been loaded from the backend
  final Set<String> remoteStudents;
  final DateTime lastSyncedAt;

  ParentStore copyWith({
    Map<String, List<HomeworkItem>>? homework,
    Map<String, List<Announcement>>? announcements,
    Map<String, AttendanceSummary>? attendance,
    Map<String, List<ExamResult>>? marks,
    Map<String, List<SchoolActivity>>? activities,
    Map<String, List<DiaryDayEntry>>? diary,
    Map<String, FeeAccount?>? fees,
    Map<String, List<AppNotification>>? notifications,
    Map<String, GrowthProfile?>? growth,
    Map<String, StarSummary>? stars,
    Map<String, SchoolDaySnapshot?>? schoolDay,
    Set<String>? remoteStudents,
    DateTime? lastSyncedAt,
  }) {
    return ParentStore(
      homework: homework ?? this.homework,
      announcements: announcements ?? this.announcements,
      attendance: attendance ?? this.attendance,
      marks: marks ?? this.marks,
      activities: activities ?? this.activities,
      diary: diary ?? this.diary,
      fees: fees ?? this.fees,
      notifications: notifications ?? this.notifications,
      growth: growth ?? this.growth,
      stars: stars ?? this.stars,
      schoolDay: schoolDay ?? this.schoolDay,
      remoteStudents: remoteStudents ?? this.remoteStudents,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

class ParentStoreNotifier extends StateNotifier<ParentStore> {
  ParentStoreNotifier(this._ref)
      : super(ParentStore(lastSyncedAt: DateTime.now()));

  final Ref _ref;
  RealtimeChannel? _channel;
  Timer? _debounce;
  Timer? _examDebounce;
  Timer? _libraryDebounce;
  String? _liveStudentId;
  String? _liveClassroomId;

  ParentRepository get _repo => _ref.read(parentRepositoryProvider);

  /// Live-refresh when the school changes anything about this child.
  void _subscribe(String studentId, String classroomId) {
    if (_liveStudentId == studentId && _liveClassroomId == classroomId) return;
    _teardownChannel();
    _liveStudentId = studentId;
    _liveClassroomId = classroomId;

    void bump() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 600), () {
        if (_liveStudentId != null) {
          syncFor(_liveStudentId!, _liveClassroomId ?? '');
        }
      });
    }

    try {
      final db = SupabaseService.client;
      var channel = db.channel('parent-$studentId');
      void listen(String table, String column, String value) {
        channel = channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: column,
            value: value,
          ),
          callback: (_) => bump(),
        );
      }

      listen('attendance', 'student_id', studentId);
      listen('notifications', 'student_id', studentId);
      listen('parent_notices', 'student_id', studentId);
      listen('homework_completions', 'student_id', studentId);
      listen('activities', 'student_id', studentId);
      listen('star_points', 'student_id', studentId);
      listen('growth_observations', 'student_id', studentId);
      listen('growth_skills', 'student_id', studentId);
      // Exam timetables and results: published/submitted rows only reach
      // this parent through RLS, so a publish or a submit elsewhere refreshes
      // the Exams and Results screens without a pull.
      void examChanged(PostgresChangePayload _) {
        _examDebounce?.cancel();
        _examDebounce = Timer(const Duration(milliseconds: 700), () {
          _ref.read(examFeedTickProvider.notifier).state++;
        });
      }

      // A mark row feeds both the Academics averages (store sync) and the
      // exam result statements (exam tick) — nothing else refreshes those.
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'marks',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'student_id',
          value: studentId,
        ),
        callback: (p) {
          bump();
          examChanged(p);
        },
      );
      for (final table in const ['exam_schedules', 'exam_papers']) {
        channel = channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: examChanged,
        );
      }
      if (classroomId.isNotEmpty) {
        channel = channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'exam_mark_sheets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'classroom_id',
            value: classroomId,
          ),
          callback: examChanged,
        );
      }
      // A book issued, returned or re-dated at the library desk refreshes
      // the Books borrowed card and screen.
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'library_loans',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'student_id',
          value: studentId,
        ),
        callback: (_) {
          _libraryDebounce?.cancel();
          _libraryDebounce = Timer(const Duration(milliseconds: 500), () {
            _ref.read(libraryTickProvider.notifier).state++;
          });
        },
      );
      if (classroomId.isNotEmpty) {
        listen('homework', 'classroom_id', classroomId);
        listen('diary_notes', 'classroom_id', classroomId);
        listen('class_day_summaries', 'classroom_id', classroomId);
        listen('announcements', 'classroom_id', classroomId);
      }
      channel.subscribe();
      _channel = channel;
    } catch (_) {
      // realtime unavailable — pull-to-refresh still works
    }
  }

  void _teardownChannel() {
    final c = _channel;
    _channel = null;
    if (c != null) {
      try {
        SupabaseService.client.removeChannel(c);
      } catch (_) {}
    }
  }

  /// Pull a single student's data from Supabase; keep the demo values on failure.
  Future<void> syncFor(String studentId, String classroomId) async {
    if (studentId.isEmpty) return;
    _subscribe(studentId, classroomId);
    final warn = _ref.read(currentSchoolProvider)?.attendanceWarningThreshold ?? 85;

    Future<T?> guard<T>(Future<T> Function() fn) async {
      try {
        return await fn();
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait([
      guard(() => _repo.homework(studentId, classroomId)),
      guard(() => _repo.announcements(studentId, classroomId)),
      guard(() => _repo.attendance(studentId, warn)),
      guard(() => _repo.marks(studentId)),
      guard(() => _repo.activities(studentId)),
      guard(() => _repo.diary(studentId, classroomId)),
      guard(() => _repo.fees(studentId)),
      guard(() => _repo.notifications(studentId)),
      guard(() => _repo.growth(studentId)),
      guard(() => _repo.schoolDay(classroomId)),
      guard(() => _repo.stars(studentId)),
    ]);

    final hw = results[0] as List<HomeworkItem>?;
    final ann = results[1] as List<Announcement>?;
    final att = results[2] as AttendanceSummary?;
    final mk = results[3] as List<ExamResult>?;
    final act = results[4] as List<SchoolActivity>?;
    final dia = results[5] as List<DiaryDayEntry>?;
    final fee = results[6] as FeeAccount?;
    final notif = results[7] as List<AppNotification>?;
    final grw = results[8] as GrowthProfile?;
    final day = results[9] as SchoolDaySnapshot?;
    final st = results[10] as StarSummary?;

    // Nothing came back at all (offline / RLS denied) -> leave state as-is;
    // screens show their own empty/error state rather than placeholder data.
    if (results.every((v) => v == null)) return;

    state = state.copyWith(
      homework: {...state.homework, if (hw != null) studentId: hw},
      announcements: {...state.announcements, if (ann != null) studentId: ann},
      attendance: {...state.attendance, if (att != null) studentId: att},
      marks: {...state.marks, if (mk != null) studentId: mk},
      activities: {...state.activities, if (act != null) studentId: act},
      diary: {...state.diary, if (dia != null) studentId: dia},
      fees: {...state.fees, studentId: fee},
      notifications: {...state.notifications, if (notif != null) studentId: notif},
      growth: {...state.growth, if (grw != null) studentId: grw},
      stars: {...state.stars, if (st != null) studentId: st},
      schoolDay: {...state.schoolDay, studentId: day},
      remoteStudents: {...state.remoteStudents, studentId},
      lastSyncedAt: DateTime.now(),
    );
  }

  // --- homework mutations -----------------------------------------------------

  void toggleHomework(String id) {
    final student = _ref.read(currentStudentProvider);
    if (student == null) return;
    final list = state.homework[student.id] ?? const [];
    HomeworkStatus? nextStatus;
    final updated = list.map((item) {
      if (item.id != id) return item;
      if (item.status == HomeworkStatus.pending) {
        nextStatus = HomeworkStatus.underReview;
      } else if (item.status == HomeworkStatus.underReview) {
        nextStatus = HomeworkStatus.pending;
      }
      return nextStatus == null ? item : item.copyWith(status: nextStatus);
    }).toList();
    state = state.copyWith(homework: {...state.homework, student.id: updated});
    if (nextStatus != null && state.remoteStudents.contains(student.id)) {
      _repo.setHomeworkStatus(id, student.id, nextStatus!).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _examDebounce?.cancel();
    _libraryDebounce?.cancel();
    _teardownChannel();
    super.dispose();
  }

  // --- reads (empty/null until the real fetch lands — never placeholder) ----

  List<HomeworkItem> homeworkFor(String id) => state.homework[id] ?? const [];
  List<Announcement> announcementsFor(String id) => state.announcements[id] ?? const [];
  AttendanceSummary? attendanceFor(String id) => state.attendance[id];
  List<ExamResult> marksFor(String id) => state.marks[id] ?? const [];
  List<SchoolActivity> activitiesFor(String id) => state.activities[id] ?? const [];
  List<DiaryDayEntry> diaryFor(String id) => state.diary[id] ?? const [];
  FeeAccount? feesFor(String id) => state.fees[id];
  List<AppNotification> notificationsFor(String id) => state.notifications[id] ?? const [];
  GrowthProfile? growthFor(String id) => state.growth[id];
  StarSummary starsFor(String id) => state.stars[id] ?? StarSummary.empty;
  SchoolDaySnapshot? schoolDayFor(String id) => state.schoolDay[id];

  /// Flips the notification's read state locally right away — don't wait on
  /// a realtime round-trip for a same-device tap the user just made — then
  /// persists it. `studentId` scopes which student's list to update.
  Future<void> markNotificationRead(String studentId, String notificationId) async {
    final list = state.notifications[studentId];
    if (list == null) return;
    final index = list.indexWhere((n) => n.id == notificationId);
    if (index < 0 || list[index].read) return;
    final updated = [...list];
    updated[index] = updated[index].copyWith(read: true);
    state = state.copyWith(notifications: {...state.notifications, studentId: updated});
    try {
      await _repo.markNotificationRead(notificationId);
    } catch (_) {}
  }
}

/// Bumped when an exam timetable or mark sheet this parent can see changes —
/// the exam providers watch it so they refetch on their own.
final examFeedTickProvider = StateProvider<int>((ref) => 0);

/// Bumped by realtime when the child's library loans change.
final libraryTickProvider = StateProvider<int>((ref) => 0);

final parentStoreProvider =
    StateNotifierProvider<ParentStoreNotifier, ParentStore>((ref) {
  final notifier = ParentStoreNotifier(ref);
  ref.listen<dynamic>(currentStudentProvider, (_, next) {
    if (next != null) notifier.syncFor(next.id as String, next.classroomId as String);
  }, fireImmediately: true);
  ref.listen(sessionProvider, (prev, next) {
    if (prev?.lastSyncedAt != next.lastSyncedAt) {
      final s = ref.read(currentStudentProvider);
      if (s != null) notifier.syncFor(s.id, s.classroomId);
    }
  });
  return notifier;
});

// ---------------------------------------------------------------------------
// derived, synchronous providers (unchanged signatures for the screens)
// ---------------------------------------------------------------------------

final studentHomeworkProvider = Provider<List<HomeworkItem>>((ref) {
  final student = ref.watch(currentStudentProvider);
  ref.watch(parentStoreProvider);
  if (student == null) return const [];
  return ref.read(parentStoreProvider.notifier).homeworkFor(student.id);
});

final studentAnnouncementsProvider = Provider<List<Announcement>>((ref) {
  final student = ref.watch(currentStudentProvider);
  ref.watch(parentStoreProvider);
  ref.watch(localeProvider);
  if (student == null) return const [];
  return ref.read(parentStoreProvider.notifier).announcementsFor(student.id);
});

final studentAttendanceProvider = Provider<AttendanceSummary?>((ref) {
  final student = ref.watch(currentStudentProvider);
  ref.watch(parentStoreProvider);
  if (student == null) return null;
  return ref.read(parentStoreProvider.notifier).attendanceFor(student.id);
});

final studentMarksProvider = Provider<List<ExamResult>>((ref) {
  final student = ref.watch(currentStudentProvider);
  ref.watch(parentStoreProvider);
  ref.watch(localeProvider);
  if (student == null) return const [];
  return ref.read(parentStoreProvider.notifier).marksFor(student.id);
});

final studentActivitiesProvider = Provider<List<SchoolActivity>>((ref) {
  final student = ref.watch(currentStudentProvider);
  ref.watch(parentStoreProvider);
  ref.watch(localeProvider);
  if (student == null) return const [];
  return ref.read(parentStoreProvider.notifier).activitiesFor(student.id);
});

final studentDiaryProvider = Provider<List<DiaryDayEntry>>((ref) {
  final student = ref.watch(currentStudentProvider);
  ref.watch(parentStoreProvider);
  ref.watch(localeProvider);
  if (student == null) return const [];
  return ref.read(parentStoreProvider.notifier).diaryFor(student.id);
});

final studentFeesProvider = Provider<FeeAccount?>((ref) {
  final student = ref.watch(currentStudentProvider);
  ref.watch(parentStoreProvider);
  if (student == null) return null;
  return ref.read(parentStoreProvider.notifier).feesFor(student.id);
});

final studentNotificationsProvider = Provider<List<AppNotification>>((ref) {
  final student = ref.watch(currentStudentProvider);
  ref.watch(parentStoreProvider);
  ref.watch(localeProvider);
  if (student == null) return const [];
  return ref.read(parentStoreProvider.notifier).notificationsFor(student.id);
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  // Message alerts get their own badge on the Messages tab instead.
  return ref
      .watch(studentNotificationsProvider)
      .where((n) => !n.read && !n.isMessageAlert)
      .length;
});

final studentGrowthProvider = Provider<GrowthProfile?>((ref) {
  final student = ref.watch(currentStudentProvider);
  ref.watch(parentStoreProvider);
  ref.watch(localeProvider);
  if (student == null) return null;
  return ref.read(parentStoreProvider.notifier).growthFor(student.id);
});

final studentStarsProvider = Provider<StarSummary>((ref) {
  final student = ref.watch(currentStudentProvider);
  ref.watch(parentStoreProvider);
  if (student == null) return StarSummary.empty;
  return ref.read(parentStoreProvider.notifier).starsFor(student.id);
});

/// True once the current child's data has come back from the school at least
/// once — lets screens tell "still loading" apart from "nothing recorded".
final studentLoadedProvider = Provider<bool>((ref) {
  final student = ref.watch(currentStudentProvider);
  final store = ref.watch(parentStoreProvider);
  return student != null && store.remoteStudents.contains(student.id);
});

final studentSchoolDayProvider = Provider<SchoolDaySnapshot?>((ref) {
  final student = ref.watch(currentStudentProvider);
  ref.watch(parentStoreProvider);
  ref.watch(localeProvider);
  if (student == null) return null;
  return ref.read(parentStoreProvider.notifier).schoolDayFor(student.id);
});

final attentionItemsProvider = Provider<List<AttentionItem>>((ref) {
  final homework = ref.watch(studentHomeworkProvider);
  final profileGaps = ref.watch(familyProfileGapsProvider);
  final fees = ref.watch(studentFeesProvider);
  final announcements = ref.watch(studentAnnouncementsProvider);
  final attendance = ref.watch(studentAttendanceProvider);
  final locale = ref.watch(localeProvider).languageCode;
  final isTamil = locale == 'ta';

  final items = <AttentionItem>[];
  final now = DateTime.now();

  // What the school is still waiting on from this family. It leads: unlike a
  // homework reminder it has been outstanding for weeks, and nothing else in
  // the app will ever ask for it.
  if (profileGaps.isNotEmpty) {
    final critical = profileGaps.where((g) => g.isCritical).length;
    items.add(AttentionItem(
      kind: AttentionKind.profile,
      title: isTamil ? 'பள்ளிக்குத் தேவையான விவரங்கள்' : 'Details the school needs',
      subtitle: critical > 0
          ? (isTamil
              ? '${profileGaps.length} விவரங்கள் — $critical அவசரம்'
              : '${profileGaps.length} missing · $critical urgent')
          : (isTamil
              ? '${profileGaps.length} விவரங்கள் நிரப்பப்படவில்லை'
              : '${profileGaps.length} still to fill in'),
      deepLink: 'profile-gaps',
    ));
  }

  for (final h in homework) {
    final u = h.urgencyOn(now);
    if (u == HomeworkUrgency.overdue) {
      items.add(AttentionItem(
        kind: AttentionKind.homeworkOverdue,
        title: isTamil ? '${h.subject} வீட்டுப்பாடம்' : '${h.subject} homework',
        subtitle: isTamil ? 'தாமதம்' : 'Overdue',
        deepLink: 'homework:${h.id}',
      ));
    } else if (u == HomeworkUrgency.dueToday) {
      items.add(AttentionItem(
        kind: AttentionKind.homeworkToday,
        title: isTamil ? '${h.subject} வீட்டுப்பாடம்' : '${h.subject} homework',
        subtitle: isTamil ? 'இன்று கடைசி நாள்' : 'Due today',
        deepLink: 'homework:${h.id}',
      ));
    }
  }

  if (fees != null && fees.hasDue && fees.nextDueDate != null) {
    final days = fees.nextDueDate!.difference(DateTime(now.year, now.month, now.day)).inDays;
    items.add(AttentionItem(
      kind: AttentionKind.fee,
      title: isTamil ? 'பள்ளிக் கட்டணம்' : 'School fee',
      subtitle: days <= 0
          ? (isTamil ? 'இன்று செலுத்த வேண்டும்' : 'Due today')
          : (isTamil ? '$days நாட்களில் செலுத்த வேண்டும்' : 'Due in $days days'),
      deepLink: 'fees',
    ));
  }

  for (final a in announcements.where((a) => a.important)) {
    items.add(AttentionItem(
      kind: AttentionKind.announcement,
      title: a.title,
      subtitle: a.body,
      deepLink: 'announcement:${a.id}',
    ));
  }

  if (attendance != null && attendance.needsAttention) {
    items.add(AttentionItem(
      kind: AttentionKind.attendance,
      title: isTamil ? 'வருகை' : 'Attendance',
      subtitle: isTamil ? 'வருகை கவனம் தேவை.' : 'Attendance requires attention.',
      deepLink: 'attendance',
    ));
  }

  return items;
});
