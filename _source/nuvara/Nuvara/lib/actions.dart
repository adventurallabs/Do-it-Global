import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException, PostgrestException;

import 'models.dart';
import 'store.dart';
import 'util.dart';

/// Every write the app makes. Multi-row changes go through database functions so they are atomic;
/// after each write the affected data is reloaded so every screen shows the saved state.
final _attendanceSeq = <String, int>{};
final _attendanceQueue = <String, Future<void>>{};
final _ratingSeq = <String, int>{};
final _ratingQueue = <String, Future<void>>{};
final _ratingSaved = <String, int?>{};
final _ratingPending = <String, int>{};

/// What `start_upi_payment` hands back: everything the UPI app needs, decided by the server.
typedef UpiOrder = ({String id, String txnRef, double amount, String vpa, String name, UpiKind kind, String? mc});

/// Thrown when the parent started a UPI payment earlier whose outcome is still unknown.
class UnfinishedPayment implements Exception {
  final String paymentId;
  const UnfinishedPayment(this.paymentId);
  @override
  String toString() => 'You started a payment for this week earlier. Tell us how it went before paying again.';
}

extension Actions on AppStore {
  Future<T> _run<T>(Future<T> Function() job, Future<void> Function() reload) async {
    try {
      final r = await job();
      await reload();
      touch();
      return r;
    } on PostgrestException catch (e) {
      throw Exception(_friendly(e));
    }
  }

  static String _friendly(PostgrestException e) {
    if (e.code == '23505' && e.message.contains('therapies_name_key')) return 'A therapy with this name already exists.';
    if (e.code == '23505' && e.message.contains('upi_accounts_vpa_key')) return 'This UPI ID is already saved.';
    if (e.code == '23503') return 'This is still in use, so it cannot be deleted.';
    if (e.code == '23P01') return 'Someone in this session is already booked at this time.';
    if (e.code == '23514' && e.message.contains('upi_accounts_vpa_check')) return 'Enter a valid UPI ID, like centre@okaxis.';
    if (e.code == '23514' && e.message.contains('merchant_code')) return 'The merchant category code is 4 digits.';
    return e.message;
  }

  // ---- therapies -----------------------------------------------------------

  Future<Therapy> saveTherapy({String? id, required String name, required double baseFee}) => _run(() async {
        final row = {'name': name.trim(), 'base_fee': baseFee};
        final r = id == null
            ? await db.from('therapies').insert(row).select().single()
            : await db.from('therapies').update(row).eq('id', id).select().single();
        return Therapy(r);
      }, loadCatalog);

  Future<void> deleteTherapy(String id) => _run(() => db.from('therapies').delete().eq('id', id), loadCatalog);

  // ---- children ------------------------------------------------------------

  static Map<String, dynamic> _childParams(String name, String dob, String father, String mother, String phone, String altPhone, Map<String, double?> fees) => {
        'p_name': name.trim(),
        'p_dob': dob,
        'p_father': father.trim(),
        'p_mother': mother.trim(),
        'p_phone': phone.trim(),
        'p_alt_phone': altPhone.trim(),
        'p_therapies': [for (final e in fees.entries) {'therapy_id': e.key, 'session_fee': e.value}],
      };

  /// [fees]: therapy id → this child's own per-session fee, or null for the therapy's base fee.
  Future<String> saveChild({
    String? id,
    required String name,
    required String dob,
    required String father,
    required String mother,
    required String phone,
    required String altPhone,
    required Map<String, double?> fees,
  }) =>
      _run(
        () async => await db.rpc('save_child', params: {'p_id': id, ..._childParams(name, dob, father, mother, phone, altPhone, fees)}) as String,
        loadCatalog,
      ).then((childId) async {
        await _syncLogin({'action': 'sync_child', 'child_id': childId});
        return childId;
      });

  /// Creates a child together with their completed intake [assessmentId], all or nothing. A null [assessmentId]
  /// creates a child who needs no assessment (e.g. assessed on paper before). Returns the child's id.
  Future<String> createAssessedChild({
    required String? assessmentId,
    required String name,
    required String dob,
    required String father,
    required String mother,
    required String phone,
    required String altPhone,
    required Map<String, double?> fees,
  }) =>
      _run(
        () async => await db.rpc('create_assessed_child', params: {'p_assessment': assessmentId, ..._childParams(name, dob, father, mother, phone, altPhone, fees)}) as String,
        loadCatalog,
      ).then((childId) async {
        intakeDrafts.removeWhere((d) => d.id == assessmentId);
        await _syncLogin({'action': 'sync_child', 'child_id': childId});
        return childId;
      });

