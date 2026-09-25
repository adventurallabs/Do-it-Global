import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// How far along one homework is: how many students still owe it, how many
/// are waiting on the teacher, how many are signed off.
class HomeworkProgress {
  final int total;
  final int toReview;
  final int done;

  const HomeworkProgress({this.total = 0, this.toReview = 0, this.done = 0});

  int get outstanding => (total - done).clamp(0, total);
  bool get allDone => total > 0 && done >= total;

  /// The one line that goes under a homework title. Written the way a teacher
  /// would say it out loud, not as raw counts.
  String get label {
    if (total == 0) return 'No students in this class';
    if (toReview > 0) return '$toReview waiting for you';
    if (allDone) return 'All $total done';
    return '$done of $total done';
  }

  Color color(BuildContext context) {
    if (toReview > 0) return AppColors.warning;
    if (allDone) return AppColors.success;
    return AppColors.onSurfaceMuted(context);
  }
}

/// Midnight-anchored day difference, so "due today" does not flip at the hour
/// the homework was created.
int daysUntilDue(DateTime due, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final a = DateTime(today.year, today.month, today.day);
  final b = DateTime(due.year, due.month, due.day);
  return b.difference(a).inDays;
}

bool isOverdue(DateTime due, {DateTime? now}) => daysUntilDue(due, now: now) < 0;

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "Due today", "Overdue by 3 days", "Due Friday" — never a bare date the
/// teacher has to compare against a calendar in their head.
String dueLabel(DateTime due, {DateTime? now}) {
  final days = daysUntilDue(due, now: now);
  if (days == 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';
  if (days == -1) return 'Was due yesterday';
  if (days < -1) return 'Overdue by ${-days} days';
  if (days <= 6) return 'Due ${_weekdays[due.weekday - 1]}';
  return 'Due ${due.day} ${_months[due.month - 1]}';
}

/// Plain date, for places that show the date itself rather than the distance.
String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

Color dueColor(BuildContext context, DateTime due, {DateTime? now}) {
  final days = daysUntilDue(due, now: now);
  if (days < 0) return AppColors.error;
  if (days == 0) return AppColors.warning;
  return AppColors.onSurfaceMuted(context);
}

/// Which bucket a homework falls into on the board.
enum HomeworkLane { needsReview, active, past }

HomeworkLane laneFor(Homework hw, HomeworkProgress progress, {DateTime? now}) {
  if (progress.toReview > 0) return HomeworkLane.needsReview;
  if (isOverdue(hw.dueDate, now: now)) return HomeworkLane.past;
  return HomeworkLane.active;
}
