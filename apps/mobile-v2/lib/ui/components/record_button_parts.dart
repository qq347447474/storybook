/// The paints and the skin behind [RecordButton]: the 74 dp key, the pulse ring
/// and the four arc layers (outline, countdown, recognition progress, focus).
///
/// Parts of `record_button.dart` on purpose — they share one centre, one set of
/// radii and one palette, and nothing outside the key needs them.
///
/// Deviation from the hand-off, deliberate: `.record-ring circle` is stroked
/// white at 92 % (app.css L2943), but the ring sits *outside* the red key, over
/// warm paper — white on `#F6F0E3` measures ≈1.1:1, under the 3:1 that
/// design-spec §7.1 asks of a non-text graphic. The arc is painted in
/// `recordRed` instead (3.6:1 on paper) and the limb it consumes keeps the 30 %
/// red wash of `.is-recording::after`.
part of 'record_button.dart';

/// The key itself: a 74 dp circle that turns red, then ink, then warm grey.
class _RecordKey extends StatelessWidget {
  const _RecordKey({
    required this.state,
    required this.pressed,
    required this.reducedMotion,
    required this.onPressStart,
    required this.onPressEnd,
  });

  final RecordState state;
  final bool pressed;
  final bool reducedMotion;
  final VoidCallback? onPressStart;
  final VoidCallback? onPressEnd;

  /// `.record-btn svg.mic-icon { width: 27px }` (app.css L2918).
  static const double _micSize = 27;

  /// The icon set has no `stop` square, so the listening face shows `pause`:
  /// two upright bars read as "stop the take" without an invented glyph
  /// (design-spec §2.7 — icons come from the shipped set or not at all).
  static const double _stopSize = AppIconSize.lg;

