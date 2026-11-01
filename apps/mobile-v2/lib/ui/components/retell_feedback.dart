/// The retell summary card of S5 (design-spec §5.8, `.retell-feedback`
/// app.css L2779-2866, prototype L565-588).
///
/// Anatomy, top to bottom: a fact-first headline with the covered-point count,
/// the "can still be added" chip row, a one-line pace hint and two text
/// actions (replay / record again). Nothing here scores the learner — the copy
/// is supplied by the caller so the tone can be reviewed in the dictionary.
library;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../app_icon.dart';
import 'app_chip.dart';
import 'dashed_border.dart';

/// One text action at the foot of the card (`.link-btn`, app.css L851-868).
class AppTextAction {
  const AppTextAction({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  /// Localised label — "Replay", "Try again".
  final String label;

  /// 16 dp leading glyph: `volume`, `rotate`…
  final String icon;

  /// Callback; `null` hides the action's affordance (disabled label).
  final VoidCallback? onPressed;
}

/// Post-recording feedback for step 4.
///
/// [title] is a fully formatted sentence from the caller. Numerals inside it
/// are picked out in `primary` — that is how "3 of 4 key points" is emphasised
/// without this widget owning the sentence (`.feedback-title .num`,
/// app.css L2806).
class RetellFeedback extends StatelessWidget {
  const RetellFeedback({
    super.key,
    required this.title,
    this.missingLabel,
    this.missingPoints = const <String>[],
    this.paceLabel,
    this.paceText,
    this.transcriptLabel,
    this.transcriptText,
    this.actions = const <AppTextAction>[],
    this.icon = 'spark',
  });

  /// Headline sentence, already interpolated by the caller. Runs of digits are
  /// emphasised.
  final String title;

  /// Micro label above the chip row, e.g. "Can still be added".
  final String? missingLabel;

  /// Key points the learner did not cover yet; rendered as soft chips.
  final List<String> missingPoints;

  /// Bold lead-in of the pace row, e.g. "Pace:".
  final String? paceLabel;

  /// Pace hint sentence.
  final String? paceText;

  /// Label above the transcript block, e.g. "What we heard".
  final String? transcriptLabel;

  /// Raw ASR transcript text to display for verification.
  final String? transcriptText;

  /// Footer text actions.
  final List<AppTextAction> actions;

  /// 18 dp headline glyph — `spark`, painted in `primary`.
  final String icon;

  /// `.retell-feedback { padding: 14px; border-radius: 18px }`
  /// (app.css L2780-2783).
  static const double _padding = 14;
  static const double _radius = 18;

  /// `.feedback-title svg { 18px }` (app.css L2801).
  static const double _iconSize = 18;

  /// `#fbf8ff` in the hand-off = `--primary` at 4 % over `--surface`. The alpha
  /// derives from the token, so no bare hex enters the widget.
  static final Color _fill = Color.alphaBlend(
    AppColors.primary.withValues(alpha: 0.04),
    AppColors.surface,
  );

  /// `rgba(91,75,214,.24)` (app.css L2781).
  static final Color _border = AppColors.primary.withValues(alpha: 0.24);

  /// `.pace-row { border-top: 1px dashed rgba(91,75,214,.2) }` (app.css L2815).
  static final Color _rule = AppColors.primary.withValues(alpha: 0.2);

  @override
  Widget build(BuildContext context) {
    final TextStyle titleStyle = AppTypography.body.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
      height: 1.5,
    );
    final TextStyle labelStyle = AppTypography.label.copyWith(color: AppColors.ink3);

    return Container(
      padding: const EdgeInsets.all(_padding),
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: AppIcon(icon, size: _iconSize, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: titleStyle,
                    children: _numberedRuns(
                      title,
                      titleStyle.copyWith(color: AppColors.primary),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (missingPoints.isNotEmpty) ...<Widget>[
            const SizedBox(height: 11),
            if (missingLabel != null) ...<Widget>[
              Text(missingLabel!, style: labelStyle),
              const SizedBox(height: 6),
            ],
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: <Widget>[
                for (final String point in missingPoints)
                  AppChip(point, variant: AppChipVariant.soft),
              ],
            ),
          ],
          if (paceText != null) ...<Widget>[
            const SizedBox(height: 11),
            // The dashed rule belongs to the section, so it is painted above
            // the padding rather than as a border on the row itself.
            SizedBox(
              height: 1,
              child: CustomPaint(painter: DashedLinePainter(color: _rule)),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: AppIcon('waves', size: 15, color: AppColors.ink3),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      // `.pace-row`: 11.5 / 400 / 1.55, `--ink-2`.
                      style: AppTypography.meta.copyWith(
                        color: AppColors.ink2,
                        height: 1.55,
                        fontWeight: FontWeight.w400,
                      ),
                      children: <InlineSpan>[
                        if (paceLabel != null)
                          TextSpan(
                            text: paceLabel,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        TextSpan(text: paceText),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (transcriptText != null && transcriptText!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            if (transcriptLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  transcriptLabel!,
                  style: AppTypography.meta.copyWith(
                    color: AppColors.ink2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
              ),
              child: Text(
                transcriptText!,
                style: AppTypography.meta.copyWith(
                  color: AppColors.ink,
                  height: 1.5,
                ),
              ),
            ),
          ],
          if (actions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: <Widget>[
                for (final AppTextAction action in actions) _TextAction(action: action),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Splits [text] so every run of digits is painted with [number] styling.
List<TextSpan> _numberedRuns(String text, TextStyle number) {
  final RegExp digits = RegExp(r'[0-9]+');
  final List<TextSpan> spans = <TextSpan>[];
  int cursor = 0;
  for (final RegExpMatch match in digits.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
    }
    spans.add(TextSpan(text: match.group(0), style: number));
    cursor = match.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor)));
  }
  return spans;
}

/// Compact footer action: 16 dp glyph + 11 px label, 44 dp touch height.
class _TextAction extends StatelessWidget {
  const _TextAction({required this.action});

  final AppTextAction action;

  @override
  Widget build(BuildContext context) {
    final Color ink = action.onPressed == null ? AppColors.ink3 : AppColors.primary;
    return TextButton(
      onPressed: action.onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: AppColors.primary,
        disabledForegroundColor: AppColors.ink3,
        textStyle: AppTypography.label.copyWith(letterSpacing: 0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppIcon(action.icon, size: AppIconSize.sm, color: ink),
          const SizedBox(width: 4),
          Text(action.label),
        ],
      ),
    );
  }
}
