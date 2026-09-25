import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/supabase_service.dart';
import '../../shared/models/activity.dart';
import '../../shared/models/app_notification.dart';
import '../../shared/models/attendance.dart';
import '../../shared/models/attention.dart';
import '../../shared/models/diary_item.dart';
import '../../shared/models/fees.dart';
import '../../shared/models/growth.dart';
import '../../shared/models/homework.dart';
import '../../shared/models/exams.dart';
import '../../shared/models/marks.dart';
import '../../shared/models/class_timetable.dart';
import '../../shared/models/event_notice.dart';
import '../../shared/models/library_loan.dart';
import '../../shared/models/event_entry.dart';
import '../../shared/models/event_result.dart';
import '../../shared/models/school.dart';
import '../../shared/models/school_day.dart';
import '../../shared/models/student.dart';

/// Talks to the shared Supabase schema and maps rows into PalliConnect models.
///
/// Every method throws on transport / mapping failure — [ParentStoreNotifier]
/// and [SessionNotifier] catch these and surface a real offline/error state;
/// there is no demo-data fallback.
class ParentRepository {
  ParentRepository(SupabaseClient? db) : _client = db;
  final SupabaseClient? _client;

  /// Throws when the backend was never initialised — callers catch it and show
  /// their offline / error state.
  SupabaseClient get _db =>
      _client ?? (throw StateError('Supabase not initialised'));

  static ParentRepository create() =>
      ParentRepository(SupabaseService.isReady ? SupabaseService.client : null);

  // ---------------------------------------------------------------------------
  // lookups (fetched once per load, reused across mappers)
  // ---------------------------------------------------------------------------

  Future<_Lookups> _lookups() async {
    // These three are independent reads — firing them together instead of
    // one after another cuts this to one round trip's worth of latency.
    final results = await Future.wait<dynamic>([
      _db.from('classrooms').select(),
      _db.from('teachers').select(),
      _db.from('school_settings').select().maybeSingle(),
    ]);
    final classrooms = (results[0] as List).cast<Map<String, dynamic>>();
    final teachers = (results[1] as List).cast<Map<String, dynamic>>();
    final settings = results[2] as Map<String, dynamic>?;
    return _Lookups(
      classrooms: {for (final c in classrooms) c['id'] as String: c},
      teacherNames: {for (final t in teachers) t['id'] as String: (t['name'] ?? '') as String},
      settings: settings,
    );
  }

  // ---------------------------------------------------------------------------
  // auth
  // ---------------------------------------------------------------------------

