import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'offline.dart';
import 'theme.dart';

/// Catches what would otherwise be lost in a release build (a grey box, a line in logcat) and reports it to
/// the `client_errors` table so the team can see crashes in the field. Best effort: never throws, sends at
/// most [_cap] distinct errors per app run, skips network failures (those are expected and shown as offline),
/// and stays quiet if the table isn't there yet.
class ErrorReporter {
  ErrorReporter._();

  static const _cap = 10;
  static final _sent = <String>{};

  static void install() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      report(details.exception, details.stack, context: details.context?.toString());
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack);
      return true;
    };
    // In release a broken widget shows a calm message instead of a grey block.
    if (kReleaseMode) ErrorWidget.builder = (_) => const _BrokenPart();
  }

  static void report(Object error, StackTrace? stack, {String? context}) {
    if (!kReleaseMode) debugPrint('Unhandled: $error');
    if (isNetworkError(error)) return;
    final message = '${context == null ? '' : '$context: '}$error';
    final key = message.length > 200 ? message.substring(0, 200) : message;
    if (_sent.length >= _cap || !_sent.add(key)) return;
    unawaited(_send(message, stack));
  }

  static Future<void> _send(String message, StackTrace? stack) async {
    try {
      await Supabase.instance.client.from('client_errors').insert({
        'message': message.length > 2000 ? message.substring(0, 2000) : message,
        'stack': stack == null ? null : (stack.toString().length > 6000 ? stack.toString().substring(0, 6000) : stack.toString()),
        'platform': defaultTargetPlatform.name,
        'app_version': const String.fromEnvironment('APP_VERSION', defaultValue: 'dev'),
      });
    } catch (_) {/* not signed in, offline, or the table isn't there: nothing more to do */}
  }
}

class _BrokenPart extends StatelessWidget {
  const _BrokenPart();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: Text("Something went wrong here. Go back and try again.", textAlign: TextAlign.center, textDirection: TextDirection.ltr, style: body(13, color: C.muted)),
      );
}
