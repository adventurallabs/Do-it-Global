import 'dart:ui' show Color;

import 'util.dart';

// One class per table (or table + its child rows). `Map` in, plain fields out.

typedef Json = Map<String, dynamic>;

enum Role {
  admin('ADMIN', '/admin'),
  therapist('THERAPIST', '/therapist'),
  parent('PARENT', '/parent');

  final String db, home;
  const Role(this.db, this.home);
  static Role of(String v) => values.firstWhere((r) => r.db == v);
}

List<Json> _rows(dynamic v) => v == null ? const [] : (v is List ? v.cast<Json>() : [v as Json]);
Json? _one(dynamic v) => v == null ? null : (v is List ? (v.isEmpty ? null : v.first as Json) : v as Json);
double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

/// Display IDs. The number itself comes from an identity column, so it is unique and never reused.
String childCode(int no) => 'C${no.toString().padLeft(3, '0')}';
String therapistCode(int no) => 'T${no.toString().padLeft(3, '0')}';

/// Matches "C007", "c7", "007" or "7" against an ID.
bool matchesCode(String query, String prefix, int no) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final digits = q.startsWith(prefix.toLowerCase()) ? q.substring(1) : q;
  final n = int.tryParse(digits);
  return n != null && n == no;
}

const _therapyPalette = [
  Color(0xFF0F7A66), Color(0xFFC2622D), Color(0xFF3D64A8), Color(0xFF8A4F9E),
  Color(0xFFA3791C), Color(0xFF2B8A9A), Color(0xFFB8486A), Color(0xFF5B6B8F),
];

class Therapy {
  final String id, name;
  final double baseFee;
  final String createdAt;
  Therapy(Json m)
      : id = m['id'],
        name = m['name'],
        baseFee = _num(m['base_fee']),
        createdAt = m['created_at'] ?? '';

  /// Stable per therapy, without storing a colour.
  Color get color => _therapyPalette[name.toLowerCase().codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0x7fffffff) % _therapyPalette.length];
}

class TherapistDetails {
  final String? dob;
  final String phone, emergencyPhone;
  final double salary;
  TherapistDetails(Json m)
      : dob = m['dob'],
        phone = m['phone'] ?? '',
        emergencyPhone = m['emergency_phone'] ?? '',
        salary = _num(m['salary']);
}

class Therapist {
  final String id, name;
  final int no;
  final String? profileId;
  final bool active;
  final List<String> therapyIds;

  /// Only returned to admins (and to the therapist themself).
  final TherapistDetails? details;
  String get code => therapistCode(no);
  String get first => firstWord(name);
  Therapist(Json m)
      : id = m['id'],
        no = m['therapist_no'],
        name = m['name'],
        profileId = m['profile_id'],
        active = m['active'],
        therapyIds = _rows(m['therapist_therapies']).map((r) => r['therapy_id'] as String).toList(),
        details = _one(m['therapist_details']) == null ? null : TherapistDetails(_one(m['therapist_details'])!);
}

class ChildTherapy {
  final String therapyId;

  /// This child's own fee per session; null = the therapy's base fee.
  final double? sessionFee;
  const ChildTherapy(this.therapyId, [this.sessionFee]);
  ChildTherapy.of(Json m)
      : therapyId = m['therapy_id'],
        sessionFee = (m['session_fee'] as num?)?.toDouble();
}

class Child {
  final String id, name, dob, fatherName, motherName, phone, altPhone;
  final int no;
  final bool active;

  /// Added with "an assessment is needed": their profile asks for one until it's completed. False for children
  /// who had the centre's paper assessment before joining (and for those added before assessments existed).
  final bool assessmentNeeded;
  final List<ChildTherapy> therapies;
  String get code => childCode(no);
  String get first => firstWord(name);
  Iterable<String> get therapyIds => therapies.map((t) => t.therapyId);
  ChildTherapy? therapyOf(String therapyId) => therapies.where((t) => t.therapyId == therapyId).firstOrNull;
  bool matches(String q) => q.trim().isEmpty || name.toLowerCase().contains(q.trim().toLowerCase()) || matchesCode(q, 'C', no);

  Child(Json m)
      : id = m['id'],
        no = m['child_no'],
        name = m['name'],
        dob = m['dob'],
        fatherName = m['father_name'] ?? '',
        motherName = m['mother_name'] ?? '',
        phone = m['phone'] ?? '',
        altPhone = m['alt_phone'] ?? '',
        active = m['active'],
        assessmentNeeded = m['assessment_needed'] == true,
        therapies = _rows(m['child_therapies']).map(ChildTherapy.of).toList();
}

