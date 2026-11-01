/// The falling paper of S6: twelve pieces, one shot, no loop
/// (`.confetti` / `@keyframes confetti-fall`, `visual/app.css` L3178-3210).
///
/// Split out of the scene so the scene file stays a readable list of layers and
/// so the painter — the only place in S6 that does frame maths — is testable on
/// its own.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The falling paper. One shot: 2.4 s after entering, every piece has faded out
/// and the controller parks — nothing loops and nothing blocks input
/// (design-spec §4.7 状态 "庆祝动画 2.4s 后自动结束，不阻塞操作").
class ConfettiLayer extends StatefulWidget {
  const ConfettiLayer({super.key});

  /// Total run of the celebration (§4.7). The last piece starts at 240 ms and
  /// falls for 1350 ms, so 2.4 s covers the whole sheet.
  static const Duration runTime = Duration(milliseconds: 2400);

  /// `.confetti i { animation: confetti-fall 1.35s }` (app.css L3197).
  static const Duration fallTime = Duration(milliseconds: 1350);

  @override
  State<ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<ConfettiLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ConfettiLayer.runTime,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? _) => CustomPaint(
          painter: ConfettiPainter(progress: _controller.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// One piece of paper: start column, size, delay, spin and colour.
class ConfettiPiece {
  const ConfettiPiece({
    required this.x,
    required this.width,
    required this.height,
    required this.delay,
    required this.spin,
    required this.color,
  });

  /// Horizontal position as a fraction of the scene width (`--x`).
  final double x;
  final double width;
  final double height;

  /// `--delay`: when this piece leaves the top edge.
  final Duration delay;

  /// `--rot`: degrees turned by the time it leaves the frame.
  final double spin;

  /// `--c` — a palette token, never a literal.
  final Color color;
}

/// Paints the twelve pieces for a given 0…1 celebration progress.
///
/// Stateless and deterministic: the sheet is a `const` table, so a rebuild
/// mid-flight reproduces exactly the same frame and the widget test can pin the
/// piece count without inspecting animation internals.
class ConfettiPainter extends CustomPainter {
  const ConfettiPainter({required this.progress});

  /// 0 → nothing has started, 1 → the sheet has landed and faded out.
  final double progress;

  /// `top: 6%` start line and the `translateY(168px)` travel of the keyframes.
  static const double startFraction = 0.06;
  static const double travel = 168;
  static const double _lead = -6;

  /// `border-radius: 2px` on every piece.
  static const double cornerRadius = 2;

  /// The twelve pieces of the hand-off, in its order (app.css/prototype S6).
  static const List<ConfettiPiece> pieces = <ConfettiPiece>[
    ConfettiPiece(x: 0.08, width: 6, height: 10, delay: Duration(milliseconds: 20), spin: 200, color: AppColors.primary),
    ConfettiPiece(x: 0.18, width: 5, height: 8, delay: Duration(milliseconds: 100), spin: 260, color: AppColors.accent),
    ConfettiPiece(x: 0.28, width: 6, height: 10, delay: Duration(milliseconds: 40), spin: 180, color: AppColors.tealInk),
    ConfettiPiece(x: 0.38, width: 4, height: 7, delay: Duration(milliseconds: 160), spin: 220, color: AppColors.recordRed),
    ConfettiPiece(x: 0.47, width: 6, height: 10, delay: Duration(milliseconds: 80), spin: 300, color: AppColors.accent),
    ConfettiPiece(x: 0.56, width: 7, height: 7, delay: Duration(milliseconds: 200), spin: 240, color: AppColors.primary),
    ConfettiPiece(x: 0.65, width: 6, height: 10, delay: Duration(milliseconds: 60), spin: 190, color: AppColors.tealInk),
    ConfettiPiece(x: 0.74, width: 5, height: 9, delay: Duration(milliseconds: 140), spin: 230, color: AppColors.recordRed),
    ConfettiPiece(x: 0.84, width: 6, height: 10, delay: Duration(milliseconds: 30), spin: 210, color: AppColors.accent),
    ConfettiPiece(x: 0.92, width: 4, height: 7, delay: Duration(milliseconds: 120), spin: 250, color: AppColors.primary),
    ConfettiPiece(x: 0.13, width: 4, height: 6, delay: Duration(milliseconds: 220), spin: 280, color: AppColors.recordRed),
    ConfettiPiece(x: 0.70, width: 4, height: 6, delay: Duration(milliseconds: 240), spin: 200, color: AppColors.tealInk),
  ];

  /// Per-piece flight progress, `0..1` (the keyframes' 0 %→100 %).
  static double _local(double progress, ConfettiPiece piece) {
    final double elapsedMs =
        progress * ConfettiLayer.runTime.inMilliseconds;
    return (elapsedMs - piece.delay.inMilliseconds) /
        ConfettiLayer.fallTime.inMilliseconds;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || progress <= 0 || progress >= 1) return;
    final double top = size.height * startFraction;
    final Paint paint = Paint()..style = PaintingStyle.fill;

    for (final ConfettiPiece piece in pieces) {
      final double t = _local(progress, piece);
      if (t <= 0 || t >= 1) continue;

      // `@keyframes confetti-fall`: fade in over the first 12 %, then out.
      final double opacity =
          t < 0.12 ? t / 0.12 : 1 - (t - 0.12) / 0.88;
      if (opacity <= 0) continue;

      final double dy = _lead + t * (travel - _lead);
      paint.color = piece.color.withValues(alpha: opacity.clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(size.width * piece.x, top + dy);
      canvas.rotate(t * piece.spin * math.pi / 180);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: piece.width,
            height: piece.height,
          ),
          const Radius.circular(cornerRadius),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
