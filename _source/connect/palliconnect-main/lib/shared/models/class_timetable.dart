/// Read-only view of a class timetable, mirrored from the school app.
class TimetablePeriod {
  final String id;
  final String name;
  final String staffId;
  final String startTime; // "HH:mm"
  final int durationMinutes;
  final String dayOfWeek; // "Monday" ... "Sunday"
  final bool isTemporary;
  final DateTime? date;
  final String? teacherName;

  const TimetablePeriod({
    required this.id,
    required this.name,
    required this.staffId,
    required this.startTime,
    required this.durationMinutes,
    required this.dayOfWeek,
    this.isTemporary = false,
    this.date,
    this.teacherName,
  });

  TimetablePeriod withTeacher(String? name) => TimetablePeriod(
        id: id,
        name: this.name,
        staffId: staffId,
        startTime: startTime,
        durationMinutes: durationMinutes,
        dayOfWeek: dayOfWeek,
        isTemporary: isTemporary,
        date: date,
        teacherName: name,
      );

  bool get isBreak {
    final n = name.toLowerCase();
    return n.contains('break') || n.contains('lunch') || n.contains('interval') || staffId == 'N/A';
  }

  int get startMinutes {
    final parts = startTime.split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  int get endMinutes => startMinutes + durationMinutes;

  String get endTime {
    final end = endMinutes % (24 * 60);
    return '${(end ~/ 60).toString().padLeft(2, '0')}:${(end % 60).toString().padLeft(2, '0')}';
  }

  factory TimetablePeriod.fromJson(Map<String, dynamic> json) {
    return TimetablePeriod(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      staffId: (json['staff_id'] ?? json['staffId'] ?? '') as String,
      startTime: (json['start_time'] ?? json['startTime'] ?? '08:00') as String,
      durationMinutes:
          ((json['duration_minutes'] ?? json['durationMinutes'] ?? 40) as num).toInt(),
      dayOfWeek: (json['day_of_week'] ?? json['dayOfWeek'] ?? 'Monday') as String,
      isTemporary:
          (json['is_temporary'] ?? json['isTemporary'] ?? false) as bool,
      date: (json['date'] as String?) != null
          ? DateTime.tryParse(json['date'] as String)
          : null,
    );
  }
}

class ClassTimetable {
  final String id;
  final String classroomId;
  final String name;
  final String startTime;
  final String endTime;
  final List<TimetablePeriod> periods;

  const ClassTimetable({
    required this.id,
    required this.classroomId,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.periods,
  });

  static const weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  /// Regular periods for [day], sorted. Ignores one-day cover periods.
  List<TimetablePeriod> forDay(String day) => periodsOn(day);

  /// What actually runs on [day]. With [date], a cover period for that exact
  /// date replaces the regular period in its slot; covers for other dates are
  /// ignored (they must not show up every week).
  List<TimetablePeriod> periodsOn(String day, {DateTime? date}) {
    final list = periods.where((p) => p.dayOfWeek == day && !p.isTemporary).toList();
    if (date != null) {
      for (final c in periods.where((p) =>
          p.isTemporary &&
          p.dayOfWeek == day &&
          p.date != null &&
          p.date!.year == date.year &&
          p.date!.month == date.month &&
          p.date!.day == date.day)) {
        list.removeWhere((p) => p.startTime == c.startTime);
        list.add(c);
      }
    }
    list.sort((a, b) {
      final t = a.startMinutes.compareTo(b.startMinutes);
      return t != 0 ? t : a.durationMinutes.compareTo(b.durationMinutes);
    });
    return list;
  }

  /// School days to show: Mon–Fri plus any other day that has periods.
  List<String> get schoolDays {
    final used = {for (final p in periods) if (!p.isTemporary) p.dayOfWeek};
    if (used.isEmpty) return const [];
    return weekdays.where((d) => weekdays.indexOf(d) < 5 || used.contains(d)).toList();
  }

  factory ClassTimetable.fromRow(Map<String, dynamic> row) {
    final rawPeriods = (row['periods'] as List?) ?? const [];
    return ClassTimetable(
      id: (row['id'] ?? '') as String,
      classroomId: (row['classroom_id'] ?? '') as String,
      name: (row['name'] ?? 'Timetable') as String,
      startTime: (row['start_time'] ?? '08:30') as String,
      endTime: (row['end_time'] ?? '15:30') as String,
      periods: rawPeriods
          .whereType<Map>()
          .map((m) => TimetablePeriod.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }
}
