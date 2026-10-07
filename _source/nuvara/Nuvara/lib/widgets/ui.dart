import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, PostgrestException;

import '../models.dart';
import '../offline.dart';
import '../theme.dart';
import '../util.dart';

/// From this width the app uses its wide layout: a side rail instead of the bottom bar, and dialogs instead of
/// bottom sheets. One value for both, so a screen never has a rail with phone sheets (or the other way round).
const wideBreakpoint = 840.0;

bool isWide(BuildContext c) => MediaQuery.sizeOf(c).width >= wideBreakpoint;

/// Content never stretches wider than a comfortable reading width, even on tablets/desktop.
const maxContent = 760.0;

/// Layered, navy-tinted shadow: a crisp contact line and a soft long drop.
const softShadow = [
  BoxShadow(color: Color(0x0A010039), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x14010039), blurRadius: 26, spreadRadius: -12, offset: Offset(0, 12)),
];

/// A white card. Tappable cards sink slightly under the finger and spring back.
class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color color;
  final Color border;
  final double radius;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.onLongPress, this.color = C.surface, this.border = C.line, this.radius = 20});

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _down = false;

  void _press(bool v) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (v != _down) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => AnimatedScale(
        scale: _down ? 0.985 : 1,
        duration: Duration(milliseconds: _down ? 90 : 220),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(widget.radius), boxShadow: softShadow),
          child: Material(
            color: widget.color,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(widget.radius), side: BorderSide(color: widget.border)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              onHighlightChanged: _press,
              splashColor: C.brand100.withValues(alpha: 0.5),
              highlightColor: C.brand50.withValues(alpha: 0.6),
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ),
        ),
      );
}

/// The navy hero surface at the top of dashboards: a deep gradient with soft orange and sky light, echoing
/// the Nuvara mark, and a fine highlight along the top edge.
class HeroSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  const HeroSurface({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.radius = 26});

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: heroGradient,
          boxShadow: const [BoxShadow(color: Color(0x2E010039), blurRadius: 28, spreadRadius: -16, offset: Offset(0, 14))],
        ),
        child: Stack(children: [
          Positioned(right: -70, top: -90, child: _glow(C.sky.withValues(alpha: 0.30), 220)),
          Positioned(left: -60, bottom: -110, child: _glow(C.clay500.withValues(alpha: 0.26), 220)),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0)]))),
          ),
          Padding(padding: padding, child: child),
        ]),
      );

  static Widget _glow(Color c, double size) => IgnorePointer(
        child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)]))),
      );
}

enum Tone { green, amber, red, blue, violet, neutral }

({Color fg, Color bg}) toneColors(Tone t) => switch (t) {
      Tone.green => (fg: C.green, bg: C.greenBg),
      Tone.amber => (fg: C.amber, bg: C.amberBg),
      Tone.red => (fg: C.red, bg: C.redBg),
      Tone.blue => (fg: C.blue, bg: C.blueBg),
      Tone.violet => (fg: C.violet, bg: C.violetBg),
      Tone.neutral => (fg: const Color(0xFF545872), bg: const Color(0xFFEEF0F6)),
    };

Tone weekTone(FeeState s) => switch (s) {
      FeeState.paid => Tone.green,
      FeeState.verifying => Tone.blue,
      FeeState.partial => Tone.amber,
      FeeState.due => Tone.red,
      FeeState.running || FeeState.waiting || FeeState.none => Tone.neutral,
    };

Tone payTone(PayStatus s) => switch (s) {
      PayStatus.confirmed => Tone.green,
      PayStatus.verifying || PayStatus.initiated => Tone.blue,
      PayStatus.failed || PayStatus.reversed => Tone.red,
      PayStatus.cancelled => Tone.neutral,
    };

class StatusChip extends StatelessWidget {
  final String label;
  final Tone tone;
  final bool dot;
  const StatusChip(this.label, {super.key, this.tone = Tone.neutral, this.dot = true});
  StatusChip.fee(FeeState s, {super.key})
      : label = s.label,
        tone = weekTone(s),
        dot = true;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot) ...[Container(width: 6, height: 6, decoration: BoxDecoration(color: c.fg, shape: BoxShape.circle)), const SizedBox(width: 6)],
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11, weight: FontWeight.w700, color: c.fg, height: 1.1))),
      ]),
    );
  }
}

