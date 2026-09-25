import 'package:flutter/material.dart';

/// App-wide day / night mode. Toggle from the clock-card control.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController([super.value = ThemeMode.light]);

  bool get isDark => value == ThemeMode.dark;

  void toggle() {
    value = isDark ? ThemeMode.light : ThemeMode.dark;
  }

  void setDark(bool dark) {
    value = dark ? ThemeMode.dark : ThemeMode.light;
  }
}

final themeController = ThemeController();
