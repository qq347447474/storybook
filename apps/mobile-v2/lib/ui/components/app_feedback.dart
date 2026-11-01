/// Quiz feedback card (design-spec §5.8, `.quiz-feedback` app.css L2376-2412).
///
/// The card states what happened and what proves it — never that the learner
/// was clever or bad (§5.8: no "great", no "wrong one!"). The sibling notice
/// bar for permission / model states lives in `inline_bar.dart`.
///
/// Strings never live here: [QuizFeedback] receives the already-localised
/// title and the verbatim evidence sentence.
library;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../app_icon.dart';

/// The result banner under the quiz options.
///
/// - [QuizFeedback.success]: green triad, `check-circle`, one line of copy.
/// - [QuizFeedback.warning]: amber triad, `alert`, copy + the story sentence
///   that proves it, with the decisive words highlighted. It must **not**
///   name the correct option (design-spec §5.8, prototype `.quiz-feedback`).
class QuizFeedback extends StatelessWidget {
  /// "Right" state: `.quiz-feedback--success` (app.css L2383).
  const QuizFeedback.success({
    super.key,
    required this.title,
    this.icon = 'check-circle',
  })  : tone = AppTones.success,
        evidenceText = null,
        evidenceLabel = null,
        highlights = const <String>[];

  /// "Not yet" state: `.quiz-feedback--warning` (app.css L2388).
  ///
  /// [evidenceText] is the verbatim story sentence; [highlights] are the
  /// keywords inside it that the learner should re-read, painted in `primary`
  /// — the Flutter equivalent of the hand-off's `<mark>` (app.css L2446).
  const QuizFeedback.warning({
    super.key,
    required this.title,
    required this.evidenceText,
    this.evidenceLabel,
    this.highlights = const <String>[],
    this.icon = 'alert',
  }) : tone = AppTones.warning;

  /// Headline copy, localised by the caller.
  final String title;

  /// Icon name for [AppIcon] — 18 dp, painted in the tone ink.
  final String icon;

  /// Semantic triad that fills and outlines the card.
  final Tone tone;

  /// Verbatim evidence sentence (warning only).
  final String? evidenceText;

  /// Micro label above the evidence, e.g. "From the story". Omitted when null.
  final String? evidenceLabel;

  /// Keywords inside [evidenceText] to emphasise. Case-insensitive.
  final List<String> highlights;

  /// `.quiz-feedback { padding: 13px 14px; border-radius: 16px }`
  /// (app.css L2377-2381).
  static const EdgeInsets _padding = EdgeInsets.symmetric(horizontal: 14, vertical: 13);
  static const double _radius = 16;

  /// `.feedback-line svg { 18px }` (app.css L2399).
  static const double _iconSize = 18;
  static const double _iconGap = 9;

  @override
  Widget build(BuildContext context) {
    // `.feedback-line`: 13 px / 600. The scale has no 13 px step, so Meta
    // (12.5 px) at 600 carries the line without inventing a size.
    final TextStyle lineStyle = AppTypography.meta.copyWith(fontWeight: FontWeight.w600);

    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: tone.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: AppIcon(icon, size: _iconSize, color: tone.ink),
              ),
              const SizedBox(width: _iconGap),
              Expanded(
                child: Text(title, style: lineStyle.copyWith(color: tone.ink)),
              ),
            ],
          ),
          if (evidenceText != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _EvidenceCard(
                text: evidenceText!,
                label: evidenceLabel,
                highlights: highlights,
              ),
            ),
        ],
      ),
    );
  }
}

/// The quoted story sentence of a wrong answer (`.evidence`, app.css L2421).
class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({
    required this.text,
    required this.label,
    required this.highlights,
  });

  final String text;
  final String? label;
  final List<String> highlights;

  @override
  Widget build(BuildContext context) {
    // `.evidence p`: serif, italic, 14/1.6. Of the seven steps the closest to
    // 14 px is Body (15 px), not Reading (18 px) — the quote is evidence
    // *inside* the card, so it must stay below the heading's weight, not above
    // it. Family and italic come from the hand-off; the step does not move.
    final TextStyle quote = AppTypography.body.copyWith(
      fontFamily: AppTypography.serifFamily,
      fontFamilyFallback: AppTypography.serifFallback,
      fontStyle: FontStyle.italic,
      height: 1.6,
      color: AppColors.ink,
    );
    final TextStyle mark = quote.copyWith(
      color: AppColors.primary,
      fontWeight: FontWeight.w700,
      fontStyle: FontStyle.normal,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        // app.css L2424 paints `surface` at .72 over the amber card.
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        // app.css L2423: `rgba(133,87,20,.16)` — the warning ink, not a hex.
        border: Border.all(color: AppColors.warningInk.withValues(alpha: 0.16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (label != null) ...<Widget>[
            Row(
              children: <Widget>[
                const AppIcon('book', size: 12, color: AppColors.warningInk),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label!,
                    style: AppTypography.label.copyWith(color: AppColors.warningInk),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Text.rich(
            TextSpan(
              style: quote,
              children: _highlightSpans(text, highlights, mark),
            ),
          ),
        ],
      ),
    );
  }
}

/// Splits [text] into plain and emphasised runs.
///
/// Matching is case-insensitive and literal (keywords come from content, so a
/// regex metacharacter must never change the result). Overlaps resolve to the
/// first keyword that matches, which is enough for word-level highlights.
List<TextSpan> _highlightSpans(String text, List<String> keywords, TextStyle emphasis) {
  final List<String> usable = keywords.where((String k) => k.trim().isNotEmpty).toList();
  if (usable.isEmpty || text.isEmpty) {
    return <TextSpan>[TextSpan(text: text)];
  }
  final RegExp pattern = RegExp(
    usable.map(RegExp.escape).join('|'),
    caseSensitive: false,
  );

  final List<TextSpan> spans = <TextSpan>[];
  int cursor = 0;
  for (final RegExpMatch match in pattern.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
    }
    spans.add(TextSpan(text: match.group(0), style: emphasis));
    cursor = match.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor)));
  }
  return spans;
}