/// The child/therapist ID shown next to every name.
class IdBadge extends StatelessWidget {
  final String code;
  final bool light;
  const IdBadge(this.code, {super.key, this.light = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: light ? Colors.white.withValues(alpha: 0.14) : C.sand,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(code, style: body(10.5, weight: FontWeight.w700, color: light ? Colors.white : C.ink.withValues(alpha: 0.72), height: 1.2).copyWith(fontFeatures: tnum, letterSpacing: 0.3)),
      );
}

/// Name followed by its ID badge, ellipsising the name rather than the ID.
class NameWithId extends StatelessWidget {
  final String name, code;
  final TextStyle? style;
  const NameWithId(this.name, this.code, {super.key, this.style});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: style ?? body(15, weight: FontWeight.w600))),
        const SizedBox(width: 7),
        IdBadge(code),
      ]);
}

class TherapyTag extends StatelessWidget {
  final Therapy therapy;
  final String? trailing;
  const TherapyTag(this.therapy, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: therapy.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(7)),
        child: Text(trailing == null ? therapy.name : '${therapy.name} · $trailing', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11.5, weight: FontWeight.w700, color: therapy.color)),
      );
}

/// Avatar colours: the brand navy, orange and sky, and deep companions that sit well beside them.
const _avatarColors = [Color(0xFF161A66), Color(0xFFD9481A), Color(0xFF1F8CC4), Color(0xFF6A3FA0), Color(0xFF0E7C6B), Color(0xFFB0306A), Color(0xFF3B4FB8), Color(0xFFB86A0E)];

Color avatarColor(String name) => _avatarColors[name.codeUnits.fold<int>(0, (a, c) => (a * 31 + c) & 0x7fffffff) % _avatarColors.length];

class Avatar extends StatelessWidget {
  final String name;
  final double size;
  final bool ring;
  const Avatar(this.name, {super.key, this.size = 40, this.ring = false});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(avatarColor(name), Colors.white, 0.14)!, avatarColor(name)]),
          border: ring ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: Text(initials(name), style: body(size * 0.36, weight: FontWeight.w700, color: Colors.white, height: 1)),
      );
}

/// Overlapping avatars, e.g. the therapists running sessions in one slot.
class AvatarStack extends StatelessWidget {
  final List<String> names;
  final double size;
  final int max;
  const AvatarStack(this.names, {super.key, this.size = 26, this.max = 4});

  @override
  Widget build(BuildContext context) {
    final shown = names.take(max).toList();
    final extra = names.length - shown.length;
    final step = size * 0.68;
    final count = shown.length + (extra > 0 ? 1 : 0);
    return SizedBox(
      width: count == 0 ? 0 : step * (count - 1) + size,
      height: size,
      child: Stack(children: [
        for (var i = 0; i < shown.length; i++) Positioned(left: i * step, child: Avatar(shown[i], size: size, ring: true)),
        if (extra > 0)
          Positioned(
            left: shown.length * step,
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: C.sand, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              child: Text('+$extra', style: body(size * 0.36, weight: FontWeight.w700, color: C.muted, height: 1)),
            ),
          ),
      ]),
    );
  }
}

typedef Seg<T> = ({T value, String label, IconData? icon});
Seg<T> seg<T>(T value, String label, [IconData? icon]) => (value: value, label: label, icon: icon);

/// The app's toggle: a track with one raised, selected segment.
class Segmented<T> extends StatelessWidget {
  final T value;
  final List<Seg<T>> options;
  final ValueChanged<T> onChanged;
  final bool expand;

  /// Segment height; passing one above 40 also enlarges the type. The default keeps compact type but is a full
  /// 44px touch target.
  final double? height;
  const Segmented({super.key, required this.value, required this.options, required this.onChanged, this.expand = false, this.height});

  @override
  Widget build(BuildContext context) {
    final h = height ?? 44;
    final big = (height ?? 0) > 40;
    final items = [
      for (final o in options)
        _wrap(
          Semantics(
            button: true,
            selected: o.value == value,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (o.value != value) HapticFeedback.selectionClick();
                onChanged(o.value);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                height: h,
                padding: EdgeInsets.symmetric(horizontal: big ? 18 : 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: o.value == value ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: o.value == value ? const [BoxShadow(color: Color(0x1C010039), blurRadius: 6, offset: Offset(0, 2))] : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (o.icon != null) ...[Icon(o.icon, size: big ? 18 : 15, color: o.value == value ? C.brand800 : C.muted), const SizedBox(width: 6)],
                  Flexible(child: Text(o.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(big ? 14 : 12.5, weight: FontWeight.w600, color: o.value == value ? C.brand800 : C.muted))),
                ]),
              ),
            ),
          ),
        ),
    ];
    final track = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: C.sand, borderRadius: BorderRadius.circular(13)),
      child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, children: items),
    );
    return expand ? track : SingleChildScrollView(scrollDirection: Axis.horizontal, child: track);
  }

  Widget _wrap(Widget w) => expand ? Expanded(child: w) : w;
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? hint;
  final Widget? action;
  const SectionTitle(this.title, {super.key, this.hint, this.action});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: display(19)),
              if (hint != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(hint!, style: body(12.5, color: C.muted))),
            ]),
          ),
          ?action,
        ]),
      );
}

