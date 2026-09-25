import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/design_system/app_spacing.dart';

class SkeletonBlock extends StatelessWidget {
  final double height;
  final double? width;
  final double radius;

  const SkeletonBlock({
    super.key,
    required this.height,
    this.width,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.white10 : const Color(0xFFE8EAEE);
    final highlight = isDark ? Colors.white24 : const Color(0xFFF5F6F8);
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class TodaySkeleton extends StatelessWidget {
  const TodaySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          SkeletonBlock(height: 28, width: 180),
          SizedBox(height: AppSpacing.md),
          SkeletonBlock(height: 110),
          SizedBox(height: AppSpacing.md),
          SkeletonBlock(height: 88),
          SizedBox(height: AppSpacing.sm),
          SkeletonBlock(height: 88),
        ],
      ),
    );
  }
}
