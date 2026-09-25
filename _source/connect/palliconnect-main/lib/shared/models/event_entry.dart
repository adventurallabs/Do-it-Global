/// An event the child's class can take part in.
class OpenEvent {
  final String id;
  final String name;
  final String description;
  final DateTime eventDate;

  /// How many of its categories this child may enter or has entered.
  final int categoryCount;

  /// How many of those the child is already in.
  final int enteredCount;

  const OpenEvent({
    required this.id,
    required this.name,
    this.description = '',
    required this.eventDate,
    this.categoryCount = 0,
    this.enteredCount = 0,
  });

  bool get isUpcoming => !eventDate.isBefore(DateTime.now().subtract(const Duration(days: 1)));
}

/// One contest inside an event, as a family sees it.
///
/// The category only reaches them at all when its head has opened their
/// child's class to it — so everything here is already theirs to enter.
class OpenEventCategory {
  final String id;
  final String eventId;
  final String name;
  final String description;

  /// Competitive categories end in places; non-competitive ones do not.
  final bool competitive;

  final bool issuesCertificates;

  /// The row id of this child's entry, when they are already in.
  final String? participantId;

  /// True when the family entered the child themselves, so they may also
  /// withdraw. An entry the head made by hand is the head's to undo.
  final bool selfRegistered;

  /// False once the day arrives, or once the head has put them in a room.
  final bool acceptingEntries;

  /// True when the head has already placed them in a room — withdrawing is
  /// no longer theirs to do.
  final bool inRoom;

  const OpenEventCategory({
    required this.id,
    required this.eventId,
    required this.name,
    this.description = '',
    this.competitive = true,
    this.issuesCertificates = true,
    this.participantId,
    this.selfRegistered = false,
    this.acceptingEntries = true,
    this.inRoom = false,
  });

  bool get isEntered => participantId != null;

  bool get canEnter => !isEntered && acceptingEntries;

  bool get canWithdraw => isEntered && selfRegistered && acceptingEntries && !inRoom;

  String get typeLabel => competitive ? 'Competitive' : 'Everyone takes part';
}
