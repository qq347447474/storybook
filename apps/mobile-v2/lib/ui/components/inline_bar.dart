/// The inline notice bar of S5 (design-spec §5.8, `.inline-bar` app.css
/// L2741-2777).
///
/// Sits above the record button inside the dock, so it must stay short: one
/// icon, one or two lines of copy and, at most, one 30 dp action. Used for
/// "microphone denied" and "speech model off" — both states where the step
/// degrades rather than stops, which is why the copy comes from the caller.
library;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../app_icon.dart';

/// Amber notice with an optional inline action.
class InlineBar extends StatelessWidget {
  const InlineBar({
    super.key,
    required this.message,
    this.icon = 'alert',
    this.actionLabel,
    this.onAction,
  }) : assert(
          onAction == null || actionLabel != null,
          'InlineBar: a tappable action needs a label.',
        );

  /// Notice copy, localised by the caller.
  final String message;

  /// 17 dp leading glyph: `mic-off`, `info`, `alert`…
  final String icon;

  /// Action label; omitted when the bar is purely informational.
  final String? actionLabel;

  /// Action callback. `null` renders the label as a disabled pill.
  final VoidCallback? onAction;

  /// `.inline-bar { padding: 11px 12px; border-radius: 14px }` (app.css L2746).
  static const EdgeInsets _padding = EdgeInsets.symmetric(horizontal: 12, vertical: 11);
  static const double _radius = 14;

  /// `.inline-bar > svg { 17px }` (app.css L2755).
  static const double _iconSize = 17;
  static const double _iconGap = 9;

  /// `.inline-action { height: 30px; margin-top: 7px }` (app.css L2767-2772).
  static const double _actionHeight = 30;
  static const double _actionGap = 7;

  @override
  Widget build(BuildContext context) {
    // Every inline bar in the flow is a warning-toned notice; there is no
    // information-only variant in the hand-off (§5.8).
    const Tone tone = AppTones.warning;
    final TextStyle label = AppTypography.label.copyWith(
      color: tone.ink,
      letterSpacing: 0,
    );

    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: tone.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: AppIcon(icon, size: _iconSize, color: tone.ink),
          ),
          const SizedBox(width: _iconGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  message,
                  // `.inline-bar` copy: 11.5 / 500 / 1.55 — Meta at 500.
                  style: AppTypography.meta.copyWith(
                    color: tone.ink,
                    height: 1.55,
                  ),
                ),
                if (actionLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: _actionGap),
                    child: FilledButton(
                      onPressed: onAction,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: tone.ink,
                        disabledBackgroundColor: AppColors.surface,
                        disabledForegroundColor: AppColors.ink3,
                        // app.css L2773: `rgba(133,87,20,.3)`.
                        side: BorderSide(color: tone.ink.withValues(alpha: 0.3)),
                        elevation: 0,
                        minimumSize: const Size(0, _actionHeight),
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        shape: const StadiumBorder(),
                        // 30 dp is the drawn height; the padded tap target keeps
                        // the touch area near the 44 dp floor (§7.5).
                        tapTargetSize: MaterialTapTargetSize.padded,
                        textStyle: label,
                      ),
                      child: Text(actionLabel!),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
