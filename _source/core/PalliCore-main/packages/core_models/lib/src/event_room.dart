import 'package:json_annotation/json_annotation.dart';

part 'event_room.g.dart';

/// A room only ever moves forward. Starting it fixes who is in it; submitting
/// fixes who won.
enum EventRoomStatus {
  @JsonValue('draft')
  draft,
  @JsonValue('started')
  started,
  @JsonValue('submitted')
  submitted;

  bool get isDraft => this == EventRoomStatus.draft;
  bool get isStarted => this == EventRoomStatus.started;
  bool get isSubmitted => this == EventRoomStatus.submitted;

  /// Participants can only be added or removed before the whistle.
  bool get acceptsParticipants => this == EventRoomStatus.draft;

  /// Places can be assigned once it is running, until it is submitted.
  bool get acceptsResults => this == EventRoomStatus.started;

  String get label => switch (this) {
        EventRoomStatus.draft => 'Not started',
        EventRoomStatus.started => 'In progress',
        EventRoomStatus.submitted => 'Results out',
      };
}

/// One heat, match or round of a category — a category can have many.
@JsonSerializable(fieldRename: FieldRename.snake)
class EventRoom {
  final String id;
  final String categoryId;
  final String name;
  final EventRoomStatus status;

  /// How many places this room awards. Three unless the head changed it.
  final int prizeCount;
  final DateTime? startedAt;
  final DateTime? submittedAt;
  final String? createdBy;
  final DateTime? createdAt;

  const EventRoom({
    required this.id,
    required this.categoryId,
    required this.name,
    this.status = EventRoomStatus.draft,
    this.prizeCount = 3,
    this.startedAt,
    this.submittedAt,
    this.createdBy,
    this.createdAt,
  });

  factory EventRoom.fromJson(Map<String, dynamic> json) => _$EventRoomFromJson(json);
  Map<String, dynamic> toJson() => _$EventRoomToJson(this);

  EventRoom copyWith({String? name, EventRoomStatus? status, int? prizeCount}) => EventRoom(
        id: id,
        categoryId: categoryId,
        name: name ?? this.name,
        status: status ?? this.status,
        prizeCount: prizeCount ?? this.prizeCount,
        startedAt: startedAt,
        submittedAt: submittedAt,
        createdBy: createdBy,
        createdAt: createdAt,
      );
}

/// A place awarded in a room. Position 1 is first place.
///
/// There is no row for a runner: everyone in the room without a place is one.
/// Recording the absence would be a second thing to keep in step with the
/// room's participants, and it would drift.
@JsonSerializable(fieldRename: FieldRename.snake)
class EventResult {
  final String roomId;
  final int position;
  final String participantId;

  const EventResult({
    required this.roomId,
    required this.position,
    required this.participantId,
  });

  factory EventResult.fromJson(Map<String, dynamic> json) => _$EventResultFromJson(json);
  Map<String, dynamic> toJson() => _$EventResultToJson(this);
}

/// The layout the admin published for a room's certificates.
///
/// The certificate itself is never stored anywhere. This row plus the result
/// is everything needed to draw one, and it is drawn on the parent's device
/// at the moment they ask for it.
@JsonSerializable(fieldRename: FieldRename.snake)
class EventCertificate {
  final String roomId;
  final String layoutId;
  final DateTime? publishedAt;

  const EventCertificate({
    required this.roomId,
    required this.layoutId,
    this.publishedAt,
  });

  factory EventCertificate.fromJson(Map<String, dynamic> json) =>
      _$EventCertificateFromJson(json);
  Map<String, dynamic> toJson() => _$EventCertificateToJson(this);
}

/// What a certificate says about one child: first place, or a runner.
enum EventStanding {
  winner,
  runner;

  bool get isWinner => this == EventStanding.winner;
}

/// Where one child finished, ready to print. [position] is null for a runner.
class EventStandingRecord {
  final String participantId;
  final String studentId;
  final String studentName;
  final String classroomLabel;
  final int? position;

  const EventStandingRecord({
    required this.participantId,
    required this.studentId,
    required this.studentName,
    this.classroomLabel = '',
    this.position,
  });

  EventStanding get standing =>
      position == null ? EventStanding.runner : EventStanding.winner;

  /// "1st place", "2nd place" — or "Runner" when they did not place.
  String get placeLabel => position == null ? 'Runner' : '${ordinal(position!)} place';

  static String ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }
}