/// Small uppercase label above a group of fields.
class Overline extends StatelessWidget {
  final String text;
  const Overline(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text.toUpperCase(), style: body(11, weight: FontWeight.w800, color: C.muted).copyWith(letterSpacing: 1.1)),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? hint;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.hint, this.action});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20), border: Border.all(color: C.line)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [C.clay50, C.brand50]),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: softShadow,
            ),
            child: Icon(icon, size: 24, color: C.brand700),
          ),
          const SizedBox(height: 14),
          Text(title, style: body(15.5, weight: FontWeight.w700), textAlign: TextAlign.center),
          if (hint != null) Padding(padding: const EdgeInsets.only(top: 5), child: Text(hint!, style: body(13.5, color: C.muted, height: 1.4), textAlign: TextAlign.center)),
          if (action != null) Padding(padding: const EdgeInsets.only(top: 18), child: action),
        ]),
      );
}

class Bar extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final double height;
  const Bar(this.value, {super.key, this.color = C.clay500, this.height = 8});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.clamp(0, 1).toDouble()),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: height, backgroundColor: C.sand, color: color),
        ),
      );
}

/// Selectable chip (therapies, weekdays, payment methods).
class TogglePill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;
  const TogglePill(this.label, {super.key, required this.active, required this.onTap, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? C.brand700;
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          // At least 44px tall: a comfortable touch target. The row centres its content in the extra height.
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: active ? c : Colors.white,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: active ? c : C.line),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (active) ...[const Icon(Icons.check_rounded, size: 15, color: Colors.white), const SizedBox(width: 5)] else if (icon != null) ...[Icon(icon, size: 15, color: C.brand700), const SizedBox(width: 5)],
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13, weight: FontWeight.w600, color: active ? Colors.white : (onTap == null ? C.muted : C.ink)))),
          ]),
        ),
      ),
    );
  }
}

class KV extends StatelessWidget {
  final String label, value;
  final IconData? icon;
  const KV(this.label, this.value, {super.key, this.icon});

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (icon != null) ...[
          Container(width: 34, height: 34, decoration: BoxDecoration(color: C.canvas, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 17, color: C.brand700)),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: body(11.5, weight: FontWeight.w600, color: C.muted)),
            const SizedBox(height: 2),
            Text(value.isEmpty ? '—' : value, style: body(14.5, weight: FontWeight.w600)),
          ]),
        ),
      ]);
}

/// Label + control; [optional] adds a subtle marker.
class Field extends StatelessWidget {
  final String label;
  final String? hint;
  final Widget child;
  final bool optional;
  const Field(this.label, {super.key, required this.child, this.hint, this.optional = false});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(text: label),
            if (optional) TextSpan(text: '  Optional', style: body(11.5, color: C.muted)),
          ]),
          style: body(12.5, weight: FontWeight.w700),
        ),
        const SizedBox(height: 7),
        child,
        if (hint != null) Padding(padding: const EdgeInsets.only(top: 5), child: Text(hint!, style: body(11.5, color: C.muted))),
      ]);
}

/// Tappable field that opens a picker.
class PickerField extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final bool placeholder;
  final String? error;
  const PickerField({super.key, required this.text, required this.icon, required this.onTap, this.placeholder = false, this.error});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: InputDecoration(errorText: error, suffixIcon: Icon(icon, size: 18, color: C.muted), suffixIconConstraints: const BoxConstraints(minWidth: 44)),
          child: Text(text, style: body(15, color: placeholder ? C.muted : C.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
}

class TimeField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const TimeField({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => PickerField(
        text: fmtTime(value),
        icon: Icons.schedule_rounded,
        onTap: () async {
          final m = toMin(value);
          final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60), initialEntryMode: TimePickerEntryMode.dial);
          if (t != null) onChanged(fromMin(t.hour * 60 + t.minute));
        },
      );
}

