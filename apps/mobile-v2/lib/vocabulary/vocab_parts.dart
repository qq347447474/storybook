/// Pieces around the S3 word card: the head line, the dot rail and the
/// previous / next controls (`.vocab-head` app.css L1920-1945, `.word-nav`
/// L2237-2290, design-spec §4.4 items 2 and 4).
///
/// Copy arrives already localised; these widgets keep the geometry and the
/// tap-target rules (every control ≥ 44 dp, design-spec §7.5).
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../ui/app_icon.dart';

/// `生词 · 第 2 步` over `在故事里遇见`, with `1 / 4` on the right.
class VocabHead extends StatelessWidget {
  const VocabHead({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.count,
  });

  /// Stage line — includes the step number.
  final String eyebrow;

  /// Section heading, serif.
  final String title;

  /// Counter of the card being shown — `1 / 4`.
  final String count;

  /// `.vocab-head { padding: 8px 2px 14px; align-items: flex-end }`.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(2, 8, 2, 14);
  static const double gap = 12;

  /// `.eyebrow` under the head is 10 px ink-2 with 0.14em tracking.
  static const double eyebrowTracking = 0.14;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  eyebrow,
                  key: const Key('vocab-eyebrow'),
                  style: AppTypography.label.copyWith(
                    color: AppColors.ink2,
                    letterSpacing: eyebrowTracking * 11,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: AppTypography.h2.copyWith(color: AppColors.ink),
                ),
              ],
            ),
          ),
          const SizedBox(width: gap),
          Text(
            count,
            key: const Key('vocab-count'),
            // `.meta-count`: 500, ink-3, tabular figures.
            style: AppTypography.tabular(
              AppTypography.meta.copyWith(color: AppColors.ink3),
            ),
          ),
        ],
      ),
    );
  }
}

/// The dot rail: one dot per card, the current one stretched into a pill.
///
/// Decorative by construction (`aria-hidden` in the hand-off): the counter in
/// [VocabHead] already says `2 / 4` in words, so the rail stays out of the
/// semantics tree.
class WordDots extends StatelessWidget {
  const WordDots({
    super.key,
    required this.count,
    required this.current,
    required this.seen,
  });

  /// How many cards the chapter has.
  final int count;

  /// Index of the card on screen.
  final int current;

  /// Indices whose back has been revealed at least once.
  final Set<int> seen;

  /// `.word-dots { gap: 6px }`, dots 6 dp, current 18 × 6 pill.
  static const double gap = 6;
  static const double dot = 6;
  static const double pillWidth = 18;

  /// `background: #ded3bf` sits between `--line` and `--line-strong`; the
  /// stronger of the two tokens is used so a dot still reads on paper.
  static const double seenOpacity = 0.55;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < count; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: gap),
            AnimatedContainer(
              key: Key('vocab-dot-$i'),
              duration: const Duration(milliseconds: 240),
              curve: const Cubic(0.22, 0.9, 0.26, 1),
              width: i == current ? pillWidth : dot,
              height: dot,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(i == current ? 3 : 999),
                color: _color(i).withValues(alpha: _opacity(i)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _color(int index) =>
      index == current || seen.contains(index)
          ? AppColors.primary
          : AppColors.lineStrong;

  double _opacity(int index) {
    if (index == current) return 1;
    return seen.contains(index) ? seenOpacity : 1;
  }
}

/// A circular previous / next control with a 44 dp hit area.
class WordNavButton extends StatelessWidget {
  const WordNavButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  /// `chevron-left` or `chevron-right`.
  final String icon;

  /// Screen-reader label — "Previous word" / "Next word".
  final String label;

  /// `null` at either end of the rail: the control dims and stops answering
  /// (design-spec §4.4 "首尾禁用").
  final VoidCallback? onPressed;

  /// `.round-btn { width/height: 40px }`, `.round-btn svg { 17px }`.
  static const double diameter = 40;
  static const double iconSize = 17;

  /// design-spec §7.5: the drawn circle may be 40 dp, the target may not.
  static const double tapTarget = 44;

  /// `.round-btn:disabled { opacity: .4 }`.
  static const double disabledOpacity = 0.4;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final Color ink = enabled ? AppColors.ink2 : AppColors.ink3;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: SizedBox(
        width: tapTarget,
        height: tapTarget,
        child: Center(
          child: Opacity(
            opacity: enabled ? 1 : disabledOpacity,
            child: Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.lineStrong),
              ),
              child: Material(
                // The circle above owns fill and border.
                type: MaterialType.transparency,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPressed,
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: AppIcon(icon, size: iconSize, color: ink),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.word-nav` — previous, dot rail, next.
class WordNav extends StatelessWidget {
  const WordNav({
    super.key,
    required this.previous,
    required this.next,
    required this.dots,
  });

  final WordNavButton previous;
  final WordNavButton next;

  /// The rail between the two controls.
  final Widget dots;

  /// `.word-nav { gap: 14px; margin-top: 16px; justify-content: space-between }`.
  static const EdgeInsets padding = EdgeInsets.only(top: 16);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          previous,
          Expanded(child: Center(child: dots)),
          next,
        ],
      ),
    );
  }
}
