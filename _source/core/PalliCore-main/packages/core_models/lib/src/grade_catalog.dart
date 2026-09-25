import 'classroom.dart';

class ParsedClassroomName {
  final String gradeKey;
  final String section;

  const ParsedClassroomName({required this.gradeKey, required this.section});
}

class ClassroomGradeGroup {
  final String gradeKey;
  final List<Classroom> classrooms;

  const ClassroomGradeGroup({
    required this.gradeKey,
    required this.classrooms,
  });

  String get title => GradeCatalog.label(gradeKey);

  bool get exists => classrooms.isNotEmpty;

  bool get hasSections {
    if (classrooms.length > 1) return true;
    if (classrooms.isEmpty) return false;
    return classrooms.first.resolvedSection.isNotEmpty;
  }

  Classroom? get singleClassroom =>
      classrooms.length == 1 ? classrooms.first : null;
}

class GradeCatalog {
  GradeCatalog._();

  static const List<String> orderedKeys = [
    'LKG',
    'UKG',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    '11',
    '12',
  ];

  static const List<String> sectionChoices = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];

  static String label(String key) {
    switch (key) {
      case 'LKG':
        return 'LKG';
      case 'UKG':
        return 'UKG';
      case '1':
        return '1st Std';
      case '2':
        return '2nd Std';
      case '3':
        return '3rd Std';
      default:
        if (int.tryParse(key) != null) return '${key}th Std';
        return key;
    }
  }

  static String composeName(String gradeKey, String section) {
    final grade = label(gradeKey);
    final trimmed = section.trim().toUpperCase();
    if (trimmed.isEmpty) return grade;
    return '$grade $trimmed';
  }

  static ParsedClassroomName parse(String name) {
    final raw = name.trim();
    if (raw.isEmpty) {
      return const ParsedClassroomName(gradeKey: '1', section: '');
    }

    final upper = raw.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    String? gradeKey;
    var rest = upper;

    if (upper.contains('LKG')) {
      gradeKey = 'LKG';
      rest = upper.replaceFirst('LKG', '');
    } else if (upper.contains('UKG')) {
      gradeKey = 'UKG';
      rest = upper.replaceFirst('UKG', '');
    } else {
      final ordinal = RegExp(
        r'\b(\d{1,2})\s*(ST|ND|RD|TH)?\b',
      ).firstMatch(upper);
      if (ordinal != null) {
        gradeKey = ordinal.group(1);
        rest = upper.replaceFirst(ordinal.group(0)!, '');
      }
    }

    rest = rest
        .replaceAll(RegExp(r'\b(STD|STANDARD|CLASS|SECTION)\b'), '')
        .replaceAll(RegExp(r'[^A-Z0-9]'), ' ')
        .trim();

    var section = '';
    final sectionMatch = RegExp(r'\b([A-G])\b').firstMatch(rest);
    if (sectionMatch != null) {
      section = sectionMatch.group(1)!;
    }

    return ParsedClassroomName(
      gradeKey: gradeKey ?? '1',
      section: section,
    );
  }

  static List<ClassroomGradeGroup> group(
    List<Classroom> classrooms, {
    bool includeEmpty = true,
  }) {
    final map = <String, List<Classroom>>{
      for (final key in orderedKeys) key: <Classroom>[],
    };
    final extras = <String, List<Classroom>>{};

    for (final classroom in classrooms) {
      final key = classroom.resolvedGradeKey;
      if (map.containsKey(key)) {
        map[key]!.add(classroom);
      } else {
        extras.putIfAbsent(key, () => []).add(classroom);
      }
    }

    for (final rooms in map.values) {
      rooms.sort((a, b) => a.resolvedSection.compareTo(b.resolvedSection));
    }

    final groups = <ClassroomGradeGroup>[
      for (final key in orderedKeys)
        if (includeEmpty || map[key]!.isNotEmpty)
          ClassroomGradeGroup(gradeKey: key, classrooms: map[key]!),
    ];

    extras.forEach((key, rooms) {
      rooms.sort((a, b) => a.resolvedSection.compareTo(b.resolvedSection));
      groups.add(ClassroomGradeGroup(gradeKey: key, classrooms: rooms));
    });

    return groups;
  }

  /// Grade keys in school order (LKG, UKG, 1 … 12), unknown keys last.
  static List<String> sortKeys(Iterable<String> keys) {
    int rank(String k) {
      final i = orderedKeys.indexOf(k);
      return i < 0 ? orderedKeys.length : i;
    }

    return keys.toSet().toList()..sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : a.compareTo(b);
      });
  }

  static String? nextKey(String key) {
    final index = orderedKeys.indexOf(key);
    if (index < 0 || index >= orderedKeys.length - 1) return null;
    return orderedKeys[index + 1];
  }

  static String weekdayName(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
