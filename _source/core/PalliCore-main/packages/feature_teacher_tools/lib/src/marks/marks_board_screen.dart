import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import '../progress/progress_widgets.dart';
import 'marks_format.dart';
import 'marks_sheet_screen.dart';

/// Every test this teacher has recorded for one class, newest first — and the
/// way back into any of them.
///
/// Before this, marks entry was write-only: once saved, a teacher could
/// neither see what they had entered nor fix a wrong score. The board is the
/// missing half, and it is also the screen that makes "record marks" an
/// obvious thing you can do rather than an icon in an app bar.
class MarksBoardScreen extends StatefulWidget {
  final String teacherId;
  final Classroom classroom;
  final TeachingScope scope;

  const MarksBoardScreen({
    super.key,
    required this.teacherId,
    required this.classroom,
    required this.scope,
  });

  static Future<void> open(
    BuildContext context, {
    required String teacherId,
    required Classroom classroom,
    required TeachingScope scope,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MarksBoardScreen(
          teacherId: teacherId,
          classroom: classroom,
          scope: scope,
        ),
      ),
    );
  }

  @override
  State<MarksBoardScreen> createState() => _MarksBoardScreenState();
}

class _MarksBoardScreenState extends State<MarksBoardScreen> {
  List<MarkSheet> _sheets = const [];
  int _rosterSize = 0;
  bool _loading = true;
  bool _error = false;
  String? _subjectFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }
    try {
      final students = await context.read<StudentRepository>().getByClassroom(widget.classroom.id);
      if (!mounted) return;
      final repo = context.read<MarkRepository>();
      // Two reads, merged by id. The roster read alone dropped every mark
      // belonging to a child who has since transferred or been archived, so
      // a test entered for the whole class came back with one or two names
      // on it; the classroom read keeps the sheet whole. The roster read
      // stays for rows written before marks carried a classroom.
      final byClass = await repo.getForClassroom(widget.classroom.id);
      if (!mounted) return;
      final byRoster = await repo.getForStudents([for (final s in students) s.id]);
      if (!mounted) return;
      final marks = {for (final m in [...byClass, ...byRoster]) m.id: m}.values;
      // A teacher's board shows their own subjects. Another teacher's
      // English column is not theirs to read here, let alone correct.
      // Formal exam papers live in Results, where they can be submitted and
      // locked — this board is for class tests only.
      final mine = marks.where((m) => !m.isExamPaper && widget.scope.canEnterMarksFor(m.subject));
      setState(() {
        _rosterSize = students.length;
        _sheets = MarkSheet.group(mine);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  List<MarkSheet> get _visible => _subjectFilter == null
      ? _sheets
      : _sheets.where((s) => s.subject == _subjectFilter).toList();

  Future<void> _record({MarkSheet? sheet}) async {
    final saved = await MarksSheetScreen.open(
      context,
      teacherId: widget.teacherId,
      classroom: widget.classroom,
      scope: widget.scope,
      sheet: sheet,
      initialSubject: sheet?.subject ?? _subjectFilter,
    );
    if (saved && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Marks · ${widget.classroom.displayName}', overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(child: _body()),
      floatingActionButton: widget.scope.canEnterMarks && !_loading
          ? FloatingActionButton.extended(
              onPressed: () => _record(),
              icon: const Icon(Icons.post_add_rounded),
              label: const Text('Record marks'),
              shape: const StadiumBorder(),
            )
          : null,
    );
  }

  Widget _body() {
    if (!widget.scope.canEnterMarks) {
      return EmptyState(
        icon: Icons.menu_book_outlined,
        title: 'No subject assigned here',
        subtitle: widget.scope.marksBlockedReason('') ??
            "You'll see subjects once the admin places you on this class's timetable.",
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load marks",
        subtitle: 'Check your connection and try again.',
        actionLabel: 'Retry',
        onAction: _load,
      );
    }

    final visible = _visible;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
        children: [
          _scopeNote(),
          if (widget.scope.subjects.length > 1) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SelectPill(
                      label: 'All',
                      selected: _subjectFilter == null,
                      onTap: () => setState(() => _subjectFilter = null),
                    ),
                  ),
                  for (final subject in widget.scope.subjects)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SelectPill(
                        label: subject,
                        selected: _subjectFilter == subject,
                        onTap: () => setState(
                            () => _subjectFilter = _subjectFilter == subject ? null : subject),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (visible.isEmpty)
            _emptyBoard()
          else ...[
            ProgressSectionTitle(
              'Recorded tests',
              trailing: '${visible.length} ${visible.length == 1 ? 'sheet' : 'sheets'}',
            ),
            for (final sheet in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SheetCard(
                  sheet: sheet,
                  rosterSize: _rosterSize,
                  onTap: () => _record(sheet: sheet),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Says plainly what this teacher owns here, so "why can't I see the maths
  /// column?" never becomes a question.
  Widget _scopeNote() {
    final subjects = widget.scope.subjects;
    return SoftSurface(
      depth: SoftDepth.none,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined, size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              subjects.length == 1
                  ? 'You record ${subjects.single} marks for this class. Other subjects belong to their own teachers.'
                  : 'You record ${subjects.join(', ')} for this class. Other subjects belong to their own teachers.',
              style: TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.onSurfaceMuted(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBoard() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: EmptyState(
        icon: Icons.grading_rounded,
        title: _subjectFilter == null ? 'No marks recorded yet' : 'No $_subjectFilter marks yet',
        subtitle: 'Record a test and it appears here as a result sheet — '
            'tap it any time to correct a score.',
        actionLabel: 'Record marks',
        onAction: () => _record(),
      ),
    );
  }
}

/// One recorded test, read the way a result sheet is read: what it was, how
/// much of the class it covers, and how the class did.
class _SheetCard extends StatelessWidget {
  final MarkSheet sheet;
  final int rosterSize;
  final VoidCallback onTap;

  const _SheetCard({required this.sheet, required this.rosterSize, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final average = sheet.averagePercent;
    final missing = rosterSize - sheet.entered;
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                sheet.isExam ? Icons.workspace_premium_rounded : Icons.assignment_turned_in_outlined,
                size: 18,
                color: sheet.isExam ? AdminLook.gold : AppColors.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sheet.testType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${sheet.subject} · ${friendlyDate(sheet.date)} · out of ${fmtNum(sheet.totalMarks)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted(context)),
                    ),
                  ],
                ),
              ),
              if (average != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: gradeColor(average).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${average.round()}% avg',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: gradeColor(average)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.groups_outlined, size: 14, color: AppColors.onSurfaceHint(context)),
              const SizedBox(width: 5),
              Text(
                '${sheet.entered} of $rosterSize entered',
                style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted(context)),
              ),
              if (missing > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$missing missing',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.warning),
                  ),
                ),
              ],
              const Spacer(),
              Text('Tap to edit',
                  style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceHint(context))),
              Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.onSurfaceHint(context)),
            ],
          ),
        ],
      ),
    );
  }
}
