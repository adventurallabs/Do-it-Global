import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'neo_widgets.dart';

class SearchFilterBar extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onSearch;
  final List<SortOption>? sortOptions;
  final SortOption? currentSort;
  final ValueChanged<SortOption>? onSortChanged;
  final List<FilterChipData>? filterChips;
  final ValueChanged<FilterChipData>? onFilterToggled;

  const SearchFilterBar({
    super.key,
    this.hintText = 'Search...',
    required this.onSearch,
    this.sortOptions,
    this.currentSort,
    this.onSortChanged,
    this.filterChips,
    this.onFilterToggled,
  });

  @override
  State<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<SearchFilterBar> {
  final _controller = TextEditingController();
  bool _showFilters = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: SoftField(
                  child: TextField(
                    controller: _controller,
                    onChanged: (val) {
                      widget.onSearch(val);
                      setState(() {});
                    },
                    style: TextStyle(color: AppColors.onSurface(context), fontSize: 15),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      prefixIcon: Icon(Icons.search, color: AppColors.onSurfaceHint(context), size: 22),
                      suffixIcon: _controller.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: AppColors.onSurfaceHint(context), size: 20),
                              onPressed: () {
                                _controller.clear();
                                widget.onSearch('');
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              if (widget.sortOptions != null || widget.filterChips != null) ...[
                const SizedBox(width: 10),
                SoftIconButton(
                  icon: Icons.tune,
                  size: 42,
                  elevated: false,
                  iconColor: _showFilters ? AppColors.accent : AppColors.onSurfaceHint(context),
                  onTap: () => setState(() => _showFilters = !_showFilters),
                ),
              ],
            ],
          ),
        ),
        if (_showFilters) ...[
          if (widget.sortOptions != null && widget.sortOptions!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('Sort: ', style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13)),
                  ...widget.sortOptions!.map(
                    (opt) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(opt.label, style: const TextStyle(fontSize: 12)),
                        selected: widget.currentSort?.value == opt.value,
                        onSelected: (_) => widget.onSortChanged?.call(opt),
                        selectedColor: AppColors.accent.withValues(alpha: 0.15),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (widget.filterChips != null && widget.filterChips!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: widget.filterChips!
                      .map(
                        (chip) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(chip.label, style: const TextStyle(fontSize: 12)),
                            selected: chip.isSelected,
                            onSelected: (_) => widget.onFilterToggled?.call(chip),
                            selectedColor: AppColors.accent.withValues(alpha: 0.15),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class SortOption {
  final String label;
  final String value;
  final bool ascending;

  const SortOption({required this.label, required this.value, this.ascending = true});
}

class FilterChipData {
  final String label;
  final String value;
  final bool isSelected;

  const FilterChipData({required this.label, required this.value, this.isSelected = false});

  FilterChipData copyWith({bool? isSelected}) {
    return FilterChipData(label: label, value: value, isSelected: isSelected ?? this.isSelected);
  }
}
