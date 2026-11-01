/// Non-interactive chrome of S7: the regular app bar and the brand footer.
///
/// Both are pure layout over the token file — `.appbar` / `.appbar__title`
/// (`visual/app.css` L950-966) and `.settings-footer` (L3457-3484). They live
/// here rather than in the screen so the screen file stays a readable list of
/// groups.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../ui/app_icon.dart';
import '../ui/app_illustration.dart';

/// Regular app bar: back control + page title on paper, no elevation.
class SettingsAppBar extends StatelessWidget {
  const SettingsAppBar({
    super.key,
    required this.title,
    required this.backLabel,
  });

  /// Page title — "Settings". Caller-localised.
  final String title;

  /// Screen-reader / tooltip label of the back control.
  final String backLabel;

  /// `.appbar { min-height: 54px; padding: 0 14px 0 8px }` (app.css L950).
  static const double minHeight = 54;

  /// `.appbar { gap: 10px }`.
  static const double gap = 10;

  /// `.icon-btn svg { width: 22px }` (app.css L777).
  static const double iconSize = 22;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8, end: 14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight),
        child: Row(
          children: <Widget>[
            // IconButton already gives the 48 dp tap target the hand-off's
            // 44 dp circle needs; no elevation and no ink outside the radius.
            IconButton(
              key: const Key('settings-back'),
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: backLabel,
              icon: const AppIcon('arrow-left', size: iconSize),
            ),
            const SizedBox(width: gap),
            Expanded(
              child: Text(
                title,
                // `.appbar__title { 600 15px/1.3; letter-spacing: .005em }`.
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.005 * 15,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Brand footer: mark, tagline, copyright (`.settings-footer`, app.css L3457).
class SettingsFooter extends StatelessWidget {
  const SettingsFooter({
    super.key,
    required this.tagline,
    required this.copyright,
  });

  /// Brand line — "Made for quiet corners."
  final String tagline;

  /// Copyright line with the edition already substituted.
  final String copyright;

  /// `.settings-footer img { width: 30px }` drawn at the 32 dp step.
  static const double markSize = 32;

  /// `.settings-footer img { opacity: .7 }`.
  static const double markOpacity = 0.7;

  /// `.settings-footer { gap: 9px; margin: 26px 0 8px }` (app.css L3457).
  static const double gap = 9;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 8),
      child: Column(
        children: <Widget>[
          Opacity(
            opacity: markOpacity,
            child: const SizedBox(
              width: markSize,
              height: markSize,
              child: AppIllustration('logo-mark'),
            ),
          ),
          const SizedBox(height: gap),
          Text(
            tagline,
            textAlign: TextAlign.center,
            // `.settings-footer .made { 500 italic 11px serif; ink-2 }`.
            style: AppTypography.meta.copyWith(
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              fontFamily: AppTypography.serifFamily,
              fontFamilyFallback: AppTypography.serifFallback,
              height: 1.5,
              color: AppColors.ink2,
            ),
          ),
          const SizedBox(height: gap),
          Text(
            copyright,
            textAlign: TextAlign.center,
            style: AppTypography.meta.copyWith(
              fontWeight: FontWeight.w400,
              height: 1.5,
              color: AppColors.ink3,
            ),
          ),
        ],
      ),
    );
  }
}
