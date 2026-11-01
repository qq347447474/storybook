/// Small pieces of the S0 book card (`.meta-dot` / `.book-progress`,
/// `visual/app.css` L1190-1250).
///
/// They live next to the card rather than inside it so that file stays a
/// readable reading order (cover → kicker → title → meta → summary → progress
/// → CTA) instead of carrying three private widgets.
library;

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';

import '../i18n/gloss_lookup.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../ui/components/segmented_bar.dart';

/// `reading progress` + `N / M` over a segmented bar (`.book-progress`).
class BookProgress extends StatelessWidget {
  const BookProgress({
    super.key,
    required this.bookId,
    required this.label,
    required this.value,
    required this.total,
    required this.done,
  });

  /// Book this block belongs to — keeps the bar key unique on a multi-book
  /// shelf.
  final String bookId;

  /// Left-hand caption — "Reading progress".
  final String label;

  /// Right-hand counter — "1 / 2", already formatted and localised.
  final String value;

  /// Segment count (one per chapter).
  final int total;

  /// Completed chapters.
  final int done;

  /// `.book-progress { padding: 11px 12px; border-radius: 14px }` on the 4 pt
  /// grid.
  static const EdgeInsets padding =
      EdgeInsets.symmetric(horizontal: 12, vertical: 12);
  static const double radius = 14;

  /// `.book-progress__copy { margin-bottom: 8px }`.
  static const double _copyGap = 8;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        // `--primary-ghost`: a 9 % brand tint, so the bar reads as progress
        // without competing with the CTA.
        color: AppColors.primaryGhost,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.label.copyWith(
                    color: AppColors.primary,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Text(
                value,
                style: AppTypography.tabular(
                  AppTypography.meta.copyWith(color: AppColors.ink2),
                ),
              ),
            ],
          ),
          const SizedBox(height: _copyGap),
          SegmentedBar(
            key: Key('library-segmented-$bookId'),
            total: total,
            filled: done,
          ),
        ],
      ),
    );
  }
}

/// `.meta-dot` — a 3 dp `line-strong` separator between meta items.
///
/// Decorative: the reader hears "2 chapters, 282 words" without it
/// (design-spec §7.2).
class MetaDot extends StatelessWidget {
  const MetaDot({super.key});

  static const double size = 3;

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.lineStrong,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
        ),
      ),
    );
  }
}

/// One-line summary of a book.
///
/// Prefers the pack's `book.blurb` (schema `content-pack.v1` §book, optional),
/// resolved in the gloss locale with the same lookup as a vocabulary gloss
/// (decision ③): the active gloss locale first, then the pack's
/// `defaultGloss`, then any available translation. When the pack ships no
/// blurb (or no usable translation) the line falls back to the first sentence
/// of the book's own opening paragraph — a catalog string here would read
/// identically for every book on the shelf.
String bookSummary(
  Book book, {
  String glossLocale = 'en',
  String defaultGloss = 'en',
}) {
  final LocalizedText? blurb = book.blurb;
  if (blurb != null && blurb.byLocale.isNotEmpty) {
    final String text = glossOf(blurb, glossLocale, defaultGloss).trim();
    if (text.isNotEmpty) return _oneLine(text);
  }
  for (final Chapter chapter in book.chapters) {
    for (final Paragraph paragraph in chapter.reading) {
      final String text = paragraph.text.trim();
      if (text.isEmpty) continue;
      final int stop = text.indexOf('. ');
      final String first = stop > 0 ? text.substring(0, stop + 1) : text;
      return _oneLine(first);
    }
  }
  return '';
}

/// The card shows at most two lines: keep any summary to one line's worth of
/// characters instead of trusting the renderer to ellipsize mid-word.
String _oneLine(String text) =>
    text.length > 160 ? '${text.substring(0, 157)}…' : text;