Future<String?> pickDate(BuildContext context, {String? initial, DateTime? first, DateTime? last, String? help}) async {
  final now = DateTime.now();
  final d = await showDatePicker(
    context: context,
    initialDate: initial == null ? now : parseD(initial),
    firstDate: first ?? DateTime(now.year - 80),
    lastDate: last ?? DateTime(now.year + 2),
    helpText: help,
  );
  return d == null ? null : iso(d);
}

/// Bottom sheet on phones, dialog on wide screens.
Future<T?> showSheet<T>(BuildContext context, {required WidgetBuilder builder, double maxWidth = 560}) {
  if (isWide(context)) {
    return showDialog<T>(
      context: context,
      barrierColor: C.brand900.withValues(alpha: 0.45),
      builder: (c) => Dialog(insetPadding: const EdgeInsets.all(24), clipBehavior: Clip.antiAlias, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 760), child: _SheetToasts(child: builder(c)))),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    clipBehavior: Clip.antiAlias,
    barrierColor: C.brand900.withValues(alpha: 0.45),
    builder: (c) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom), child: _SheetToasts(child: builder(c))),
  );
}

/// Gives a sheet or dialog its own SnackBars. The page's messenger would draw them on the page, under the
/// modal barrier and the sheet, so a failed save inside a sheet went unseen. Here they are drawn in the
/// navigator's overlay just above this route: in the free space above a bottom sheet when there is room for
/// one, otherwise at the foot of the screen, on top of the sheet. The sheet itself is laid out unchanged.
class _SheetToasts extends StatefulWidget {
  final Widget child;
  const _SheetToasts({required this.child});

  @override
  State<_SheetToasts> createState() => _SheetToastsState();
}

class _SheetToastsState extends State<_SheetToasts> {
  final _portal = OverlayPortalController()..show();
  final _box = GlobalKey();

  /// Distance from the bottom of the overlay to the bottom of the SnackBar area.
  double _lift = 0;

  // Called just before a SnackBar shows, and again whenever the sheet changes size (e.g. the failed save that
  // raised it also adds error lines to the form): measure where the sheet sits.
  void _place() {
    if (!mounted) return;
    final box = _box.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    var lift = 0.0;
    if (box != null && overlay != null && box.hasSize && overlay.hasSize) {
      final r = MatrixUtils.transformRect(box.getTransformTo(overlay), Offset.zero & box.size);
      const room = 96.0;
      // A dialog that ends well above the bottom leaves the foot of the screen free; a bottom sheet doesn't, so
      // use the space above it when a SnackBar fits there.
      if (overlay.size.height - r.bottom < room && r.top - MediaQuery.paddingOf(context).top >= room) lift = overlay.size.height - r.top;
    }
    if (lift != _lift) setState(() => _lift = lift);
  }

  void _placeAfterLayout() => WidgetsBinding.instance.addPostFrameCallback((_) => _place());

  @override
  Widget build(BuildContext context) => _SheetMessenger(
        beforeShow: () {
          _place();
          _placeAfterLayout();
        },
        child: OverlayPortal(
          controller: _portal,
          overlayChildBuilder: (c) {
            // Above the sheet nothing sits under the SnackBar: drop the system-bar padding and the keyboard inset.
            final mq = MediaQuery.of(c).removePadding(removeTop: true, removeBottom: _lift > 0).removeViewInsets(removeBottom: _lift > 0);
            return Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: _lift,
              child: _SnackBarsOnly(child: MediaQuery(data: mq, child: const Scaffold(backgroundColor: Colors.transparent, body: SizedBox.shrink()))),
            );
          },
          child: NotificationListener<SizeChangedLayoutNotification>(
            onNotification: (_) {
              _placeAfterLayout();
              return false;
            },
            child: SizeChangedLayoutNotifier(key: _box, child: widget.child),
          ),
        ),
      );
}

class _SnackBarsOnly extends SingleChildRenderObjectWidget {
  const _SnackBarsOnly({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSnackBarsOnly();
}

/// The SnackBar host spans the sheet's whole area but only a SnackBar on it takes taps; everywhere else they
/// reach the sheet or barrier below. The Scaffold's own layers fill the host, so anything hit that is smaller
/// belongs to a SnackBar.
class _RenderSnackBarsOnly extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (child == null || !size.contains(position)) return false;
    final probe = BoxHitTestResult();
    if (!child!.hitTest(probe, position: position)) return false;
    if (!probe.path.any((e) => e.target is RenderBox && (e.target as RenderBox).size != size)) return false;
    return super.hitTest(result, position: position);
  }
}

class _SheetMessenger extends ScaffoldMessenger {
  final VoidCallback beforeShow;
  const _SheetMessenger({required this.beforeShow, required super.child});

