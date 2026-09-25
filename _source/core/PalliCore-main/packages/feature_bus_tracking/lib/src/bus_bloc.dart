import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';

abstract class BusEvent {}

class LoadBuses extends BusEvent {}

class SubscribeToLocations extends BusEvent {}

class AddBus extends BusEvent {
  final Bus bus;
  AddBus(this.bus);
}

class UpdateBus extends BusEvent {
  final Bus bus;
  UpdateBus(this.bus);
}

class DeleteBus extends BusEvent {
  final String id;
  DeleteBus(this.id);
}

class LocationsUpdated extends BusEvent {
  final List<Bus> buses;
  LocationsUpdated(this.buses);
}

abstract class BusState {}

class BusInitial extends BusState {}

class BusLoading extends BusState {}

class BusLoaded extends BusState {
  final List<Bus> buses;
  BusLoaded(this.buses);
}

class BusError extends BusState {
  final String message;
  BusError(this.message);
}

class BusBloc extends Bloc<BusEvent, BusState> {
  final BusRepository _repository;

  BusBloc(this._repository) : super(BusInitial()) {
    on<LoadBuses>((event, emit) async {
      emit(BusLoading());
      try {
        final buses = await _repository.getAll();
        emit(BusLoaded(buses));
      } catch (e) {
        emit(BusError(e.toString()));
      }
    });

    on<SubscribeToLocations>((event, emit) {
      _repository.subscribeToBusLocations().listen((buses) {
        add(LocationsUpdated(buses));
      });
    });

    on<AddBus>((event, emit) async {
      try {
        await _repository.upsert(event.bus);
        add(LoadBuses());
      } catch (e) {
        emit(BusError(e.toString()));
      }
    });

    on<UpdateBus>((event, emit) async {
      try {
        await _repository.upsert(event.bus);
        add(LoadBuses());
      } catch (e) {
        emit(BusError(e.toString()));
      }
    });

    on<LocationsUpdated>((event, emit) {
      if (event.buses.isEmpty && state is BusLoaded) return;
      emit(BusLoaded(event.buses));
    });

    on<DeleteBus>((event, emit) async {
      try {
        await _repository.delete(event.id);
        add(LoadBuses());
      } catch (e) {
        emit(BusError(e.toString()));
      }
    });
  }
}
