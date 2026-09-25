import 'package:json_annotation/json_annotation.dart';

part 'event_category.g.dart';

/// Whether a category ends in a podium.
///
/// Not every school event is a race. Sports day has heats with places; mass
/// drill, a yoga demonstration, the Republic Day song and a fancy-dress
/// parade have none — everyone who takes part has taken part, and asking the
/// head for three winners would make them invent some.
enum EventCategoryKind {
  @JsonValue('competitive')
  competitive,
  @JsonValue('non_competitive')
  nonCompetitive;

  bool get isCompetitive => this == EventCategoryKind.competitive;

  String get label => switch (this) {
        EventCategoryKind.competitive => 'Competitive',
        EventCategoryKind.nonCompetitive => 'Non-competitive',
      };

  String get blurb => switch (this) {
        EventCategoryKind.competitive =>
          'Rooms award places. Everyone who does not place is a runner.',
        EventCategoryKind.nonCompetitive =>
          'No places and no ranking — everyone who takes part is a participant.',
      };

  /// What the people without a place are called on screen.
  String get otherName => isCompetitive ? 'Runners' : 'Participants';
}

/// One contest inside a school event: "Running" or "Volleyball" under
/// "Sports Day".
///
/// A category is the unit everything else hangs off — it has heads who run
/// it, participants entered into it, and rooms that are raced or played.
@JsonSerializable(fieldRename: FieldRename.snake)
class EventCategory {
  final String id;
  final String eventId;
  final String name;
  final String description;

  /// Decided by the admin when the category is made, and fixed once any
  /// place has been awarded.
  final EventCategoryKind kind;

  /// Whether taking part here earns a certificate at all. A house march-past
  /// usually does not.
  final bool issuesCertificates;

  final DateTime? createdAt;

  const EventCategory({
    required this.id,
    required this.eventId,
    required this.name,
    this.description = '',
    this.kind = EventCategoryKind.competitive,
    this.issuesCertificates = true,
    this.createdAt,
  });

  bool get isCompetitive => kind.isCompetitive;

  factory EventCategory.fromJson(Map<String, dynamic> json) => _$EventCategoryFromJson(json);
  Map<String, dynamic> toJson() => _$EventCategoryToJson(this);

  EventCategory copyWith({
    String? name,
    String? description,
    EventCategoryKind? kind,
    bool? issuesCertificates,
  }) =>
      EventCategory(
        id: id,
        eventId: eventId,
        name: name ?? this.name,
        description: description ?? this.description,
        kind: kind ?? this.kind,
        issuesCertificates: issuesCertificates ?? this.issuesCertificates,
        createdAt: createdAt,
      );
}

/// A teacher put in charge of a category. One teacher may head several, and
/// a category may have more than one head — both directions are real: the PT
/// master runs four track events, and volleyball needs two people.
@JsonSerializable(fieldRename: FieldRename.snake)
class EventCategoryHead {
  final String categoryId;
  final String teacherId;

  const EventCategoryHead({required this.categoryId, required this.teacherId});

  factory EventCategoryHead.fromJson(Map<String, dynamic> json) =>
      _$EventCategoryHeadFromJson(json);
  Map<String, dynamic> toJson() => _$EventCategoryHeadToJson(this);
}

/// A student entered into a category, from the class they represent.
///
/// [classroomId] is stamped when they are entered rather than read from the
/// student later — it is the class they competed for on the day, which does
/// not change when they move up a year.
@JsonSerializable(fieldRename: FieldRename.snake)
class EventParticipant {
  final String id;
  final String categoryId;
  final String studentId;
  final String classroomId;
  final String? addedBy;

  /// True when the family entered the child themselves from PalliConnect,
  /// rather than the head adding them. The head sees which is which.
  final bool selfRegistered;

  const EventParticipant({
    required this.id,
    required this.categoryId,
    required this.studentId,
    this.classroomId = '',
    this.addedBy,
    this.selfRegistered = false,
  });

  factory EventParticipant.fromJson(Map<String, dynamic> json) =>
      _$EventParticipantFromJson(json);
  Map<String, dynamic> toJson() => _$EventParticipantToJson(this);
}
