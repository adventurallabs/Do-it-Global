import 'package:flutter/material.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

/// Label / icon / colour for each kind of progress entry, shared by the hub,
/// the recorder and the per-student page so they always read as one system.
class ProgressKindMeta {
  final String action; // verb shown on buttons
  final String noun; // plural noun for lists
  final String hint; // one-line explanation
  final IconData icon;
  final Color color;

  const ProgressKindMeta(this.action, this.noun, this.hint, this.icon, this.color);

  static ProgressKindMeta of(ProgressKind kind) => switch (kind) {
        ProgressKind.star => const ProgressKindMeta(
            'Give stars', 'Stars', 'Reward something good', Icons.star_rounded, AdminLook.gold),
        ProgressKind.activity => const ProgressKindMeta('Log activity', 'Activities',
            'Events, competitions, clubs', Icons.emoji_events_rounded, AppColors.eventCard),
        ProgressKind.observation => const ProgressKindMeta('Add a note', 'Notes',
            'What parents should know', Icons.sticky_note_2_rounded, AppColors.studentCard),
        ProgressKind.skill => const ProgressKindMeta('Rate skills', 'Skills',
            'Update skill levels', Icons.auto_graph_rounded, AppColors.examCard),
      };
}

Color toneColor(ObservationTone tone) => switch (tone) {
      ObservationTone.positive => AppColors.success,
      ObservationTone.neutral => AppColors.examCard,
      ObservationTone.attention => AppColors.warning,
    };

String toneLabel(ObservationTone tone) => switch (tone) {
      ObservationTone.positive => 'Positive',
      ObservationTone.neutral => 'General',
      ObservationTone.attention => 'Needs attention',
    };

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Today", "Yesterday", "3 days ago", "12 Sep".
String friendlyDate(DateTime date) {
  final now = DateTime.now();
  final d = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff > 1 && diff < 7) return '$diff days ago';
  return '${date.day} ${_months[date.month - 1]}${date.year == now.year ? '' : ' ${date.year}'}';
}

/// Sorts a roster the way teachers read it: by roll number, then name.
List<Student> sortedRoster(List<Student> students) {
  int roll(Student s) => int.tryParse(s.rollNumber.trim()) ?? 1 << 30;
  return [...students]
    ..sort((a, b) {
      final r = roll(a).compareTo(roll(b));
      return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
}

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

class StudentInitials extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  const StudentInitials({super.key, required this.name, this.size = 36, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withValues(alpha: 0.16),
      ),
      child: Text(
        initialsOf(name),
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: c,
        ),
      ),
    );
  }
}

/// Small section heading used down every progress page.
class ProgressSectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  final Widget? action;
  const ProgressSectionTitle(this.title, {super.key, this.trailing, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: AdminLook.inkOf(context),
              ),
            ),
          ),
          if (trailing != null)
            Text(trailing!,
                style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted(context))),
          ?action,
        ],
      ),
    );
  }
}

/// A pill that can be toggled on/off — used for presets and students.
class SelectPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color color;
  final IconData? icon;
  final Widget? leading;

  const SelectPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.color = AppColors.accent,
    this.icon,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final ink = AdminLook.inkOf(context);
    return Material(
      color: selected ? color.withValues(alpha: 0.16) : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? color : AppColors.onSurfaceHint(context).withValues(alpha: 0.45),
          width: selected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: EdgeInsets.fromLTRB(leading != null ? 5 : 14, 6, 14, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 8)],
                if (selected)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(Icons.check_rounded, size: 16, color: color),
                  )
                else if (icon != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(icon, size: 16, color: AppColors.onSurfaceMuted(context)),
                  ),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Four-step skill level picker (Emerging → Advanced). [value] is 0..4.
class SkillLevelPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final bool compact;
  const SkillLevelPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    const color = AppColors.examCard;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var step = 1; step <= 4; step++)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Tooltip(
              message: SkillLevel.labels[step - 1],
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onChanged(value == step ? 0 : step),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: compact ? 34 : 44,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: step <= value ? color.withValues(alpha: 0.18 + step * 0.12) : Colors.transparent,
                    border: Border.all(
                      color: step <= value ? color : AppColors.onSurfaceHint(context).withValues(alpha: 0.4),
                      width: step == value ? 1.8 : 1,
                    ),
                  ),
                  child: Text(
                    SkillLevel.labels[step - 1].substring(0, compact ? 1 : 3),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: step == value ? FontWeight.w800 : FontWeight.w600,
                      color: step <= value ? color : AppColors.onSurfaceMuted(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Read-only four-segment bar for a skill level.
class SkillLevelBar extends StatelessWidget {
  final String level;
  const SkillLevelBar({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final step = SkillLevel.stepOf(level);
    return Row(
      children: [
        for (var i = 1; i <= 4; i++)
          Expanded(
            child: Container(
              height: 6,
              margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: i <= step
                    ? AppColors.examCard
                    : AppColors.onSurfaceHint(context).withValues(alpha: 0.25),
              ),
            ),
          ),
      ],
    );
  }
}
