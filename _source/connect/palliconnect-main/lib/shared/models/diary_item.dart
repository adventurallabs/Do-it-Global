enum DiaryEntryKind { homework, teacherNote, notice, activity }

class DiaryDayEntry {
  final String id;
  final String studentId;
  final DateTime date;
  final DiaryEntryKind kind;
  final String title;
  final String body;
  final String? teacherName;
  final bool hasAttachment;

  const DiaryDayEntry({
    required this.id,
    required this.studentId,
    required this.date,
    required this.kind,
    required this.title,
    required this.body,
    this.teacherName,
    this.hasAttachment = false,
  });
}
