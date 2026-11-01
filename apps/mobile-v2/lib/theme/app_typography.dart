/// Design tokens — type scale.
///
/// Mirrors `visual/design-spec.md` §2.2 (font stacks) and §2.3 (seven-step
/// scale); the pixel values are copied 1:1 from `visual/app.css` `:root`
/// (`--font-serif` L51-52, `--fs-*` / `--lh-*` L57-70). Screens must take
/// text styles from here — never inline a `TextStyle(fontSize: ...)`.
///
/// | level   | size / line | family | weight | tracking |
/// | ------- | ----------- | ------ | ------ | -------- |
/// | display | 34 / 41     | sans   | 800    | -0.03em  |
/// | title   | 28 / 35     | serif  | 600    | 0        |
/// | h2      | 22 / 29     | serif  | 600    | 0        |
/// | reading | 18 / 31     | serif  | 400    | 0        |
/// | body    | 15 / 23     | sans   | 400    | 0        |
/// | meta    | 12.5 / 18   | sans   | 500    | 0        |
/// | label   | 11 / 16     | sans   | 700    | 0.13em   |
///
/// Line heights are authored as pixel pairs (`41 / 34`) on purpose: the spec
/// fixes absolute px line heights, while Flutter only accepts a multiplier —
/// keeping both numbers next to each other makes the token auditable.
///
/// Styles here carry no `color`: ink is applied where the style is consumed
/// (see `app_theme.dart`), so one scale serves paper, card and tonal surfaces.
library;

import 'package:flutter/painting.dart';

/// Static type scale. Use these instead of literal font sizes.
class AppTypography {
  const AppTypography._();

  // ------------------------------------------------------------- font stacks
  /// Generic serif family (app.css `--font-serif`). Android and iOS both
  /// resolve the generic `serif` alias to their system serif face, so no font
  /// asset is bundled (design-spec §2.2: system fallbacks only).
  static const String serifFamily = 'serif';

  /// Latin old-style/didone faces first, CJK serif faces next, generic last —
  /// the exact order of `--font-serif` in app.css L51-52.
  static const List<String> serifFallback = <String>[
    'Iowan Old Style',
    'Palatino Linotype',
    'Book Antiqua',
    'Palatino',
    'Songti SC',
    'Source Han Serif SC',
    'Noto Serif CJK SC',
    'STSong',
    'SimSun',
    'Georgia',
  ];

  // ------------------------------------------------------------------- scale
  /// Display — page hero titles ("Library", "Done"). CJK sans 800, -0.03em.
  static const TextStyle display = TextStyle(
    fontSize: 34,
    height: 41 / 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.03 * 34,
  );

  /// Title — chapter and sheet titles. Serif 600.
  static const TextStyle title = TextStyle(
    fontSize: 28,
    height: 35 / 28,
    fontWeight: FontWeight.w600,
    fontFamily: serifFamily,
    fontFamilyFallback: serifFallback,
  );

  /// H2 — question headings, in-book headings. Serif 600.
  static const TextStyle h2 = TextStyle(
    fontSize: 22,
    height: 29 / 22,
    fontWeight: FontWeight.w600,
    fontFamily: serifFamily,
    fontFamilyFallback: serifFallback,
  );

  /// Reading — story body and quoted evidence. Serif 400, ≤ 34 words a line.
  static const TextStyle reading = TextStyle(
    fontSize: 18,
    height: 31 / 18,
    fontWeight: FontWeight.w400,
    fontFamily: serifFamily,
    fontFamilyFallback: serifFallback,
  );

  /// Body — explanations, buttons, options. Sans 400 (600 for emphasis).
  static const TextStyle body = TextStyle(
    fontSize: 15,
    height: 23 / 15,
    fontWeight: FontWeight.w400,
  );

  /// Meta — counters, durations, helper copy. Sans 500.
  static const TextStyle meta = TextStyle(
    fontSize: 12.5,
    height: 18 / 12.5,
    fontWeight: FontWeight.w500,
  );

  /// Label — uppercase or micro labels. Sans 700, 0.13em tracking.
  static const TextStyle label = TextStyle(
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.13 * 11,
  );

  // ----------------------------------------------------------------- numbers
  /// Tabular figures (design-spec §2.2: counters, timers, progress must not
  /// jitter). Pass to `TextStyle.fontFeatures`.
  static const List<FontFeature> tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// Returns [style] with tabular figures enabled — for timers, counters and
  /// progress numbers rendered through the sans scale.
  static TextStyle tabular(TextStyle style) =>
      style.copyWith(fontFeatures: tabularFigures);
}
