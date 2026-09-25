import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';

/// "82" not "82.0", "82.5" kept — marks are read at a glance, and a trailing
/// ".0" on every row is noise.
String fmtNum(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// The band a percentage falls in. Same colours in the teacher's table and
/// the sheet list, so a weak test looks the same wherever it is read.
Color gradeColor(double percent) {
  if (percent >= 75) return AppColors.success;
  if (percent >= 50) return AppColors.warning;
  return AppColors.error;
}
