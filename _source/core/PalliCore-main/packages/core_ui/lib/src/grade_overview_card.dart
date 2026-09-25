import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'admin_look.dart';
import 'neo_widgets.dart';

class GradeOverviewCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool exists;
  final bool hasSections;
  final VoidCallback onTap;

  const GradeOverviewCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.exists,
    required this.hasSections,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      depth: SoftDepth.one,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Row(
        children: [
          AdminIconWell(
            icon: Icons.school_outlined,
            color: exists ? AdminLook.gold : AppColors.onSurfaceHint(context),
            size: 40,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: exists ? AppColors.onSurface(context) : AppColors.onSurfaceMuted(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 12)),
              ],
            ),
          ),
          StatusPill(
            label: !exists
                ? 'Not created'
                : hasSections
                    ? 'Has sections'
                    : 'No sections',
            color: !exists
                ? AppColors.onSurfaceHint(context)
                : hasSections
                    ? AppColors.accent
                    : AppColors.success,
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceHint(context)),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const StatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