  @override
  ScaffoldMessengerState createState() => _SheetMessengerState();
}

/// Shows SnackBars on the sheet's own Scaffold while the sheet is open. Once it is closing (e.g. "Saved" raised
/// right after Navigator.pop, or by a button that captured this messenger) they go to the page's messenger, so
/// they don't vanish with the sheet.
class _SheetMessengerState extends ScaffoldMessengerState {
  ScaffoldMessengerState? _page;
  ModalRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _page = context.findAncestorStateOfType<ScaffoldMessengerState>();
    _route = ModalRoute.of(context);
  }

  ScaffoldMessengerState? get _away => mounted && (_route?.isActive ?? true) ? null : ((_page?.mounted ?? false) ? _page : null);

  @override
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(SnackBar snackBar, {AnimationStyle? snackBarAnimationStyle}) {
    final away = _away;
    if (away != null) return away.showSnackBar(snackBar, snackBarAnimationStyle: snackBarAnimationStyle);
    (widget as _SheetMessenger).beforeShow();
    return super.showSnackBar(snackBar, snackBarAnimationStyle: snackBarAnimationStyle);
  }

  @override
  void hideCurrentSnackBar({SnackBarClosedReason reason = SnackBarClosedReason.hide}) {
    final away = _away;
    away != null ? away.hideCurrentSnackBar(reason: reason) : super.hideCurrentSnackBar(reason: reason);
  }

  @override
  void removeCurrentSnackBar({SnackBarClosedReason reason = SnackBarClosedReason.remove}) {
    final away = _away;
    away != null ? away.removeCurrentSnackBar(reason: reason) : super.removeCurrentSnackBar(reason: reason);
  }
}

class SheetBody extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> footer;
  final Widget? trailing;
  final EdgeInsets padding;
  const SheetBody({super.key, required this.title, this.subtitle, required this.child, this.footer = const [], this.trailing, this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 20)});

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!isWide(context))
          Center(child: Container(margin: const EdgeInsets.only(top: 10), width: 38, height: 4, decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(9)))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: display(22)),
                if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text(subtitle!, style: body(13.5, color: C.muted))),
              ]),
            ),
            ?trailing,
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded), color: C.muted, tooltip: 'Close'),
          ]),
        ),
        const Divider(),
        // Without a footer the list runs to the bottom edge, so keep its last row clear of the system navigation bar.
        Flexible(child: SingleChildScrollView(padding: footer.isEmpty ? padding.copyWith(bottom: padding.bottom + MediaQuery.paddingOf(context).bottom) : padding, child: child)),
        if (footer.isNotEmpty) ...[
          const Divider(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: _Footer(children: footer),
            ),
          ),
        ],
      ]);
}

/// Sheet footer buttons side by side, the primary (last) on the right. Two buttons share the width equally; with
/// more, the last gets a double share. When any label would be cut off (narrow phones, large text) they stack,
/// primary at the bottom.
class _Footer extends MultiChildRenderObjectWidget {
  const _Footer({required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFooter();
}

class _FooterData extends ContainerBoxParentData<RenderBox> {}

class _RenderFooter extends RenderBox with ContainerRenderObjectMixin<RenderBox, _FooterData>, RenderBoxContainerDefaultsMixin<RenderBox, _FooterData> {
  static const gap = 10.0;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FooterData) child.parentData = _FooterData();
  }

  // Each child's share of [width] side by side, or null when one of them wouldn't fit its share.
  List<double>? _row(List<RenderBox> kids, double width) {
    final n = kids.length;
    if (n == 0) return const [];
    if (!width.isFinite) return null;
    final weights = [for (var i = 0; i < n; i++) n > 2 && i == n - 1 ? 2.0 : 1.0];
    final unit = (width - gap * (n - 1)) / weights.fold<double>(0, (a, b) => a + b);
    final shares = [for (final w in weights) w * unit];
    for (var i = 0; i < n; i++) {
      if (kids[i].getMaxIntrinsicWidth(double.infinity) > shares[i] + 0.5) return null;
    }
    return shares;
  }

