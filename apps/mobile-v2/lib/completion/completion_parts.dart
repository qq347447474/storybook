/// Copy blocks and the bottom dock of S6 (design-spec §4.7 items 2-6,
/// `visual/app.css` L3212-3300).
///
/// Every string arrives already localised: the screen owns the data, these
/// widgets own the geometry and the token discipline.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../ui/app_icon.dart';
import '../ui/components/app_chip.dart';

/// Eyebrow + big serif headline + explanation.
class CompletionHeading extends StatelessWidget {
  const CompletionHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    this.body,
    required this.bodyTail,
  });

  /// "Chapter 1 complete" — the fact of the screen.
  final String eyebrow;

  /// "You told the story." — the tone of the screen (serif, Title step).
  final String title;

  /// How the pass went: "you met 4 new words…". `null` when the caller has no
  /// chapter to count from — the tail still lands, nothing is invented.
  final String? body;

  /// "No score — just one complete pass." (design-spec §4.7: 没有分数).
  final String bodyTail;

  /// `.complete-eyebrow { margin-top: 4px }`, `.complete-title { 10px }`,
  /// `.complete-body { max-width: 280px; margin-top: 10px }`.
  static const double eyebrowGap = 4;
  static const double titleGap = 10;
  static const double bodyGap = 10;
  static const double bodyMaxWidth = 280;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const SizedBox(height: eyebrowGap),
        Text(
          eyebrow,
          key: const Key('completion-eyebrow'),
          textAlign: TextAlign.center,
          // `.eyebrow { 700 label; 0.16em; primary }` — the one brand touch.
          style: AppTypography.label.copyWith(
            color: AppColors.primary,
            letterSpacing: 0.16 * 11,
          ),
        ),
        const SizedBox(height: titleGap),
        Text(
          title,
          key: const Key('completion-title'),
          textAlign: TextAlign.center,
          // `.complete-title { 600 33px/1.2 serif; letter-spacing: -0.02em }` on
          // the nearest serif step (Title, 28).
          style: AppTypography.title.copyWith(
            color: AppColors.ink,
            letterSpacing: -0.02 * 28,
          ),
        ),
        const SizedBox(height: bodyGap),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: bodyMaxWidth),
          child: Column(
            children: <Widget>[
              // Two whole catalog sentences, never concatenated fragments
              // (docs/03 §3): the count clause can be dropped on its own.
              if (body != null)
                Text(
                  body!,
                  key: const Key('completion-body'),
                  textAlign: TextAlign.center,
                  style: AppTypography.meta.copyWith(color: AppColors.ink2),
                ),
              Text(
                bodyTail,
                key: const Key('completion-body-tail'),
                textAlign: TextAlign.center,
                style: AppTypography.meta.copyWith(color: AppColors.ink2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The four steps of the loop, all ticked (`.recap`, app.css L3238).
///
/// A tick plus the step name — the chip never says "done" by colour alone
/// (design-spec §7.2).
class CompletionRecap extends StatelessWidget {
  const CompletionRecap({super.key, required this.labels});

  /// Step names in loop order: read, words, quiz, retell.
  final List<String> labels;

  /// `.recap { gap: 6px; margin-top: 17px }`.
  static const double gap = 6;
  static const double topGap = 17;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: topGap),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: gap,
        runSpacing: gap,
        children: <Widget>[
          for (final String label in labels)
            AppChip(label, icon: 'check'),
        ],
      ),
    );
  }
}

/// The story's closing line with its credit (`.quote-card`, app.css L3256).
class CompletionQuote extends StatelessWidget {
  const CompletionQuote({
    super.key,
    required this.quote,
    required this.attribution,
  });

  /// Content-language sentence from the chapter — never translated (docs/03 §1).
  final String quote;

  /// "THE PAPER BOAT · CH. 1", already assembled and upper-cased by the caller.
  final String attribution;

  /// `.quote-card { max-width: 300px; margin-top: 18px; padding: 12px 15px }`.
  static const double maxWidth = 300;
  static const double topGap = 18;
  static const EdgeInsets padding = EdgeInsets.fromLTRB(15, 12, 15, 12);

  /// `border-left: 2px solid var(--accent)` — the hand-off's editorial rule for
  /// a quotation, not a decorative card stripe.
  static const double rule = 2;

  /// `border-radius: 0 12px 12px 0`.
  static const BorderRadiusGeometry radius =
      BorderRadiusDirectional.horizontal(end: Radius.circular(12));

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('completion-quote'),
      constraints: const BoxConstraints(maxWidth: maxWidth),
      margin: const EdgeInsets.only(top: topGap),
      padding: padding,
      decoration: BoxDecoration(
        // `rgba(255, 252, 246, .72)` over paper.
        color: AppColors.surface.withValues(alpha: 0.72),
        border: const Border(
          left: BorderSide(color: AppColors.accent, width: rule),
        ),
        borderRadius: radius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            quote,
            // `italic 400 13.5px/1.6 serif; ink-2` — the meta step in the serif
            // voice, the same pairing S7's footer uses.
            style: AppTypography.meta.copyWith(
              color: AppColors.ink2,
              fontStyle: FontStyle.italic,
              fontFamily: AppTypography.serifFamily,
              fontFamilyFallback: AppTypography.serifFallback,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            attribution,
            // `500 9.5px/1.4; letter-spacing: .08em; uppercase; ink-3`.
            style: AppTypography.label.copyWith(
              color: AppColors.ink3,
              letterSpacing: 0.08 * 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// `.complete-dock` — the 56 dp "back to contents" plate with the ghost
/// "read it again" under it.
///
/// Built here rather than from `AppDock` because S6 has no helper line and owns
/// its own gesture-inset padding (`calc(var(--gesture-inset) + 4px)`), while
/// keeping the theme's 56 dp pill untouched.
class CompleteDock extends StatelessWidget {
  const CompleteDock({
    super.key,
    required this.ctaLabel,
    required this.againLabel,
    this.onCta,
    this.onAgain,
  });

  /// Primary CTA — "Back to contents".
  final String ctaLabel;

  /// Ghost action — "Read it again".
  final String againLabel;

  final VoidCallback? onCta;
  final VoidCallback? onAgain;

  /// `.complete-dock { gap: 2px; padding: 12px var(--gutter)
  /// calc(var(--gesture-inset) + 4px) }`.
  static const double gap = 2;
  static const double gutter = 20;
  static const double topPadding = 12;
  static const double _safeAreaTrailing = 4;

  /// `.btn svg { width: 19px }` (app.css L813).
  static const double ctaIconSize = 19;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        gutter,
        topPadding,
        gutter,
        bottomInset + _safeAreaTrailing,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // The 56 dp height is a red line (§6.4), so the label scales to 130 %
          // and no further.
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: FilledButton(
              key: const Key('completion-cta'),
              onPressed: onCta,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(child: Text(ctaLabel, textAlign: TextAlign.center)),
                  const SizedBox(width: 8),
                  const AppIcon(
                    'arrow-right',
                    size: ctaIconSize,
                    color: AppColors.onPrimary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: gap),
          // A plain `TextButton` (the theme's 46 dp ghost recipe) rather than a
          // label+icon row: the ghost carries no glyph here, and a bare Text
          // wraps instead of overflowing at 150 % text scale.
          TextButton(
            key: const Key('completion-again'),
            onPressed: onAgain,
            child: Text(againLabel, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
