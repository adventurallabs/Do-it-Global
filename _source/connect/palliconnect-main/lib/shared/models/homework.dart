enum HomeworkUrgency { overdue, dueToday, upcoming, completed }

enum HomeworkStatus { pending, underReview, completed }

class HomeworkItem {
  final String id;
  final String studentId;
  final String subject;
  final String title;
  final String instructions;
  final String teacherName;
  final DateTime assignedOn;
  final DateTime dueDate;
  final HomeworkStatus status;
  final bool hasAttachment;
  final DateTime? completedAt;

  const HomeworkItem({
    required this.id,
    required this.studentId,
    required this.subject,
    required this.title,
    required this.instructions,
    required this.teacherName,
    required this.assignedOn,
    required this.dueDate,
    this.status = HomeworkStatus.pending,
    this.hasAttachment = false,
    this.completedAt,
  });

  bool get isCompleted => status == HomeworkStatus.completed;
  bool get isUnderReview => status == HomeworkStatus.underReview;
  bool get isPending => status == HomeworkStatus.pending;
  
  // Legacy getter to prevent compilation errors during migration
  bool get completed => isCompleted;

  HomeworkUrgency urgencyOn(DateTime now) {
    if (isCompleted) return HomeworkUrgency.completed;
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    if (due.isBefore(today)) return HomeworkUrgency.overdue;
    if (due == today) return HomeworkUrgency.dueToday;
    return HomeworkUrgency.upcoming;
  }

  HomeworkItem copyWith({
    HomeworkStatus? status,
    DateTime? completedAt,
  }) {
    return HomeworkItem(
      id: id,
      studentId: studentId,
      subject: subject,
      title: title,
      instructions: instructions,
      teacherName: teacherName,
      assignedOn: assignedOn,
      dueDate: dueDate,
      status: status ?? this.status,
      hasAttachment: hasAttachment,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
