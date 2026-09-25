import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// The files on a person's record.
///
/// The bucket behind these is private, so nothing here is a link a browser
/// could guess. Opening one mints a signed URL that lasts ten minutes; the
/// list itself only ever shows names.
class PersonDocumentsSection extends StatefulWidget {
  final DocumentOwner ownerType;
  final String ownerId;
  final List<DocumentKind> kinds;

  /// Called after a change, so a profile can re-check what is still missing.
  final VoidCallback? onChanged;

  const PersonDocumentsSection({
    super.key,
    required this.ownerType,
    required this.ownerId,
    required this.kinds,
    this.onChanged,
  });

  @override
  State<PersonDocumentsSection> createState() => _PersonDocumentsSectionState();
}

class _PersonDocumentsSectionState extends State<PersonDocumentsSection> {
  List<PersonDocument> _documents = const [];
  bool _loading = true;
  bool _busy = false;

  PersonMediaRepository get _repo => context.read<PersonMediaRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final docs = await _repo.documents(
        ownerType: widget.ownerType,
        ownerId: widget.ownerId,
      );
      if (mounted) {
        setState(() {
          _documents = docs;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _say(String message, {bool bad = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: bad ? AppColors.error : null,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _add() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = picked?.files.singleOrNull;
    final bytes = file?.bytes;
    if (bytes == null || !mounted) return;
    if (bytes.lengthInBytes > 10 * 1024 * 1024) {
      _say('That file is over 10 MB. Pick a smaller one.', bad: true);
      return;
    }

    final choice = await showModalBottomSheet<(DocumentKind, String)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _KindSheet(kinds: widget.kinds, fileName: file!.name),
    );
    if (choice == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await _repo.addDocument(
        ownerType: widget.ownerType,
        ownerId: widget.ownerId,
        kind: choice.$1,
        label: choice.$2,
        bytes: bytes,
        fileName: file!.name,
      );
      await _load();
      widget.onChanged?.call();
      _say('Document added.');
    } catch (e) {
      _say(PersonMediaRepository.describeError(e), bad: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(PersonDocument document) async {
    setState(() => _busy = true);
    try {
      final url = await _repo.signedUrl(document);
      if (!mounted) return;
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok) _say('Could not open that file.', bad: true);
    } catch (e) {
      _say(PersonMediaRepository.describeError(e), bad: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(PersonDocument document) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this document?'),
        content: Text('${document.displayName} will be deleted for good.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.deleteDocument(document);
      await _load();
      widget.onChanged?.call();
    } catch (e) {
      _say(PersonMediaRepository.describeError(e), bad: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mute = AppColors.onSurfaceMuted(context);
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_documents.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 2),
            child: Text('Nothing filed yet.', style: TextStyle(fontSize: 12.5, color: mute)),
          )
        else
          for (final doc in _documents)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SoftSurface(
                depth: SoftDepth.one,
                borderRadius: BorderRadius.circular(14),
                padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                onTap: _busy ? null : () => _open(doc),
                child: Row(
                  children: [
                    Icon(doc.isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
                        size: 20, color: AppColors.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(doc.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 1),
                          Text(
                            [doc.kind.label, if (doc.sizeLabel.isNotEmpty) doc.sizeLabel]
                                .join(' · '),
                            style: TextStyle(fontSize: 11.5, color: mute),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _busy ? null : () => _remove(doc),
                      icon: const Icon(Icons.delete_outline_rounded, size: 19),
                      tooltip: 'Remove',
                      color: mute,
                    ),
                  ],
                ),
              ),
            ),
        SizedBox(
          height: 44,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _add,
            icon: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload_file_outlined, size: 19),
            label: const Text('Add document'),
          ),
        ),
      ],
    );
  }
}

/// What kind of paper this is, and what to call it.
class _KindSheet extends StatefulWidget {
  final List<DocumentKind> kinds;
  final String fileName;

  const _KindSheet({required this.kinds, required this.fileName});

  @override
  State<_KindSheet> createState() => _KindSheetState();
}

class _KindSheetState extends State<_KindSheet> {
  late DocumentKind _kind = widget.kinds.first;
  final _label = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('What is this?',
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(widget.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted(context))),
              const SizedBox(height: 16),
              DropdownButtonFormField<DocumentKind>(
                initialValue: _kind,
                isExpanded: true,
                items: [
                  for (final k in widget.kinds)
                    DropdownMenuItem(value: k, child: Text(k.label)),
                ],
                onChanged: (v) => setState(() => _kind = v ?? _kind),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _label,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Name it (optional)',
                  hintText: _kind.label,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, (_kind, _label.text)),
                  child: const Text('Upload'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