  @override
  Widget build(BuildContext context) {
    final bool recording = state == RecordState.recording;
    final Duration motion = reducedMotion ? Duration.zero : RecordButton.motion;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: onPressStart == null ? null : (TapDownDetails _) => onPressStart!(),
      onTapUp: onPressEnd == null ? null : (TapUpDetails _) => onPressEnd!(),
      onTapCancel: onPressEnd,
      child: AnimatedScale(
        // `.record-btn:active { transform: scale(.96) }` (app.css L2914);
        // `.is-recording { transform: scale(1.03) }` (L2954).
        scale: pressed ? 0.96 : (recording && !reducedMotion ? 1.03 : 1),
        duration: motion,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          width: RecordButton.size,
          height: RecordButton.size,
          duration: motion,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _fill,
            shape: BoxShape.circle,
            boxShadow: _shadows,
          ),
          child: Center(
            child: AppIcon(
              recording ? 'pause' : 'mic',
              size: recording ? _stopSize : _micSize,
              color: AppColors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Color get _fill => switch (state) {
        RecordState.idle =>
          pressed ? AppColors.primaryStrong : AppColors.primary,
        RecordState.recording => AppColors.recordRed,
        RecordState.processing => AppColors.ink2,
        RecordState.disabled => AppColors.recordDisabled,
      };

  /// Key shadows, straight from the hand-off: a brand-tinted glow at rest and a
  /// wider red-brown one while listening (app.css L2901 / L2952). Both are
  /// tinted with their own fill, never with black, so the paper page keeps its
  /// warmth (design-spec §2.5).
  List<BoxShadow> get _shadows => switch (state) {
        RecordState.idle => <BoxShadow>[
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.65),
              offset: const Offset(0, 12),
              blurRadius: 26,
              spreadRadius: -10,
            ),
          ],
        RecordState.recording => <BoxShadow>[
            BoxShadow(
              color: AppColors.recordRed.withValues(alpha: 0.1),
              spreadRadius: 10,
            ),
            BoxShadow(
              color: AppColors.recordRed.withValues(alpha: 0.6),
              offset: const Offset(0, 12),
              blurRadius: 28,
              spreadRadius: -12,
            ),
          ],
        RecordState.processing || RecordState.disabled => const <BoxShadow>[],
      };
}

/// `rec-pulse` (app.css L2982): the ring breathes out to 130 % and fades.
class _PulseRing extends StatelessWidget {
  const _PulseRing({super.key, required this.pulse});

  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ScaleTransition(
        scale: Tween<double>(begin: 1, end: RecordButton.pulseScale)
            .animate(CurvedAnimation(parent: pulse, curve: Curves.easeOut)),
        child: FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0).animate(pulse),
          child: SizedBox.square(
            dimension: RecordButton.canvasSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // `.is-recording::after { border-color: rgba(200,80,60,.3) }`
                // (app.css L2958) — the key's own red at 30 %.
                border: Border.fromBorderSide(
                  BorderSide(
                    color: AppColors.recordRed.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Outline ring, countdown arc, recognition progress and focus ring.
class _RecordRingPainter extends CustomPainter {
  const _RecordRingPainter({
    required this.state,
    required this.fraction,
    required this.focused,
    required this.processingProgress,
  });

  /// Which face of the key is up — decides whether a ring exists at all.
  final RecordState state;

  /// `heldSeconds / maxSeconds`, already clamped to `0..1`.
  final double fraction;

  /// Keyboard focus is on the key (design-spec §7.3 focus ring).
  final bool focused;

  /// Determinate recognition progress, `0..1`, or null for no arc.
  final double? processingProgress;

  /// `border: 1.5px` on both rings (app.css L2924 / L2958).
  static const double _stroke = 1.5;

  /// `outline: 3px` (design-spec §7.3).
  static const double _focusStroke = 3;

  /// `outline-offset: 2px`, so the ring sits 2 dp outside the 74 dp key.
  static const double _focusRadius =
      RecordButton.size / 2 + 2 + _focusStroke / 2;

  /// Recognition arc just inside the key edge.
  static const double _progressRadius = RecordButton.size / 2 - 5;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final Offset centre = size.center(Offset.zero);
    final double outer = size.shortestSide / 2 - _stroke / 2;

    switch (state) {
      case RecordState.recording:
        // The limb the take has left, then the part it already used
        // (design-spec §5.7 "倒计时环从 0 到 360°").
        _arc(canvas, centre, outer, AppColors.recordRed.withValues(alpha: 0.3));
        if (fraction > 0) {
          _arc(
            canvas,
            centre,
            outer,
            AppColors.recordRed,
            sweep: 2 * math.pi * fraction,
          );
        }
      case RecordState.idle:
      case RecordState.processing:
        // `.record-btn::after { border: 1.5px solid rgba(91,75,214,.18) }`.
        _arc(canvas, centre, outer, AppColors.primary.withValues(alpha: 0.18));
      case RecordState.disabled:
        // `.record-btn:disabled::after { border-color: transparent }` — a
        // disabled key carries no halo at all (design-spec §5.7).
        break;
    }

    final double? progress = processingProgress;
    if (state == RecordState.processing && progress != null) {
      _arc(
        canvas,
        centre,
        _progressRadius,
        AppColors.onPrimary.withValues(alpha: 0.28),
        stroke: 2,
      );
      if (progress > 0) {
        _arc(
          canvas,
          centre,
          _progressRadius,
          AppColors.onPrimary,
          sweep: 2 * math.pi * progress,
          stroke: 2,
        );
      }
    }

    if (focused) {
      _arc(
        canvas,
        centre,
        _focusRadius,
        AppColors.focus,
        stroke: _focusStroke,
      );
    }
  }

  /// One clockwise arc from 12 o'clock; a full turn when [sweep] is omitted.
  void _arc(
    Canvas canvas,
    Offset centre,
    double radius,
    Color color, {
    double? sweep,
    double stroke = _stroke,
  }) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2,
      sweep ?? 2 * math.pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RecordRingPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.fraction != fraction ||
        oldDelegate.focused != focused ||
        oldDelegate.processingProgress != processingProgress;
  }
}
