import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/localization/l10n_ext.dart';
import '../../core/utils/formatters.dart';
import '../../shared/models/diary_item.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/section_header.dart';
import '../parent/parent_store.dart';

import '../../core/navigation/app_routes.dart';
import '../../shared/widgets/homework_card.dart';
import '../homework/homework_screen.dart';
import '../homework/homework_detail_screen.dart';

class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key});

  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  late DateTime _selected;
  String _query = '';
  bool _showCalendar = false;

  @override
  void initState() {
    super.initState();
    _selected = dateOnly(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final allDiary = ref.watch(studentDiaryProvider);
    final allHomework = ref.watch(studentHomeworkProvider);

    final dayDiary = allDiary.where((e) => isSameDay(e.date, _selected)).toList();
    final dayHomework = allHomework.where((e) => isSameDay(e.assignedOn, _selected)).toList();

    final searching = _query.trim().isNotEmpty;
    
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.tabDiary, style: theme.textTheme.headlineMedium)),
                  IconButton(
                    tooltip: l10n.homework,
                    onPressed: () => AppRoutes.push(context, const HomeworkScreen()),
                    icon: const Icon(Icons.assignment_outlined, color: AppColors.primaryBlue),
                  ),
                  IconButton(
                    tooltip: l10n.calendar,
                    onPressed: () => setState(() => _showCalendar = !_showCalendar),
                    icon: const Icon(Icons.calendar_month_outlined),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (!searching)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => setState(() => _selected = _selected.subtract(const Duration(days: 1))),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        DateFormat.yMMMMEEEEd().format(_selected),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _selected = _selected.add(const Duration(days: 1))),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
            if (_showCalendar && !searching)
              CalendarDatePicker(
                initialDate: _selected,
                firstDate: DateTime(2025, 6, 1),
                lastDate: DateTime.now().add(const Duration(days: 30)),
                onDateChanged: (d) => setState(() {
                  _selected = dateOnly(d);
                  _showCalendar = false;
                }),
              ),
            Expanded(
              child: (dayDiary.isEmpty && dayHomework.isEmpty)
                  ? AppEmptyState(
                      icon: Icons.menu_book_outlined,
                      title: l10n.noDiaryTitle,
                      body: l10n.noDiaryBody,
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        108,
                      ),
                      children: [
                        if (dayHomework.isNotEmpty) ...[
                          SectionHeader(title: l10n.homework),
                          ...dayHomework.map((h) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: HomeworkCard(
                              item: h, 
                              onOpen: () => AppRoutes.push(context, HomeworkDetailScreen(item: h)),
                              onToggle: () => ref.read(parentStoreProvider.notifier).toggleHomework(h.id),
                            ),
                          )),
                        ],
                        ..._group(context, dayDiary).expand((section) => [
                              SectionHeader(title: section.$1),
                              ...section.$2.map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                  child: _DiaryCard(entry: e),
                                ),
                              ),
                            ]),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<(String, List<DiaryDayEntry>)> _group(BuildContext context, List<DiaryDayEntry> items) {
    final l10n = context.l10n;
    Map<DiaryEntryKind, List<DiaryDayEntry>> map = {
      DiaryEntryKind.teacherNote: [],
      DiaryEntryKind.notice: [],
      DiaryEntryKind.activity: [],
    };
    for (final e in items) {
      if (e.kind == DiaryEntryKind.homework) continue; // Handled separately
      map[e.kind]!.add(e);
    }
    String title(DiaryEntryKind k) => switch (k) {
          DiaryEntryKind.homework => l10n.homework,
          DiaryEntryKind.teacherNote => l10n.teacherNotes,
          DiaryEntryKind.notice => l10n.schoolNotices,
          DiaryEntryKind.activity => l10n.activities,
        };
    return map.entries.where((e) => e.value.isNotEmpty).map((e) => (title(e.key), e.value)).toList();
  }
}

class _DiaryCard extends StatelessWidget {
  final DiaryDayEntry entry;

  const _DiaryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = switch (entry.kind) {
      DiaryEntryKind.homework => Icons.menu_book_outlined,
      DiaryEntryKind.teacherNote => Icons.notes_outlined,
      DiaryEntryKind.notice => Icons.campaign_outlined,
      DiaryEntryKind.activity => Icons.emoji_events_outlined,
    };
    return PremiumCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.info, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(entry.body, style: theme.textTheme.bodyMedium),
                if (entry.teacherName != null)
                  Text(entry.teacherName!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
