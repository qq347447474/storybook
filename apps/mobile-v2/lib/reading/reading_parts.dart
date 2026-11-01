/// Copy blocks of S2: the chapter head, the 3:2 scene plate, the reading card
/// and the tap hint (`.reading-head` / `.scene-figure` / `.story-card`,
/// `visual/app.css` L1660-1960, design-spec §4.3).
///
/// Presentational only: the screen owns the timeline and the player, and hands
/// these widgets values plus one callback per gesture.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../ui/app_icon.dart';

/// `.reading-head`: eyebrow over the serif chapter title.
class ChapterHead extends StatelessWidget {
  const ChapterHead({super.key, required this.eyebrow, required this.title});

  /// "THE PAPER BOAT · 第 1 章" — brand, tracked, upper-case in the hand-off.
  final String eyebrow;

  /// Chapter title, content language (never translated).
  final String title;

  /// `.reading-head { padding: 8px 2px 12px }`, `.reading-title { margin-top: 5px }`.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(2, 8, 2, 12);
  static const double gap = 5;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            eyebrow,
            key: const Key('reading-eyebrow'),
            // `.reading-head .eyebrow { 10px; .13em; ink-2 }`.
            style: AppTypography.label.copyWith(
              color: AppColors.ink2,
              letterSpacing: 0.13 * 11,
            ),
          ),
          const SizedBox(height: gap),
          Text(
            title,
            key: const Key('reading-title'),
            // `.reading-title { 600 29px/1.2 serif; letter-spacing: -.015em }`
            // on the nearest serif step (Title).
            style: AppTypography.title.copyWith(
              color: AppColors.ink,
              letterSpacing: -0.015 * 28,
            ),
          ),
        ],
      ),
    );
  }
}

/// One sentence of the story as it is drawn in the card.
class StorySentence {
  const StorySentence({
    required this.text,
    required this.current,
    required this.onTap,
    required this.words,
  });

  /// Sentence text, content language.
  final String text;

  /// Whether the playhead is inside this sentence.
  final bool current;

  /// Tapping the sentence starts playback from its first word.
  final VoidCallback onTap;

  /// Vocabulary words to underline (dotted, `accent-strong`).
  final List<String> words;
}

/// `.story-card` — head (`跟读` + counter + headphones) over the story text.
class ReadingCard extends StatelessWidget {
  const ReadingCard({
    super.key,
    required this.followLabel,
    required this.counter,
    required this.sentences,
    required this.sentenceKeyPrefix,
    required this.paragraphKeys,
  });

  /// Card head label — "Follow along".
  final String followLabel;

  /// `2 / 6` — the sentence the playhead sits in.
  final String counter;

  /// Sentences grouped by paragraph; each inner list is one paragraph block.
  final List<List<StorySentence>> sentences;

  /// Key prefix, e.g. `sentence` → `sentence-0-1`.
  final String sentenceKeyPrefix;

  /// One key per paragraph block, so the screen can measure what has been seen
  /// (the "read" signal of the state machine).
  final List<GlobalKey> paragraphKeys;

  /// `.story-card { padding: 14px 16px 18px; border-radius: 20px }`.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(16, 14, 16, 18);
  static const double radius = 20;
  static const double headGap = 12;

  /// Between two paragraphs of the same card.
  static const double paragraphGap = 14;

  /// `.story { font: 400 18px/31px var(--font-serif); letter-spacing: 0 }`.
  static TextStyle get bodyStyle => AppTypography.reading.copyWith(
        color: AppColors.ink,
        height: 31 / 18,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                followLabel,
                // `.story-card__head { 700 label; .13em; ink-3 }`.
                style: AppTypography.label.copyWith(color: AppColors.ink3),
              ),
              const Spacer(),
              Text(
                counter,
                key: const Key('reading-sentence-count'),
                style: AppTypography.tabular(
                  AppTypography.meta.copyWith(color: AppColors.ink3),
                ),
              ),
              const SizedBox(width: 6),
              const AppIcon('headphones', size: 14, color: AppColors.ink3),
            ],
          ),
          const SizedBox(height: headGap),
          for (int p = 0; p < sentences.length; p++) ...<Widget>[
            if (p > 0) const SizedBox(height: paragraphGap),
            KeyedSubtree(
              key: paragraphKeys[p],
              child: Wrap(
                spacing: 5,
                runSpacing: 2,
                children: <Widget>[
                  for (int s = 0; s < sentences[p].length; s++)
                    _SentenceRun(
                      key: Key('$sentenceKeyPrefix-$p-$s'),
                      sentence: sentences[p][s],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One tappable sentence; the current one sits on a `primary-soft` wash.
class _SentenceRun extends StatelessWidget {
  const _SentenceRun({super.key, required this.sentence});

  final StorySentence sentence;

  /// `.is-current` sentence background (`--primary-soft`) with 4 dp radius.
  static const BorderRadius _radius = BorderRadius.all(Radius.circular(4));

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: sentence.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        decoration: BoxDecoration(
          color: sentence.current ? AppColors.primarySoft : null,
          borderRadius: _radius,
        ),
        child: Text.rich(
          TextSpan(
            style: ReadingCard.bodyStyle,
            children: _highlightVocabulary(sentence.text, sentence.words),
          ),
        ),
      ),
    );
  }
}

/// Splits [text] into plain runs and vocabulary runs (dotted `accent-strong`
/// underline, app.css L1888 — the hand-off's "点状下划线，不弹翻译").
List<TextSpan> _highlightVocabulary(String text, List<String> words) {
  final List<String> usable = words
      .map((String w) => w.trim())
      .where((String w) => w.length > 1)
      .toList();
  if (usable.isEmpty || text.isEmpty) return <TextSpan>[TextSpan(text: text)];

  final RegExp pattern = RegExp(
    usable.map(RegExp.escape).join('|'),
    caseSensitive: false,
  );
  const TextStyle mark = TextStyle(
    decoration: TextDecoration.underline,
    decorationStyle: TextDecorationStyle.dotted,
    decorationColor: AppColors.accentStrong,
    decorationThickness: 1.5,
  );

  final List<TextSpan> spans = <TextSpan>[];
  int cursor = 0;
  for (final RegExpMatch match in pattern.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
    }
    spans.add(TextSpan(text: match.group(0), style: mark));
    cursor = match.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor)));
  }
  return spans;
}

/// The one line of instruction under the card (`点任意句子，从这里开始听`).
class TapHint extends StatelessWidget {
  const TapHint({super.key, required this.text});

  /// Localised hint.
  final String text;

  /// `.tap-hint { margin-top: 12px; gap: 6px }`, glyph 14 dp.
  static const EdgeInsets padding = EdgeInsets.only(top: 12);
  static const double gap = 6;
  static const double iconSize = 14;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          const AppIcon('headphones', size: iconSize, color: AppColors.ink3),
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
