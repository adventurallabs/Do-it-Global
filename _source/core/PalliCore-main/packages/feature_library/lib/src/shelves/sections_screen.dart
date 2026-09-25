import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import '../library_widgets.dart';
import 'section_detail_screen.dart';

/// Section management: the library's sections (A, B, REF…), each holding
/// racks named after it (A1, A2…).
class SectionsScreen extends StatefulWidget {
  const SectionsScreen({super.key});

  @override
  State<SectionsScreen> createState() => _SectionsScreenState();
}

class _SectionsScreenState extends State<SectionsScreen> with LibraryLive {
  List<LibrarySection> _sections = const [];
  List<LibraryRack> _racks = const [];
  Map<String, int> _booksBySection = const {};
  bool _loading = true;
  Object? _error;

  @override
  Future<void> reload() async {
    try {
      final results = await Future.wait([library.sections(), library.racks(), library.slotBooks()]);
      if (!mounted) return;
      final counts = <String, int>{};
      for (final s in results[2] as List<LibrarySlotBooks>) {
        counts[s.sectionId] = (counts[s.sectionId] ?? 0) + s.copies;
      }
      setState(() {
        _sections = results[0] as List<LibrarySection>;
        _racks = results[1] as List<LibraryRack>;
        _booksBySection = counts;
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

  Future<void> _create() async {
    final id = await showSectionForm(context);
    if (id != null && mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => SectionDetailScreen(sectionId: id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Section management')),
      floatingActionButton: FloatingActionButton.extended(
        shape: const StadiumBorder(),
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create section'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? LibraryLoadError(error: _error!, onRetry: refreshLibrary)
            : RefreshIndicator(
                color: AppColors.accent,
                onRefresh: refreshLibrary,
                child: _sections.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(
                            height: 380,
                            child: EmptyState(
                              icon: Icons.grid_view_rounded,
                              title: 'No sections yet',
                              subtitle: 'Create section A, then add racks A1, A2… with their shelves and partitions.',
                            ),
                          ),
                        ],
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisExtent: 150,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _sections.length,
                        itemBuilder: (context, i) => _card(_sections[i]),
                      ),
              ),
      ),
    );
  }

  Widget _card(LibrarySection s) {
    final racks = _racks.where((r) => r.sectionId == s.id).length;
    final books = _booksBySection[s.id] ?? 0;
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SectionDetailScreen(sectionId: s.id))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: LibraryColors.shelves.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              s.code,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: LibraryColors.shelves),
            ),
          ),
          const Spacer(),
          Text(
            s.label.isEmpty ? 'Section ${s.code}' : s.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            '$racks rack${racks == 1 ? '' : 's'} · $books book${books == 1 ? '' : 's'}',
            style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

/// Create a section, or (with [section]) rename its label. The code itself
/// never changes once racks are named after it.
Future<String?> showSectionForm(BuildContext context, {LibrarySection? section}) async {
  final repo = context.read<LibraryRepository>();
  final code = TextEditingController(text: section?.code ?? '');
  final label = TextEditingController(text: section?.label ?? '');
  final formKey = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      var saving = false;
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> save() async {
            if (!formKey.currentState!.validate()) return;
            setLocal(() => saving = true);
            try {
              final String id;
              if (section == null) {
                id = await repo.createSection(code.text.trim(), label: label.text.trim());
              } else {
                await repo.updateSectionLabel(section.id, label.text.trim());
                id = section.id;
              }
              if (ctx.mounted) Navigator.pop(ctx, id);
            } catch (e) {
              setLocal(() => saving = false);
              if (ctx.mounted) showLibraryError(ctx, e);
            }
          }

          return AlertDialog(
            title: Text(section == null ? 'Create section' : 'Section ${section.code}'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: code,
                    enabled: section == null,
                    autofocus: section == null,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
                      LengthLimitingTextInputFormatter(4),
                      TextInputFormatter.withFunction((o, n) => n.copyWith(text: n.text.toUpperCase())),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Section name',
                      hintText: 'A',
                      helperText: 'Letters only. Racks will be named A1, A2…',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a letter, like A' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: label,
                    autofocus: section != null,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Description (optional)', hintText: 'Science & Maths'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(onPressed: saving ? null : save, child: Text(section == null ? 'Create' : 'Save')),
            ],
          );
        },
      );
    },
  );
}
