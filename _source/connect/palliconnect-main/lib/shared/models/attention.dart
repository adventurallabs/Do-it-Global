enum AttentionKind { homeworkToday, homeworkOverdue, fee, announcement, attendance, marks, profile }

class AttentionItem {
  final AttentionKind kind;
  final String title;
  final String subtitle;
  final String deepLink;

  const AttentionItem({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.deepLink,
  });
}

class Announcement {
  final String id;
  final String studentId;
  final String title;
  final String body;
  final DateTime date;
  final bool important;

  const Announcement({
    required this.id,
    required this.studentId,
    required this.title,
    required this.body,
    required this.date,
    this.important = false,
  });
}