  /// Keeps a person's login in step after a save. The save itself already succeeded, so a failure here
  /// is reported through [loginWarning] instead of being thrown.
  Future<void> _syncLogin(Map<String, dynamic> body) async {
    loginWarning = null;
    try {
      await _accounts(body);
    } catch (e) {
      loginWarning = 'Saved, but the login could not be set up: ${e.toString().replaceFirst('Exception: ', '')}';
    }
    await Future.wait([loadCatalog(), if (isAdmin) loadParentLogins()]);
    touch();
  }

  // ---- the session record --------------------------------------------------

  /// Marks [childIds] present/late/absent (null clears). Shows immediately; reverts if the save fails.
  /// Saves for one session are sent one after another, so quick taps land in the order they were made.
  Future<void> markAttendance(Session s, List<String> childIds, String? status) {
    final before = {for (final id in childIds) id: (attendance: s.seat(id)?.attendance, rating: s.seat(id)?.rating)};
    final token = {for (final id in childIds) id: _attendanceSeq['${s.id}|$id'] = (_attendanceSeq['${s.id}|$id'] ?? 0) + 1};
    // The server drops the rating of a child who didn't come (`mark_attendance`), so do the same here.
    final keepsRating = status == 'present' || status == 'late';
    for (final id in childIds) {
      s.seat(id)?.attendance = status;
      if (!keepsRating) s.seat(id)?.rating = null;
    }
    touch();
    Future<void> send() async {
      try {
        await db.rpc('mark_attendance', params: {'p_session': s.id, 'p_children': childIds, 'p_status': status});
        // The bill follows attendance.
        if (role != null && role != Role.therapist) loadFees().then((_) => touch(), onError: (_) {});
        if (role != null && role != Role.parent) loadPendingReports().then((_) => touch(), onError: (_) {});
      } catch (e) {
        // Only undo seats no later tap has changed since.
        var reverted = false;
        before.forEach((id, b) {
          if (_attendanceSeq['${s.id}|$id'] == token[id]) {
            s.seat(id)
              ?..attendance = b.attendance
              ..rating = b.rating;
            reverted = true;
          }
        });
        if (reverted) touch();
        if (e is PostgrestException) throw Exception(_friendly(e));
        rethrow;
      }
    }

    final next = (_attendanceQueue[s.id] ?? Future.value()).catchError((_) {}).then((_) => send());
    _attendanceQueue[s.id] = next;
    return next;
  }

  /// Saves the therapist's note for one child. The note is updated in place; no reload needed.
  Future<void> saveNote(Session s, String childId, String note) async {
    try {
      await db.rpc('save_session_note', params: {'p_session': s.id, 'p_child': childId, 'p_note': note.trim()});
      s.seat(childId)?.note = note.trim();
      touch();
    } on PostgrestException catch (e) {
      throw Exception(_friendly(e));
    }
  }

  /// The therapist's 0–10 rating for one child in [s] (null clears it). Shows immediately; like attendance,
  /// saves for one child are sent one after another so quick taps land in order, and a failure of the latest
  /// tap goes back to the last rating the server accepted.
  Future<void> rateSession(Session s, String childId, int? rating) {
    final key = '${s.id}|$childId';
    final seat = s.seat(childId);
    if ((_ratingPending[key] ?? 0) == 0) _ratingSaved[key] = seat?.rating;
    _ratingPending[key] = (_ratingPending[key] ?? 0) + 1;
    final token = _ratingSeq[key] = (_ratingSeq[key] ?? 0) + 1;
    seat?.rating = rating;
    touch();
    Future<void> send() async {
      try {
        await db.rpc('rate_session', params: {'p_session': s.id, 'p_child': childId, 'p_rating': rating, 'p_note': null});
        _ratingSaved[key] = rating;
        await Future.wait([
          if (progressOf(childId) != null) loadProgress(childId, force: true),
          loadPendingReports(),
        ]);
        touch();
      } catch (e) {
        if (_ratingSeq[key] == token) {
          seat?.rating = _ratingSaved[key];
          touch();
        }
        if (e is PostgrestException) throw Exception(_friendly(e));
        rethrow;
      } finally {
        _ratingPending[key] = _ratingPending[key]! - 1;
      }
    }

    final next = (_ratingQueue[key] ?? Future.value()).catchError((_) {}).then((_) => send());
    _ratingQueue[key] = next;
    return next;
  }

