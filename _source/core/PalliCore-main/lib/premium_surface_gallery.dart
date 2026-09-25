import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';

/// Isolated lab for [PremiumSurface]. Not wired into product screens.
class PremiumSurfaceGallery extends StatelessWidget {
  const PremiumSurfaceGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'PremiumSurface',
          style: TextStyle(color: PremiumColors.ink, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          const Text(
            'Same material · three shapes',
            style: TextStyle(color: PremiumColors.mute, fontSize: 14),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              PremiumSurface.circle(
                child: const Icon(Icons.logout_rounded, size: 20, color: PremiumColors.ink),
              ),
              const SizedBox(width: 16),
              PremiumSurface.circle(
                child: const Icon(Icons.auto_awesome_rounded, size: 20, color: PremiumColors.goldMid),
              ),
              const SizedBox(width: 16),
              PremiumSurface.pill(
                child: const Text(
                  '09/09',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: PremiumColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          PremiumSurface.card(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 42,
                  height: 42,
                  child: PremiumSurface(
                    type: PremiumSurfaceType.card,
                    borderRadius: BorderRadius.circular(PremiumConstants.iconWellRadius),
                    finish: PremiumFinish.recessed,
                    showArcs: false,
                    elevation: PremiumElevation.control,
                    padding: const EdgeInsets.all(8),
                    child: const FittedBox(
                      child: Icon(Icons.school_outlined, color: PremiumColors.goldMid),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '8',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: PremiumColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                const Text('Students', style: TextStyle(color: PremiumColors.mute, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
