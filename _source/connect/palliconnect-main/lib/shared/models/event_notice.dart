class EventNotice {
  final String id;
  final String eventId;
  final String title;
  final String body;
  final String description;
  final DateTime eventDate;
  final DateTime? lastPayDate;
  final double feeAmount;
  final DateTime? seenAt;
  final DateTime createdAt;

  const EventNotice({
    required this.id,
    required this.eventId,
    required this.title,
    required this.body,
    required this.description,
    required this.eventDate,
    this.lastPayDate,
    this.feeAmount = 0,
    this.seenAt,
    required this.createdAt,
  });

  bool get requiresFee => feeAmount > 0;
  bool get isSeen => seenAt != null;
}