  /// Retire or bring back a child (hidden from pickers) without losing their history.
  Future<void> setChildActive(String id, bool active) =>
      _run(() => db.from('children').update({'active': active}).eq('id', id), loadCatalog).then((_) => _syncLogin({'action': 'sync_child', 'child_id': id}));

  /// Retire or bring back a therapist; they disappear from the session pickers while inactive.
  Future<void> setTherapistActive(String id, bool active) =>
      _run(() => db.from('therapists').update({'active': active}).eq('id', id), loadCatalog).then((_) => _syncLogin({'action': 'sync_therapist', 'therapist_id': id}));

  /// Parent: tell the centre the child will miss [s]. A null [reason] withdraws the notice.
  Future<void> reportAbsence(Session s, String childId, String? reason) => _run(
        () => db.rpc('report_absence', params: {'p_session': s.id, 'p_child': childId, 'p_reason': reason}),
        () => loadWeek(weekStart(s.date), force: true),
      );

  // ---- confirming and rescheduling ----------------------------------------

  /// Parent: confirm [sessions] for [childId]. Shows at once; the server skips any that have started, are
  /// marked away or have a change request waiting. Returns how many it confirmed.
  Future<int> confirmSessions(String childId, List<Session> sessions) async {
    final now = DateTime.now();
    final changed = [for (final s in sessions) if (s.seat(childId) case final seat? when !seat.confirmed) seat];
    for (final seat in changed) {
      seat.confirmedAt = now;
    }
    touch();
    try {
      return await _run(
        () async => ((await db.rpc('confirm_sessions', params: {'p_child': childId, 'p_sessions': [for (final s in sessions) s.id]})) as num).toInt(),
        () => Future.wait({for (final s in sessions) weekStart(s.date)}.map((m) => loadWeek(m, force: true))),
      );
    } catch (_) {
      for (final seat in changed) {
        seat.confirmedAt = null;
      }
      touch();
      rethrow;
    }
  }

  /// Sessions [childId] could move into instead of [s]: same therapy, same day, upcoming and free for them.
  Future<List<RescheduleOption>> rescheduleOptions(Session s, String childId) async {
    try {
      final rows = await db.rpc('reschedule_options', params: {'p_session': s.id, 'p_child': childId});
      return [for (final m in (rows as List).cast<Json>()) RescheduleOption(m)];
    } on PostgrestException catch (e) {
      throw Exception(_friendly(e));
    }
  }

  /// Parent: ask the centre to move [s] (scope 'once': this day only) or this and every later session at that
  /// time ('series': regularly), either into an existing session ([target]) or at a time that suits the family.
  Future<void> requestReschedule(Session s, String childId,
          {required String scope, RescheduleOption? target, String? date, String? start, String? end, required String reason}) =>
      _run(
        () => db.rpc('request_reschedule', params: {
          'p_session': s.id,
          'p_child': childId,
          'p_scope': scope,
          'p_target': target?.sessionId,
          'p_date': target == null ? date : null,
          'p_start': target == null ? start : null,
          'p_end': target == null ? end : null,
          'p_reason': reason.trim(),
        }),
        () => Future.wait([loadRequests(), loadWeek(weekStart(s.date), force: true)]),
      );

  Future<void> cancelReschedule(String id) => _run(() => db.rpc('cancel_reschedule', params: {'p_id': id}), loadRequests);

  /// Admin: approve (moves the seat(s) into [therapistId]'s session at the new time, all or nothing) or reject.
  /// Returns how many sessions moved.
  Future<int> resolveReschedule(RescheduleRequest r, {required bool approve, String? date, String? start, String? end, String? therapistId, String note = ''}) => _run(
        () async => ((await db.rpc('resolve_reschedule', params: {
                  'p_id': r.id,
                  'p_approve': approve,
                  'p_date': date,
                  'p_start': start,
                  'p_end': end,
                  'p_therapist': therapistId,
                  'p_note': note.trim(),
                })) as num)
            .toInt(),
        () => Future.wait([loadRequests(), if (approve) reloadWeeks(), if (approve && date != null) loadWeek(weekStart(date), force: true), if (approve) loadWeekIndex()]),
      );

  // ---- logins ------------------------------------------------------------------

  Future<Map> _accounts(Map<String, dynamic> body) async {
    try {
      final r = await db.functions.invoke('accounts', body: body);
      return (r.data as Map?) ?? const {};
    } on FunctionException catch (e) {
      throw Exception(functionError(e));
    }
  }

