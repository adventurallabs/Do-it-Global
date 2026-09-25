import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:core_models/core_models.dart';
import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart';
import 'announcement_bloc.dart';

class AnnouncementScreen extends StatelessWidget {
  final bool isAdmin;
  final String teacherId;
  const AnnouncementScreen({super.key, this.isAdmin = true, this.teacherId = ''});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AnnouncementBloc(
        RepositoryProvider.of<AnnouncementRepository>(context),
      )..add(LoadAnnouncements()),
      child: isAdmin
          ? const _AdminAnnouncementsView()
          : _TeacherAnnouncementsView(teacherId: teacherId),
    );
  }
}

class _TeacherAnnouncementsView extends StatefulWidget {
  final String teacherId;
  const _TeacherAnnouncementsView({required this.teacherId});

  @override
  State<_TeacherAnnouncementsView> createState() => _TeacherAnnouncementsViewState();
}

class _TeacherAnnouncementsViewState extends State<_TeacherAnnouncementsView> {
  List<Classroom> _myClassrooms = [];

  @override
  void initState() {
    super.initState();
    _loadClassrooms();
  }

  Future<void> _loadClassrooms() async {
    try {
      final all = await RepositoryProvider.of<ClassroomRepository>(context).getAll();
      if (!mounted) return;
      setState(() => _myClassrooms =
          all.where((c) => c.classTeacherId == widget.teacherId).toList());
    } catch (_) {}
  }

