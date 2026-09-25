import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_models/core_models.dart';
import 'directory_bloc.dart';
import 'student_detail_screen.dart';
import 'teacher_detail_screen.dart';
import 'student_form_screen.dart';
import 'teacher_form_screen.dart';
import 'deactivated_directory_screen.dart';

class DirectoryScreen extends StatefulWidget {
  final String initialTab;
  const DirectoryScreen({super.key, this.initialTab = 'students'});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  String _sortBy = 'name';

  @override
  void initState() {
    super.initState();
    context.read<DirectoryBloc>().add(LoadDirectory());
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab == 'teachers' ? 1 : 0,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.initialTab == 'teachers' ? 'Staff' : 'Students'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/admin'),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_off_outlined),
              tooltip: 'Deactivated',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DeactivatedDirectoryScreen()),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Students'),
              Tab(text: 'Staff'),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SoftField(
                child: TextField(
                  onChanged: (val) {
                    context.read<DirectoryBloc>().add(SearchDirectory(val));
                  },
                  style: TextStyle(color: AppColors.onSurface(context), fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search by name...',
                    prefixIcon: Icon(Icons.search, color: AppColors.onSurfaceHint(context), size: 22),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            // Sort chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text('Sort: ', style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12)),
                  const SizedBox(width: 4),
                  _SortChip(label: 'Name', value: 'name', current: _sortBy, onTap: (v) {
                    setState(() => _sortBy = v);
                    context.read<DirectoryBloc>().add(SortDirectory(v));
                  }),
                  const SizedBox(width: 6),
                  _SortChip(label: 'Class', value: 'class', current: _sortBy, onTap: (v) {
                    setState(() => _sortBy = v);
                    context.read<DirectoryBloc>().add(SortDirectory(v));
                  }),
                ],
              ),
            ),
            BlocBuilder<DirectoryBloc, DirectoryState>(
              builder: (context, state) {
                if (state is! DirectoryLoaded || state.classrooms.isEmpty) return const SizedBox.shrink();
                return SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: const Text('All classes'),
                          selected: state.classFilter == null,
                          onSelected: (_) => context.read<DirectoryBloc>().add(FilterByClass(null)),
                        ),
                      ),
                      ...state.classrooms.map((classroom) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(classroom.name),
                              selected: state.classFilter == classroom.id,
                              onSelected: (_) => context.read<DirectoryBloc>().add(
                                    FilterByClass(state.classFilter == classroom.id ? null : classroom.id),
                                  ),
                            ),
                          )),
                    ],
                  ),
                );
              },
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                children: [
                  _StudentList(onCreateStudent: () => _openStudentForm(context)),
                  _TeacherList(onCreateTeacher: () => _openTeacherForm(context)),
                ],
              ),
            ),
          ],
          ),
        ),
        floatingActionButton: Builder(
          builder: (context) {
            return FloatingActionButton(
              onPressed: () {
                // Determine which tab is active
                final tabController = DefaultTabController.of(context);
                if (tabController.index == 0) {
                  _openStudentForm(context);
                } else {
                  _openTeacherForm(context);
                }
              },
              child: const Icon(Icons.add),
            );
          },
        ),
      ),
    );
  }

  void _openStudentForm(BuildContext context, {Student? student}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<DirectoryBloc>(),
          child: StudentFormScreen(student: student),
        ),
      ),
    );
  }

  void _openTeacherForm(BuildContext context, {Teacher? teacher}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<DirectoryBloc>(),
          child: TeacherFormScreen(teacher: teacher),
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onTap;

  const _SortChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: isSelected
          ? GoldRimSurface(
              depth: SoftDepth.two,
              borderRadius: BorderRadius.circular(20),
              rimWidth: 1.1,
              texture: false,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AdminLook.inkOf(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : NeoWell(
              borderRadius: BorderRadius.circular(20),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AdminLook.muteOf(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
    );
  }
}

class _StudentList extends StatelessWidget {
  final VoidCallback onCreateStudent;

  const _StudentList({required this.onCreateStudent});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DirectoryBloc, DirectoryState>(
      builder: (context, state) {
        if (state is DirectoryLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is DirectoryLoaded) {
          if (state.filteredStudents.isEmpty) {
            return EmptyState(
              icon: Icons.people_outline,
              title: 'No Students Found',
              actionLabel: 'Add Student',
              onAction: onCreateStudent,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            addAutomaticKeepAlives: false,
            itemCount: state.filteredStudents.length,
            itemBuilder: (context, index) {
              final student = state.filteredStudents[index];
              return AnimatedListItem(
                index: index,
                child: _PersonCard(
                  name: student.name,
                  subtitle: state.classroomName(student.classroomId) == student.classroomId
                      ? 'Roll: ${student.rollNumber}'
                      : '${state.classroomName(student.classroomId)} · Roll ${student.rollNumber}',
                  photoUrl: student.photoUrl,
                  icon: Icons.person_rounded,
                  color: AppColors.studentCard,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: context.read<DirectoryBloc>(),
                        child: StudentDetailScreen(student: student),
                      ),
                    ),
                  ),
                  onDelete: () => _confirmDelete(context, student.id, true),
                ),
              );
            },
          );
        }
        if (state is DirectoryError) {
          return _DirectoryError(message: state.message);
        }
        return const SizedBox();
      },
    );
  }

  void _confirmDelete(BuildContext context, String id, bool isStudent) {
    showDialog(
      context: context,
      builder: (_) => VerificationDialog(
        title: 'Deactivate Student',
        content: 'This revokes their parent login immediately and hides them from the '
            'active list. Their history stays intact — find them under Deactivated to '
            'reactivate or delete permanently.',
        confirmWord: 'DEACTIVATE',
        actionLabel: 'Deactivate',
        onConfirm: () => context.read<DirectoryBloc>().add(DeleteStudent(id)),
      ),
    );
  }
}