  Size _layout(BoxConstraints constraints, Size Function(RenderBox, BoxConstraints) lay, {bool place = false}) {
    final kids = getChildrenAsList();
    final width = constraints.maxWidth;
    final shares = _row(kids, width);
    final sizes = [for (var i = 0; i < kids.length; i++) lay(kids[i], BoxConstraints.tightFor(width: shares == null ? width : shares[i]))];
    var height = 0.0;
    if (shares != null) {
      for (final s in sizes) {
        if (s.height > height) height = s.height;
      }
      var x = 0.0;
      for (var i = 0; i < kids.length && place; i++) {
        (kids[i].parentData! as _FooterData).offset = Offset(x, (height - sizes[i].height) / 2);
        x += shares[i] + gap;
      }
    } else {
      for (var i = 0; i < kids.length; i++) {
        if (place) (kids[i].parentData! as _FooterData).offset = Offset(0, height);
        height += sizes[i].height + (i < kids.length - 1 ? gap : 0);
      }
    }
    return constraints.constrain(Size(width, height));
  }

  @override
  void performLayout() => size = _layout(constraints, (c, k) => (c..layout(k, parentUsesSize: true)).size, place: true);

  @override
  Size computeDryLayout(BoxConstraints constraints) => _layout(constraints, (c, k) => c.getDryLayout(k));

  @override
  double computeMinIntrinsicWidth(double height) => getChildrenAsList().fold<double>(0, (a, c) => math.max(a, c.getMinIntrinsicWidth(height)));

  @override
  double computeMaxIntrinsicWidth(double height) {
    final kids = getChildrenAsList();
    return kids.fold<double>(0, (a, c) => a + c.getMaxIntrinsicWidth(height)) + (kids.isEmpty ? 0 : gap * (kids.length - 1));
  }

  @override
  double computeMinIntrinsicHeight(double width) => _layout(BoxConstraints(maxWidth: width), (c, k) => Size(k.maxWidth, c.getMinIntrinsicHeight(k.maxWidth))).height;

  @override
  double computeMaxIntrinsicHeight(double width) => _layout(BoxConstraints(maxWidth: width), (c, k) => Size(k.maxWidth, c.getMaxIntrinsicHeight(k.maxWidth))).height;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
}

/// Told about failures that never reached the server, so the app can switch to its offline mode (set in main).
void Function(Object error)? onNetworkError;

String cleanError(Object e) => switch (e) {
      _ when isNetworkError(e) => "You're offline, so this didn't go through. It will work again once you're connected.",
      PostgrestException x => x.message,
      AuthException x => x.message,
      _ => e.toString().replaceFirst('Exception: ', ''),
    };

void toast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? C.red : null));
}

Future<bool> confirm(BuildContext context, {required String title, required String message, String action = 'Delete', bool danger = true}) async {
  final r = await showDialog<bool>(
    context: context,
    barrierColor: C.brand900.withValues(alpha: 0.45),
    builder: (c) => AlertDialog(
      title: Text(title, style: display(21)),
      content: Text(message, style: body(14.5, color: C.muted, height: 1.45)),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), style: danger ? FilledButton.styleFrom(backgroundColor: C.red) : null, child: Text(action)),
      ],
    ),
  );
  return r ?? false;
}

/// A button that runs an async job, shows progress, and reports failure. Returning a string shows it as a toast.
class ActionButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Future<String?> Function()? onPressed;

  /// filled | outlined | text | danger
  final String kind;
  final bool large;

  /// Overrides the look (e.g. a white button on the dark hero).
  final ButtonStyle? style;
  const ActionButton(this.label, {super.key, this.icon, required this.onPressed, this.kind = 'filled', this.large = false, this.style});

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool busy = false;

  Future<void> _run() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => busy = true);
    try {
      final msg = await widget.onPressed!();
      if (msg != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (isNetworkError(e)) onNetworkError?.call(e);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(cleanError(e)), backgroundColor: C.red));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    // While busy the button keeps its colours (a disabled button turns grey and hides the spinner); taps are ignored.
    final on = widget.onPressed == null ? null : (busy ? _ignore : _run);
    final spinnerColor = widget.style?.foregroundColor?.resolve(const {}) ?? (widget.kind == 'filled' ? Colors.white : C.brand700);
    final child = Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      if (busy)
        Padding(padding: const EdgeInsets.only(right: 9), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: spinnerColor)))
      else if (widget.icon != null)
        Padding(padding: const EdgeInsets.only(right: 8), child: Icon(widget.icon, size: 18)),
      Flexible(child: Text(widget.label, overflow: TextOverflow.ellipsis)),
    ]);
    final big = widget.large ? const Size(0, 54) : null;
    ButtonStyle look(ButtonStyle base) => widget.style == null ? base : widget.style!.merge(base);
    final button = switch (widget.kind) {
      'outlined' => OutlinedButton(onPressed: on, style: look(OutlinedButton.styleFrom(minimumSize: big)), child: child),
      'text' => TextButton(onPressed: on, style: widget.style, child: child),
      'danger' => OutlinedButton(onPressed: on, style: look(OutlinedButton.styleFrom(foregroundColor: C.red, side: const BorderSide(color: Color(0xFFF3C4CB)), minimumSize: big)), child: child),
      _ => FilledButton(onPressed: on, style: look(FilledButton.styleFrom(minimumSize: big)), child: child),
    };
    return Semantics(liveRegion: busy, label: busy ? '${widget.label}, please wait' : null, child: button);
  }

  static void _ignore() {}
}

