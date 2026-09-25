import 'package:core_models/core_models.dart';
import 'record_export.dart';

/// Builds the spreadsheet a school keeps once a leaver's record is erased.
///
/// The archive deletes for good after 30 days, so this is the last copy that
/// will exist. It therefore writes out the whole file — the profile, and for
/// a child every mark and every attendance day — rather than a summary.
class LeaverExport {
  LeaverExport._();

  static String _date(DateTime? value) {
    if (value == null) return '';
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  static String _money(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2);

  static const _staffHeaders = [
    'Name',
    'Staff ID',
    'Role',
    'Subjects',
    'Contact number',
    'Date of birth',
    'Qualification',
    'Address',
    'Salary',
    'Left because',
    'Left on',
    'Erased on',
    'Note',
  ];

  static List<String> _staffRow(Teacher teacher) => [
        teacher.name,
        teacher.id,
        teacher.roleLabel,
        teacher.subjects.join('; '),
        teacher.contactNumber,
        _date(teacher.dob),
        teacher.qualification,
        teacher.address,
        _money(teacher.salary),
        teacher.exit?.reason.label ?? '',
        _date(teacher.exitAt),
        _date(teacher.purgeAfter),
        teacher.exitNote,
      ];

  /// One row per staff member — the shape for "download every discontinued
  /// teacher", and equally correct for a single one.
  static List<ExportSheet> staff(List<Teacher> teachers) => [
        ExportSheet(
          name: 'Staff',
          headers: _staffHeaders,
          rows: [for (final t in teachers) _staffRow(t)],
        ),
      ];

  static const _studentHeaders = [
    'Name',
    'Admission number',
    'Roll number',
    'Class when they left',
    'Father',
    'Mother',
    'Contact number',
    'Second contact',
    'Address',
    'Date of birth',
    'Fees',
    'Academic year',
    'Left because',
    'Left on',
    'Erased on',
    'Note',
  ];

  static List<String> _studentRow(Student student, {String className = ''}) => [
        student.name,
        student.admissionNo,
        student.rollNumber,
        className,
        student.fatherName,
        student.motherName,
        student.contactNumber,
        student.secondaryContactNumber ?? '',
        student.address,
        _date(student.dob),
        _money(student.fees),
        student.academicYearId,
        student.lifecycle.label,
        _date(student.exitAt),
        _date(student.purgeAfter),
        student.exitNote,
      ];

  /// One row per child. [classNames] maps a classroom id to its display name
  /// — a leaver's own classroom is already cleared, so the caller passes the
  /// class they were in when the exit was recorded, if it knows it.
  static List<ExportSheet> students(
    List<Student> students, {
    Map<String, String> classNames = const {},
  }) =>
      [
        ExportSheet(
          name: 'Students',
          headers: _studentHeaders,
          rows: [
            for (final s in students)
              _studentRow(s, className: classNames[s.classroomId] ?? ''),
          ],
        ),
      ];

  /// A single child's complete file: profile, every mark, every attendance
  /// day. Empty sections are left out so the workbook has no blank tabs.
  static List<ExportSheet> studentFile(
    Student student, {
    String className = '',
    List<Mark> marks = const [],
    List<Attendance> attendance = const [],
  }) {
    final sheets = <ExportSheet>[
      ExportSheet(
        name: 'Profile',
        headers: _studentHeaders,
        rows: [_studentRow(student, className: className)],
      ),
    ];

    if (marks.isNotEmpty) {
      final sorted = [...marks]..sort((a, b) => b.date.compareTo(a.date));
      sheets.add(ExportSheet(
        name: 'Marks',
        headers: const ['Date', 'Subject', 'Test', 'Score', 'Out of', 'Percent', 'Grade'],
        rows: [
          for (final m in sorted)
            [
              _date(m.date),
              m.subject,
              m.testType,
              // Absent is not a zero.
              // A grades-only paper has no score (total 0) — leave it blank.
              m.isAbsent ? 'AB' : (m.totalMarks <= 0 ? '' : _money(m.score)),
              m.totalMarks <= 0 ? '' : _money(m.totalMarks),
              m.isAbsent || m.totalMarks <= 0 ? '' : ((m.score / m.totalMarks) * 100).round().toString(),
              m.isAbsent ? '' : (m.grade ?? ''),
            ],
        ],
      ));
    }

    if (attendance.isNotEmpty) {
      final sorted = [...attendance]..sort((a, b) => b.date.compareTo(a.date));
      sheets.add(ExportSheet(
        name: 'Attendance',
        headers: const ['Date', 'Status', 'Kind'],
        rows: [
          for (final a in sorted)
            [
              _date(a.date),
              switch (a.status) {
                AttendanceStatus.present => 'Present',
                AttendanceStatus.absent => 'Absent',
                AttendanceStatus.od => 'On duty / excused',
                AttendanceStatus.delayed => 'Late',
              },
              a.periodId == 'homeroom' ? 'Daily roll call' : a.periodId,
            ],
        ],
      ));
    }

    return sheets;
  }

  /// A single staff member's file. Kept as its own entry point so callers
  /// read the same way for both kinds of leaver.
  static List<ExportSheet> staffFile(Teacher teacher) => staff([teacher]);
}
