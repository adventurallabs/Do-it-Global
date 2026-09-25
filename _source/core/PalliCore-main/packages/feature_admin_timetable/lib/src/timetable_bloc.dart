import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';

abstract class TimetableEvent {}

class LoadTimetables extends TimetableEvent {
  final String classroomId;
  LoadTimetables(this.classroomId);
}

class CreateTimetable extends TimetableEvent {
  final Timetable timetable;
  CreateTimetable(this.timetable);
}

class DeleteTimetable extends TimetableEvent {
  final String timetableId;
  final String classroomId;
  DeleteTimetable(this.timetableId, this.classroomId);
}

class ActivateTimetable extends TimetableEvent {
  final String timetableId;
  final String classroomId;
  ActivateTimetable(this.timetableId, this.classroomId);
}

class AddPeriod extends TimetableEvent {
  final String timetableId;
  final Period period;
  final bool applyWeekdays;
  AddPeriod(this.timetableId, this.period, {this.applyWeekdays = false});
}

class UpdatePeriod extends TimetableEvent {
  final String timetableId;
  final Period period;
  final bool isTemporary;
  UpdatePeriod(this.timetableId, this.period, {this.isTemporary = false});
}

class DeletePeriod extends TimetableEvent {
  final String timetableId;
  final String periodId;
  DeletePeriod(this.timetableId, this.periodId);
}

/// Removes several periods in one write — e.g. the same duplicate on every
/// weekday. Separate [DeletePeriod] events would race and drop all but one.
class DeletePeriods extends TimetableEvent {
  final String timetableId;
  final Set<String> periodIds;
  DeletePeriods(this.timetableId, this.periodIds);
}

class UpdateTimetableSettings extends TimetableEvent {
  final String timetableId;
  final int intervalCount;
  UpdateTimetableSettings(this.timetableId, this.intervalCount);
}

abstract class TimetableState {}

class TimetableInitial extends TimetableState {}

class TimetableLoading extends TimetableState {}

class TimetablesLoaded extends TimetableState {
  final List<Timetable> timetables;
  TimetablesLoaded(this.timetables);
}

class TimetableError extends TimetableState {
  final String message;
  TimetableError(this.message);
}

class TimetableBloc extends Bloc<TimetableEvent, TimetableState> {
  final TimetableRepository _repository;

  TimetableBloc(this._repository) : super(TimetableInitial()) {
    on<LoadTimetables>(_onLoad);
    on<CreateTimetable>(_onCreate);
    on<DeleteTimetable>(_onDelete);
    on<ActivateTimetable>(_onActivate);
    on<AddPeriod>(_onAddPeriod);
    on<UpdatePeriod>(_onUpdatePeriod);
    on<DeletePeriod>((e, emit) => _deletePeriods(e.timetableId, {e.periodId}, emit));
    on<DeletePeriods>((e, emit) => _deletePeriods(e.timetableId, e.periodIds, emit));
    on<UpdateTimetableSettings>(_onSettings);
  }

  Future<void> _onLoad(LoadTimetables event, Emitter<TimetableState> emit) async {
    if (state is! TimetablesLoaded) emit(TimetableLoading());
    try {
      final timetables = await _repository.getForClass(event.classroomId);
      timetables.sort((a, b) => a.isActive == b.isActive ? 0 : (a.isActive ? -1 : 1));
      emit(TimetablesLoaded(timetables));
    } catch (e) {
      emit(TimetableError(e.toString()));
    }
  }

  Future<void> _onCreate(CreateTimetable event, Emitter<TimetableState> emit) async {
    await _repository.upsert(event.timetable);
    emit(TimetablesLoaded(_merge(event.timetable)));
  }

  Future<void> _onDelete(DeleteTimetable event, Emitter<TimetableState> emit) async {
    await _repository.delete(event.timetableId);
    final next = _current.where((t) => t.id != event.timetableId).toList();
    emit(TimetablesLoaded(next));
  }

