/// Section chrome around the S1 trail: the "Chapters" heading with the book's
/// length, and the quiet note under the last card (`.trail-head` app.css
/// L1398-1425, `.trail-note` L1618).
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../ui/app_icon.dart';

/// "Chapters" with the book's length on the right.
class TrailHead extends StatelessWidget {
  const TrailHead({super.key, required this.title, this.lengthLabel});

  /// Section heading — "Chapters". Caller-localised.
  final String title;

  /// "About 3 min"; `null` drops the legend (no audio and no sentences).
  final String? lengthLabel;

  /// `.trail-head { margin: 22px 2px 4px }`.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(2, 22, 2, 4);

  /// `.trail-legend { gap: 5px }` and `svg { width: 13px }`.
  static const double gap = 5;
  static const double iconSize = 13;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: AppTypography.h2.copyWith(color: AppColors.ink),
            ),
          ),
          if (lengthLabel != null) ...<Widget>[
            const SizedBox(width: gap),
            const AppIcon('clock', size: iconSize, color: AppColors.ink3),
            const SizedBox(width: gap),
            Text(
              lengthLabel!,
              style: AppTypography.tabular(
                AppTypography.meta.copyWith(color: AppColors.ink3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// `.trail-note` — the quiet strip explaining the four-step loop and the fact
/// that finished chapters stay open for another read (design-spec §4.2 item 5).
class TrailNote extends StatelessWidget {
  const TrailNote({super.key, required this.text});

  /// The explanation. Caller-localised.
  final String text;

  /// `.trail-note { margin: 18px 2px 4px; gap: 8px }` on the 10 dp small-radius
  /// step, `surface-sunken` fill.
  static const EdgeInsets margin = EdgeInsets.fromLTRB(2, 18, 2, 4);
  static const EdgeInsets padding = EdgeInsets.all(12);
  static const double radius = 10;
  static const double gap = 8;
  static const double iconSize = 15;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: AppIcon('info', size: iconSize, color: AppColors.ink3),
          ),
          const SizedBox(width: gap),
          Expanded(
            child: Text(
              text,
              style: AppTypography.meta.copyWith(color: AppColors.ink3),
            ),
          ),
        ],
      ),
    );
  }
}
