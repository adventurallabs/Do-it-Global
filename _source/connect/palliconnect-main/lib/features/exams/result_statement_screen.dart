import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_provider.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/localization/l10n_ext.dart';
import '../../shared/models/exams.dart';
import '../../shared/widgets/error_state.dart';
import 'exam_providers.dart';
import 'exam_widgets.dart';

/// A child's statement of marks for one exam, laid out the way the state
/// board prints one: the student's particulars, then one bordered row per
/// subject, then total and result. A subject whose teacher hasn't submitted
/// yet stays in the table with its result blank.
///
/// The columns follow what the school chose for the exam: marks, grades, or
/// both.
class ResultStatementScreen extends ConsumerWidget {
  final String examId;
  const ResultStatementScreen({super.key, required this.examId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(parentExamResultsProvider);
    final student = ref.watch(currentStudentProvider);
    final school = ref.watch(currentSchoolProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.exStatementOfMarks)),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AppErrorState(onRetry: () {
            ref.invalidate(parentExamsProvider);
            ref.invalidate(parentExamMarksProvider);
          }),
          data: (sheets) {
            final sheet = sheets.where((s) => s.exam.examId == examId).firstOrNull;
            if (sheet == null) {
              return Center(child: Text(l10n.exResultsNotOut));
            }
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(parentExamMarksProvider);
                await ref.read(parentExamMarksProvider.future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xl),
                children: [
                  _Statement(
                    sheet: sheet,
                    schoolName: school?.name ?? '',
                    studentName: student?.fullName ?? '',
                    registerNo: student?.admissionNo ?? '',
                    rollNo: student?.rollNo ?? '',
                    // The class the exam was sat in — after promotion the
                    // child's current section says nothing about it.
                    classSection: [
                      gradeLabel(sheet.exam.gradeKey),
                      if (student?.className == sheet.exam.gradeKey && (student?.sectionName ?? '').isNotEmpty)
                        student!.sectionName,
                    ].join(' '),
                  ),
                  if (sheet.exam.mode.usesGrades && sheet.exam.scale.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _ScaleKey(exam: sheet.exam),
                  ],
                  if (sheet.awaitedCount > 0) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _Note(
                      icon: Icons.hourglass_top_rounded,
                      color: AppColors.primaryBlue,
                      text: l10n.exPendingNote(sheet.awaitedCount),
                    ),
                  ],
                  if (sheet.rows.any((r) => r.absent)) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _Note(icon: Icons.info_outline_rounded, color: AppColors.warning, text: l10n.exAbsentNote),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

typedef _CellStyle = TextStyle Function({bool bold, Color? color, double size});
typedef _Pad = Widget Function(Widget child, {Alignment align});

class _Statement extends StatelessWidget {
  final ExamResultSheet sheet;
  final String schoolName;
  final String studentName;
  final String registerNo;
  final String rollNo;
  final String classSection;

  const _Statement({
    required this.sheet,
    required this.schoolName,
    required this.studentName,
    required this.registerNo,
    required this.rollNo,
    required this.classSection,
  });

  ExamResultMode get _mode => sheet.exam.mode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final line = isDark ? AppColors.grey600 : AppColors.grey300;
    final paper = isDark ? AppColors.surfaceDark : Colors.white;
    final headBg = isDark ? AppColors.royalBlue.withValues(alpha: 0.4) : AppColors.royalBlue;
    final subBg = isDark ? AppColors.royalBlue.withValues(alpha: 0.16) : AppColors.infoSoft;
    final ink = theme.textTheme.bodyLarge?.color;

    TextStyle cell({bool bold = false, Color? color, double size = 13.5}) =>
        TextStyle(fontSize: size, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: color ?? ink, height: 1.25);

    Widget pad(Widget child, {Alignment align = Alignment.centerLeft}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Align(alignment: align, child: child),
        );

    final passed = sheet.passed;
    final overallColor = passed == null
        ? AppColors.primaryBlue
        : passed
            ? AppColors.success
            : AppColors.error;

    // Column plan per result type. Widths sum to what fits a 360dp phone
    // beside a flexible subject column.
    final cols = <_Col>[
      _Col(l10n.exSNo, const FixedColumnWidth(34)),
      _Col(l10n.exSubject, const FlexColumnWidth()),
      if (_mode.usesMarks) _Col(l10n.exMax, const FixedColumnWidth(42)),
      if (_mode == ExamResultMode.marks) _Col(l10n.exPass, const FixedColumnWidth(42)),
      if (_mode.usesMarks) _Col(l10n.exMarks, const FixedColumnWidth(56)),
      if (_mode.usesGrades) _Col(l10n.exGrade, FixedColumnWidth(_mode == ExamResultMode.grades ? 96 : 56)),
      _Col(l10n.exResult, const FixedColumnWidth(58)),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: paper,
        border: Border.all(color: line, width: 1.2),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: headBg,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                children: [
                  if (schoolName.isNotEmpty)
                    Text(schoolName.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.8)),
                  const SizedBox(height: 4),
                  Text(l10n.exStatementOfMarks.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1.4)),
                  const SizedBox(height: 2),
                  Text(sheet.exam.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                ],
              ),
            ),
            Table(
              border: TableBorder(
                horizontalInside: BorderSide(color: line),
                verticalInside: BorderSide(color: line),
                bottom: BorderSide(color: line),
              ),
              columnWidths: const {0: FlexColumnWidth(1.1), 1: FlexColumnWidth(1.9)},
              children: [
                for (final (k, v) in [
                  (l10n.exStudentName, studentName),
                  (l10n.exRegisterNo, registerNo),
                  (l10n.exClassSection, classSection),
                  (l10n.exRollNo, rollNo),
                ])
                  TableRow(
                    decoration: BoxDecoration(color: subBg.withValues(alpha: 0.45)),
                    children: [
                      pad(Text(k, style: cell(size: 12.5, color: theme.textTheme.bodySmall?.color))),
                      pad(Text(v.isEmpty ? '—' : v, style: cell(bold: true))),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Table(
              border: TableBorder(
                top: BorderSide(color: line),
                bottom: BorderSide(color: line),
                horizontalInside: BorderSide(color: line),
                verticalInside: BorderSide(color: line),
              ),
              columnWidths: {for (var i = 0; i < cols.length; i++) i: cols[i].width},
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: BoxDecoration(color: subBg),
                  children: [
                    for (var i = 0; i < cols.length; i++)
                      pad(
                        Text(cols[i].title, style: cell(bold: true, size: 11)),
                        align: i == 1 ? Alignment.centerLeft : Alignment.center,
                      ),
                  ],
                ),
                for (var i = 0; i < sheet.rows.length; i++) _row(context, i, sheet.rows[i], cell, pad),
                if (_mode.usesMarks) _totalRow(l10n.exTotal, subBg, cell, pad),
              ],
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: _mode.usesMarks
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.exPercentage, style: theme.textTheme.labelSmall),
                              Text(
                                sheet.percent == null ? '—' : '${sheet.percent!.toStringAsFixed(1)}%',
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              if (sheet.overallGrade != null)
                                Text('${l10n.exOverallGrade}: ${sheet.overallGrade}',
                                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                            ],
                          )
                        : Text(
                            '${sheet.releasedCount}/${sheet.rows.length} · ${l10n.exGraded}',
                            style: theme.textTheme.labelLarge,
                          ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(l10n.exOverall, style: theme.textTheme.labelSmall),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: overallColor.withValues(alpha: 0.14),
                          border: Border.all(color: overallColor.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          passed == null
                              ? l10n.exAwaited.toUpperCase()
                              : passed
                                  ? l10n.exResultPass
                                  : l10n.exResultFail,
                          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, color: overallColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  TableRow _totalRow(String label, Color subBg, _CellStyle cell, _Pad pad) {
    return TableRow(
      decoration: BoxDecoration(color: subBg.withValues(alpha: 0.6)),
      children: [
        const SizedBox.shrink(),
        pad(Text(label.toUpperCase(), style: cell(bold: true))),
        pad(Text(fmtMarks(sheet.maxTotal), style: cell(bold: true, size: 12.5)), align: Alignment.center),
        if (_mode == ExamResultMode.marks) const SizedBox.shrink(),
        pad(Text(sheet.isComplete ? fmtMarks(sheet.scored) : '', style: cell(bold: true, size: 15)), align: Alignment.center),
        if (_mode.usesGrades)
          pad(Text(sheet.overallGrade ?? '', style: cell(bold: true, size: 13)), align: Alignment.center),
        const SizedBox.shrink(),
      ],
    );
  }

  TableRow _row(BuildContext context, int i, ResultRow r, _CellStyle cell, _Pad pad) {
    final l10n = context.l10n;
    final outcome = r.outcome;
    final (resultText, resultColor) = switch (outcome) {
      SubjectOutcome.pass => (l10n.exResultPass, AppColors.success),
      SubjectOutcome.fail => (l10n.exResultFail, AppColors.error),
      SubjectOutcome.absent => (l10n.exAbsent, AppColors.warning),
      SubjectOutcome.awaited => ('', AppColors.grey400),
    };
    final failColor = outcome == SubjectOutcome.fail ? AppColors.error : null;
    final marksText = r.absent ? l10n.exAbsent : (r.score == null ? '' : fmtMarks(r.score!));
    final gradeText = r.absent ? l10n.exAbsent : (r.grade ?? '');
    return TableRow(
      decoration: outcome == SubjectOutcome.fail ? BoxDecoration(color: AppColors.error.withValues(alpha: 0.05)) : null,
      children: [
        pad(Text('${i + 1}', style: cell(size: 12.5)), align: Alignment.center),
        InkWell(
          onTap: () => showPaperSheet(
            context,
            r.paper,
            heading: '${sheet.exam.name} · ${gradeLabel(sheet.exam.gradeKey)}',
            showMarks: _mode.usesMarks,
          ),
          child: pad(Text(r.paper.subject, style: cell(bold: true))),
        ),
        if (_mode.usesMarks) pad(Text(fmtMarks(r.paper.maxMarks), style: cell(size: 12.5)), align: Alignment.center),
        if (_mode == ExamResultMode.marks)
          pad(Text(fmtMarks(r.paper.passMarks), style: cell(size: 12.5)), align: Alignment.center),
        if (_mode.usesMarks)
          pad(Text(marksText, style: cell(bold: true, size: 16, color: failColor)), align: Alignment.center),
        if (_mode.usesGrades)
          pad(
            Text(
              gradeText,
              textAlign: TextAlign.center,
              style: cell(
                bold: true,
                size: gradeText.length > 4 ? 12 : 16,
                color: _mode == ExamResultMode.grades ? failColor : null,
              ),
            ),
            align: Alignment.center,
          ),
        pad(Text(resultText, style: cell(bold: true, size: 11, color: resultColor)), align: Alignment.center),
      ],
    );
  }
}

class _Col {
  final String title;
  final TableColumnWidth width;
  const _Col(this.title, this.width);
}

/// The grade scale, so a parent can read "B1" without asking.
class _ScaleKey extends StatelessWidget {
  final ParentExam exam;
  const _ScaleKey({required this.exam});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.exGradeScale, style: theme.textTheme.labelMedium),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final b in exam.scale)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (b.pass ? AppColors.primaryBlue : AppColors.error).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  b.min == null ? b.label : '${b.label}  ${fmtMarks(b.min!)}%+',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: b.pass ? theme.textTheme.bodyLarge?.color : AppColors.error,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _Note({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4))),
        ],
      ),
    );
  }
}