  Future<void> _onActivate(ActivateTimetable event, Emitter<TimetableState> emit) async {
    await _repository.activateTimetable(event.timetableId, event.classroomId);
    final updated = _current.map((t) {
      if (t.classroomId != event.classroomId) return t;
      return _copy(t, isActive: t.id == event.timetableId);
    }).toList();
    emit(TimetablesLoaded(updated));
  }

  Future<void> _onAddPeriod(AddPeriod event, Emitter<TimetableState> emit) async {
    final timetable = _byId(event.timetableId);
    if (timetable == null) {
      emit(TimetableError('The timetable is no longer available.'));
      return;
    }
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    final additions = event.applyWeekdays
        ? weekdays
            .map((day) => event.period.copyWith(
                  id: '${event.period.id}_$day',
                  dayOfWeek: day,
                ))
            .toList()
        : [event.period];
    final updated = _copy(timetable, periods: [...timetable.periods, ...additions]);
    await _repository.upsert(updated);
    emit(TimetablesLoaded(_merge(updated)));
  }

  Future<void> _onUpdatePeriod(UpdatePeriod event, Emitter<TimetableState> emit) async {
    final timetable = _byId(event.timetableId);
    if (timetable == null) {
      emit(TimetableError('The timetable is no longer available.'));
      return;
    }
    if (event.isTemporary) {
      final temp = event.period.copyWith(
        id: 'tmp_${DateTime.now().millisecondsSinceEpoch}',
        isTemporary: true,
        date: DateTime.now(),
      );
      final withoutOldTemp = timetable.periods.where((p) {
        if (!p.isTemporary) return true;
        return !(p.dayOfWeek == temp.dayOfWeek && p.startTime == temp.startTime && _sameDay(p.date, DateTime.now()));
      }).toList();
      final updated = _copy(timetable, periods: [...withoutOldTemp, temp]);
      await _repository.upsert(updated);
      emit(TimetablesLoaded(_merge(updated)));
      return;
    }
    final updated = _copy(
      timetable,
      periods: timetable.periods.map((p) => p.id == event.period.id ? event.period : p).toList(),
    );
    await _repository.upsert(updated);
    emit(TimetablesLoaded(_merge(updated)));
  }

  Future<void> _deletePeriods(String timetableId, Set<String> ids, Emitter<TimetableState> emit) async {
    final timetable = _byId(timetableId);
    if (timetable == null) {
      emit(TimetableError('The timetable is no longer available.'));
      return;
    }
    final updated = _copy(
      timetable,
      periods: timetable.periods.where((p) => !ids.contains(p.id)).toList(),
    );
    await _repository.upsert(updated);
    emit(TimetablesLoaded(_merge(updated)));
  }

  Future<void> _onSettings(UpdateTimetableSettings event, Emitter<TimetableState> emit) async {
    final timetable = _byId(event.timetableId);
    if (timetable == null) return;
    final updated = _copy(timetable, intervalCount: event.intervalCount);
    await _repository.upsert(updated);
    emit(TimetablesLoaded(_merge(updated)));
  }

  bool _sameDay(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  List<Timetable> get _current => state is TimetablesLoaded ? (state as TimetablesLoaded).timetables : const [];

  Timetable? _byId(String id) {
    for (final timetable in _current) {
      if (timetable.id == id) return timetable;
    }
    return null;
  }

  List<Timetable> _merge(Timetable timetable) {
    final next = [..._current];
    final index = next.indexWhere((t) => t.id == timetable.id);
    if (index >= 0) {
      next[index] = timetable;
    } else {
      next.add(timetable);
    }
    next.sort((a, b) => a.isActive == b.isActive ? 0 : (a.isActive ? -1 : 1));
    return next;
  }

  Timetable _copy(
    Timetable timetable, {
    bool? isActive,
    List<Period>? periods,
    int? intervalCount,
  }) {
    return Timetable(
      id: timetable.id,
      classroomId: timetable.classroomId,
      name: timetable.name,
      isActive: isActive ?? timetable.isActive,
      periods: periods ?? timetable.periods,
      startTime: timetable.startTime,
      endTime: timetable.endTime,
      intervalCount: intervalCount ?? timetable.intervalCount,
    );
  }
}