class Slot {
  final String id, date, start, end;
  final List<Session> sessions;
  int get minutes => toMin(end) - toMin(start);

  /// Column key in the weekly grid: the same time range on different days lines up.
  String get key => '$start-$end';
  Slot(Json m)
      : id = m['id'],
        date = m['slot_date'],
        start = hm(m['start_time']),
        end = hm(m['end_time']),
        sessions = [] {
    sessions.addAll(_rows(m['sessions']).map((s) => Session(s, this)));
    sessions.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
}

/// One child's place in a dated session. Attendance and notice are mutable so a tap can show
/// instantly while the save happens in the background.
class Seat {
  final String childId;

  /// present | late | absent | null (not marked yet)
  String? attendance;
  String note;

  /// Set when a parent has told the centre the child will miss this session.
  String? absenceReason;
  final DateTime? absenceAt;

  /// 0–10, given by the session's therapist once the child attended.
  int? rating;

  /// The per-session fee charged, fixed when the child was marked present or late.
  double? rate;

  /// When the family confirmed they'll come to this session; null until they do.
  DateTime? confirmedAt;
  Seat(Json m)
      : childId = m['child_id'],
        attendance = m['attendance'],
        note = m['note'] ?? '',
        absenceReason = m['absence_reason'],
        absenceAt = m['absence_at'] == null ? null : DateTime.parse(m['absence_at']).toLocal(),
        rating = (m['rating'] as num?)?.toInt(),
        rate = (m['rate'] as num?)?.toDouble(),
        confirmedAt = m['confirmed_at'] == null ? null : DateTime.parse(m['confirmed_at']).toLocal();
  bool get noticed => absenceReason != null;
  bool get attended => attendance == 'present' || attendance == 'late';
  bool get confirmed => confirmedAt != null;

  /// Attended but the therapist hasn't rated the session yet.
  bool get reportPending => attended && rating == null;
}

class Session {
  final String id, name, therapistId, therapyId;
  final List<String> childIds;
  final Map<String, Seat> seats;
  final Slot slot;
  String get date => slot.date;
  String get start => slot.start;
  String get end => slot.end;
  Seat? seat(String childId) => seats[childId];

  /// 'upcoming' | 'live' | 'done', by the device clock.
  String get phase {
    final now = '${todayISO()} ${nowHM()}';
    if ('$date $end'.compareTo(now) <= 0) return 'done';
    if ('$date $start'.compareTo(now) <= 0) return 'live';
    return 'upcoming';
  }

  /// Seats the family still has to answer for: upcoming, not confirmed and not reported away.
  /// (A seat with a change request waiting is answered too; see `AppStore.awaitingConfirmation`.)
  bool unconfirmed(String childId) {
    final s = seats[childId];
    return s != null && phase == 'upcoming' && !s.confirmed && !s.noticed;
  }

  int get markedCount => seats.values.where((s) => s.attendance != null).length;

  /// Attendance can be marked from 15 minutes before the start (the database enforces the same rule).
  bool get attendanceOpen {
    final opens = fromMin((toMin(start) - 15).clamp(0, 24 * 60 - 1));
    return '$date $opens'.compareTo('${todayISO()} ${nowHM()}') <= 0;
  }

  /// Finished and every child marked. Until attendance is complete a finished session is not "completed".
  bool get completed => phase == 'done' && markedCount == seats.length;

  /// Whether a child's attendance can still be set by the therapist: from 15 minutes before the start
  /// until the end; after the end only for a child who was never marked (once). Mirrors `mark_attendance`.
  bool canMarkSeat(String childId) => attendanceOpen && (phase != 'done' || seats[childId]?.attendance == null);

  /// Ratings open at the start and stay open until given (mirrors `rate_session`).
  bool get ratingOpen => phase != 'upcoming';

