/// Head, tip and the pure helpers of the S4 quiz (`.quiz-head` app.css
/// L2226-2248, `.quiz-progress-note` L2451, design-spec §4.5).
///
/// The widgets in `quiz_body.dart` own the answer list and the verdict card;
/// this file owns the framing and the two pieces of text analysis the wrong
/// answer needs.
library;

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../ui/app_icon.dart';
import '../ui/components/option_row.dart';

/// `测验 · 第 3 步` + `1 / 3` over the serif question.
class QuizHead extends StatelessWidget {
  const QuizHead({
    super.key,
    required this.eyebrow,
    required this.count,
    required this.prompt,
    this.promptGloss,
  });

  /// Stage line — includes the step number.
  final String eyebrow;

  /// Question counter — `1 / 5`.
  final String count;

  /// The question, in the content language (never translated).
  final String prompt;

  /// Optional line in the gloss locale (decision ③). `null` hides it.
  final String? promptGloss;

  /// `.quiz-head { padding: 8px 2px 0 }`, `.q-title { margin-top: 12px }`.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(2, 8, 2, 0);
  static const double promptGap = 12;

  /// `.quiz-head .eyebrow { letter-spacing: .13em }` — purple, unlike S3's
  /// head: the hand-off paints this one with the base `.eyebrow`.
  static const double eyebrowTracking = 0.13;

  /// `.q-title { max-width: 310px }`.
  static const double promptMaxWidth = 310;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  eyebrow,
                  key: const Key('quiz-eyebrow'),
                  style: AppTypography.label.copyWith(
                    color: AppColors.primary,
                    letterSpacing: eyebrowTracking * 11,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                count,
                key: const Key('quiz-count'),
                // `.meta-count`: 500 ink-3 with tabular figures.
                style: AppTypography.tabular(
                  AppTypography.meta.copyWith(color: AppColors.ink3),
                ),
              ),
            ],
          ),
          const SizedBox(height: promptGap),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: promptMaxWidth),
            child: Text(
              prompt,
              key: const Key('quiz-prompt'),
              // `.q-title { 600 25px/1.34 serif; letter-spacing: -.012em }` on
              // the nearest serif step (H2).
              style: AppTypography.h2.copyWith(
                color: AppColors.ink,
                letterSpacing: -0.012 * 22,
              ),
            ),
          ),
          if (promptGloss != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              promptGloss!,
              style: AppTypography.meta.copyWith(color: AppColors.ink3),
            ),
          ],
        ],
      ),
    );
  }
}

/// `.quiz-progress-note` — the rule of the exercise, stated once per question.
class QuizTipBar extends StatelessWidget {
  const QuizTipBar({super.key, required this.text});

  /// "You can try again even if you miss…" — localised by the caller.
  final String text;

  /// `.quiz-progress-note { margin-top: 16px; gap: 6px }`, glyph 13 dp.
  static const EdgeInsets padding = EdgeInsets.only(top: 16);
  static const double gap = 6;
  static const double iconSize = 13;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
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

/// Words worth marking inside the evidence sentence.
///
/// Deliberately conservative (design-spec §4.5: "命中不到就不高亮"): only words
/// of four or more latin letters taken from the **correct option**, matched on
/// a word boundary against the evidence sentence, at most three, in the order
/// they appear. No overlap means no highlight at all — a wrong colour block is
/// worse than no block.
List<String> evidenceHighlights(String correctOption, String evidence) {
  if (correctOption.isEmpty || evidence.isEmpty) return const <String>[];
  final RegExp word = RegExp(r"[A-Za-z][A-Za-z'-]{3,}");
  final List<String> hits = <String>[];
  final Set<String> seen = <String>{};
  for (final RegExpMatch match in word.allMatches(correctOption)) {
    final String token = match.group(0)!;
    if (!seen.add(token.toLowerCase())) continue;
    final RegExp boundary = RegExp(
      '\\b${RegExp.escape(token)}\\b',
      caseSensitive: false,
    );
    if (!boundary.hasMatch(evidence)) continue;
    hits.add(token);
    if (hits.length == 3) break;
  }
  return hits;
}

/// The verdict of one answer, as an [OptionVisualState].
///
/// Before judging, only the picked row differs; afterwards every un-picked row
/// dims — **including the right answer when the learner missed it**, so the
/// feedback never points at the correct option (design-spec §4.5).
OptionVisualState optionVisualState({
  required int option,
  required int? selected,
  required bool submitted,
  required bool correct,
}) {
  if (!submitted) {
    return selected == option
        ? OptionVisualState.selected
        : OptionVisualState.idle;
  }
  if (selected != option) return OptionVisualState.dimmed;
  return correct ? OptionVisualState.correct : OptionVisualState.wrong;
}

/// The `evidence` paragraph of [item], when the pack has one.
String? evidenceParagraph(List<Paragraph> reading, QuizItem item) {
  for (final Paragraph paragraph in reading) {
    if (paragraph.id == item.evidence) return paragraph.text;
  }
  return null;
}
