/// Transient toast: the dark pill of design-spec §5.10 (`.toast`
/// app.css L1071-1092, prototype L3681).
///
/// Used for short, non-critical confirmations only — "recorded too short",
/// "replaying", a permission note. Anything the learner must act on belongs in
/// [InlineBar] instead, because a toast is gone in 2.4 s.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// The toast surface itself: ink at 94 %, paper text, 14 dp radius.
///
/// Standalone and const so it can be previewed or embedded; the overlay helper
/// [showAppToast] wraps it in the positioned, fading layer.
class AppToast extends StatelessWidget {
  const AppToast(this.message, {super.key});

  /// Text to show. Caller-localised, one short line.
  final String message;

  /// 2.4 s — `.toast` plus the 240 ms fade of `--dur-base` (app.css L1088).
  static const Duration defaultDuration = Duration(milliseconds: 2400);

  /// `.toast { bottom: calc(var(--gesture-inset) + 210px) }` (app.css L1073):
  /// 210 dp above the gesture inset keeps the dock CTA and the record button
  /// clear.
  static const double defaultBottomOffset = 210;

  /// `.toast { padding: 10px 16px; border-radius: 14px }`.
  static const EdgeInsets _padding = EdgeInsets.symmetric(horizontal: 16, vertical: 10);
  static const double _radius = 14;

  /// `.toast { max-width: min(300px, 100% - 40px) }` (app.css L1075).
  static const double maxWidth = 300;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // Announced without stealing focus; the pill is not a control.
      liveRegion: true,
      container: true,
      child: Container(
        padding: _padding,
        decoration: BoxDecoration(
          color: AppColors.toastScrim,
          borderRadius: BorderRadius.circular(_radius),
          // app.css L1085 draws a black float shadow; the system tints its
          // shadows with `--ink` (design-spec §2.5), so the toast follows.
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.28),
              blurRadius: 30,
              spreadRadius: -12,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          // `.toast`: 12 / 500 / 1.45 paper text — Meta is the same slot.
          style: AppTypography.meta.copyWith(color: AppColors.paper),
        ),
      ),
    );
  }
}

/// Shows [message] over the nearest overlay and removes it after [duration].
///
/// Calling again replaces the previous toast instead of stacking: the old
/// entry is removed first, which disposes its timer with it. The entry is
/// removed after the fade-out completes, so a toast never pops out of
/// existence.
void showAppToast(
  BuildContext context,
  String message, {
  Duration duration = AppToast.defaultDuration,
  double bottomOffset = AppToast.defaultBottomOffset,
}) {
  final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    // No overlay (unit-test host or a bare widget tree): a toast is optional
    // chrome, so failing here would be worse than losing the hint.
    assert(
      false,
      'showAppToast: no Overlay above this context — wrap the app in a '
      'MaterialApp or Navigator before showing a toast.',
    );
    return;
  }

  _ToastSession.dismiss();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (BuildContext overlayContext) => _ToastLayer(
      message: message,
      duration: duration,
      bottomOffset: bottomOffset,
      onDismissed: () {
        if (identical(_ToastSession.entry, entry)) {
          _ToastSession.entry = null;
        }
        if (entry.mounted) {
          entry.remove();
        }
      },
    ),
  );
  _ToastSession.entry = entry;
  overlay.insert(entry);
}

/// Removes the live toast at once, without a fade.
///
/// Call this when the screen changes: design-spec §5.10 requires a toast to
/// disappear on navigation, and the overlay entry outlives the screen that
/// showed it.
void hideAppToast() => _ToastSession.dismiss();

/// Tracks the one live toast so a second call can replace it.
class _ToastSession {
  const _ToastSession._();

  static OverlayEntry? entry;

  /// Removes the live toast immediately (no fade) — used when a new message
  /// supersedes it.
  static void dismiss() {
    final OverlayEntry? current = entry;
    entry = null;
    if (current != null && current.mounted) {
      current.remove();
    }
  }
}

/// Positioned, fading toast body; owns the auto-hide timer and the animation.
class _ToastLayer extends StatefulWidget {
  const _ToastLayer({
    required this.message,
    required this.duration,
    required this.bottomOffset,
    required this.onDismissed,
  });

  final String message;
  final Duration duration;
  final double bottomOffset;
  final VoidCallback onDismissed;

  @override
  State<_ToastLayer> createState() => _ToastLayerState();
}

class _ToastLayerState extends State<_ToastLayer> with SingleTickerProviderStateMixin {
  /// `--dur-base: 240ms` with `--ease-out` (app.css L1087-1088).
  static const Duration _motion = Duration(milliseconds: 240);
  static const Curve _curve = Cubic(0.22, 0.9, 0.26, 1);

  /// `transform: translate(-50%, 8px)` (app.css L1083) — 8 dp of a ~40 dp pill.
  static const double _riseFraction = 0.2;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _motion,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.duration, _hide);
  }

  Future<void> _hide() async {
    if (!mounted) return;
    await _controller.reverse();
    if (!mounted) return;
    widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double safeBottom = MediaQuery.paddingOf(context).bottom;
    // Reduced motion keeps the fade (it is a state change, not decoration) but
    // drops the rise, so the pill does not travel across the page.
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    final Animation<double> opacity = CurvedAnimation(
      parent: _controller,
      curve: reduced ? Curves.linear : _curve,
    );
    final Animation<Offset> offset = Tween<Offset>(
      begin: Offset(0, reduced ? 0 : _riseFraction),
      end: Offset.zero,
    ).animate(opacity);

    return Positioned(
      left: 20,
      right: 20,
      bottom: safeBottom + widget.bottomOffset,
      child: IgnorePointer(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppToast.maxWidth),
            child: SlideTransition(
              position: offset,
              child: FadeTransition(
                opacity: opacity,
                child: AppToast(widget.message),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