  /// Children who attended and are still waiting for their session report.
  List<String> get pendingReports => phase == 'upcoming' ? const [] : [for (final e in seats.entries) if (e.value.reportPending) e.key];
  Session(Json m, this.slot)
      : id = m['id'],
        name = m['name'],
        therapistId = m['therapist_id'],
        therapyId = m['therapy_id'] ?? '',
        childIds = _rows(m['session_children']).map((r) => r['child_id'] as String).toList(),
        seats = {for (final r in _rows(m['session_children'])) r['child_id'] as String: Seat(r)};
}

/// How each role signs in. Therapists and parents get an internal email derived from what they type.
String? loginEmail(Role role, String typed) {
  final t = typed.trim();
  switch (role) {
    case Role.admin:
      return t.contains('@') ? t.toLowerCase() : null;
    case Role.therapist:
      final d = digits10(t);
      return d.length == 10 ? 't$d@therapist.nuvara.app' : null;
    case Role.parent:
      final m = RegExp(r'^[cC]?\s*0*(\d{1,6})$').firstMatch(t);
      return m == null ? null : 'child-${int.parse(m.group(1)!)}@parent.nuvara.app';
  }
}

/// "c2", "C002" or "2" → "C002"; anything else is returned trimmed and upper-cased.
String normaliseChildCode(String typed) {
  final m = RegExp(r'^[cC]?\s*0*(\d{1,6})$').firstMatch(typed.trim());
  return m == null ? typed.trim().toUpperCase() : childCode(int.parse(m.group(1)!));
}

/// The starting password the centre gives out: first letter of the name + date of birth (DDMMYYYY).
String defaultPassword(String name, String? dob) {
  if (name.trim().isEmpty || dob == null) return '';
  final p = dob.split('-');
  return '${name.trim()[0].toUpperCase()}${p[2]}${p[1]}${p[0]}';
}

/// A message in one of the centre's conversations: with a child's family ([childId]) or with a
/// therapist ([therapistId]). Exactly one of the two is set; families and therapists never share a thread.
class Message {
  final String id, body;
  final String? childId, therapistId, senderId;
  final bool fromAdmin;
  final DateTime at;
  DateTime? readAt;
  Message(Json m)
      : id = m['id'],
        childId = m['child_id'],
        therapistId = m['therapist_id'],
        body = m['body'],
        senderId = m['sender_id'],
        fromAdmin = m['from_admin'],
        at = DateTime.parse(m['created_at']).toLocal(),
        readAt = m['read_at'] == null ? null : DateTime.parse(m['read_at']).toLocal();

  /// The conversation this belongs to.
  Convo get convo => therapistId != null ? Convo.therapist(therapistId!) : Convo.family(childId!);
}

/// Which conversation: the admin with a child's family, or the admin with a therapist.
class Convo {
  final String id;
  final bool therapist;
  const Convo.family(this.id) : therapist = false;
  const Convo.therapist(this.id) : therapist = true;
  bool has(Message m) => therapist ? m.therapistId == id : m.childId == id;

  @override
  bool operator ==(Object other) => other is Convo && other.id == id && other.therapist == therapist;
  @override
  int get hashCode => Object.hash(id, therapist);
}

/// One rated or noted session of a child, for the progress charts and the day view.
class ProgressPoint {
  final String sessionId, date, start, end, sessionName, therapyId, therapistId, note;
  final String? attendance;
  final int? rating;
  ProgressPoint(Json m)
      : sessionId = m['session_id'],
        date = m['day'],
        start = hm(m['start_time']),
        end = hm(m['end_time']),
        sessionName = m['session_name'],
        therapyId = m['therapy_id'],
        therapistId = m['therapist_id'],
        attendance = m['attendance'],
        rating = (m['rating'] as num?)?.toInt(),
        note = m['note'] ?? '';
  DateTime get at => DateTime.parse('$date $start:00');
  bool get attended => attendance == 'present' || attendance == 'late';

  /// Attended, but the therapist hasn't rated it yet.
  bool get pending => attended && rating == null;
}

/// An attended session still waiting for its therapist's report (rating + description).
class PendingReport {
  final String sessionId, childId, date, start, end, sessionName, therapyId, therapistId;
  PendingReport(Json m)
      : sessionId = m['session_id'],
        childId = m['child_id'],
        date = m['day'],
        start = hm(m['start_time']),
        end = hm(m['end_time']),
        sessionName = m['session_name'],
        therapyId = m['therapy_id'],
        therapistId = m['therapist_id'];
}

/// One day on a progress chart: the average rating of that day's rated sessions.
typedef DayRating = ({String date, double value, int count});

/// How a 0–10 rating reads in words. The same bands colour the charts.
String ratingBand(double r) => r >= 7 ? 'Doing well' : (r >= 4 ? 'Developing' : 'Needs support');

/// A child's sessions in one therapy for one week, and what they cost.
class FeeLine {
  final String therapyId;
  final int allocated, attended, absent, unmarked, upcoming;
  final double amount;