/// Plain button with an optional leading icon, for synchronous actions (open a sheet, navigate).
Widget btn(String label, {IconData? icon, required VoidCallback? onPressed, String kind = 'outlined'}) {
  final child = Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
    if (icon != null) Padding(padding: const EdgeInsets.only(right: 8), child: Icon(icon, size: 18)),
    Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
  ]);
  return switch (kind) {
    'filled' => FilledButton(onPressed: onPressed, child: child),
    'text' => TextButton(onPressed: onPressed, child: child),
    'soft' => FilledButton(onPressed: onPressed, style: FilledButton.styleFrom(backgroundColor: C.brand50, foregroundColor: C.brand800, disabledBackgroundColor: C.sand), child: child),
    // White on the mark's orange is only 3.7:1; the deeper clay600 reads at AA.
    'accent' => FilledButton(onPressed: onPressed, style: FilledButton.styleFrom(backgroundColor: C.clay600, foregroundColor: Colors.white), child: child),
    _ => OutlinedButton(onPressed: onPressed, child: child),
  };
}

/// Centres content horizontally at [maxContent]. Always as tall as its child: a plain Center would
/// grow to fill a Scaffold's bottom bar and squeeze the page body to nothing.
class Constrained extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const Constrained({super.key, required this.child, this.maxWidth = maxContent});

  @override
  Widget build(BuildContext context) => Center(heightFactor: 1, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child));
}

/// Scrollable page body for the bottom-nav tabs and pushed screens. Long lists pass [itemCount] and
/// [itemBuilder]; those rows follow [children] and are only built when scrolled into view.
/// When a page first opens its top rows ease in one after another; rebuilds and scrolling don't replay it.
class PageList extends StatefulWidget {
  final List<Widget> children;
  final EdgeInsets padding;
  final Future<void> Function()? onRefresh;
  final int itemCount;
  final IndexedWidgetBuilder? itemBuilder;
  const PageList({super.key, required this.children, this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 32), this.onRefresh, this.itemCount = 0, this.itemBuilder});

  @override
  State<PageList> createState() => _PageListState();
}

class _PageListState extends State<PageList> {
  final _opened = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final n = widget.children.length;
    final fresh = DateTime.now().difference(_opened) < const Duration(milliseconds: 600) && !MediaQuery.disableAnimationsOf(context);
    // Leave the last row clear of the system navigation bar and of a floating action button.
    final fab = Scaffold.maybeOf(context)?.hasFloatingActionButton ?? false;
    final list = ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: widget.padding.copyWith(bottom: widget.padding.bottom + MediaQuery.paddingOf(context).bottom + (fab ? 72 : 0)),
      itemCount: n + (widget.itemBuilder == null ? 0 : widget.itemCount),
      itemBuilder: (c, i) {
        final row = Constrained(child: i < n ? widget.children[i] : widget.itemBuilder!(c, i - n));
        return fresh && i < 12 ? Entrance(delay: Duration(milliseconds: 35 * i), child: row) : row;
      },
    );
    return widget.onRefresh == null ? list : RefreshIndicator(color: C.clay500, backgroundColor: Colors.white, onRefresh: widget.onRefresh!, child: list);
  }
}

/// Fades and lifts its child into place once, after [delay].
class Entrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final double offset;
  const Entrance({super.key, required this.child, this.delay = Duration.zero, this.offset = 14});

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  Timer? _wait;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _wait = Timer(widget.delay, _c.forward);
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    _curve.dispose();
    _c.dispose();
    super.dispose();
  }

  late final _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  // Fade and slide are applied by the compositor: nothing under [child] rebuilds while it moves.
  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _curve,
        child: AnimatedBuilder(
          animation: _curve,
          child: widget.child,
          builder: (_, child) => Transform.translate(offset: Offset(0, widget.offset * (1 - _curve.value)), child: child),
        ),
      );
}

