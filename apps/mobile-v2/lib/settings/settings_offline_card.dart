/// The S7 offline card (design-spec §4.8 item 2, `.offline-card` in
/// `visual/app.css` L3296-3348).
///
/// The hand-off paints it with a violet-to-paper gradient. The design system
/// has no gradient token and inventing one would put two unnameable stops in
/// the palette, so the card uses the surface recipe the spec actually
/// specifies: `surface` fill, `line` hairline, 14 dp corners. The status is
/// carried by an [AppBadge] (13 dp icon + text, design-spec §5.2) instead of
/// the hand-off's 21 dp tag, so "content ready" reads the same as every other
/// status pill in the app.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../ui/app_icon.dart';
import '../ui/components/app_chip.dart';
import 'settings_rows.dart';

/// Offline availability summary: download tile, title, body, status badge.
class SettingsOfflineCard extends StatelessWidget {
  const SettingsOfflineCard({
    super.key,
    required this.title,
    required this.body,
    required this.badgeLabel,
  });

  /// "Built offline". Caller-localised.
  final String title;

  /// One or two lines explaining that a chapter works in airplane mode.
  final String body;

  /// Badge text — "Content ready".
  final String badgeLabel;

  /// `.offline-icon { width: 38px; height: 38px }` (app.css L3303).
  static const double tileSize = 38;

  /// `.offline-icon svg { width: 19px }` (app.css L3312).
  static const double tileIconSize = 19;

  /// `.offline-card { gap: 12px; padding: 14px }` (app.css L3298-3301).
  static const double gap = 12;
  static const EdgeInsets padding = EdgeInsets.all(14);

  /// `.offline-card p { margin-top: 3px }` (app.css L3325).
  static const double bodyGap = 3;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(SettingsLayout.radiusCard),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: tileSize,
            height: tileSize,
            decoration: BoxDecoration(
              // The hand-off floats a white tile with a card shadow; inside a
              // surface card that reads as nothing, so the tile takes the
              // brand tint step instead.
              color: AppColors.primarySoft,
              borderRadius:
                  BorderRadius.circular(SettingsLayout.radiusInner),
            ),
            child: Center(
              child: AppIcon(
                'download',
                size: tileIconSize,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        // `.offline-card h2 { font: 700 13px/1.4 }` — the
                        // Body step at 700.
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppBadge(
                      icon: 'check',
                      label: badgeLabel,
                      tone: AppBadgeTone.success,
                    ),
                  ],
                ),
                const SizedBox(height: bodyGap),
                Text(
                  body,
                  // `.offline-card p { font: 400 11px/1.55; color: ink-2 }`.
                  style: AppTypography.meta.copyWith(
                    fontWeight: FontWeight.w400,
                    height: 1.55,
                    color: AppColors.ink2,
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