  /// The signed-in parent's own account row (RLS restricts this to exactly
  /// one row — their own). Null if not signed in or not yet linked.
  Future<Map<String, dynamic>?> myParentAccount() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return null;
    return _db
        .from('parent_accounts')
        .select('student_id, register_number, is_active, must_change_password')
        .eq('auth_user_id', uid)
        .maybeSingle();
  }

  // ---------------------------------------------------------------------------
  // students / school
  // ---------------------------------------------------------------------------

  Future<({List<Student> students, School school})> bootstrap() async {
    // _lookups() and the students read don't depend on each other either —
    // run them concurrently rather than lookups-then-students.
    final results = await Future.wait<dynamic>([
      _lookups(),
      _db.from('students').select().order('name'),
    ]);
    final lk = results[0] as _Lookups;
    final rows = (results[1] as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty) {
      throw StateError('no students in project');
    }
    final students = rows.map((r) => _student(r, lk)).toList();
    final s = lk.settings;
    final school = School(
      id: 'school',
      name: (s?['name'] ?? 'School') as String,
      logoUrl: (s?['logo_url'] ?? '') as String,
      primaryColorHex: (s?['primary_color_hex'] ?? '#2F6BFF') as String,
      attendanceWarningThreshold: (s?['attendance_warning_threshold'] ?? 85) as int,
      enabledFeatures: ((s?['enabled_features'] as List?)?.cast<String>()) ??
          const ['diary', 'homework', 'attendance', 'fees', 'marks', 'activities',
                 'growth', 'stars', 'notifications', 'announcements', 'messages', 'timetable',
                 'events', 'bus_tracking'],
    );
    return (students: students, school: school);
  }

  Student _student(Map<String, dynamic> r, _Lookups lk) {
    final classroom = lk.classrooms[r['classroom_id']];
    final teacherId = classroom?['class_teacher_id'] as String?;
    return Student(
      id: r['id'] as String,
      schoolId: 'school',
      admissionNo: (r['admission_no'] ?? r['roll_number'] ?? '') as String,
      rollNo: (r['roll_number'] ?? '') as String,
      fullName: (r['name'] ?? '') as String,
      photoUrl: r['photo_url'] as String?,
      className: (classroom?['grade_key'] ?? '') as String,
      sectionName: (classroom?['section'] ?? '') as String,
      academicYear: (r['academic_year_id'] ?? '2026-2027') as String,
      bloodGroup: r['blood_group'] as String?,
      classTeacher: teacherId == null ? null : lk.teacherNames[teacherId],
      classroomId: (r['classroom_id'] ?? '') as String,
      gender: r['gender'] as String?,
      dob: _date(r['dob']),
      address: r['address'] as String?,
      emergencyContact: r['emergency_contact'] as String?,
      needsTransport: r['needs_transport'] as bool?,
    );
  }

  // ---------------------------------------------------------------------------
  // homework  (+ per-student completion state)
  // ---------------------------------------------------------------------------

  Future<List<HomeworkItem>> homework(String studentId, String classroomId) async {
    final lk = await _lookups();
    final rows = await _db
        .from('homework')
        .select()
        .or('classroom_id.eq.$classroomId,student_id.eq.$studentId')
        .order('due_date', ascending: false);
    final completions = await _db
        .from('homework_completions')
        .select()
        .eq('student_id', studentId);
    final statusById = <String, Map<String, dynamic>>{
      for (final c in completions) c['homework_id'] as String: c,
    };
    return rows.where((r) => r['student_id'] == null || r['student_id'] == studentId).map((r) {
      final c = statusById[r['id']];
      return HomeworkItem(
        id: r['id'] as String,
        studentId: studentId,
        subject: (r['subject'] ?? '') as String,
        title: (r['title'] ?? '') as String,
        instructions: (r['description'] ?? '') as String,
        teacherName: lk.teacherNames[r['created_by']] ?? '',
        assignedOn: _date(r['created_at']) ?? DateTime.now(),
        dueDate: _date(r['due_date']) ?? DateTime.now(),
        status: _homeworkStatus(c?['status'] as String?),
        hasAttachment: r['attachment_url'] != null,
        completedAt: _date(c?['reviewed_at']),
      );
    }).toList();
  }

  /// parent submits / un-submits — pending <-> under_review
  Future<void> setHomeworkStatus(String homeworkId, String studentId, HomeworkStatus status) async {
    await _db.from('homework_completions').upsert({
      'homework_id': homeworkId,
      'student_id': studentId,
      'status': _homeworkStatusName(status),
      'submitted_at': status == HomeworkStatus.underReview
          ? DateTime.now().toIso8601String()
          : null,
    }, onConflict: 'homework_id,student_id');
  }

  // ---------------------------------------------------------------------------
  // announcements
  // ---------------------------------------------------------------------------

  Future<List<Announcement>> announcements(String studentId, String classroomId) async {
    final rows = await _db
        .from('announcements')
        .select()
        .inFilter('target', ['overall', 'parents', 'students'])
        .order('created_at', ascending: false);
    final now = DateTime.now();
    return rows.where((r) {
      final expires = _date(r['expires_at']);
      if (expires != null && expires.isBefore(now)) return false;
      if (r['scope'] == 'classroom') return r['classroom_id'] == classroomId;
      return true;
    }).map((r) => Announcement(
          id: r['id'] as String,
          studentId: studentId,
          title: (r['title'] ?? '') as String,
          body: (r['content'] ?? '') as String,
          date: _date(r['created_at']) ?? now,
          important: (r['is_important'] ?? false) as bool,
        )).toList();
  }

  // ---------------------------------------------------------------------------
  // attendance
  // ---------------------------------------------------------------------------

  Future<AttendanceSummary> attendance(String studentId, int warningThreshold) async {
    final rows = await _db
        .from('attendance')
        .select()
        .eq('student_id', studentId)
        .order('date', ascending: false)
        .limit(120);
    // One school day is one attendance figure. Counting rows instead meant a
    // day with a roll call plus six per-period rows counted seven times, which
    // both inflated the totals and let a single absent period drag the
    // percentage down. The homeroom roll call is the day's answer; anything
    // else only fills in a day it never covered.
    final days = <DateTime, AttendanceMark>{};
    final fromRollCall = <DateTime>{};
    for (final r in rows) {
      final d = _date(r['date']);
      if (d == null) continue;
      final key = DateTime(d.year, d.month, d.day);
      final mark = _attendanceMark(r['status'] as String?);
      if (mark == AttendanceMark.none) continue;
      final isRollCall = (r['period_id'] as String?) == 'homeroom';
      if (isRollCall) {
        days[key] = mark;
        fromRollCall.add(key);
        continue;
      }
      if (fromRollCall.contains(key)) continue;
      // Among per-period rows for one day, an absence is the one worth
      // showing — a child marked away for any period was away.
      final existing = days[key];
      if (existing == null || mark == AttendanceMark.absent) days[key] = mark;
    }

    var present = 0, absent = 0, leave = 0;
    for (final mark in days.values) {
      switch (mark) {
        case AttendanceMark.present:
          present++;
        case AttendanceMark.absent:
          absent++;
        case AttendanceMark.leave:
          leave++;
        case AttendanceMark.none:
          break;
      }
    }
    final counted = present + absent + leave;
    final percent = counted == 0 ? 100 : ((present / counted) * 100).round();
    return AttendanceSummary(
      present: present,
      absent: absent,
      leave: leave,
      percent: percent,
      warningThreshold: warningThreshold,
      days: days,
    );
  }

  // ---------------------------------------------------------------------------
  // marks
  // ---------------------------------------------------------------------------

  Future<List<ExamResult>> marks(String studentId) async {
    final rows = await _db
        .from('marks')
        .select()
        .eq('student_id', studentId)
        // An absent paper isn't a zero — it belongs on the exam's own result
        // statement, not in the subject averages.
        .eq('is_absent', false)
        // Grades-only exam rows carry no score (total 0) and would divide by
        // zero in the averages; they live on the result statement instead.
        .gt('total_marks', 0)
        .order('date', ascending: false);
    return rows.map((r) => ExamResult(
          examName: (r['test_type'] ?? 'Test') as String,
          examGroup: ((r['exam_id'] ?? '') as String).isEmpty
              ? 'unit'
              : r['exam_id'] as String,
          subject: (r['subject'] ?? '') as String,
          scored: _num(r['score']).round(),
          maxMarks: _num(r['total_marks'], fallback: 100).round(),
        )).toList();
  }

  // ---------------------------------------------------------------------------
  // activities
  // ---------------------------------------------------------------------------

  Future<List<SchoolActivity>> activities(String studentId) async {
    final rows = await _db
        .from('activities')
        .select()
        .eq('student_id', studentId)
        .order('date', ascending: false);
    return rows.map((r) => SchoolActivity(
          id: r['id'] as String,
          studentId: studentId,
          name: (r['name'] ?? '') as String,
          date: _date(r['date']) ?? DateTime.now(),
          category: (r['category'] ?? '') as String,
          achievement: r['achievement'] as String?,
          result: r['result'] as String?,
          teacherRemarks: r['teacher_remarks'] as String?,
          documentLabel: r['document_label'] as String?,
        )).toList();
  }

  // ---------------------------------------------------------------------------
  // diary
  // ---------------------------------------------------------------------------

  Future<List<DiaryDayEntry>> diary(String studentId, String classroomId) async {
    final rows = await _db
        .from('diary_notes')
        .select()
        .or('classroom_id.eq.$classroomId,student_id.eq.$studentId')
        .order('note_date', ascending: false)
        .limit(80);
    return rows.where((r) => r['student_id'] == null || r['student_id'] == studentId).map((r) {
      return DiaryDayEntry(
        id: r['id'] as String,
        studentId: studentId,
        date: _date(r['note_date']) ?? DateTime.now(),
        kind: _diaryKind(r['kind'] as String?),
        title: (r['title'] ?? '') as String,
        body: (r['body'] ?? '') as String,
        teacherName: r['teacher_name'] as String?,
        hasAttachment: (r['has_attachment'] ?? false) as bool,
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // fees
  // ---------------------------------------------------------------------------

  Future<FeeAccount?> fees(String studentId) async {
    final ledger = await _db
        .from('student_fee_ledger')
        .select()
        .eq('student_id', studentId)
        .maybeSingle();
    final payments = await _db
        .from('fee_payments')
        .select()
        .eq('student_id', studentId)
        .order('paid_on', ascending: false);
    if (ledger == null && payments.isEmpty) return null;

    final tuitionTotal = _num(ledger?['tuition_due']).round();
    final tuitionPaid = _num(ledger?['tuition_paid']).round();
    final eventTotal = _num(ledger?['event_due']).round();
    final eventPaid = _num(ledger?['event_paid']).round();

    final categories = <FeeCategory>[
      FeeCategory(nameKey: 'tuition', total: tuitionTotal, paid: tuitionPaid),
      if (eventTotal > 0)
        FeeCategory(nameKey: 'activity', total: eventTotal, paid: eventPaid),
    ];

    final history = payments.map((p) => PaymentRecord(
          date: _date(p['paid_on']) ?? DateTime.now(),
          amount: _num(p['amount']).round(),
          status: _paymentStatus(p['status'] as String?),
          receiptId: (p['receipt_no'] ?? p['id'] ?? '') as String,
        )).toList();

    // next due = earliest unpaid event pay date
    DateTime? nextDue;
    if (eventTotal > eventPaid) {
      final notices = await _db
          .from('parent_notices')
          .select('event_id, school_events(last_pay_date)')
          .eq('student_id', studentId);
      for (final n in notices) {
        final ev = n['school_events'];
        final d = ev is Map ? _date(ev['last_pay_date']) : null;
        if (d == null) continue;
        final current = nextDue;
        if (current == null || d.isBefore(current)) nextDue = d;
      }
    }

    return FeeAccount(
      studentId: studentId,
      academicYear: '2026-2027',
      categories: categories,
      history: history,
      nextDueDate: nextDue,
    );
  }

  Future<void> recordOnlinePayment({
    required String studentId,
    required int amountInr,
    String? razorpayOrderId,
    String? razorpayPaymentId,
  }) async {
    await _db.from('fee_payments').insert({
      'id': 'pay-${DateTime.now().millisecondsSinceEpoch}',
      'student_id': studentId,
      'amount': amountInr,
      'kind': 'tuition',
      'method': 'razorpay',
      'status': razorpayPaymentId == null ? 'pending' : 'success',
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'note': 'Paid in app',
    });
  }

  // ---------------------------------------------------------------------------
  // notifications
  // ---------------------------------------------------------------------------

  Future<List<AppNotification>> notifications(String studentId) async {
    final rows = await _db
        .from('notifications')
        .select()
        .eq('recipient_role', 'parent')
        .eq('student_id', studentId)
        .order('created_at', ascending: false)
        .limit(60);
    return rows.map((r) => AppNotification(
          id: r['id'] as String,
          studentId: studentId,
          kind: _notificationKind(r['kind'] as String?),
          title: (r['title'] ?? '') as String,
          body: (r['body'] ?? '') as String,
          createdAt: _date(r['created_at']) ?? DateTime.now(),
          deepLink: (r['deep_link'] ?? '') as String,
          grouped: (r['grouped'] ?? false) as bool,
          groupCount: r['group_count'] as int?,
          important: (r['is_important'] ?? false) as bool,
          read: r['read_at'] != null,
        )).toList();
  }

  Future<void> markNotificationRead(String id) async {
    await _db.from('notifications').update({'read_at': DateTime.now().toIso8601String()}).eq('id', id);
  }

  // ---------------------------------------------------------------------------
  // growth
  // ---------------------------------------------------------------------------

  Future<GrowthProfile> growth(String studentId) async {
    final results = await Future.wait<dynamic>([
      _db
          .from('growth_observations')
          .select()
          .eq('student_id', studentId)
          .order('date', ascending: false)
          .limit(100),
      _db.from('growth_skills').select().eq('student_id', studentId).order('name'),
    ]);
    final obs = (results[0] as List).cast<Map<String, dynamic>>();
    final skills = (results[1] as List).cast<Map<String, dynamic>>();
    return GrowthProfile(
      observations: obs.map((o) => GrowthObservation(
            id: (o['id'] ?? '') as String,
            title: (o['title'] ?? 'Note') as String,
            body: (o['body'] ?? '') as String,
            source: (o['source'] ?? '') as String,
            date: _date(o['date']) ?? DateTime.now(),
            tone: switch (o['tone']) {
              'attention' => ObservationTone.attention,
              'neutral' => ObservationTone.neutral,
              _ => ObservationTone.positive,
            },
            category: (o['category'] ?? '') as String,
          )).toList(),
      skills: skills.map((s) => AssessedSkill(
            name: (s['name'] ?? '') as String,
            level: (s['level'] ?? '') as String,
            category: (s['category'] ?? '') as String,
            updatedAt: _date(s['updated_at']),
          )).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // star points
  // ---------------------------------------------------------------------------

  Future<StarSummary> stars(String studentId) async {
    final rows = await _db
        .from('star_points')
        .select()
        .eq('student_id', studentId)
        .order('created_at', ascending: false)
        .limit(300);
    return StarSummary(rows.map((r) => StarAward(
          id: r['id'] as String,
          points: (r['points'] as num?)?.toInt() ?? 1,
          reason: (r['reason'] ?? '') as String,
          teacherName: (r['awarded_by_name'] ?? '') as String,
          date: _date(r['created_at']) ?? DateTime.now(),
        )).toList());
  }

  // ---------------------------------------------------------------------------
  // class timetable (read-only)
  // ---------------------------------------------------------------------------

  Future<ClassTimetable?> timetable(String classroomId) async {
    if (classroomId.isEmpty) return null;
    final rows = await _db
        .from('timetables')
        .select()
        .eq('classroom_id', classroomId)
        .order('is_active', ascending: false);
    if (rows.isEmpty) return null;
    final active = rows.firstWhere(
      (r) => r['is_active'] == true,
      orElse: () => rows.first,
    );
    final teachers = await _db.from('teachers').select('id, name');
    final names = {for (final t in teachers) t['id'] as String: (t['name'] ?? '') as String};
    final tt = ClassTimetable.fromRow(Map<String, dynamic>.from(active));
    return ClassTimetable(
      id: tt.id,
      classroomId: tt.classroomId,
      name: tt.name,
      startTime: tt.startTime,
      endTime: tt.endTime,
      periods: tt.periods
          .map((p) => p.withTeacher(names[p.staffId]))
          .toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // events & notices
  // ---------------------------------------------------------------------------

  /// Every library book this child has borrowed, newest first. RLS limits
  /// the rows to this parent's own child whatever the filter says.
  Future<List<LibraryLoan>> libraryLoans(String studentId) async {
    final rows = await _db
        .from('library_loans')
        .select('id, book_title, book_author, book_publisher, issued_at, due_date, returned_at')
        .eq('borrower_kind', 'student')
        .eq('student_id', studentId)
        .order('issued_at', ascending: false);
    return rows.map(LibraryLoan.fromJson).toList();
  }

  Future<List<EventNotice>> eventNotices(String studentId) async {
    final rows = await _db
        .from('parent_notices')
        .select('*, school_events(*)')
        .eq('student_id', studentId)
        .order('created_at', ascending: false);
    return rows.map((r) {
      final ev = (r['school_events'] is Map)
          ? Map<String, dynamic>.from(r['school_events'] as Map)
          : <String, dynamic>{};
      return EventNotice(
        id: r['id'] as String,
        eventId: (r['event_id'] ?? '') as String,
        title: (r['title'] ?? ev['name'] ?? 'Event') as String,
        body: (r['body'] ?? '') as String,
        description: (ev['description'] ?? '') as String,
        eventDate: _date(ev['event_date']) ?? _date(r['created_at']) ?? DateTime.now(),
        lastPayDate: _date(ev['last_pay_date']),
        feeAmount: _num(ev['fee_amount']),
        seenAt: _date(r['seen_at']),
        createdAt: _date(r['created_at']) ?? DateTime.now(),
      );
    }).toList();
  }

  /// Events with at least one category this child's class has been opened
  /// to, or that they are already entered in.
  ///
  /// RLS does the filtering: `event_categories` only returns rows open to
  /// their classroom or rows their child is in, so anything that comes back
  /// is already theirs to see.
  Future<List<OpenEvent>> openEvents(String studentId) async {
    final categories = await _db
        .from('event_categories')
        .select('id, event_id, school_events(id, name, description, event_date)');
    if (categories.isEmpty) return const [];

    final mine = await _db
        .from('event_participants')
        .select('category_id')
        .eq('student_id', studentId);
    final enteredCategories = {for (final m in mine) m['category_id'] as String};

    final byEvent = <String, OpenEvent>{};
    final counted = <String, int>{};
    final entered = <String, int>{};
    for (final c in categories) {
      final ev = c['school_events'];
      if (ev is! Map) continue;
      final e = Map<String, dynamic>.from(ev);
      final id = (e['id'] ?? '') as String;
      if (id.isEmpty) continue;
      counted[id] = (counted[id] ?? 0) + 1;
      if (enteredCategories.contains(c['id'])) {
        entered[id] = (entered[id] ?? 0) + 1;
      }
      byEvent[id] = OpenEvent(
        id: id,
        name: (e['name'] ?? 'Event') as String,
        description: (e['description'] ?? '') as String,
        eventDate: _date(e['event_date']) ?? DateTime.now(),
      );
    }
    final out = [
      for (final e in byEvent.values)
        OpenEvent(
          id: e.id,
          name: e.name,
          description: e.description,
          eventDate: e.eventDate,
          categoryCount: counted[e.id] ?? 0,
          enteredCount: entered[e.id] ?? 0,
        ),
    ]..sort((a, b) => a.eventDate.compareTo(b.eventDate));
    return out;
  }

  /// The categories of one event this child may enter, with their current
  /// standing in each.
  Future<List<OpenEventCategory>> openCategories({
    required String eventId,
    required String studentId,
  }) async {
    final categories = await _db
        .from('event_categories')
        .select('id, event_id, name, description, kind, issues_certificates')
        .eq('event_id', eventId)
        .order('name');
    if (categories.isEmpty) return const [];

    final ids = [for (final c in categories) c['id'] as String];
    final mine = await _db
        .from('event_participants')
        .select('id, category_id, self_registered')
        .eq('student_id', studentId)
        .inFilter('category_id', ids);
    final entryByCategory = {for (final m in mine) m['category_id'] as String: m};

    // Once the head has put them in a room, withdrawing is no longer theirs.
    final myEntryIds = [for (final m in mine) m['id'] as String];
    final inRooms = myEntryIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _db
            .from('event_room_participants')
            .select('participant_id')
            .inFilter('participant_id', myEntryIds);
    final placed = {for (final r in inRooms) r['participant_id'] as String};

    // Entries close on the day, which is a property of the event, not of
    // each category — so one date read answers it for all of them. This
    // only decides whether the button is offered; the database checks it
    // again on the insert, so a stale screen cannot slip one through.
    final event = await _db
        .from('school_events')
        .select('event_date')
        .eq('id', eventId)
        .maybeSingle();
    final eventDay = _date(event?['event_date']);
    final today = DateTime.now();
    final stillOpen = eventDay != null &&
        !DateTime(eventDay.year, eventDay.month, eventDay.day).isBefore(
          DateTime(today.year, today.month, today.day),
        );

    return [
      for (final c in categories)
        () {
          final id = c['id'] as String;
          final entry = entryByCategory[id];
          return OpenEventCategory(
            id: id,
            eventId: (c['event_id'] ?? '') as String,
            name: (c['name'] ?? 'Category') as String,
            description: (c['description'] ?? '') as String,
            competitive: (c['kind'] ?? 'competitive') != 'non_competitive',
            issuesCertificates: c['issues_certificates'] != false,
            participantId: entry?['id'] as String?,
            selfRegistered: entry?['self_registered'] == true,
            acceptingEntries: stillOpen,
            inRoom: entry != null && placed.contains(entry['id']),
          );
        }(),
    ];
  }

  /// Enters this child. The database checks again that the category is open
  /// to their class and still taking entries, so a stale screen cannot slip
  /// one through.
  Future<void> enterCategory({
    required String categoryId,
    required String studentId,
    required String classroomId,
  }) async {
    await _db.from('event_participants').insert({
      'id': 'ep_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      'category_id': categoryId,
      'student_id': studentId,
      'classroom_id': classroomId,
      'self_registered': true,
    });
  }

  Future<void> withdrawFromCategory(String participantId) async {
    await _db.from('event_participants').delete().eq('id', participantId);
  }

  /// Every submitted event room this child was in, newest first.
  ///
  /// RLS decides what comes back: a room is only visible once it has been
  /// submitted and this child was in it, so there is nothing to filter here
  /// beyond joining up the names.
  Future<List<ChildEventResult>> eventResults(String studentId) async {
    final entries = await _db
        .from('event_participants')
        .select('id, category_id, classroom_id, event_categories(id, name, event_id, kind)')
        .eq('student_id', studentId);
    if (entries.isEmpty) return const [];

    final participantIds = [for (final e in entries) e['id'] as String];
    final links = await _db
        .from('event_room_participants')
        .select('room_id, participant_id')
        .inFilter('participant_id', participantIds);
    if (links.isEmpty) return const [];

    final roomIds = {for (final l in links) l['room_id'] as String}.toList();
    final rooms = await _db
        .from('event_rooms')
        .select('id, name, category_id, status, prize_count, submitted_at')
        .inFilter('id', roomIds)
        .eq('status', 'submitted');
    if (rooms.isEmpty) return const [];

    final visibleRoomIds = [for (final r in rooms) r['id'] as String];
    final results = await _db
        .from('event_results')
        .select('room_id, position, participant_id')
        .inFilter('room_id', visibleRoomIds);
    final certificates = await _db
        .from('event_certificates')
        .select('room_id, layout_id')
        .inFilter('room_id', visibleRoomIds);

    final eventIds = <String>{};
    final categoryOf = <String, Map<String, dynamic>>{};
    for (final e in entries) {
      final cat = e['event_categories'];
      if (cat is Map) {
        final m = Map<String, dynamic>.from(cat);
        categoryOf[e['category_id'] as String] = m;
        final ev = (m['event_id'] ?? '') as String;
        if (ev.isNotEmpty) eventIds.add(ev);
      }
    }
    final events = eventIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _db
            .from('school_events')
            .select('id, name, event_date')
            .inFilter('id', eventIds.toList());
    final eventById = {for (final e in events) e['id'] as String: e};

    final participantByRoom = <String, String>{
      for (final l in links) '${l['room_id']}': l['participant_id'] as String,
    };
    final categoryByParticipant = {
      for (final e in entries) e['id'] as String: e['category_id'] as String,
    };
    final classroomByParticipant = {
      for (final e in entries) e['id'] as String: (e['classroom_id'] ?? '') as String,
    };
    final placeByRoom = <String, int>{};
    for (final r in results) {
      final room = r['room_id'] as String;
      if (participantByRoom[room] == r['participant_id']) {
        placeByRoom[room] = (r['position'] as num).toInt();
      }
    }
    final layoutByRoom = {
      for (final c in certificates) c['room_id'] as String: c['layout_id'] as String,
    };
    final classrooms = await _classroomNames();

    final out = <ChildEventResult>[];
    for (final room in rooms) {
      final roomId = room['id'] as String;
      final participantId = participantByRoom[roomId];
      if (participantId == null) continue;
      final categoryId = categoryByParticipant[participantId] ?? '';
      final category = categoryOf[categoryId];
      final eventId = (category?['event_id'] ?? '') as String;
      final event = eventById[eventId];
      out.add(ChildEventResult(
        roomId: roomId,
        roomName: (room['name'] ?? '') as String,
        categoryId: categoryId,
        categoryName: (category?['name'] ?? 'Event') as String,
        eventId: eventId,
        eventName: (event?['name'] ?? 'Event') as String,
        eventDate: _date(event?['event_date']) ?? DateTime.now(),
        classLabel: classrooms[classroomByParticipant[participantId]] ?? '',
        position: placeByRoom[roomId],
        competitive: (category?['kind'] ?? 'competitive') != 'non_competitive',
        prizeCount: ((room['prize_count'] ?? 3) as num).toInt(),
        certificateLayoutId: layoutByRoom[roomId],
        submittedAt: _date(room['submitted_at']),
      ));
    }
    out.sort((a, b) => b.eventDate.compareTo(a.eventDate));
    return out;
  }

  /// How many papers are on the child's file. Used only to decide whether to
  /// keep asking for them.
  Future<int> documentCount(String studentId) async {
    final rows = await _db
        .from('person_documents')
        .select('id')
        .eq('owner_type', 'student')
        .eq('owner_id', studentId);
    return rows.length;
  }

  /// True once the school has a bus and both stops on record.
  Future<bool> hasTransportDetails(String studentId) async {
    final row = await _db
        .from('student_transport')
        .select('bus_id, pickup_location, drop_location')
        .eq('student_id', studentId)
        .maybeSingle();
    if (row == null) return false;
    bool has(Object? v) => v != null && v.toString().trim().isNotEmpty;
    return has(row['bus_id']) && has(row['pickup_location']) && has(row['drop_location']);
  }

  /// The details a family can answer for themselves. Deliberately a narrow
  /// list — a parent cannot edit their child's class, fees or register number.
  Future<void> updateOwnChildDetails({
    String? gender,
    String? bloodGroup,
    DateTime? dob,
    String? address,
    String? emergencyContact,
    String? emergencyContactAlt,
    bool? needsTransport,
    String? photoUrl,
  }) async {
    final patch = <String, dynamic>{
      if (gender != null) 'gender': gender,
      if (bloodGroup != null) 'blood_group': bloodGroup,
      if (dob != null) 'dob': dob,
      if (address != null) 'address': address,
      if (emergencyContact != null) 'emergency_contact': emergencyContact,
      if (emergencyContactAlt != null) 'emergency_contact_alt': emergencyContactAlt,
      if (needsTransport != null) 'needs_transport': needsTransport,
      if (photoUrl != null) 'photo_url': photoUrl,
    };
    if (patch.isEmpty) return;
    // Through an RPC, not a direct update: row-level security decides which
    // rows a caller may touch, not which columns, so a policy loose enough to
    // allow a blood group would also allow rewriting fees. The function is
    // the column allowlist.
    await _db.rpc('parent_update_child_details', params: {
      'p_gender': gender,
      'p_blood_group': bloodGroup,
      'p_dob': dob?.toIso8601String(),
      'p_address': address,
      'p_emergency_contact': emergencyContact,
      'p_emergency_contact_alt': emergencyContactAlt,
      'p_needs_transport': needsTransport,
      'p_photo_url': photoUrl,
    });
  }

  Future<Map<String, String>> _classroomNames() async {
    final rows = await _db.from('classrooms').select('id, name');
    return {for (final r in rows) r['id'] as String: (r['name'] ?? '') as String};
  }

  Future<void> markNoticeSeen(String noticeId) async {
    await _db
        .from('parent_notices')
        .update({'seen_at': DateTime.now().toIso8601String()})
        .eq('id', noticeId);
  }

  // ---------------------------------------------------------------------------
  // exam timetables + results
  // ---------------------------------------------------------------------------

  /// Every published exam timetable this parent may see (RLS: their child's
  /// standard, or one the child has marks in), with its papers. Two reads.
  Future<List<ParentExam>> examTimetables() async {
    final results = await Future.wait<dynamic>([
      _db
          .from('exam_schedules')
          .select('exam_id, grade_key, first_date, last_date, published_at, exams(name, result_mode, grade_scale)')
          .eq('status', 'published'),
      _db.from('exam_papers').select(
          'id, exam_id, grade_key, subject, exam_date, start_time, end_time, syllabus, max_marks, pass_marks'),
    ]);
    final schedules = (results[0] as List).cast<Map<String, dynamic>>();
    final papers = (results[1] as List).cast<Map<String, dynamic>>();
    final byKey = <String, List<ExamPaper>>{};
    for (final p in papers) {
      final date = _date(p['exam_date']);
      if (date == null) continue;
      byKey.putIfAbsent('${p['exam_id']}|${p['grade_key']}', () => []).add(ExamPaper(
            id: p['id'] as String,
            subject: (p['subject'] ?? '') as String,
            date: DateTime(date.year, date.month, date.day),
            startTime: (p['start_time'] ?? '00:00') as String,
            endTime: (p['end_time'] ?? '00:00') as String,
            syllabus: (p['syllabus'] ?? '') as String,
            maxMarks: _num(p['max_marks'], fallback: 100),
            passMarks: _num(p['pass_marks'], fallback: 35),
          ));
    }
    final out = <ParentExam>[];
    for (final s in schedules) {
      final key = '${s['exam_id']}|${s['grade_key']}';
      final list = (byKey[key] ?? <ExamPaper>[])..sort(ExamPaper.compare);
      if (list.isEmpty) continue;
      final exam = s['exams'] is Map ? Map<String, dynamic>.from(s['exams'] as Map) : const <String, dynamic>{};
      out.add(ParentExam(
        examId: s['exam_id'] as String,
        name: (exam['name'] ?? 'Exam') as String,
        mode: ExamResultModeX.parse(exam['result_mode']),
        scale: [
          for (final b in (exam['grade_scale'] as List? ?? const []))
            if (b is Map) GradeBand.fromJson(Map<String, dynamic>.from(b)),
        ],
        gradeKey: (s['grade_key'] ?? '') as String,
        firstDate: list.first.date,
        lastDate: list.last.date,
        publishedAt: _date(s['published_at']),
        papers: list,
      ));
    }
    out.sort((a, b) => (b.firstDate ?? DateTime(1970)).compareTo(a.firstDate ?? DateTime(1970)));
    return out;
  }

  /// This child's formal exam marks, keyed by paper id. RLS only returns a
  /// mark once its section's sheet has been submitted — so anything missing
  /// here is "awaited", never a half-typed draft.
  Future<Map<String, ({double score, bool absent, String? grade})>> examMarks(String studentId) async {
    final rows = await _db
        .from('marks')
        .select('paper_id, score, is_absent, grade')
        .eq('student_id', studentId)
        .not('paper_id', 'is', null);
    return {
      for (final r in rows)
        r['paper_id'] as String: (
          score: _num(r['score']),
          absent: r['is_absent'] == true,
          grade: r['grade'] as String?,
        ),
    };
  }

  // ---------------------------------------------------------------------------
  // messaging (parent <-> class teacher)
  // ---------------------------------------------------------------------------

  /// The signed-in parent's real identity (auth uid) — used for `parent_id`
  /// on threads/messages, matching how the schema documents that column.
  /// Falls back to a fixed value only if somehow called before sign-in.
  String get parentActorId => _db.auth.currentUser?.id ?? 'parent';

  /// Finds or creates the thread between this parent and the student's class
  /// teacher. Returns the thread row, or null if the backend is unreachable.
  ///
  /// There is exactly one parent login per student (see `parent_accounts`),
  /// so a thread is keyed by `student_id` alone here.
  ///
  /// Self-heals: if a thread already exists but its `teacher_id` is stale
  /// (empty, or the classroom's class teacher changed since) — or its
  /// `parent_id` predates this parent-identity fix — it's updated to the
  /// freshly-resolved values rather than left pointing nowhere. Otherwise a
  /// thread created before a class teacher was assigned stays invisible to
  /// every teacher forever.
  Future<Map<String, dynamic>?> ensureThread({
    required String studentId,
    required String classroomId,
  }) async {
    final classroom = classroomId.isEmpty
        ? null
        : await _db.from('classrooms').select().eq('id', classroomId).maybeSingle();
    final teacherId = (classroom?['class_teacher_id'] ?? '') as String;

    final existing = await _db
        .from('message_threads')
        .select()
        .eq('student_id', studentId)
        .maybeSingle();
    if (existing != null) {
      final updates = <String, dynamic>{};
      if (teacherId.isNotEmpty && teacherId != (existing['teacher_id'] ?? '')) {
        updates['teacher_id'] = teacherId;
      }
      if (classroomId.isNotEmpty && classroomId != (existing['classroom_id'] ?? '')) {
        updates['classroom_id'] = classroomId;
      }
      if (parentActorId != (existing['parent_id'] ?? '')) {
        updates['parent_id'] = parentActorId;
      }
      if (updates.isEmpty) return existing;
      final healed = await _db
          .from('message_threads')
          .update(updates)
          .eq('id', existing['id'] as String)
          .select()
          .maybeSingle();
      return healed ?? existing;
    }

    final row = {
      'id': 'th-$studentId-$parentActorId',
      'student_id': studentId,
      'classroom_id': classroomId,
      'parent_id': parentActorId,
      'teacher_id': teacherId,
      'last_message_at': DateTime.now().toIso8601String(),
    };
    final saved = await _db
        .from('message_threads')
        .upsert(row, onConflict: 'student_id,parent_id,teacher_id')
        .select()
        .maybeSingle();
    return saved ?? row;
  }

  Future<List<Map<String, dynamic>>> threadMessages(String threadId) async {
    final rows = await _db
        .from('messages')
        .select()
        .eq('thread_id', threadId)
        .order('created_at');
    return rows.cast<Map<String, dynamic>>();
  }

  Stream<List<Map<String, dynamic>>> watchThreadMessages(String threadId) {
    final db = _client;
    if (db == null) return const Stream.empty();
    return db
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('thread_id', threadId)
        .order('created_at')
        .map((rows) => rows.cast<Map<String, dynamic>>()
          // Belt-and-suspenders: the realtime channel's own ordering isn't
          // guaranteed to stay correct as rows stream in incrementally —
          // always re-sort explicitly so messages never render grouped by
          // sender instead of true chronological order.
          ..sort((a, b) {
            final ta = DateTime.tryParse('${a['created_at']}') ?? DateTime(0);
            final tb = DateTime.tryParse('${b['created_at']}') ?? DateTime(0);
            return ta.compareTo(tb);
          }));
  }

  Future<void> sendMessage({
    required String threadId,
    required String body,
    String kind = 'text',
    String? attachmentName,
    int? attachmentSize,
    String? leaveRequestId,
  }) async {
    await _db.from('messages').insert({
      'id': 'm-${DateTime.now().millisecondsSinceEpoch}',
      'thread_id': threadId,
      'sender_role': 'parent',
      'sender_id': parentActorId,
      'kind': kind,
      'body': body,
      'attachment_name': attachmentName,
      'attachment_size': attachmentSize,
      'leave_request_id': leaveRequestId,
    });
  }

  Future<void> markThreadRead(String threadId) async {
    await _db.from('message_threads').update({'parent_unread': 0}).eq('id', threadId);
  }

  Future<int> threadUnreadForParent(String threadId) async {
    final row = await _db.from('message_threads').select('parent_unread').eq('id', threadId).maybeSingle();
    return (row?['parent_unread'] as int?) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // student leave / absence requests
  // ---------------------------------------------------------------------------

  Future<String> createLeaveRequest({
    required String studentId,
    required String kind, // 'leave' | 'late_info' | 'absent_info'
    required DateTime fromDate,
    DateTime? toDate,
    required String reason,
  }) async {
    final id = 'slr-${DateTime.now().millisecondsSinceEpoch}';
    await _db.from('student_leave_requests').insert({
      'id': id,
      'student_id': studentId,
      'requested_by': parentActorId,
      'kind': kind,
      'from_date': fromDate.toIso8601String(),
      'to_date': toDate?.toIso8601String(),
      'reason': reason,
    });
    return id;
  }

  Future<List<Map<String, dynamic>>> leaveRequests(String studentId) async {
    final rows = await _db
        .from('student_leave_requests')
        .select()
        .eq('student_id', studentId)
        .order('created_at', ascending: false);
    return rows.cast<Map<String, dynamic>>();
  }

  // ---------------------------------------------------------------------------
  // "today at school" snapshot
  // ---------------------------------------------------------------------------

  Future<SchoolDaySnapshot?> schoolDay(String classroomId) async {
    final row = await _db
        .from('class_day_summaries')
        .select()
        .eq('classroom_id', classroomId)
        .order('summary_date', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    // Only today's update belongs on the Today screen — an older one would
    // read as if it happened today.
    final day = _date(row['summary_date']);
    final now = DateTime.now();
    if (day == null || day.year != now.year || day.month != now.month || day.day != now.day) {
      return null;
    }
    final learning = ((row['learning'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => LearningItem(
              subject: (m['subject'] ?? '') as String,
              topic: (m['topic'] ?? '') as String,
            ))
        .toList();
    final signals = ((row['growth_signals'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => GrowthSignal(
              name: (m['name'] ?? '') as String,
              indicator: (m['indicator'] ?? '↑') as String,
            ))
        .toList();
    return SchoolDaySnapshot(
      teacherNote: (row['teacher_note'] ?? '') as String,
      learning: learning,
      growingIn: signals,
    );
  }

  // ---------------------------------------------------------------------------
  // parsers
  // ---------------------------------------------------------------------------

  static DateTime? _date(Object? v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  static double _num(Object? v, {double fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  static HomeworkStatus _homeworkStatus(String? s) => switch (s) {
        'under_review' => HomeworkStatus.underReview,
        'completed' => HomeworkStatus.completed,
        _ => HomeworkStatus.pending,
      };

  static String _homeworkStatusName(HomeworkStatus s) => switch (s) {
        HomeworkStatus.underReview => 'under_review',
        HomeworkStatus.completed => 'completed',
        HomeworkStatus.pending => 'pending',
      };

  static AttendanceMark _attendanceMark(String? s) => switch (s) {
        'present' => AttendanceMark.present,
        'absent' => AttendanceMark.absent,
        'late' || 'delayed' || 'od' || 'excused' || 'half_day' => AttendanceMark.leave,
        _ => AttendanceMark.none,
      };

  static DiaryEntryKind _diaryKind(String? s) => switch (s) {
        'notice' => DiaryEntryKind.notice,
        'activity' => DiaryEntryKind.activity,
        _ => DiaryEntryKind.teacherNote,
      };

  static PaymentStatus _paymentStatus(String? s) => switch (s) {
        'success' => PaymentStatus.paid,
        'pending' => PaymentStatus.pending,
        'failed' => PaymentStatus.failed,
        _ => PaymentStatus.processing,
      };

  static NotificationKind _notificationKind(String? s) => switch (s) {
        'homework' => NotificationKind.homework,
        'marks' || 'exam' => NotificationKind.marks,
        'attendance' => NotificationKind.attendance,
        'fees' || 'event' => NotificationKind.fees,
        'announcement' => NotificationKind.announcement,
        'activity' => NotificationKind.activity,
        'star' => NotificationKind.star,
        'growth' => NotificationKind.growth,
        'library' => NotificationKind.libraryBook,
        _ => NotificationKind.school,
      };
}

class _Lookups {
  _Lookups({required this.classrooms, required this.teacherNames, required this.settings});
  final Map<String, Map<String, dynamic>> classrooms;
  final Map<String, String> teacherNames;
  final Map<String, dynamic>? settings;
}

final parentRepositoryProvider = Provider<ParentRepository>((ref) => ParentRepository.create());
