import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

/// The school's own name and crest, set once from the admin's home screen.
///
/// Certificates carry both, and nothing else in the app can supply them — so
/// until this is filled in, the certificate layouts stay locked. The card says
/// that plainly rather than letting the admin discover it on prize day.
class SchoolIdentityCard extends StatefulWidget {
  const SchoolIdentityCard({super.key});

  @override
  State<SchoolIdentityCard> createState() => _SchoolIdentityCardState();
}

class _SchoolIdentityCardState extends State<SchoolIdentityCard> {
  SchoolProfile? _profile;
  bool _busy = false;

  SchoolSettingsRepository get _repo => context.read<SchoolSettingsRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _repo.get();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      if (mounted) setState(() {});
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

  Future<void> _editName() async {
    final controller = TextEditingController(
      text: _profile?.hasName == true ? _profile!.name : '',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('School name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'As it should read on a certificate',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.saveName(name);
      await _load();
      _say('School name saved.');
    } catch (e) {
      _say('Could not save the name: $e', bad: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadLogo() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );
    final file = picked?.files.singleOrNull;
    final bytes = file?.bytes;
    if (bytes == null || !mounted) return;
    if (bytes.lengthInBytes > 2 * 1024 * 1024) {
      _say('That image is over 2 MB. Pick a smaller one.', bad: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await _repo.uploadLogo(bytes: bytes, extension: file!.extension ?? 'png');
      await _load();
      _say('School logo updated.');
    } catch (e) {
      _say('Could not upload the logo: $e', bad: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final mute = AppColors.onSurfaceMuted(context);
    final ready = profile?.isReadyForCertificates ?? false;
    // Sits inside the home screen's own 20pt gutter, so no outer padding here.
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Crest(url: profile?.logoUrl ?? ''),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.hasName == true ? profile!.name : 'Name your school',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        ready
                            ? 'Certificate layouts are unlocked.'
                            : 'Add your ${_missingText(profile)} to unlock certificates.',
                        style: TextStyle(fontSize: 12.5, height: 1.3, color: ready ? AppColors.success : mute),
                      ),
                    ],
                  ),
                ),
                if (_busy)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _busy ? null : _editName,
                  icon: const Icon(Icons.drive_file_rename_outline_rounded, size: 18),
                  label: Text(profile?.hasName == true ? 'Edit name' : 'Set name'),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: _busy ? null : _uploadLogo,
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: Text(profile?.hasLogo == true ? 'Replace logo' : 'Upload logo'),
                ),
              ],
            ),
          ],
        ),
    );
  }

  String _missingText(SchoolProfile? profile) {
    final missing = profile?.missingForCertificates ?? const ['school name', 'school logo'];
    if (missing.length == 1) return missing.single;
    return '${missing.first} and ${missing.last}';
  }
}

class _Crest extends StatelessWidget {
  final String url;
  const _Crest({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AdminLook.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminLook.gold.withValues(alpha: 0.28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? Icon(Icons.apartment_rounded, color: AdminLook.gold.withValues(alpha: 0.8), size: 24)
          : Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.broken_image_outlined, color: AppColors.onSurfaceHint(context), size: 22),
            ),
    );
  }
}
