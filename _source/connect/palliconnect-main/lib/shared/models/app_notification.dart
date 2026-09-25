enum NotificationKind {
  homework,
  marks,
  attendance,
  fees,
  announcement,
  activity,
  star,
  growth,
  libraryBook,
  school,
}

class AppNotification {
  final String id;
  final String studentId;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final String deepLink;
  final bool grouped;
  final int? groupCount;
  final bool important;
  final bool read;

  const AppNotification({
    required this.id,
    required this.studentId,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.deepLink,
    this.grouped = false,
    this.groupCount,
    this.important = false,
    this.read = false,
  });

  /// A message-kind alert (its deep link points at a chat thread) — these
  /// get their own badge on the Messages tab instead of the general bell.
  bool get isMessageAlert => deepLink.startsWith('thread:');

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      studentId: studentId,
      kind: kind,
      title: title,
      body: body,
      createdAt: createdAt,
      deepLink: deepLink,
      grouped: grouped,
      groupCount: groupCount,
      important: important,
      read: read ?? this.read,
    );
  }
}
