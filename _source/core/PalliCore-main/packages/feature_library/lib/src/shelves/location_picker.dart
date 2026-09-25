import 'package:flutter/material.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import '../library_widgets.dart';
import 'rack_grid.dart';

/// Walks the librarian through section → rack → shelf/partition and returns
/// the partition tapped, or null if they back out.
Future<LibrarySlot?> pickLibrarySlot(
  BuildContext context, {
  required String title,
  LibrarySlot? current,
  String? highlightBookId,
}) {
  return Navigator.of(context).push<LibrarySlot>(
    MaterialPageRoute(
      builder: (_) => _LocationPickerScreen(title: title, current: current, highlightBookId: highlightBookId),
    ),
  );
}

class _LocationPickerScreen extends StatefulWidget {
  final String title;
  final LibrarySlot? current;
  final String? highlightBookId;

  const _LocationPickerScreen({required this.title, this.current, this.highlightBookId});

  @override
  State<_LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<_LocationPickerScreen> with LibraryLive {
  List<LibrarySection> _sections = const [];
  List<LibraryRack> _racks = const [];
  List<LibrarySlotBooks> _contents = const [];
  LibrarySection? _section;
  LibraryRack? _rack;
  bool _loading = true;
  Object? _error;

  @override
  Future<void> reload() async {
    final rackId = _rack?.id;
    try {
      final results = await Future.wait([
        library.sections(),
        library.racks(),
        if (rackId != null) library.slotBooks(rackId: rackId),
      ]);
      if (!mounted) return;
      setState(() {
        _sections = results[0] as List<LibrarySection>;
        _racks = results[1] as List<LibraryRack>;
        if (_rack != null && _rack!.id == rackId) {
          _contents = results[2] as List<LibrarySlotBooks>;
          // The rack may have been resized or removed meanwhile.
          final fresh = _racks.where((r) => r.id == _rack!.id);
          _rack = fresh.isEmpty ? null : fresh.first;
        }
        if (_section != null && !_sections.any((s) => s.id == _section!.id)) {
          _section = null;
          _rack = null;
        }
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

  Future<void> _openRack(LibraryRack rack) async {
    setState(() {
      _rack = rack;
      _contents = const [];
    });
    try {
      final contents = await library.slotBooks(rackId: rack.id);
      if (mounted && _rack?.id == rack.id) setState(() => _contents = contents);
    } catch (e) {
      if (mounted) showLibraryError(context, e);
    }
  }

  void _back() {
    setState(() {
      if (_rack != null) {
        _rack = null;
      } else {
        _section = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = _rack != null
        ? 3
        : _section != null
        ? 2
        : 1;
    return PopScope(
      canPop: step == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? LibraryLoadError(error: _error!, onRetry: refreshLibrary)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Breadcrumb(
                      section: _section,
                      rack: _rack,
                      onSection: () => setState(() {
                        _section = null;
                        _rack = null;
                      }),
                      onRack: () => setState(() => _rack = null),
                    ),
                    Expanded(child: _body(step)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _body(int step) {
    if (step == 1) {
      if (_sections.isEmpty) {
        return const EmptyState(
          icon: Icons.grid_view_rounded,
          title: 'No sections yet',
          subtitle: 'Create a section and its racks in Section management first.',
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          for (final s in _sections)
            _PickTile(
              icon: Icons.grid_view_rounded,
              title: s.displayName,
              subtitle: '${_racks.where((r) => r.sectionId == s.id).length} racks',
              onTap: () => setState(() => _section = s),
            ),
        ],
      );
    }
    if (step == 2) {
      final racks = _racks.where((r) => r.sectionId == _section!.id).toList()
        ..sort((a, b) => a.position.compareTo(b.position));
      if (racks.isEmpty) {
        return const EmptyState(
          icon: Icons.view_week_rounded,
          title: 'No racks in this section',
          subtitle: 'Add a rack to it in Section management.',
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          for (final r in racks)
            _PickTile(
              icon: Icons.view_week_rounded,
              title: 'Rack ${r.code}',
              subtitle: '${r.shelfCount} shelves · ${r.partitionsPerShelf} partitions each',
              onTap: () => _openRack(r),
            ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Text(
          'Tap a partition. A partition holds any number of books.',
          style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13),
        ),
        const SizedBox(height: 14),
        RackGrid(
          rack: _rack!,
          contents: groupBySlot(_contents),
          marked: widget.current,
          highlightBookId: widget.highlightBookId,
          onTap: (slot) {
            if (widget.current != null && widget.current!.sameAs(slot)) {
              showLibraryDone(context, 'That is where it is now — pick another partition.');
              return;
            }
            Navigator.pop(context, slot);
          },
        ),
      ],
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  final LibrarySection? section;
  final LibraryRack? rack;
  final VoidCallback onSection;
  final VoidCallback onRack;

  const _Breadcrumb({required this.section, required this.rack, required this.onSection, required this.onRack});

  @override
  Widget build(BuildContext context) {
    Widget crumb(String text, {VoidCallback? onTap, bool current = false}) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: current ? FontWeight.w800 : FontWeight.w600,
            color: current ? AppColors.onSurface(context) : AppColors.accent,
          ),
        ),
      ),
    );
    final sep = Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.onSurfaceHint(context));
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          crumb('Sections', onTap: section == null ? null : onSection, current: section == null),
          if (section != null) ...[
            sep,
            crumb('Section ${section!.code}', onTap: rack == null ? null : onRack, current: rack == null),
          ],
          if (rack != null) ...[sep, crumb('Rack ${rack!.code}', current: true)],
        ],
      ),
    );
  }
}

class _PickTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PickTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: LibraryColors.shelves),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12.5)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceHint(context)),
        ],
      ),
    );
  }
}