  /// The per-session rates charged and how many sessions at each (usually a single rate).
  final List<({double rate, int count})> rates;
  FeeLine(Json m)
      : therapyId = m['therapy_id'],
        allocated = m['allocated'],
        attended = m['attended'],
        absent = m['absent'],
        unmarked = m['unmarked'],
        upcoming = m['upcoming'],
        amount = _num(m['amount']),
        rates = [for (final r in _rows(m['rates'])) (rate: _num(r['rate']), count: (r['count'] as num).toInt())];
}

enum FeeState {
  paid('Paid'),
  verifying('Verifying'),
  partial('Partly paid'),
  due('Due'),
  running('Sessions ahead'),
  waiting('Awaiting attendance'),
  none('Nothing to pay');

  final String label;
  const FeeState(this.label);
}

/// One child's bill for one Monday–Sunday week, worked out by the database from attended sessions.
/// It grows as sessions are attended and can be paid at any time, also before the week ends.
class FeeWeek {
  final String childId, monday;
  final int allocated, attended, absent, unmarked, upcoming;
  final double amount, paid, verifying;
  final List<FeeLine> lines;

  /// The week is over and every session in it is marked, so the bill won't change any more.
  final bool closed;
  FeeWeek(Json m)
      : childId = m['child_id'],
        monday = m['week_start'],
        allocated = (m['allocated'] as num).toInt(),
        attended = (m['attended'] as num).toInt(),
        absent = (m['absent'] as num).toInt(),
        unmarked = (m['unmarked'] as num).toInt(),
        upcoming = (m['upcoming'] as num).toInt(),
        amount = _num(m['amount']),
        paid = _num(m['paid']),
        verifying = _num(m['verifying']),
        lines = _rows(m['lines']).map(FeeLine.new).toList(),
        closed = m['closed'] == true;

  /// What is owed right now for the sessions attended so far.
  double get due => (amount - paid - verifying) < 0.005 ? 0 : amount - paid - verifying;
  double get credit => (paid - amount) > 0.005 ? paid - amount : 0;
  bool get payable => due > 0;

  /// The current week: more attended sessions may still be added to it.
  bool get open => !closed;

  FeeState get state {
    if (due > 0) return paid > 0 || verifying > 0 ? FeeState.partial : FeeState.due;
    if (verifying > 0) return FeeState.verifying;
    if (paid > 0) return FeeState.paid;
    if (!closed) return unmarked > 0 && upcoming == 0 ? FeeState.waiting : FeeState.running;
    return FeeState.none;
  }
}

enum PayStatus {
  initiated('Not finished'),
  verifying('Verifying'),
  confirmed('Paid'),
  failed('Failed'),
  cancelled('Cancelled'),
  reversed('Reversed');

  final String label;
  const PayStatus(this.label);
  static PayStatus of(String v) => values.firstWhere((s) => s.name == v);
}

class Payment {
  final String id, childId, monday, method, txnRef, note;
  final double amount;
  final PayStatus status;
  final String? payeeVpa, payeeName, payeeKind, utr, upiTxnId, upiApp, verifiedBy, paidOn;
  final int? receiptNo;
  final DateTime createdAt;
  final DateTime? resolvedAt, reconciledAt;
  Payment(Json m)
      : id = m['id'],
        childId = m['child_id'],
        monday = m['week_start'],
        method = m['method'],
        txnRef = m['txn_ref'],
        note = m['note'] ?? '',
        amount = _num(m['amount']),
        status = PayStatus.of(m['status']),
        payeeVpa = m['payee_vpa'],
        payeeName = m['payee_name'],
        payeeKind = m['payee_kind'],
        utr = m['utr'],
        upiTxnId = m['upi_txn_id'],
        upiApp = m['upi_app'],
        verifiedBy = m['verified_by'],
        paidOn = m['paid_on'],
        receiptNo = (m['receipt_no'] as num?)?.toInt(),
        createdAt = DateTime.parse(m['created_at']).toLocal(),
        resolvedAt = m['resolved_at'] == null ? null : DateTime.parse(m['resolved_at']).toLocal(),
        reconciledAt = m['reconciled_at'] == null ? null : DateTime.parse(m['reconciled_at']).toLocal();

  /// Has a receipt: confirmed by the UPI app or by the admin.
  bool get confirmed => status == PayStatus.confirmed;

