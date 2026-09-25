import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';

abstract class AnnouncementEvent {}

class LoadAnnouncements extends AnnouncementEvent {}

class CreateAnnouncement extends AnnouncementEvent {
  final Announcement announcement;
  CreateAnnouncement(this.announcement);
}

class UpdateAnnouncement extends AnnouncementEvent {
  final Announcement announcement;
  UpdateAnnouncement(this.announcement);
}

class DeleteAnnouncement extends AnnouncementEvent {
  final String id;
  DeleteAnnouncement(this.id);
}

abstract class AnnouncementState {}

class AnnouncementInitial extends AnnouncementState {}

class AnnouncementLoading extends AnnouncementState {}

class AnnouncementLoaded extends AnnouncementState {
  final List<Announcement> announcements;
  AnnouncementLoaded(this.announcements);
}

class AnnouncementError extends AnnouncementState {
  final String message;
  AnnouncementError(this.message);
}

class AnnouncementBloc extends Bloc<AnnouncementEvent, AnnouncementState> {
  final AnnouncementRepository _repository;

  AnnouncementBloc(this._repository) : super(AnnouncementInitial()) {
    on<LoadAnnouncements>((event, emit) async {
      emit(AnnouncementLoading());
      try {
        final announcements = await _repository.getAll();
        emit(AnnouncementLoaded(announcements));
      } catch (e) {
        emit(AnnouncementError(e.toString()));
      }
    });

    on<CreateAnnouncement>((event, emit) async {
      try {
        await _repository.upsert(event.announcement);
        add(LoadAnnouncements());
      } catch (e) {
        emit(AnnouncementError(e.toString()));
      }
    });

    on<UpdateAnnouncement>((event, emit) async {
      try {
        await _repository.upsert(event.announcement);
        add(LoadAnnouncements());
      } catch (e) {
        emit(AnnouncementError(e.toString()));
      }
    });

    on<DeleteAnnouncement>((event, emit) async {
      try {
        await _repository.delete(event.id);
        add(LoadAnnouncements());
      } catch (e) {
        emit(AnnouncementError(e.toString()));
      }
    });
  }
}
