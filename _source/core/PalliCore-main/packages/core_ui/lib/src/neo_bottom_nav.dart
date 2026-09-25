import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'admin_look.dart';

/// Floating gold-rimmed navigation surface. The selected pill glides to the
/// chosen tab (it used to jump), and the icon lifts slightly as it lands.
class NeoBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final List<NeoNavItem> items;

  const NeoBottomNav({
    super.key,
    required this.index,
    required this.onChanged,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final selected = items.isEmpty ? 0 : index.clamp(0, items.length - 1);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
      child: GoldRimSurface(
        depth: SoftDepth.three,
        borderRadius: BorderRadius.circular(999),
        rimWidth: 1.45,
        padding: EdgeInsets.zero,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: LayoutBuilder(
              builder: (context, box) {
                final w = items.isEmpty ? 0.0 : box.maxWidth / items.length;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 340),
                      curve: Curves.easeOutCubic,
                      left: selected * w,
                      top: 0,
                      bottom: 0,
                      width: w,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: GoldRimSurface(
                          depth: SoftDepth.two,
                          borderRadius: BorderRadius.circular(22),
                          rimWidth: 1.15,
                          texture: false,
                          expand: true,
                          padding: EdgeInsets.zero,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child: _NavTile(
                              item: items[i],
                              selected: i == selected,
                              onTap: () {
                                if (i == selected) return;
                                HapticFeedback.selectionClick();
                                onChanged(i);
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class NeoNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badgeCount;

  const NeoNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
  });
}

class _NavTile extends StatelessWidget {
  final NeoNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavTile({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 7),
          child: _label(context),
        ),
      ),
    );
  }

  Widget _label(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedScale(
          scale: selected ? 1.08 : 1,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: selected ? AdminLook.gold : AppColors.onSurfaceHint(context)),
                duration: const Duration(milliseconds: 220),
                builder: (context, color, _) => Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 22,
                  color: color,
                ),
              ),
              if (item.badgeCount > 0)
                Positioned(
                  right: -6,
                  top: -3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 15),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.badgeCount > 99 ? '99+' : '${item.badgeCount}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 220),
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AdminLook.inkOf(context) : AppColors.onSurfaceHint(context),
            height: 1.1,
          ),
          child: Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
