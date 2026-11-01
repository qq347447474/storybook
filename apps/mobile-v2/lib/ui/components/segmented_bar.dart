/// Segmented progress bar (`.segmented`, `visual/app.css` L1232-1250).
///
/// One rounded segment per countable unit — S0 uses it for the two chapters
/// of a book (`reading progress 1 / 2`), S1 reuses the same widget with four
/// segments for the four stages. Decorative by construction: the numbers next
/// to it carry the meaning (`aria-hidden="true"` in the hand-off), so the bar
/// stays out of the semantics tree and design-spec §7.2 (never colour-only)
/// is satisfied by the adjacent count.
library;

import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';

/// A row of [total] equal segments, the first [filled] of them brand-filled.
class SegmentedBar extends StatelessWidget {
  const SegmentedBar({
    super.key,
    required this.total,
    required this.filled,
    this.height = 6,
    this.gap = 3,
  });

  /// Number of segments. `<= 0` renders nothing (a book with no chapters
  /// must not draw an empty frame).
  final int total;

  /// How many leading segments are complete. Clamped into `0..total`, so a
  /// progress read that overshoots can never paint past the bar.
  final int filled;

  /// Segment thickness. 6 dp is the S0 reading step; the hand-off draws the
  /// same bar at 4 dp inside S1 rows.
  final double height;

  /// Gap between segments (`.segmented { gap: 4px }`, tightened to 3 dp so a
  /// 320 dp content column divides evenly on the 4 pt grid).
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (total <= 0 || height <= 0) return const SizedBox.shrink();
    final int done = filled.clamp(0, total);
    // Pill ends: half the thickness, which keeps one rule for both heights.
    final BorderRadius radius = BorderRadius.circular(height / 2);

    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: Row(
          // Stretch is load-bearing: a childless [DecoratedBox] collapses to
          // zero height under the Row's default loose cross-axis constraint.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < total; i++) ...<Widget>[
              if (i > 0) SizedBox(width: gap),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    // Filled segments are the brand; the track is the
                    // sunken surface token, so the bar reads on paper and
                    // on a card alike.
                    color: i < done ? AppColors.primary : AppColors.surfaceSunken,
                    borderRadius: radius,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