  /// Creates or updates the therapist's mobile-number login (default password on creation).
  Future<void> syncTherapistLogin(String id) => _run(() => _accounts({'action': 'sync_therapist', 'therapist_id': id}), () => Future.wait([loadCatalog(), loadParentLogins()]));

  /// Creates or updates the parent login for a child (child ID + default password on creation).
  Future<void> syncChildLogin(String id) => _run(() => _accounts({'action': 'sync_child', 'child_id': id}), loadParentLogins);

  /// Back to the default password; they must choose a new one when they next sign in.
  Future<void> resetTherapistPassword(String id) => _run(() => _accounts({'action': 'reset_password', 'kind': 'therapist', 'id': id}), loadParentLogins);
  Future<void> resetParentPassword(String childId) => _run(() => _accounts({'action': 'reset_password', 'kind': 'child', 'id': childId}), loadParentLogins);

  // ---- messages ----------------------------------------------------------------

  Future<void> sendMessage(Convo to, String body) async {
    final text = body.trim();
    if (text.isEmpty) return;
    try {
      final row = await db
          .from('messages')
          .insert({if (to.therapist) 'therapist_id': to.id else 'child_id': to.id, 'body': text, 'from_admin': isAdmin, 'sender_id': userId})
          .select()
          .single();
      final m = Message(row);
      if (!messages.any((x) => x.id == m.id)) messages.add(m);
      touch();
    } on PostgrestException catch (e) {
      throw Exception(_friendly(e));
    }
  }

  /// Marks the other side's messages in this conversation as read.
  Future<void> markThreadRead(Convo c) async {
    final mine = messages.where((m) => c.has(m) && m.readAt == null && m.fromAdmin != isAdmin).toList();
    if (mine.isEmpty) return;
    final now = DateTime.now();
    for (final m in mine) {
      m.readAt = now;
    }
    touch();
    try {
      await (c.therapist ? db.rpc('mark_therapist_thread_read', params: {'p_therapist': c.id}) : db.rpc('mark_thread_read', params: {'p_child': c.id}));
    } catch (_) {/* stays unread on the server; the next open retries */}
  }

  /// Removes the child and their parent login.
  Future<void> deleteChild(String id) async {
    final login = await db.from('profiles').select('id').eq('child_id', id).maybeSingle();
    await _run(() => db.from('children').delete().eq('id', id), () => Future.wait([loadCatalog(), reloadWeeks(), loadFees(), loadWeekIndex(), loadParentLogins(), loadRequests()]));
    if (login != null) await _accounts({'action': 'delete_profile', 'profile_id': login['id']}).catchError((_) => const {});
  }

  // ---- therapists ----------------------------------------------------------

  Future<String> saveTherapist({
    String? id,
    required String name,
    required String? dob,
    required String phone,
    required String emergencyPhone,
    required double salary,
    required List<String> therapyIds,
  }) =>
      _run(
        () async => await db.rpc('save_therapist', params: {
          'p_id': id,
          'p_name': name.trim(),
          'p_dob': dob,
          'p_phone': phone.trim(),
          'p_emergency': emergencyPhone.trim(),
          'p_salary': salary,
          'p_therapies': therapyIds,
        }) as String,
        loadCatalog,
      ).then((therapistId) async {
        await _syncLogin({'action': 'sync_therapist', 'therapist_id': therapistId});
        return therapistId;
      });

  /// Removes the therapist and their login.
  Future<void> deleteTherapist(String id) async {
    final login = therapist(id)?.profileId;
    await _run(() async {
      try {
        await db.from('therapists').delete().eq('id', id);
      } on PostgrestException catch (e) {
        if (e.code == '23503') throw Exception('This therapist still has sessions in the timetable. Remove or reassign them first, or mark them as inactive.');
        rethrow;
      }
    }, loadCatalog);
    if (login != null) await _accounts({'action': 'delete_profile', 'profile_id': login}).catchError((_) => const {});
  }

  // ---- timetable -----------------------------------------------------------

  /// Creates the time slot on each of [dates]; dates that already have it are skipped. Returns how many were new.
  Future<int> createSlots(List<String> dates, String start, String end) => _run(
        () async => (await db.rpc('create_slots', params: {'p_dates': dates, 'p_start': start, 'p_end': end}) as num).toInt(),
        () => _reloadWeeksOf(dates),
      );

