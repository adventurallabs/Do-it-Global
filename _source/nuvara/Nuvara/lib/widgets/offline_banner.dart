import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../offline.dart';
import '../store.dart';
import '../theme.dart';

/// Puts a slim bar above every screen while the app can't reach the server: it says the data shown is
/// saved on this device and how old it is, and offers Retry (the app also retries on its own). When the
/// connection comes back it says so briefly, then gets out of the way.
class OfflineFrame extends StatefulWidget {
  final Widget child;
  const OfflineFrame({super.key, required this.child});

  @override
  State<OfflineFrame> createState() => _OfflineFrameState();
}

class _OfflineFrameState extends State<OfflineFrame> {
  bool _wasOffline = false, _backOnline = false;
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = context.select<AppStore, bool>((s) => s.role != null);
    final offline = signedIn && context.select<AppStore, bool>((s) => s.offline);
    final busy = context.select<AppStore, bool>((s) => s.reconnecting);
    final asOf = context.select<AppStore, DateTime?>((s) => s.dataAsOf);
    if (_wasOffline && !offline && signedIn) {
      _backOnline = true;
      _hide?.cancel();
      _hide = Timer(const Duration(milliseconds: 2600), () {
        if (mounted) setState(() => _backOnline = false);
      });
    }
    _wasOffline = offline;
    final show = offline || _backOnline;

    return Column(children: [
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: show ? _bar(context, offline: offline, busy: busy, asOf: asOf) : const SizedBox(width: double.infinity),
      ),
      // The bar already sits under the status bar, so the screen below mustn't pad for it again.
      Expanded(child: show ? MediaQuery.removePadding(context: context, removeTop: true, child: widget.child) : widget.child),
    ]);
  }

  Widget _bar(BuildContext context, {required bool offline, required bool busy, DateTime? asOf}) {
    final fg = offline ? C.amber : C.green;
    final text = offline ? (asOf == null ? "You're offline" : "You're offline · showing data from ${savedAtLabel(asOf)}") : 'Back online · up to date';
    return Material(
      color: offline ? C.amberBg : C.greenBg,
      child: SafeArea(
        bottom: false,
        child: Semantics(
          liveRegion: true,
          child: InkWell(
            onTap: offline && !busy ? () => context.read<AppStore>().reconnect() : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                child: Row(children: [
                  Icon(offline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded, size: 18, color: fg),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(12.5, weight: FontWeight.w700, color: fg, height: 1.3))),
                  if (offline)
                    busy
                        ? const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: C.amber)))
                        : TextButton(
                            onPressed: () => context.read<AppStore>().reconnect(),
                            style: TextButton.styleFrom(foregroundColor: C.amber, minimumSize: const Size(0, 36), visualDensity: VisualDensity.compact),
                            child: const Text('Retry'),
                          ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
