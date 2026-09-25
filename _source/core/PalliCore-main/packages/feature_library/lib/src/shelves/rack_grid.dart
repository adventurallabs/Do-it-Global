import 'package:flutter/material.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import '../library_widgets.dart';

/// Groups a rack's contents by partition.
Map<(int, int), List<LibrarySlotBooks>> groupBySlot(Iterable<LibrarySlotBooks> rows) {
  final out = <(int, int), List<LibrarySlotBooks>>{};
  for (final r in rows) {
    out.putIfAbsent((r.slot.shelfNo, r.slot.partitionNo), () => []).add(r);
  }
  return out;
}

/// A rack drawn the way it stands: shelf 1 at the top, partitions left to
/// right. Each box shows how many books it holds.
class RackGrid extends StatelessWidget {
  final LibraryRack rack;
  final Map<(int, int), List<LibrarySlotBooks>> contents;
  final ValueChanged<LibrarySlot>? onTap;

  /// Drawn with a ring — the partition being moved from, or just picked.
  final LibrarySlot? marked;

  /// Partitions holding this title are tinted, so the librarian can see
  /// where a book already lives.
  final String? highlightBookId;

  const RackGrid({
    super.key,
    required this.rack,
    required this.contents,
    this.onTap,
    this.marked,
    this.highlightBookId,
  });

  static const double _minBox = 58;
  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final n = rack.partitionsPerShelf;
        final labelW = 34.0;
        final avail = box.maxWidth - labelW - 8;
        final fit = (avail - _gap * (n - 1)) / n;
        final boxW = fit >= _minBox ? fit : _minBox;
        final rowW = labelW + 8 + boxW * n + _gap * (n - 1);
        final grid = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var shelf = 1; shelf <= rack.shelfCount; shelf++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: labelW,
                      child: Text(
                        'S$shelf',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppColors.onSurfaceMuted(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    for (var p = 1; p <= n; p++) ...[
                      if (p > 1) const SizedBox(width: _gap),
                      _PartitionBox(
                        width: boxW,
                        slot: LibrarySlot(rackId: rack.id, rackCode: rack.code, shelfNo: shelf, partitionNo: p),
                        books: contents[(shelf, p)] ?? const [],
                        marked:
                            marked != null &&
                            marked!.rackId == rack.id &&
                            marked!.shelfNo == shelf &&
                            marked!.partitionNo == p,
                        highlightBookId: highlightBookId,
                        onTap: onTap,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
        if (rowW <= box.maxWidth) return grid;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: rowW, child: grid),
        );
      },
    );
  }
}

class _PartitionBox extends StatelessWidget {
  final double width;
  final LibrarySlot slot;
  final List<LibrarySlotBooks> books;
  final bool marked;
  final String? highlightBookId;
  final ValueChanged<LibrarySlot>? onTap;

  const _PartitionBox({
    required this.width,
    required this.slot,
    required this.books,
    required this.marked,
    required this.highlightBookId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final copies = books.fold<int>(0, (sum, b) => sum + b.copies);
    final empty = copies == 0;
    final hasBook = highlightBookId != null && books.any((b) => b.bookId == highlightBookId);
    final tint = hasBook ? AppColors.accent : LibraryColors.shelved;
    final bg = empty
        ? AppColors.onSurfaceHint(context).withValues(alpha: 0.08)
        : tint.withValues(alpha: hasBook ? 0.26 : 0.10 + (copies.clamp(0, 12) / 12) * 0.22);
    return Semantics(
      button: onTap != null,
      label: '${slot.label}, ${empty ? 'empty' : '$copies books'}',
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap == null ? null : () => onTap!(slot),
          child: Container(
            width: width,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: marked ? AppColors.accent : AppColors.onSurfaceHint(context).withValues(alpha: 0.22),
                width: marked ? 2.4 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'P${slot.partitionNo}',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.onSurfaceHint(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                empty
                    ? Icon(Icons.add_rounded, size: 18, color: AppColors.onSurfaceHint(context))
                    : Text('$copies', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