class _TeacherList extends StatefulWidget {
  final VoidCallback onCreateTeacher;

  const _TeacherList({required this.onCreateTeacher});

  @override
  State<_TeacherList> createState() => _TeacherListState();
}

class _TeacherListState extends State<_TeacherList> {
  StaffRole? _role;
  String? _subject;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DirectoryBloc, DirectoryState>(
      builder: (context, state) {
        if (state is DirectoryLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is DirectoryLoaded) {
          var staff = _role == null
              ? state.filteredTeachers
              : state.filteredTeachers.where((t) => t.role == _role).toList();
          if (_subject != null) {
            staff = staff.where((t) => t.subjects.contains(_subject)).toList();
          }
          final subjects = {for (final t in state.filteredTeachers) ...t.subjects}.toList()..sort();
          return Column(
            children: [
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _roleChip('All staff', null),
                    _roleChip('Teaching', StaffRole.teaching),
                    _roleChip('Non-teaching', StaffRole.nonTeaching),
                    _roleChip('Drivers', StaffRole.driver),
                    _roleChip('Office', StaffRole.office),
                    _roleChip('Librarian', StaffRole.librarian),
                  ],
                ),
              ),
              if (subjects.isNotEmpty) ...[
                const SizedBox(height: 6),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: subjects
                        .map((subject) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: FilterChip(
                                label: Text(subject, style: const TextStyle(fontSize: 12)),
                                visualDensity: VisualDensity.compact,
                                selected: _subject == subject,
                                onSelected: (_) => setState(() => _subject = _subject == subject ? null : subject),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
              Expanded(
                child: staff.isEmpty
                    ? EmptyState(
                        icon: Icons.badge_outlined,
                        title: 'No staff found',
                        actionLabel: 'Add staff',
                        onAction: widget.onCreateTeacher,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        addAutomaticKeepAlives: false,
                        itemCount: staff.length,
                        itemBuilder: (context, index) {
                          final teacher = staff[index];
                          final classIds = state.teacherClassroomIds[teacher.id] ?? {};
                          final classNames = classIds.map(state.classroomName).join(', ');
                          final subjectNames = teacher.subjects.join(', ');
                          return AnimatedListItem(
                            index: index,
                            child: _PersonCard(
                              name: teacher.name,
                              subtitle: '${teacher.roleLabel}'
                                  '${subjectNames.isEmpty ? '' : ' · $subjectNames'}'
                                  '${classNames.isEmpty ? '' : ' · $classNames'}',
                              photoUrl: teacher.photoUrl,
                              icon: Icons.badge_rounded,
                              color: AppColors.teacherCard,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BlocProvider.value(
                                    value: context.read<DirectoryBloc>(),
                                    child: TeacherDetailScreen(teacher: teacher),
                                  ),
                                ),
                              ),
                              onDelete: () => _confirmDelete(context, teacher.id),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        }
        if (state is DirectoryError) {
          return _DirectoryError(message: state.message);
        }
        return const SizedBox();
      },
    );
  }

  Widget _roleChip(String label, StaffRole? role) {
    final selected = _role == role;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _role = role),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (_) => VerificationDialog(
        title: 'Deactivate Staff',
        content: 'This revokes their login immediately and hides them from the active '
            'list. Their history stays intact — find them under Deactivated to '
            'reactivate or delete permanently.',
        confirmWord: 'DEACTIVATE',
        actionLabel: 'Deactivate',
        onConfirm: () => context.read<DirectoryBloc>().add(DeleteTeacher(id)),
      ),
    );
  }
}

class _DirectoryError extends StatelessWidget {
  final String message;

  const _DirectoryError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            const Text('Directory could not be loaded', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: AppColors.onSurfaceMuted(context))),
          ],
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final String? photoUrl;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PersonCard({
    required this.name,
    required this.subtitle,
    this.photoUrl,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(16),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: color.withValues(alpha: 0.15),
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
          child: photoUrl == null
              ? Icon(icon, color: color, size: 22)
              : null,
        ),
        title: Text(
          name,
          style: TextStyle(
            color: AppColors.onSurface(context),
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.person_off_outlined, color: AppColors.error, size: 20),
          tooltip: 'Deactivate',
          onPressed: onDelete,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
