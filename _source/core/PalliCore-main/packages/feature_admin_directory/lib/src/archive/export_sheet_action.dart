import 'dart:io';

import 'package:flutter/material.dart';
import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes an export to a file and hands it to the device's share sheet, so
/// the admin can put it wherever they keep records — Drive, email, the SD
/// card. Nothing is uploaded by the app itself.
class ExportSheetAction {
  ExportSheetAction._();

  /// Asks which format, writes the file, then shares it. Returns false if the
  /// admin backed out.
  static Future<bool> run(
    BuildContext context, {
    required String title,
    required String baseName,
    required List<ExportSheet> sheets,
  }) async {
    if (sheets.every((s) => s.isEmpty)) {
      _toast(context, 'Nothing to export yet.');
      return false;
    }
    final format = await showModalBottomSheet<_Format>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.grid_on_rounded, color: AppColors.success),
              title: const Text('Excel workbook (.xlsx)'),
              subtitle: Text(
                sheets.length > 1
                    ? '${sheets.length} tabs — ${sheets.map((s) => s.name).join(', ')}'
                    : 'Opens in Excel, Numbers and Google Sheets',
              ),
              onTap: () => Navigator.pop(ctx, _Format.xlsx),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined, color: AppColors.accent),
              title: const Text('CSV file (.csv)'),
              subtitle: const Text('Plain text — opens anywhere, imports into any system'),
              onTap: () => Navigator.pop(ctx, _Format.csv),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (format == null || !context.mounted) return false;

    try {
      final isXlsx = format == _Format.xlsx;
      final bytes = isXlsx ? RecordExport.toXlsx(sheets) : RecordExport.toCsv(sheets);
      final name = RecordExport.fileName(baseName, _stamp(), isXlsx ? 'xlsx' : 'csv');
      // The share sheet needs a real file path, and the cache directory is
      // the one place that exists and is writable on every platform.
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}$name');
      await file.writeAsBytes(bytes, flush: true);
      if (!context.mounted) return false;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          fileNameOverrides: [name],
          subject: title,
        ),
      );
      return true;
    } catch (_) {
      if (context.mounted) {
        _toast(context, "Couldn't create the file. Check storage space and try again.");
      }
      return false;
    }
  }

  static String _stamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  static void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }
}

enum _Format { xlsx, csv }
