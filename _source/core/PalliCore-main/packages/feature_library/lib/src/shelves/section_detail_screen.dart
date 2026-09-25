import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import '../library_widgets.dart';
import 'rack_screen.dart';
import 'sections_screen.dart';

/// One section and its racks.
class SectionDetailScreen extends StatefulWidget {
  final String sectionId;
  const SectionDetailScreen({super.key, required this.sectionId});

  @override
  State<SectionDetailScreen> createState() => _SectionDetailScreenState();
}

class _SectionDetailScreenState extends State<SectionDetailScreen> with LibraryLive {
  LibrarySection? _section;
  List<LibraryRack> _racks = const [];
  Map<String, int> _booksByRack = const {};
  bool _loading = true;
  bool _gone = false;
  Object? _error;

  @override
  Future<void> reload() async {
    try {
      final results = await Future.wait([
        library.sections(),
        library.racks(sectionId: widget.sectionId),
        library.slotBooks(sectionId: widget.sectionId),
      ]);
      if (!mounted) return;
      final sections = (results[0] as List<LibrarySection>).where((s) => s.id == widget.sectionId);
      final counts = <String, int>{};
      for (final s in results[2] as List<LibrarySlotBooks>) {
        counts[s.slot.rackId] = (counts[s.slot.rackId] ?? 0) + s.copies;
      }
      setState(() {
        _section = sections.isEmpty ? null : sections.first;
        _gone = _section == null;
        _racks = results[1] as List<LibraryRack>;
        _booksByRack = counts;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  Future<void> _createRack() async {
    final section = _section;
    if (section == null) return;
    final size = await showRackSizeDialog(context, title: 'New rack in Section ${section.code}');
    if (size == null || !mounted) return;
    try {
      final code = await library.createRack(section.id, shelves: size.shelves, partitions: size.partitions);
      if (mounted) showLibraryDone(context, 'Rack $code created');
    } catch (e) {
      if (mounted) showLibraryError(context, e);
    }
  }

  Future<void> _deleteSection() async {
    final section = _section;
    if (section == null) return;
    final books = _booksByRack.values.fold<int>(0, (a, b) => a + b);
    final ok = await confirmTypedDelete(
      context,
      title: 'Delete Section ${section.code}',
      message:
          'This deletes the section and its ${_racks.length} rack${_racks.length == 1 ? '' : 's'}. '
          '${books == 0 ? 'No books are on them.' : 'The $books book${books == 1 ? '' : 's'} on them stay in the library as Unassigned.'}',
    );
    if (!ok || !mounted) return;
    final repo = context.read<LibraryRepository>();
    try {
      final moved = await repo.deleteSection(section.id);
      if (!mounted) return;
      showLibraryDone(context, moved == 0 ? 'Section deleted' : 'Section deleted · $moved books moved to Unassigned');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showLibraryError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final section = _section;
    return Scaffold(
      appBar: AppBar(
        title: Text(section == null ? 'Section' : 'Section ${section.code}'),
        actions: [
          if (section != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'label') showSectionForm(context, section: section);
                if (v == 'delete') _deleteSection();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'label',
                  child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit description')),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline_rounded, color: AppColors.error),
                    title: Text('Delete section'),
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: section == null
          ? null
          : FloatingActionButton.extended(
              shape: const StadiumBorder(),
              onPressed: _createRack,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create rack'),
            ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? LibraryLoadError(error: _error!, onRetry: refreshLibrary)
            : _gone
            ? const EmptyState(icon: Icons.grid_view_rounded, title: 'This section was deleted')
            : RefreshIndicator(
                color: AppColors.accent,
                onRefresh: refreshLibrary,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    if (section!.label.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                        child: Text(
                          section.label,
                          style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 14),
                        ),
                      ),
                    if (_racks.isEmpty)
                      const SizedBox(
                        height: 320,
                        child: EmptyState(
                          icon: Icons.view_week_rounded,
                          title: 'No racks yet',
                          subtitle: 'Create a rack and choose its shelves and partitions per shelf.',
                        ),
                      )
                    else
                      for (final r in _racks) _rackTile(r),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _rackTile(LibraryRack r) {
    final books = _booksByRack[r.id] ?? 0;
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RackScreen(rackId: r.id))),
      child: Row(
        children: [
          _MiniRack(shelves: r.shelfCount, partitions: r.partitionsPerShelf),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rack ${r.code}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(
                  '${r.shelfCount} shelves × ${r.partitionsPerShelf} partitions · $books book${books == 1 ? '' : 's'}',
                  style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12.5),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceHint(context)),
        ],
      ),
    );
  }
}

/// A thumbnail of a rack's shape.
class _MiniRack extends StatelessWidget {
  final int shelves;
  final int partitions;
  const _MiniRack({required this.shelves, required this.partitions});

  @override
  Widget build(BuildContext context) {
    final rows = shelves.clamp(1, 6);
    final cols = partitions.clamp(1, 6);
    return Container(
      width: 46,
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: LibraryColors.shelves.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows; i++)
            Expanded(
              child: Row(
                children: [
                  for (var j = 0; j < cols; j++)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: LibraryColors.shelves.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Asks for a rack's shelves and partitions per shelf.
Future<({int shelves, int partitions})?> showRackSizeDialog(
  BuildContext context, {
  required String title,
  int shelves = 4,
  int partitions = 4,
  String action = 'Create',
}) {
  return showDialog<({int shelves, int partitions})>(
    context: context,
    builder: (ctx) {
      var s = shelves;
      var p = partitions;
      return StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Number of shelves', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              CopyStepper(value: s, max: 30, onChanged: (v) => setLocal(() => s = v)),
              const SizedBox(height: 16),
              const Text('Partitions per shelf', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              CopyStepper(value: p, max: 30, onChanged: (v) => setLocal(() => p = v)),
              const SizedBox(height: 12),
              Text(
                '${s * p} partitions in all. Each partition holds any number of books.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.onSurfaceMuted(ctx), fontSize: 12.5),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, (shelves: s, partitions: p)), child: Text(action)),
          ],
        ),
      );
    },
  );
}
