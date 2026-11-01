/// Missing-media placeholder (design-spec §5.11, `.media-ph` app.css
/// L1031-1060).
///
/// A dashed `line-strong` frame on `surface-sunken` with a 26 dp image glyph,
/// the asset's alt text and, when the load can be retried, a 36 dp button.
/// The frame keeps the asset's aspect ratio so a failed image never makes the
/// layout jump — "no blank block, no broken-image glyph, no crash" (§5.11).
library;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../app_icon.dart';
import 'dashed_border.dart';

/// Alt text + retry for an image or an audio cover that is not available.
class MediaPlaceholder extends StatelessWidget {
  const MediaPlaceholder({
    super.key,
    required this.altText,
    this.aspectRatio = defaultAspectRatio,
    this.icon = 'image',
    this.retryLabel,
    this.onRetry,
  }) : assert(
          onRetry == null || retryLabel != null,
          'MediaPlaceholder: a retry button needs a label.',
        );

  /// What the missing asset would show. Required: §5.11 forbids an unexplained
  /// blank frame for a screen reader.
  final String altText;

  /// Width / height of the frame. `null` lets the parent decide the height
  /// (e.g. inside a fixed-height card).
  final double? aspectRatio;

  /// 26 dp glyph — `image` for pictures, `headphones` for audio.
  final String icon;

  /// Retry button label, localised by the caller. Omitted → no button.
  final String? retryLabel;

  /// Retry callback. `null` renders the label as a disabled button.
  final VoidCallback? onRetry;

  /// Cover ratio of the hand-off (design-spec §2.4: illustrations are 3:2).
  static const double defaultAspectRatio = 3 / 2;

  /// `.media-ph { border-radius: var(--r-lg) }` (app.css L1038, `--r-lg: 20px`).
  static const double _radius = 20;

  /// `.media-ph { padding: 18px; gap: 8px }` (app.css L1037).
  static const EdgeInsets _padding = EdgeInsets.all(18);
  static const double _iconGap = 8;

  /// `.media-ph svg { 26px }` (app.css L1045).
  static const double _iconSize = 26;

  /// `.media-ph p { max-width: 220px }` (app.css L1052).
  static const double _textMaxWidth = 220;

  /// `.media-ph .btn { height: 36px; padding: 0 14px }` (app.css L1057-1060).
  static const double _retryHeight = 36;

  @override
  Widget build(BuildContext context) {
    final Widget body = DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: CustomPaint(
        painter: DashedBoxBorderPainter(
          color: AppColors.lineStrong,
          radius: _radius,
        ),
        child: Padding(
          padding: _padding,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AppIcon(icon, size: _iconSize, color: AppColors.ink3),
                const SizedBox(height: _iconGap),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _textMaxWidth),
                  child: Text(
                    altText,
                    textAlign: TextAlign.center,
                    style: AppTypography.meta.copyWith(color: AppColors.ink3),
                  ),
                ),
                if (retryLabel != null) ...<Widget>[
                  const SizedBox(height: _iconGap),
                  FilledButton(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      // `.btn` (secondary): surface plate, `line-strong` edge.
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.ink,
                      disabledBackgroundColor: AppColors.surface,
                      disabledForegroundColor: AppColors.disabledInk,
                      side: const BorderSide(color: AppColors.lineStrong),
                      elevation: 0,
                      minimumSize: const Size(0, _retryHeight),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: const StadiumBorder(),
                      textStyle: AppTypography.meta.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(retryLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    final double? ratio = aspectRatio;
    if (ratio == null) {
      return body;
    }
    return AspectRatio(aspectRatio: ratio, child: body);
  }
}
