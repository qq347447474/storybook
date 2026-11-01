/// Generic 3D flip container (design-spec §5.6, `.flip-card` / `.flip-face`
/// app.css L1962-2004).
///
/// Controlled and content-agnostic: the surface passes [revealed] and reacts to
/// [onToggle]; the two faces are arbitrary widgets. `word_card.dart` is the S3
/// content layer on top of this.
///
/// The flip is a single `rotateY` on a perspective matrix, and the visible face
/// is swapped at 90°, so the back is never read upside-down: it is counter-
/// rotated by π. Only `transform` changes per frame, which keeps the animation
/// on the compositor — no layout, no paint of the faces' contents.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A fixed-height card that flips between [front] and [back].
class FlipCard extends StatefulWidget {
  const FlipCard({
    super.key,
    required this.revealed,
    required this.front,
    required this.back,
    this.onToggle,
    this.height = 280,
    this.duration = const Duration(milliseconds: 320),
    this.borderRadius = 20,
  }) : assert(height > 0, 'FlipCard: height must be positive.');

  /// Which face is shown. Owned by the caller — tapping only reports intent.
  final bool revealed;

  /// Face shown while `revealed == false`.
  final Widget front;

  /// Face shown while `revealed == true`.
  final Widget back;

  /// Tap callback. `null` makes the card inert but still announceable.
  final VoidCallback? onToggle;

  /// Card height. A flip card has a fixed footprint by design, so the content
  /// of both faces has to fit (or scroll internally).
  final double height;

  /// `.flip-card { transition: transform var(--dur-slow) }` — 320 ms.
  final Duration duration;

  /// Corner radius used to clip both faces.
  final double borderRadius;

  /// Perspective strength of the 3D projection. `1 / 1400` mirrors the CSS
  /// `perspective: 1400px` of `.vocab-stage` (app.css L1959); a little steeper
  /// because a phone screen is narrower than the reference stage.
  static const double perspective = 0.0012;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.revealed ? 1 : 0,
  );

  bool _reducedMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(covariant FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revealed == widget.revealed &&
        oldWidget.duration == widget.duration) {
      return;
    }
    // Reduced motion (§5.6 "减少动效时直接切换") collapses the tween to zero
    // length instead of skipping the code path, so the face still changes.
    final Duration length = _reducedMotion ? Duration.zero : widget.duration;
    _controller.duration = length;
    final double target = widget.revealed ? 1 : 0;
    if (_controller.value == target) return;
    _controller.animateTo(target, duration: length, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _face(Widget child) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      clipBehavior: Clip.antiAlias,
      child: SizedBox.expand(child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: widget.revealed,
      onTap: widget.onToggle,
      child: GestureDetector(
        onTap: widget.onToggle,
        // Opaque so the whole card is a target, including its padding.
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: widget.height,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? _) {
              final double angle = _controller.value * math.pi;
              // Swap at the halfway point: past 90° the front is edge-on.
              final bool showingBack = _controller.value >= 0.5;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, FlipCard.perspective)
                  ..rotateY(angle),
                child: showingBack
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(math.pi),
                        child: _face(widget.back),
                      )
                    : _face(widget.front),
              );
            },
          ),
        ),
      ),
    );
  }
}
