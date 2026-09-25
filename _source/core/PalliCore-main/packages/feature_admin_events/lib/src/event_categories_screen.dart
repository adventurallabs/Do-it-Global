import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import 'event_results_screen.dart';

/// The contests inside one event, and who runs each of them.
///
/// A category with no head goes nowhere: nobody can enter students for it and
/// it never appears on a teacher's dashboard. That is the one thing this
/// screen has to make impossible to miss.
class EventCategoriesScreen extends StatefulWidget {
  final SchoolEvent event;
  const EventCategoriesScreen({super.key, required this.event});

  static Future<void> open(BuildContext context, SchoolEvent event) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventCategoriesScreen(event: event)),
      );

  @override
  State<EventCategoriesScreen> createState() => _EventCategoriesScreenState();
}

class _EventCategoriesScreenState extends State<EventCategoriesScreen> {
  List<EventCategory> _categories = const [];
  List<Teacher> _teachers = const [];
  Map<String, List<String>> _headsBy = const {};
  bool _loading = true;
  bool _error = false;

  EventProgramRepository get _repo => context.read<EventProgramRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _error = false);
    try {
      final (categories, teachers, heads) = await (
        _repo.categories(eventId: widget.event.id),
        context.read<TeacherRepository>().getAll(),
        _repo.heads(),
      ).wait;
      if (!mounted) return;
      final by = <String, List<String>>{};
      for (final h in heads) {
        by.putIfAbsent(h.categoryId, () => []).add(h.teacherId);
      }
      setState(() {
        _categories = categories;
        _teachers = teachers;
        _headsBy = by;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  String _nameOf(String teacherId) =>
      _teachers.where((t) => t.id == teacherId).firstOrNull?.name ?? 'Unknown';

  void _fail(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(EventProgramRepository.describeError(error)),
        backgroundColor: AppColors.error,
      ));
  }

  Future<void> _editCategory([EventCategory? category]) async {
    final result = await showModalBottomSheet<EventCategory>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _CategorySheet(eventId: widget.event.id, editing: category),
    );
    if (result == null || !mounted) return;
    try {
      await _repo.saveCategory(result);
      await _load();
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _addHead(EventCategory category) async {
    final current = _headsBy[category.id] ?? const <String>[];
    final picked = await showTeacherPicker(
      context: context,
      // Event heads work from the teacher dashboard, which a librarian never sees.
      teachers: _teachers.where((t) => !current.contains(t.id) && !t.isLibrarian).toList(),
      title: 'Head of ${category.name}',
      subtitle: 'They enter students and record the result. A teacher can head '
          'more than one category.',
    );
    if (picked == null || !mounted) return;
    try {
      await _repo.setHeads(category.id, [...current, picked.id]);
      await _load();
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _removeHead(EventCategory category, String teacherId) async {
    final current = [...?_headsBy[category.id]]..remove(teacherId);
    try {
      await _repo.setHeads(category.id, current);
      await _load();
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _deleteCategory(EventCategory category) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${category.name}?'),
        content: const Text(
          'Its participants, rooms and results go with it. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.deleteCategory(category.id);
      await _load();
    } catch (e) {
      _fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.event.name} · categories', overflow: TextOverflow.ellipsis),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editCategory(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add category'),
        shape: const StadiumBorder(),
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load categories",
        subtitle: 'Check your connection and try again.',
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    if (_categories.isEmpty) {
      return EmptyState(
        icon: Icons.emoji_events_outlined,
        title: 'No categories yet',
        subtitle: 'Add the contests this event is made of — Running, Volleyball, '
            'Fancy dress — then give each one a head teacher.',
        actionLabel: 'Add category',
        onAction: () => _editCategory(),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final category = _categories[i];
          final heads = _headsBy[category.id] ?? const <String>[];
          return AnimatedListItem(
            index: i,
            child: _CategoryCard(
              category: category,
              headNames: {for (final id in heads) id: _nameOf(id)},
              onAddHead: () => _addHead(category),
              onRemoveHead: (id) => _removeHead(category, id),
              onRename: () => _editCategory(category),
              onDelete: () => _deleteCategory(category),
              onResults: () => EventResultsScreen.open(context, event: widget.event, category: category),
            ),
          );
        },
      ),
    );
  }
}

/// Name, type and whether it certifies — everything the admin decides about
/// a category, in one sheet.
class _CategorySheet extends StatefulWidget {
  final String eventId;
  final EventCategory? editing;

  const _CategorySheet({required this.eventId, this.editing});

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late EventCategoryKind _kind = widget.editing?.kind ?? EventCategoryKind.competitive;
  late bool _certificates = widget.editing?.issuesCertificates ?? true;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final editing = widget.editing;
    Navigator.pop(
      context,
      editing == null
          ? EventCategory(
              id: EventProgramRepository.newId('ec'),
              eventId: widget.eventId,
              name: name,
              kind: _kind,
              issuesCertificates: _certificates,
            )
          : editing.copyWith(name: name, kind: _kind, issuesCertificates: _certificates),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mute = AppColors.onSurfaceMuted(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.editing == null ? 'New category' : 'Edit category',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              TextField(
                controller: _name,
                autofocus: widget.editing == null,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Category name',
                  hintText: 'Running, Volleyball, Mass drill, Fancy dress…',
                ),
              ),
              const SizedBox(height: 20),
              Text('TYPE',
                  style: TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: mute)),
              const SizedBox(height: 8),
              for (final kind in EventCategoryKind.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _KindOption(
                    kind: kind,
                    selected: _kind == kind,
                    onTap: () => setState(() => _kind = kind),
                  ),
                ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                value: _certificates,
                onChanged: (v) => setState(() => _certificates = v),
                contentPadding: EdgeInsets.zero,
                title: const Text('Issues certificates',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                subtitle: Text(
                  _certificates
                      ? 'Parents can download a certificate once results are out.'
                      : 'No certificates for this category — a march-past or a rehearsal.',
                  style: TextStyle(fontSize: 12, height: 1.3, color: mute),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 50,
                width: double.infinity,
                child: FilledButton(onPressed: _save, child: const Text('Save category')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KindOption extends StatelessWidget {
  final EventCategoryKind kind;
  final bool selected;
  final VoidCallback onTap;

  const _KindOption({required this.kind, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            kind.isCompetitive ? Icons.emoji_events_outlined : Icons.groups_2_outlined,
            size: 20,
            color: selected ? AppColors.accent : AppColors.onSurfaceHint(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kind.label,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(kind.blurb,
                    style: TextStyle(
                        fontSize: 12, height: 1.3, color: AppColors.onSurfaceMuted(context))),
              ],
            ),
          ),
          Icon(
            selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
            color: selected ? AppColors.accent : AppColors.onSurfaceHint(context),
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final EventCategory category;
  final Map<String, String> headNames;
  final VoidCallback onAddHead;
  final ValueChanged<String> onRemoveHead;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onResults;

  const _CategoryCard({
    required this.category,
    required this.headNames,
    required this.onAddHead,
    required this.onRemoveHead,
    required this.onRename,
    required this.onDelete,
    required this.onResults,
  });

  @override
  Widget build(BuildContext context) {
    final mute = AppColors.onSurfaceMuted(context);
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_outlined, size: 20, color: AppColors.eventCard),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      '${category.kind.label}'
                      '${category.issuesCertificates ? ' · certificates' : ' · no certificates'}',
                      style: TextStyle(fontSize: 11.5, color: mute),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) => v == 'rename' ? onRename() : onDelete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          if (headNames.isEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 4, bottom: 10, right: 4),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_off_outlined, size: 17, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No head yet — nobody can enter students or record a result '
                      'for this category.',
                      style: TextStyle(fontSize: 12.5, height: 1.3, color: mute),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            const SizedBox(height: 10),
            Text('HEAD${headNames.length == 1 ? '' : 'S'}',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: mute)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in headNames.entries)
                  Chip(
                    label: Text(entry.value, style: const TextStyle(fontSize: 12.5)),
                    avatar: const Icon(Icons.person_rounded, size: 15),
                    onDeleted: () => onRemoveHead(entry.key),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              TextButton.icon(
                onPressed: onAddHead,
                icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                label: Text(headNames.isEmpty ? 'Assign head' : 'Add head'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onResults,
                icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                label: const Text('Results'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
