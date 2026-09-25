import 'package:flutter/material.dart';

class AppRoutes {
  /// A plain page route: the theme's [AppPageTransitionsBuilder] paints the
  /// brand backdrop into the page and slides it in, so every pushed screen
  /// looks like the rest of the app and fully covers the one beneath.
  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => page));
  }
}
