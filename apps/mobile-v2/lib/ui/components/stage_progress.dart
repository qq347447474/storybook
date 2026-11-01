/// The four-step stage progress bar of S2–S5 (design-spec §5.3).
///
/// A 4 dp full-radius track with a brand fill and a tabular `1 / 4` counter on
/// the right. Geometry and timing come from the hand-off:
/// `.top-progress` (app.css L980-999) and `.step-count` (app.css L1000-1006).
library;

import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Track + counter for "step N of 4".
///
/// [step] is the number of *completed* stages, so `step: 2` renders a half
/// fill. The widget owns no copy: the counter is derived from [step] and
/// [total], and the screen-reader sentence is passed in as [semanticLabel]
/// (design-spec §6.5 — `1 / 4` alone is not speakable in every locale).
class StageProgress extends StatelessWidget {
  const StageProgress({
    super.key,
    required this.step,
    this.total = 4,
    this.semanticLabel,
  })  : assert(total > 0, 'StageProgress: total must be positive'),
        assert(
          step >= 0 && step <= total,
          'StageProgress: step must lie within 0..total',
        );

  /// Completed stages, `0..total`.
  final int step;

  /// Stage count of the chapter flow. The design fixes four.
  final int total;

  /// Localised sentence for the screen reader, e.g. "Step 2 of 4".
  final String? semanticLabel;

  /// `.top-progress { height: 4px }` (app.css L982).
  static const double trackHeight = 4;

  /// `.top-progress > i { transition: width 380ms }` (app.css L992).
  static const Duration motion = Duration(milliseconds: 380);

  /// `--ease-out: cubic-bezier(.22, .9, .26, 1)` (app.css L89).
  static const Curve curve = Cubic(0.22, 0.9, 0.26, 1);

  /// `.step-count { min-width: 38px }` (app.css L1002).
  static const double _counterMinWidth = 38;

  /// Gap between track and counter; the hand-off pins 10 dp in the S2 header.
  static const double _gap = 10;

  @override
  Widget build(BuildContext context) {
    final double progress = step / total;
    final bool reducedMotion = MediaQuery.disableAnimationsOf(context);

    final Widget track = SizedBox(
      height: trackHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(trackHeight / 2),
        child: ColoredBox(
          color: AppColors.progressTrack,
          child: TweenAnimationBuilder<double>(
            // `begin == end` on the first frame: the bar appears already at its
            // value and only animates when the step advances. An entry sweep
            // from 0 would read as "loading" instead of "progress".
            tween: Tween<double>(begin: progress, end: progress),
            duration: reducedMotion ? Duration.zero : motion,
            curve: curve,
            builder: (BuildContext context, double value, Widget? bar) {
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: value,
                    child: bar,
                  ),
                ],
              );
            },
            child: const ColoredBox(color: AppColors.primary),
          ),
        ),
      ),
    );

    Widget row = Row(
      children: <Widget>[
        Expanded(child: track),
        const SizedBox(width: _gap),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: _counterMinWidth),
          child: Text(
            '$step / $total',
            // `.step-count`: 600 weight, ink-3, tabular figures.
            style: AppTypography.tabular(
              AppTypography.meta.copyWith(
                color: AppColors.ink3,
                fontWeight: FontWeight.w600,
              ),
            ),
            textAlign: TextAlign.right,
            softWrap: false,
          ),
        ),
      ],
    );

    if (semanticLabel != null) {
      row = Semantics(
        container: true,
        label: semanticLabel,
        child: ExcludeSemantics(child: row),
      );
    }
    return row;
  }
}