  Future<void> deleteSlot(Slot s) => _run(() => db.from('timetable_slots').delete().eq('id', s.id), () => _reloadWeeksOf([s.date], seats: true));

  /// Adds the same session to the [start]–[end] slot on each of [dates], creating missing slots. All or nothing.
  Future<int> createSessions({
    required List<String> dates,
    required String start,
    required String end,
    required String name,
    required String therapistId,
    required String therapyId,
    required List<String> childIds,
  }) =>
      _run(
        () async => (await db.rpc('create_sessions', params: {
          'p_dates': dates,
          'p_start': start,
          'p_end': end,
          'p_name': name.trim(),
          'p_therapist': therapistId,
          'p_therapy': therapyId,
          'p_children': childIds,
        }) as num)
            .toInt(),
        () => _reloadWeeksOf(dates),
      );

  Future<void> updateSession(Session s, {required String name, required String therapistId, required String therapyId, required List<String> childIds}) => _run(
        () => db.rpc('update_session', params: {'p_session': s.id, 'p_name': name.trim(), 'p_therapist': therapistId, 'p_therapy': therapyId, 'p_children': childIds}),
        () => _reloadWeeksOf([s.date], seats: true),
      );

  Future<void> deleteSession(Session s) => _run(() => db.from('sessions').delete().eq('id', s.id), () => _reloadWeeksOf([s.date], seats: true));

  /// Admin: takes [childId] out of [sessions] (upcoming ones; the server skips any that have started or are
  /// marked). A session left without children is deleted. Returns how many sessions the child left.
  /// Uses `remove_child_from_sessions` when the database has it, otherwise the session edits one by one.
  Future<int> removeChildFromSessions(String childId, List<Session> sessions) async {
    if (sessions.isEmpty) return 0;
    final dates = [for (final s in sessions) s.date];
    try {
      final n = ((await db.rpc('remove_child_from_sessions', params: {'p_child': childId, 'p_sessions': [for (final s in sessions) s.id]})) as num).toInt();
      await _reloadWeeksOf(dates, seats: true);
      touch();
      return n;
    } on PostgrestException catch (e) {
      // Older database without the function: same result through the existing session edits.
      if (e.code != 'PGRST202' && e.code != '42883') throw Exception(_friendly(e));
    }
    var n = 0;
    try {
      for (final s in sessions) {
        final others = [for (final id in s.childIds) if (id != childId) id];
        if (others.isEmpty) {
          await db.from('sessions').delete().eq('id', s.id);
        } else {
          await db.rpc('update_session', params: {'p_session': s.id, 'p_name': s.name, 'p_therapist': s.therapistId, 'p_therapy': s.therapyId, 'p_children': others});
        }
        n++;
      }
    } on PostgrestException catch (e) {
      throw Exception(_friendly(e));
    } finally {
      await _reloadWeeksOf(dates, seats: true).catchError((_) {});
      touch();
    }
    return n;
  }

  Future<int> copyWeek(String fromMonday, String toMonday) => _run(
        () async => (await db.rpc('copy_week', params: {'p_from': fromMonday, 'p_to': toMonday}) as num).toInt(),
        () => _reloadWeeksOf([toMonday]),
      );

  /// [seats]: children were taken out of sessions, which can close families' requests (the server turns down
  /// a request whose session is deleted) and drop reports that were still owed.
  Future<void> _reloadWeeksOf(List<String> dates, {bool seats = false}) => Future.wait([
        ...{for (final d in dates) weekStart(d)}.map((m) => loadWeek(m, force: true)),
        loadWeekIndex(),
        loadFees(),
        if (seats) loadRequests(),
        if (seats) loadPendingReports(),
      ]);

  // ---- fees and payments ------------------------------------------------------

  /// Admin: one amount received for a child, settling the oldest unpaid weeks first. Returns how many weeks it covered.
  Future<int> recordChildPayment({required String childId, required double amount, required String method, required String note, required String paidOn}) => _run(
        () async => ((await db.rpc('record_child_payment', params: {'p_child': childId, 'p_amount': amount, 'p_method': method, 'p_note': note.trim(), 'p_paid_on': paidOn})) as num).toInt(),
        loadFees,
      );

  /// Admin: money received at the centre for one week.
  Future<void> recordPayment({required String childId, required String monday, required double amount, required String method, required String note, required String paidOn}) => _run(
        () => db.rpc('record_payment', params: {'p_child': childId, 'p_week': monday, 'p_amount': amount, 'p_method': method, 'p_note': note.trim(), 'p_paid_on': paidOn}),
        loadFees,
      );