/// One row of a list drawn as a single rounded card: corners on the first and last row, hairlines between.
class GroupedRow extends StatelessWidget {
  final int index, count;
  final Widget child;
  final double indent;
  const GroupedRow({super.key, required this.index, required this.count, required this.child, this.indent = 16});

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(20);
    final first = index == 0, last = index == count - 1;
    final radius = BorderRadius.vertical(top: first ? r : Radius.zero, bottom: last ? r : Radius.zero);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border(
          left: const BorderSide(color: C.line),
          right: const BorderSide(color: C.line),
          top: first ? const BorderSide(color: C.line) : BorderSide.none,
          bottom: last ? const BorderSide(color: C.line) : BorderSide.none,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!first) Divider(indent: indent),
          child,
        ]),
      ),
    );
  }
}

/// Large title row used at the top of each tab.
class TabHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const TabHeader(this.title, {super.key, this.subtitle, this.actions = const []});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: display(30, weight: FontWeight.w500)),
              if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(subtitle!, style: body(13.5, color: C.muted))),
            ]),
          ),
          ...actions,
        ]),
      );
}

class SearchField extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const SearchField({super.key, required this.hint, required this.onChanged});

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _c,
        onChanged: (v) {
          setState(() {});
          widget.onChanged(v);
        },
        textInputAction: TextInputAction.search,
        style: body(15),
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: const Icon(Icons.search_rounded, size: 21, color: C.muted),
          prefixIconConstraints: const BoxConstraints(minWidth: 46),
          suffixIcon: _c.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: C.muted,
                  tooltip: 'Clear',
                  onPressed: () {
                    _c.clear();
                    setState(() {});
                    widget.onChanged('');
                  },
                ),
        ),
      );
}

/// 0–100 level marker for a therapy.
class LevelSlider extends StatelessWidget {
  final Therapy therapy;
  final int value;
  final ValueChanged<int> onChanged;
  final ValueChanged<int>? onChangeEnd;
  const LevelSlider({super.key, required this.therapy, required this.value, required this.onChanged, this.onChangeEnd});

  @override
  Widget build(BuildContext context) {
    final c = therapy.color;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: c.withValues(alpha: 0.16))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text('Current ${therapy.name.toLowerCase()} level', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13.5, weight: FontWeight.w600))),
          Text('$value', style: display(20, color: c).copyWith(fontFeatures: tnum)),
          Text(' /100', style: body(11.5, color: C.muted)),
        ]),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(activeTrackColor: c, thumbColor: c, inactiveTrackColor: c.withValues(alpha: 0.14), overlayColor: c.withValues(alpha: 0.12), trackHeight: 6),
          child: Slider(
            value: value.toDouble(),
            max: 100,
            divisions: 100,
            label: '$value',
            onChanged: (v) => onChanged(v.round()),
            onChangeEnd: onChangeEnd == null ? null : (v) => onChangeEnd!(v.round()),
          ),
        ),
      ]),
    );
  }
}

/// Tinted square icon used in list tiles and cards.
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconTile(this.icon, {super.key, this.color = C.brand700, this.size = 42});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(size * 0.3)),
        child: Icon(icon, size: size * 0.48, color: color),
      );
}

/// Numeric money input with a ₹ prefix.
class MoneyField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String? error;
  final bool autofocus;
  const MoneyField({super.key, required this.controller, this.onChanged, this.error, this.autofocus = false});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        onChanged: onChanged,
        autofocus: autofocus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,8}(\.\d{0,2})?'))],
        style: body(15, weight: FontWeight.w600).copyWith(fontFeatures: tnum),
        decoration: InputDecoration(
          errorText: error,
          prefixIcon: Padding(padding: const EdgeInsets.only(left: 14, right: 6), child: Text('₹', style: body(16, weight: FontWeight.w700, color: C.muted))),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          hintText: '0',
        ),
      );
}

double? parseMoney(String s) => double.tryParse(s.trim());

/// Builds [builder] a few frames after it first appears, showing an empty box of [height] meanwhile.
/// Splits a heavy screen section across frames so scrolling it into view never stalls a single frame.
class Deferred extends StatefulWidget {
  final WidgetBuilder builder;
  final int frames;
  final double height;
  const Deferred({super.key, required this.builder, this.frames = 1, this.height = 120});

  @override
  State<Deferred> createState() => _DeferredState();
}

class _DeferredState extends State<Deferred> {
  late int _wait = widget.frames;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() {
    if (_wait <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _wait--);
      _tick();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  Widget build(BuildContext context) => _wait > 0 ? SizedBox(height: widget.height) : widget.builder(context);
}
