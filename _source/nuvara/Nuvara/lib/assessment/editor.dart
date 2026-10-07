import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models.dart' show Json;
import '../offline.dart' show isNetworkError;
import 'api.dart' show AssessmentConflict;
import 'catalog.dart';
import 'model.dart';
import 'pending.dart';

enum SaveState { saved, pending, saving, offline, error, conflict }

typedef SaveInfo = ({SaveState state, DateTime? at, String? error});

/// Holds the assessment being filled in and keeps it saved.
///
/// Every change is applied in memory at once and saved shortly after typing pauses (one save for a burst of
/// changes). Saves never overlap; a change made during a save is sent right after it. If the server can't be
/// reached the changes are also written to this device ([PendingAssessments]) and retried with back-off, so
/// closing the app or losing the network loses nothing. Each save carries the revision it was made on: if
/// someone else saved in between, saving stops and the screen asks which version to keep.
class AssessmentEditor extends ChangeNotifier {
  final Assessment a;
  final Future<int> Function(String id, int rev, Json payload) _send;

  /// Whose device copy to keep on failure; null keeps none (tests).
  final String? userId;
  final Duration debounce;
  bool readOnly;

  AssessmentEditor(this.a, {required Future<int> Function(String id, int rev, Json payload) save, this.userId, this.readOnly = false, this.debounce = const Duration(milliseconds: 1200)})
      : _send = save,
        section = sectionIndex(a.pick('current_section') ?? 'demographics');

  /// The section on screen; `sections.length` is the review page.
  int section;
  bool get reviewing => section >= sections.length;

  /// Bumped when the answers are replaced wholesale (another version loaded), so text boxes reload.
  int generation = 0;

  final info = ValueNotifier<SaveInfo>((state: SaveState.saved, at: null, error: null));
  SaveState get state => info.value.state;

  int _edits = 0, _saved = 0;
  bool get unsaved => _edits != _saved;
  Timer? _timer, _retry;
  int _retryStep = 0;
  Future<bool>? _inflight;
  bool _disposed = false;

  void _set(SaveState s, {DateTime? at, String? error}) {
    if (_disposed) return;
    info.value = (state: s, at: at ?? info.value.at, error: error);
  }

  // ---- changes

  /// Applies [fn] and schedules a save. [rebuild] false skips redrawing the page (typing that doesn't change
  /// whether a field is filled, so progress stays the same).
  void change(VoidCallback fn, {bool rebuild = true}) {
    if (readOnly) return;
    fn();
    _edits++;
    if (state != SaveState.conflict) {
      if (state != SaveState.offline && state != SaveState.error) _set(SaveState.pending);
      _timer?.cancel();
      _timer = Timer(debounce, _kick);
    }
    if (rebuild && !_disposed) notifyListeners();
  }

  void setText(String key, String v) {
    final was = a.text(key).trim().isNotEmpty;
    change(() => a.put(key, v), rebuild: was != v.trim().isNotEmpty);
  }

  void setFindingText(Finding x, String key, String v) {
    final was = x.text(key).trim().isNotEmpty;
    change(() => x.setText(key, v), rebuild: was != v.trim().isNotEmpty);
  }

  void goTo(int i) {
    section = i.clamp(0, sections.length);
    if (i < sections.length && !readOnly && a.pick('current_section') != sections[i].id) {
      change(() => a.put('current_section', sections[i].id), rebuild: false);
    }
    notifyListeners();
  }

  // ---- saving

  void _kick() => unawaited(_save());

  Future<bool> _save() => _inflight ??= _loop().whenComplete(() => _inflight = null);

  Future<bool> _loop() async {
    while (unsaved && state != SaveState.conflict) {
      final at = _edits;
      final payload = a.payload();
      _set(SaveState.saving, error: null);
      try {
        a.rev = await _send(a.id, a.rev, payload);
        a.updatedAt = DateTime.now();
        if (a.status == 'draft') a.status = 'in_progress';
        _saved = at;
        _retryStep = 0;
        _retry?.cancel();
        if (userId != null) await PendingAssessments.remove(userId!, a.id);
        _set(unsaved ? SaveState.pending : SaveState.saved, at: DateTime.now());
      } on AssessmentConflict {
        await _keepOnDevice(payload);
        _set(SaveState.conflict);
        if (!_disposed) notifyListeners();
        return false;
      } catch (e) {
        await _keepOnDevice(payload);
        final offline = isNetworkError(e);
        _set(offline ? SaveState.offline : SaveState.error, error: offline ? null : e.toString().replaceFirst('Exception: ', ''));
        _scheduleRetry(offline);
        return false;
      }
    }
    return !unsaved;
  }

  Future<void> _keepOnDevice(Json payload) async {
    if (userId != null) await PendingAssessments.write(userId!, a.id, a.rev, payload);
  }

  void _scheduleRetry(bool offline) {
    if (_disposed) return;
    _retry?.cancel();
    const steps = [5, 10, 20, 40, 60];
    // A refused save (not a network problem) is retried slowly: it usually needs the therapist to fix something.
    final s = offline ? steps[_retryStep.clamp(0, steps.length - 1)] : 30;
    _retryStep++;
    _retry = Timer(Duration(seconds: s), _kick);
  }

  /// Saves now. True when everything is on the server.
  Future<bool> flush() async {
    _timer?.cancel();
    if (_inflight != null) await _inflight;
    if (!unsaved) return true;
    return _save();
  }

  /// Retry button.
  Future<bool> retry() {
    _retryStep = 0;
    return flush();
  }

  // ---- conflicts and recovery

  /// Another device saved: replace what's here with [theirs].
  void takeTheirs(Assessment theirs) {
    a.replaceWith(theirs);
    _saved = _edits;
    generation++;
    if (userId != null) unawaited(PendingAssessments.remove(userId!, a.id));
    _set(SaveState.saved, at: DateTime.now());
    notifyListeners();
  }

  /// Another device saved: write what's here over it ([serverRev] is their revision).
  Future<bool> keepMine(int serverRev) {
    a.rev = serverRev;
    _set(SaveState.pending);
    _edits++;
    return flush();
  }

  /// Puts back changes kept on this device after a failed save, and saves them.
  void restore(Json payload) {
    a.applyPayload(payload);
    generation++;
    change(() {});
    unawaited(flush());
  }

  /// Marks the (saved) assessment completed through [complete]; throws when it can't be.
  Future<void> complete(Future<int> Function(String id, int rev) complete) async {
    if (!await flush()) {
      throw Exception(state == SaveState.conflict ? 'This assessment was changed on another device. Choose which version to keep first.' : 'Couldn\'t save the latest changes. Check your connection and try again.');
    }
    a.rev = await complete(a.id, a.rev);
    a.status = 'completed';
    a.completedAt ??= DateTime.now();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _retry?.cancel();
    // Leaving with changes not yet sent: send them anyway (and keep them on the device if that fails).
    // Through _save, so it joins a save already running instead of racing it with the same revision.
    if (unsaved && state != SaveState.conflict) unawaited(_save().catchError((_) => false));
    info.dispose();
    super.dispose();
  }
}
