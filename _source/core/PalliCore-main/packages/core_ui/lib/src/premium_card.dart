import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'admin_look.dart';

/// Management category card — gold-rimmed Level 1 surface.
class PremiumCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final Widget? trailing;
  final int? badgeCount;

  const PremiumCard({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.iconColor = AppColors.accent,
    this.onTap,
    this.trailing,
    this.badgeCount,
  });

  @override
  State<PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends State<PremiumCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        scale: _pressed ? 0.98 : 1,
        child: GoldRimSurface(
          depth: SoftDepth.one,
          borderRadius: BorderRadius.circular(30),
          rimWidth: 1.4,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminIconWell(icon: widget.icon, color: AdminLook.gold),
              const Spacer(),
              Text(
                widget.title,
                style: TextStyle(
                  color: AppColors.onSurface(context),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.subtitle!,
                  style: TextStyle(
                    color: AppColors.onSurfaceMuted(context),
                    fontSize: 12,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
