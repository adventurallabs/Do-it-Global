import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'app_colors.dart';

/// The picked image, and the name it came with.
class PickedPhoto {
  final Uint8List bytes;
  final String extension;

  const PickedPhoto({required this.bytes, required this.extension});
}

/// A round photo well with "Camera" and "Gallery" under it.
///
/// It hands the bytes back rather than uploading them itself: at admission
/// the child has no row yet, so there is nowhere to attach a file to until
/// the form is saved. The caller decides when the upload happens.
class PersonPhotoField extends StatefulWidget {
  /// Shown when nothing new has been picked — an existing photo.
  final String? currentUrl;

  /// What the caller should upload on save. Null means leave it as it is.
  final ValueChanged<PickedPhoto?> onPicked;

  final String label;
  final double size;

  const PersonPhotoField({
    super.key,
    required this.onPicked,
    this.currentUrl,
    this.label = 'Photo',
    this.size = 96,
  });

  @override
  State<PersonPhotoField> createState() => _PersonPhotoFieldState();
}

class _PersonPhotoFieldState extends State<PersonPhotoField> {
  Uint8List? _preview;
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        // A face at 1200px is plenty and keeps a classful of photos from
        // costing a parent their data allowance.
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (file == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
      setState(() {
        _preview = bytes;
        _busy = false;
      });
      widget.onPicked(PickedPhoto(bytes: bytes, extension: ext));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Could not open that: $e'),
          backgroundColor: AppColors.error,
        ));
    }
  }

  void _clear() {
    setState(() => _preview = null);
    widget.onPicked(null);
  }

  @override
  Widget build(BuildContext context) {
    final mute = AppColors.onSurfaceMuted(context);
    final hasNew = _preview != null;
    final hasExisting = (widget.currentUrl ?? '').trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceLight,
              border: Border.all(color: AppColors.divider),
            ),
            clipBehavior: Clip.antiAlias,
            child: _busy
                ? const Center(
                    child: SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                : hasNew
                    ? Image.memory(_preview!, fit: BoxFit.cover)
                    : hasExisting
                        ? Image.network(
                            widget.currentUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                Icon(Icons.person_rounded, size: 34, color: mute),
                          )
                        : Icon(Icons.add_a_photo_outlined, size: 28, color: mute),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface(context))),
                const SizedBox(height: 2),
                Text(
                  hasNew
                      ? 'New photo ready — it uploads when you save.'
                      : hasExisting
                          ? 'Tap to replace.'
                          : 'Optional now; it can be added later.',
                  style: TextStyle(fontSize: 11.5, height: 1.3, color: mute),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    TextButton.icon(
                      onPressed: _busy ? null : () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Camera'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Gallery'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    if (hasNew)
                      TextButton(
                        onPressed: _busy ? null : _clear,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 34),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Undo'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