  /// Confirmed on the UPI app's word alone, and the admin hasn't yet seen the money in the bank.
  bool get unreconciled => confirmed && verifiedBy == 'upi_app' && reconciledAt == null;
  String get receiptCode => receiptNo == null ? '' : 'NV-${receiptNo.toString().padLeft(6, '0')}';
  String get when => paidOn ?? iso(createdAt);
}

/// A UPI ID the centre receives payments on. Only one is active at a time.
/// A personal UPI ID takes person-to-person payments; a merchant (business) one takes merchant payments,
/// which carry our reference (`tr`) and can be matched to the payment exactly.
enum UpiKind {
  personal('Personal'),
  merchant('Business / merchant');

  final String label;
  const UpiKind(this.label);
  static UpiKind of(String? v) => v == 'merchant' ? merchant : personal;
}

class UpiAccount {
  final String id, vpa, payeeName, label;
  final UpiKind kind;
  final String? merchantCode;
  final bool active, archived;
  UpiAccount(Json m)
      : id = m['id'],
        vpa = m['vpa'],
        payeeName = m['payee_name'],
        label = m['label'] ?? '',
        kind = UpiKind.of(m['kind']),
        merchantCode = m['merchant_code'],
        active = m['active'],
        archived = m['archived'];
}

/// A merchant category code: 4 digits, given by the bank or UPI business app.
bool validMcc(String v) => RegExp(r'^[0-9]{4}$').hasMatch(v.trim());

/// Same rule as the database check on `upi_accounts.vpa`.
bool validVpa(String v) => RegExp(r'^[A-Za-z0-9._-]{2,255}@[A-Za-z][A-Za-z0-9.-]{1,63}$').hasMatch(v.trim());

enum RequestStatus {
  pending('Waiting for the centre'),
  approved('Moved'),
  rejected('Not possible'),
  cancelled('Withdrawn');

  final String label;
  const RequestStatus(this.label);
  static RequestStatus of(String v) => values.firstWhere((s) => s.name == v);
}

/// A family asking to move one session, or every later session at that time, to another time.
class RescheduleRequest {
  final String id, childId, scope, fromDate, fromStart, fromEnd, sessionName, reason, adminNote;
  final String? sessionId, therapistId, therapyId, preferredDate, preferredStart, preferredEnd, newDate, newStart, newEnd;

  /// The existing session the family picked to move into (null when they suggested a time instead).
  final String? targetSessionId, targetTherapistId, newTherapistId;
  final RequestStatus status;
  final int moved;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  RescheduleRequest(Json m)
      : id = m['id'],
        childId = m['child_id'],
        scope = m['scope'],
        fromDate = m['from_date'],
        fromStart = hm(m['from_start']),
        fromEnd = hm(m['from_end']),
        sessionName = m['session_name'],
        reason = m['reason'] ?? '',
        adminNote = m['admin_note'] ?? '',
        sessionId = m['session_id'],
        therapistId = m['therapist_id'],
        therapyId = m['therapy_id'],
        preferredDate = m['preferred_date'],
        preferredStart = m['preferred_start'] == null ? null : hm(m['preferred_start']),
        preferredEnd = m['preferred_end'] == null ? null : hm(m['preferred_end']),
        newDate = m['new_date'],
        newStart = m['new_start'] == null ? null : hm(m['new_start']),
        newEnd = m['new_end'] == null ? null : hm(m['new_end']),
        targetSessionId = m['target_session_id'],
        targetTherapistId = m['target_therapist_id'],
        newTherapistId = m['new_therapist_id'],
        status = RequestStatus.of(m['status']),
        moved = (m['moved'] as num?)?.toInt() ?? 0,
        createdAt = DateTime.parse(m['created_at']).toLocal(),
        resolvedAt = m['resolved_at'] == null ? null : DateTime.parse(m['resolved_at']).toLocal();
  bool get series => scope == 'series';
  bool get pending => status == RequestStatus.pending;

  /// The family picked an existing session rather than suggesting a time.
  bool get picked => targetTherapistId != null;

  /// Still waiting, but the session it was about has already started, so it can only be turned down.
  bool get expired => pending && '$fromDate $fromStart'.compareTo('${todayISO()} ${nowHM()}') <= 0;
}

/// A session a family may ask to move into: same therapy, same day, upcoming, and free for their child.
class RescheduleOption {
  final String sessionId, name, therapistId, date, start, end;
  RescheduleOption(Json m)
      : sessionId = m['session_id'],
        name = m['name'],
        therapistId = m['therapist_id'],
        date = m['slot_date'],
        start = hm(m['start_time']),
        end = hm(m['end_time']);
}
