/// How the child did in one event category.
///
/// Built from a submitted room: a place means they won it, no place means
/// they were a runner. The certificate is only offered once the school has
/// chosen a layout — until then the result is shown without one.
class ChildEventResult {
  final String roomId;
  final String roomName;
  final String categoryId;
  final String categoryName;
  final String eventId;
  final String eventName;
  final DateTime eventDate;
  final String classLabel;

  /// 1 for first place. Null when the child was a runner.
  final int? position;

  /// False for a category that is not a contest at all — mass drill, a
  /// yoga demonstration. Nobody is ranked, so nobody is a "runner".
  final bool competitive;

  /// How many places the room awarded — "3rd of 3".
  final int prizeCount;

  /// The layout the admin published, or null while certificates are not out.
  final String? certificateLayoutId;

  final DateTime? submittedAt;

  const ChildEventResult({
    required this.roomId,
    required this.roomName,
    required this.categoryId,
    required this.categoryName,
    required this.eventId,
    required this.eventName,
    required this.eventDate,
    this.classLabel = '',
    this.position,
    this.competitive = true,
    this.prizeCount = 3,
    this.certificateLayoutId,
    this.submittedAt,
  });

  bool get isWinner => position != null;

  bool get hasCertificate => (certificateLayoutId ?? '').isNotEmpty;

  /// "1st place", or what the people without one are called here.
  String get placeLabel =>
      position == null ? (competitive ? 'Runner' : 'Participant') : '$ordinal place';

  String get ordinal {
    final n = position;
    if (n == null) return '';
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }
}