  Future<void> _compose() async {
    final bloc = context.read<AnnouncementBloc>();
    final announcement = await showAnnouncementComposer(
      context,
      classrooms: _myClassrooms,
      authorId: widget.teacherId,
    );
    if (announcement != null) bloc.add(CreateAnnouncement(announcement));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _myClassrooms.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _compose,
              icon: const Icon(Icons.add),
              label: const Text('Notice for my class'),
              shape: const StadiumBorder(),
            ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SoftPageHeader(
              title: 'Announcements',
              subtitle: 'School notices and your class updates',
            ),
            Expanded(
              child: BlocBuilder<AnnouncementBloc, AnnouncementState>(
                builder: (context, state) {
                  if (state is AnnouncementLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is AnnouncementError) {
                    return Center(
                      child: Text('Error: ${state.message}', style: const TextStyle(color: AppColors.error)),
                    );
                  }
                  if (state is AnnouncementLoaded) {
                    final myClassroomIds =
                        _myClassrooms.map((c) => c.id).toSet();
                    final items = state.announcements
                        .where(
                          (a) =>
                              a.target == AnnouncementTarget.overall ||
                              a.target == AnnouncementTarget.teachers ||
                              (a.isClassroomScoped &&
                                  myClassroomIds.contains(a.classroomId)),
                        )
                        .toList()
                      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                    if (items.isEmpty) {
                      return const EmptyState(
                        icon: Icons.campaign_outlined,
                        title: 'No announcements',
                        subtitle: 'School-wide and staff notices will show up here.',
                      );
                    }
                    return RefreshIndicator(
                      color: AppColors.accent,
                      onRefresh: () async {
                        context.read<AnnouncementBloc>().add(LoadAnnouncements());
                        await context.read<AnnouncementBloc>().stream.firstWhere(
                              (s) => s is AnnouncementLoaded || s is AnnouncementError,
                            );
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final announcement = items[index];
                          return AnimatedListItem(
                            index: index,
                            child: _AnnouncementCard(
                              announcement: announcement,
                              isAdmin: false,
                              canDelete: widget.teacherId.isNotEmpty &&
                                  announcement.createdBy == widget.teacherId,
                            ),
                          );
                        },
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminAnnouncementsView extends StatelessWidget {
  const _AdminAnnouncementsView();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Announcements'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/admin'),
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'School-wide'),
              Tab(text: 'Staff'),
              Tab(text: 'Students'),
              Tab(text: 'Parents'),
            ],
          ),
          actions: [
            BlocBuilder<AnnouncementBloc, AnnouncementState>(
              builder: (context, state) {
                return IconButton(
                  tooltip: 'New announcement',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => _showCreateDialog(context),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: BlocBuilder<AnnouncementBloc, AnnouncementState>(
          builder: (context, state) {
            if (state is AnnouncementLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is AnnouncementLoaded) {
              return TabBarView(
                children: [
                  _AnnouncementTab(
                    announcements: state.announcements
                        .where((a) => a.target == AnnouncementTarget.overall)
                        .toList(),
                    target: AnnouncementTarget.overall,
                    isAdmin: true,
                  ),
                  _AnnouncementTab(
                    announcements: state.announcements
                        .where((a) => a.target == AnnouncementTarget.teachers)
                        .toList(),
                    target: AnnouncementTarget.teachers,
                    isAdmin: true,
                  ),
                  _AnnouncementTab(
                    announcements: state.announcements
                        .where((a) => a.target == AnnouncementTarget.students)
                        .toList(),
                    target: AnnouncementTarget.students,
                    isAdmin: true,
                  ),
                  // Includes class teachers' notices to their class's parents.
                  _AnnouncementTab(
                    announcements: state.announcements
                        .where((a) => a.target == AnnouncementTarget.parents)
                        .toList(),
                    target: AnnouncementTarget.parents,
                    isAdmin: true,
                  ),
                ],
              );
            }
            if (state is AnnouncementError) {
              return Center(
                child: Text('Error: ${state.message}', style: TextStyle(color: AppColors.error)),
              );
            }
            return const SizedBox();
          },
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final bloc = context.read<AnnouncementBloc>();
    final announcement = await showAnnouncementComposer(context);
    if (announcement != null) bloc.add(CreateAnnouncement(announcement));
  }
}

class _AnnouncementTab extends StatelessWidget {
  final List<Announcement> announcements;
  final AnnouncementTarget target;
  final bool isAdmin;

  const _AnnouncementTab({required this.announcements, required this.target, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    if (announcements.isEmpty) {
      return EmptyState(
        icon: Icons.campaign_outlined,
        title: 'No announcements',
        subtitle: 'Tap + to post one ${audienceLabel(target).toLowerCase()}.',
      );
    }
    final sorted = [...announcements]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final announcement = sorted[index];
        return AnimatedListItem(
          index: index,
          child: _AnnouncementCard(announcement: announcement, isAdmin: isAdmin),
        );
      },
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  final bool isAdmin;
  final bool canDelete;

  const _AnnouncementCard({
    required this.announcement,
    required this.isAdmin,
    this.canDelete = false,
  });

  String _getTimeRemaining() {
    final remaining = announcement.expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return 'Expired';
    if (remaining.inDays > 0) return '${remaining.inDays}d left';
    if (remaining.inHours > 0) return '${remaining.inHours}h left';
    return '${remaining.inMinutes}m left';
  }

  Color _getTargetColor() {
    switch (announcement.target) {
      case AnnouncementTarget.teachers:
        return AppColors.teacherCard;
      case AnnouncementTarget.students:
        return AppColors.studentCard;
      case AnnouncementTarget.parents:
        return AppColors.studentCard;
      case AnnouncementTarget.overall:
        return AppColors.announcementCard;
    }
  }

  String _targetLabel() => announcement.isClassroomScoped
      ? 'Class notice · parents'
      : audienceLabel(announcement.target);

  @override
  Widget build(BuildContext context) {
    final targetColor = _getTargetColor();
    final timeLeft = _getTimeRemaining();
    final isExpired = announcement.expiresAt.isBefore(DateTime.now());

    return SoftSurface(
      depth: SoftDepth.one,
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: targetColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _targetLabel(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: targetColor, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              if (announcement.isImportant) ...[
                const SizedBox(width: 6),
                const Icon(Icons.priority_high_rounded, size: 16, color: AppColors.error),
              ],
              const Spacer(),
              Text(
                timeLeft,
                style: TextStyle(
                  color: isExpired ? AppColors.error : AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(width: 8),
                NeoCircleButton(
                  icon: Icons.edit_rounded,
                  size: 34,
                  tooltip: 'Edit',
                  iconColor: AppColors.warning,
                  onTap: () => _edit(context),
                ),
              ],
              if (isAdmin || canDelete) ...[
                const SizedBox(width: 6),
                NeoCircleButton(
                  icon: Icons.delete_rounded,
                  size: 34,
                  tooltip: 'Delete',
                  iconColor: AppColors.error,
                  onTap: () => _confirmDelete(context),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            announcement.title,
            style: TextStyle(
              color: AppColors.onSurface(context),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            announcement.content,
            style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 14, height: 1.4),
            maxLines: isAdmin ? 3 : 6,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final bloc = context.read<AnnouncementBloc>();
    final next = await showAnnouncementComposer(context, existing: announcement);
    if (next != null) bloc.add(UpdateAnnouncement(next));
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => SimpleConfirmDialog(
        title: 'Delete Announcement',
        content: 'Are you sure you want to delete "${announcement.title}"?',
        onConfirm: () {
          context.read<AnnouncementBloc>().add(DeleteAnnouncement(announcement.id));
        },
      ),
    );
  }
}

String audienceLabel(AnnouncementTarget t) => switch (t) {
      AnnouncementTarget.overall => 'For everyone',
      AnnouncementTarget.teachers => 'For staff',
      AnnouncementTarget.students => 'For students',
      AnnouncementTarget.parents => 'For parents',
    };

/// One composer for both roles.
/// * Admin (no [classrooms]): picks the audience; school-wide.
/// * Class teacher ([classrooms] given): a notice to one class's parents.
/// Editing keeps everything the form doesn't show (scope, class, author...).
Future<Announcement?> showAnnouncementComposer(
  BuildContext context, {
  Announcement? existing,
  List<Classroom>? classrooms,
  String authorId = '',
}) {
  return showModalBottomSheet<Announcement>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _AnnouncementComposer(
      existing: existing,
      classrooms: classrooms,
      authorId: authorId,
    ),
  );
}

class _AnnouncementComposer extends StatefulWidget {
  final Announcement? existing;
  final List<Classroom>? classrooms;
  final String authorId;

  const _AnnouncementComposer({this.existing, this.classrooms, this.authorId = ''});

  @override
  State<_AnnouncementComposer> createState() => _AnnouncementComposerState();
}

class _AnnouncementComposerState extends State<_AnnouncementComposer> {
  static const _expiryDays = [1, 3, 7, 14, 30];

  late final TextEditingController _titleC =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _bodyC =
      TextEditingController(text: widget.existing?.content ?? '');
  late AnnouncementTarget _target = widget.existing?.target ?? AnnouncementTarget.overall;
  late bool _important = widget.existing?.isImportant ?? false;
  late int _days = _initialDays();
  Classroom? _classroom;

  bool get _teacherMode => widget.classrooms != null;

  int _initialDays() {
    final e = widget.existing;
    if (e == null) return _teacherMode ? 3 : 7;
    final left = e.expiresAt.difference(DateTime.now()).inDays;
    return _expiryDays.firstWhere((d) => d >= left, orElse: () => 30);
  }

  @override
  void initState() {
    super.initState();
    final rooms = widget.classrooms ?? const <Classroom>[];
    _classroom = rooms.isNotEmpty ? rooms.first : null;
  }

  @override
  void dispose() {
    _titleC.dispose();
    _bodyC.dispose();
    super.dispose();
  }

  bool get _valid =>
      _titleC.text.trim().isNotEmpty &&
      _bodyC.text.trim().isNotEmpty &&
      (!_teacherMode || _classroom != null);

  void _submit() {
    if (!_valid) return;
    final now = DateTime.now();
    final e = widget.existing;
    final expires = now.add(Duration(days: _days));
    final Announcement result;
    if (_teacherMode) {
      result = Announcement(
        id: now.millisecondsSinceEpoch.toString(),
        title: _titleC.text.trim(),
        content: _bodyC.text.trim(),
        target: AnnouncementTarget.parents,
        scope: AnnouncementScope.classroom,
        classroomId: _classroom!.id,
        isImportant: _important,
        createdBy: widget.authorId,
        createdAt: now,
        expiresAt: expires,
      );
    } else {
      result = Announcement(
        id: e?.id ?? now.millisecondsSinceEpoch.toString(),
        title: _titleC.text.trim(),
        content: _bodyC.text.trim(),
        target: e?.isClassroomScoped == true ? e!.target : _target,
        scope: e?.scope ?? AnnouncementScope.school,
        classroomId: e?.classroomId,
        isImportant: _important,
        createdBy: e?.createdBy ?? widget.authorId,
        createdAt: e?.createdAt ?? now,
        expiresAt: expires,
      );
    }
    Navigator.pop(context, result);
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(text,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceMuted(context))),
      );

  @override
  Widget build(BuildContext context) {
    final e = widget.existing;
    final rooms = widget.classrooms ?? const <Classroom>[];
    final lockedAudience = e?.isClassroomScoped == true;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              e != null
                  ? 'Edit announcement'
                  : _teacherMode
                      ? 'Notice for parents'
                      : 'New announcement',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: AdminLook.inkOf(context),
              ),
            ),
            if (_teacherMode) ...[
              const SizedBox(height: 4),
              Text("Only this class's parents will see it.",
                  style: TextStyle(fontSize: 13, color: AppColors.onSurfaceMuted(context))),
            ],
            const SizedBox(height: 16),
            if (_teacherMode && rooms.length > 1) ...[
              _label('Class'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in rooms)
                    ChoiceChip(
                      label: Text(c.name),
                      selected: _classroom?.id == c.id,
                      onSelected: (_) => setState(() => _classroom = c),
                    ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            if (!_teacherMode && !lockedAudience) ...[
              _label('Who is it for?'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in AnnouncementTarget.values)
                    ChoiceChip(
                      label: Text(audienceLabel(t)),
                      selected: _target == t,
                      onSelected: (_) => setState(() => _target = t),
                    ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: _titleC,
              autofocus: e == null,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyC,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Message',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            _label('Show for'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in _expiryDays)
                  ChoiceChip(
                    label: Text(d == 1 ? '1 day' : '$d days'),
                    selected: _days == d,
                    onSelected: (_) => setState(() => _days = d),
                  ),
              ],
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _important,
              onChanged: (v) => setState(() => _important = v),
              title: const Text('Mark as important'),
              subtitle: const Text('Highlighted at the top for readers'),
            ),
            const SizedBox(height: 8),
            SoftPrimaryButton(
              label: e == null ? 'Post' : 'Save changes',
              icon: Icons.send_rounded,
              onPressed: _valid ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}
