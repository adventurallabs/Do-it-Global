import 'package:flutter/material.dart';

enum PremiumElevation { control, card, hero }

abstract final class PremiumShadows {
  static List<BoxShadow> of(PremiumElevation elevation) {
    switch (elevation) {
      case PremiumElevation.control:
        return const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(4, 8)),
          BoxShadow(color: Color(0xE6FFFFFF), blurRadius: 10, offset: Offset(-3, -3)),
        ];
      case PremiumElevation.hero:
        return const [
          BoxShadow(color: Color(0x29000000), blurRadius: 40, offset: Offset(10, 18)),
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(2, 6)),
          BoxShadow(color: Color(0xF2FFFFFF), blurRadius: 14, offset: Offset(-5, -6)),
        ];
      case PremiumElevation.card:
        return const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 30, offset: Offset(8, 12)),
          BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(2, 4)),
          BoxShadow(color: Color(0xE6FFFFFF), blurRadius: 12, offset: Offset(-4, -4)),
        ];
    }
  }
}
