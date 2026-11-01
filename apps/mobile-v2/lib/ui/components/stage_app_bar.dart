/// The S2–S5 stage app bar: close, 4 dp stage track, `N / 4` counter
/// (`.appbar--progress` app.css L968-1006, design-spec §5.3).
///
/// One widget for all four step screens so the 50 dp height, the 44 dp close
/// target and the counter's tabular figures can never drift between them.
/// The screen passes copy; the bar owns geometry.
library;

import 'package:flutter/material.dart';

import '../app_icon.dart';
import 'stage_progress.dart';

class StageAppBar extends StatelessWidget {
  const StageAppBar({
    super.key,
    required this.step,
    this.total = 4,
    required this.onClose,
    this.closeLabel,
    this.progressLabel,
    this.onPreviousStep,
    this.onNextStep,
    this.previousLabel,
    this.nextLabel,
  });

  /// Step the screen belongs to, `1..total` — S3 passes `2`.
  final int step;

  /// Stage count of the chapter loop; the design fixes four.
  final int total;

  /// Leaves the step (usually `Navigator.maybePop`); returns to the stage
  /// before this one.
  final VoidCallback onClose;

  /// Screen-reader / tooltip label of the close control.
  final String? closeLabel;

  /// Localised sentence for the progress bar, e.g. "Words · step 2 of 4".
  final String? progressLabel;

  /// Navigate to the previous step (practice mode).
  final VoidCallback? onPreviousStep;

  /// Navigate to the next step (practice mode).
  final VoidCallback? onNextStep;

  /// Tooltip for the previous-step arrow.
  final String? previousLabel;

  /// Tooltip for the next-step arrow.
  final String? nextLabel;

  /// `.appbar--progress { min-height: 50px; gap: 12px; padding: 2px 18px 0 8px }`.
  static const double minHeight = 50;
  static const double gap = 12;

  /// `.icon-btn svg { width: 22px }` (app.css L777).
  static const double iconSize = 22;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 2, 18, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight),
        child: Row(
          children: <Widget>[
            IconButton(
              key: const Key('stage-close'),
              onPressed: onClose,
              tooltip: closeLabel,
              icon: const AppIcon('close', size: iconSize),
            ),
            const SizedBox(width: gap),
            // Previous-step arrow (practice mode).
            if (onPreviousStep != null)
              IconButton(
                key: const Key('stage-prev'),
                onPressed: step > 1 ? onPreviousStep : null,
                tooltip: previousLabel,
                icon: AppIcon(
                  'chevron-left',
                  size: iconSize,
                  color: step > 1 ? null : Colors.grey,
                ),
              ),
            // [StageProgress] already ends in the `N / 4` counter (min-width
            // 38, tabular), so the bar must not draw a second one.
            Expanded(
              child: StageProgress(
                key: const Key('stage-progress'),
                step: step,
                total: total,
                semanticLabel: progressLabel,
              ),
            ),
            // Next-step arrow (practice mode).
            if (onNextStep != null)
              IconButton(
                key: const Key('stage-next'),
                onPressed: step < total ? onNextStep : null,
                tooltip: nextLabel,
                icon: AppIcon(
                  'chevron-right',
                  size: iconSize,
                  color: step < total ? null : Colors.grey,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