  /// Admin: 'confirm' / 'reject' a payment waiting for verification, 'reverse' a confirmed one, or
  /// 'reconcile' an app-confirmed one once the money is seen in the bank.
  Future<void> reviewPayment(Payment p, String action, {String note = ''}) =>
      _run(() => db.rpc('review_payment', params: {'p_payment': p.id, 'p_action': action, 'p_note': note.trim()}), loadFees);

  /// Opens a UPI payment for what is due now in a week (it doesn't have to be over). Throws [UnfinishedPayment] if an earlier attempt must be settled first.
  Future<UpiOrder> startUpiPayment(String childId, String monday) async {
    try {
      final r = (await db.rpc('start_upi_payment', params: {'p_child': childId, 'p_week': monday}) as Map).cast<String, dynamic>();
      await loadFees();
      touch();
      return (
        id: r['id'] as String,
        txnRef: r['txn_ref'] as String,
        amount: (r['amount'] as num).toDouble(),
        vpa: r['vpa'] as String,
        name: r['name'] as String,
        kind: UpiKind.of(r['kind'] as String?),
        mc: r['mc'] as String?,
      );
    } on PostgrestException catch (e) {
      final m = RegExp(r'UNFINISHED:([0-9a-f-]{36})').firstMatch(e.message);
      if (m != null) {
        await loadFees();
        touch();
        throw UnfinishedPayment(m.group(1)!);
      }
      throw Exception(_friendly(e));
    }
  }

  /// Hands the UPI app's reply to the server, which decides the outcome. Returns the payment's new status.
  /// Network failures are retried, because the money may already have moved.
  Future<PayStatus> completeUpiPayment(String paymentId, String? response, String? app) async {
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        final r = (await db.rpc('complete_upi_payment', params: {'p_payment': paymentId, 'p_response': response ?? '', 'p_app': app ?? ''}) as Map);
        await loadFees();
        touch();
        return PayStatus.of(r['status'] as String);
      } on PostgrestException catch (e) {
        throw Exception(_friendly(e));
      } catch (_) {
        await Future.delayed(Duration(seconds: 1 << attempt));
      }
    }
    throw Exception("Couldn't reach the server to confirm the payment. Your payment is saved; open Fees and tap Finish when you're back online.");
  }

  /// The parent paid but the UPI app didn't say so: the bank reference goes to the admin to verify.
  Future<void> submitUpiReference(String paymentId, String utr) => _run(() => db.rpc('submit_upi_reference', params: {'p_payment': paymentId, 'p_utr': utr.trim()}), loadFees);

  /// The parent didn't pay.
  Future<void> cancelUpiPayment(String paymentId) => _run(() => db.rpc('cancel_upi_payment', params: {'p_payment': paymentId}), loadFees);

  // ---- UPI IDs (admin) -------------------------------------------------------

  Future<void> saveUpiAccount({String? id, required String vpa, required String payeeName, required String label, UpiKind kind = UpiKind.personal, String? merchantCode}) => _run(() async {
        final mc = merchantCode?.trim() ?? '';
        final row = {
          'vpa': vpa.trim().toLowerCase(),
          'payee_name': payeeName.trim(),
          'label': label.trim(),
          'kind': kind.name,
          'merchant_code': kind == UpiKind.merchant && mc.isNotEmpty ? mc : null,
        };
        if (id == null) {
          final created = await db.from('upi_accounts').insert(row).select().single();
          // The first UPI ID becomes the active one.
          if (activeUpi == null) await db.rpc('set_active_upi', params: {'p_id': created['id']});
        } else {
          await db.from('upi_accounts').update(row).eq('id', id);
        }
      }, loadUpiAccounts);

  Future<void> setActiveUpi(String id) => _run(() => db.rpc('set_active_upi', params: {'p_id': id}), loadUpiAccounts);

  /// Removes a UPI ID; one that has received payments is archived instead, so its history stays intact.
  Future<void> removeUpiAccount(UpiAccount a) => _run(() async {
        if (a.active) throw Exception('Make another UPI ID active before removing this one.');
        try {
          await db.from('upi_accounts').delete().eq('id', a.id);
        } on PostgrestException catch (e) {
          if (e.code != '23503') rethrow;
          await db.from('upi_accounts').update({'archived': true}).eq('id', a.id);
        }
      }, loadUpiAccounts);
}
