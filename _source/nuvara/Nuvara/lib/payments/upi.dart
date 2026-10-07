import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;

import '../actions.dart' show UpiOrder;
import '../models.dart' show UpiKind;
import '../util.dart';

/// What came back from the UPI app. [response] is the app's raw reply; it is passed to the server as is,
/// and the server decides what it means.
typedef UpiReply = ({bool launched, String? response});

/// UPI intent payments (Android). On other platforms the parent scans the QR code or pays the UPI ID by
/// hand and gives us the UPI reference instead.
class Upi {
  static const _channel = MethodChannel('nuvara/upi');

  /// Only Android lets us open a UPI app and get its reply.
  static bool get canLaunch => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// The standard UPI deep link (NPCI linking spec). Payee, amount and kind come from the server's order.
  ///
  /// * Personal UPI ID: a person-to-person link. `tr` and `mc` mark a merchant payment, and UPI apps refuse
  ///   those for a personal ID (BHIM: "request type is not supported", Google Pay: declined), so they are
  ///   left out.
  /// * Merchant UPI ID: `tr` carries our reference and the app echoes it back, tying the reply to this
  ///   payment; `mc` is added when the admin gave the category code.
  ///
  /// Either way the reference also goes first in the note (`tn`), which lands in both parties' UPI history
  /// and statements, so the admin can always match the money to the payment.
  ///
  /// The query is built by hand: Dart's `queryParameters` writes spaces as `+` and `@` as `%40`, which
  /// several UPI apps don't decode.
  static Uri link(UpiOrder o, String note) {
    final tn = '${o.txnRef} $note';
    final merchant = o.kind == UpiKind.merchant;
    final params = {
      'pa': o.vpa,
      'pn': o.name,
      if (merchant && o.mc != null) 'mc': o.mc!,
      if (merchant) 'tr': o.txnRef,
      'am': o.amount.toStringAsFixed(2),
      'cu': 'INR',
      // Some apps cut the note at 50 characters; the reference goes first so it survives.
      'tn': tn.substring(0, tn.length.clamp(0, 50)).trim(),
    };
    String enc(String s) => Uri.encodeComponent(s).replaceAll('%40', '@');
    return Uri.parse('upi://pay?${params.entries.map((e) => '${e.key}=${enc(e.value)}').join('&')}');
  }

  /// How many UPI apps are installed (0 when unknown).
  static Future<int> apps() async {
    if (!canLaunch) return 0;
    try {
      return await _channel.invokeMethod<int>('apps') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Shows the "Pay with" chooser and waits until the parent comes back from the UPI app.
  ///
  /// The UPI app's reply can get lost (Android killed or recreated our activity while the parent was paying),
  /// and then the call would never return. So once Nuvara is back on screen after the UPI app, it waits [grace]
  /// for the reply and otherwise goes on without one, as it does after [limit] in any case. No reply means the
  /// server keeps the payment open and the parent says whether they paid; nothing is assumed either way.
  static Future<UpiReply> pay(Uri link, {Duration grace = const Duration(seconds: 8), Duration limit = const Duration(minutes: 15)}) async {
    const noReply = (launched: true, response: null);
    final reply = _channel.invokeMapMethod<String, dynamic>('pay', {'uri': link.toString()}).then<UpiReply>((r) => (launched: r?['launched'] == true, response: r?['response'] as String?));
    final back = Completer<UpiReply>();
    var away = false;
    Timer? wait;
    final listener = AppLifecycleListener(
      onHide: () => away = true,
      onResume: () {
        if (away) wait ??= Timer(grace, () => back.isCompleted ? null : back.complete(noReply));
      },
    );
    try {
      return await Future.any([reply, back.future]).timeout(limit, onTimeout: () => noReply);
    } finally {
      wait?.cancel();
      listener.dispose();
    }
  }
}

/// "Fee C001 · 28 Sep" — what the parent sees in their UPI app and bank statement.
String upiNote(String childCode, String monday) => 'Fee $childCode wk ${fmtDate(monday, 'd MMM')}';

/// A UPI reference typed by a parent: letters and digits only, upper case.
String cleanUtr(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
bool validUtr(String s) => RegExp(r'^[A-Z0-9]{6,35}$').hasMatch(cleanUtr(s));
