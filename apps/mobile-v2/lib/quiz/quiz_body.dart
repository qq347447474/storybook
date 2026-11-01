/// Answer list, verdict card and scroll body of the S4 quiz (`.options` app.css
/// L2249-2374, `.quiz-feedback` L2376-2464, design-spec §4.5 / §5.8).
///
/// Presentational only: the screen owns the state machine and hands every
/// decision down as a value or a callback.
library;

import 'package:flutter/material.dart';

import '../ui/components/app_feedback.dart';
import '../ui/components/option_row.dart';
import 'quiz_parts.dart';

/// The answer list of one question: `A`, `B`, `C` rows, 10 dp apart.
class QuizOptions extends StatelessWidget {
  const QuizOptions({
    super.key,
    required this.options,
    required this.stateOf,
    required this.onSelect,
  });

  /// Option texts of the current question.
  final List<String> options;

  /// Visual state of row [i] — the screen owns the verdict.
  final OptionVisualState Function(int index) stateOf;

  /// `null` once the question has been judged (§5.5: rows stop answering).
  final ValueChanged<int>? onSelect;

  /// Letters are conventions, not copy (A–D in every locale).
  static const List<String> letters = <String>['A', 'B', 'C', 'D'];

  /// `.options { gap: 10px }` on the 4 pt grid.
  static const EdgeInsets rowPadding = EdgeInsets.only(bottom: 10);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < options.length; i++)
          Padding(
            padding: rowPadding,
            child: OptionRow(
              key: Key('quiz-option-$i'),
              letter: letters[i % letters.length],
              text: options[i],
              state: stateOf(i),
              onTap: onSelect == null ? null : () => onSelect!(i),
            ),
          ),
      ],
    );
  }
}

/// The verdict under the options: one line when right, the story sentence when
/// not (design-spec §5.8 — never the correct option).
class QuizFeedbackArea extends StatelessWidget {
  const QuizFeedbackArea({
    super.key,
    required this.correct,
    required this.correctTitle,
    required this.wrongTitle,
    required this.evidenceText,
    required this.evidenceLabel,
    required this.correctOption,
  });

  /// Which card to paint.
  final bool correct;

  /// "You read it." — success line.
  final String correctTitle;

  /// "Look back at the story." — warning line.
  final String wrongTitle;

  /// Verbatim story sentence; `null` hides the quote (no `evidence` paragraph).
  final String? evidenceText;

  /// Micro label above the quote — "From the story".
  final String evidenceLabel;

  /// Text of the right answer: the only source of highlight keywords.
  final String correctOption;

  @override
  Widget build(BuildContext context) {
    if (correct) {
      return QuizFeedback.success(
        key: const Key('quiz-feedback'),
        title: correctTitle,
      );
    }
    return QuizFeedback.warning(
      key: const Key('quiz-feedback'),
      title: wrongTitle,
      evidenceText: evidenceText,
      evidenceLabel: evidenceLabel,
      // Conservative overlap with the right answer; empty paints no marks.
      highlights: evidenceText == null
          ? const <String>[]
          : evidenceHighlights(correctOption, evidenceText!),
    );
  }
}

/// The scrollable body of S4: head, answers, verdict, then the rule of the
/// exercise. Kept together so the screen reads as a state machine.
class QuizBody extends StatelessWidget {
  const QuizBody({
    super.key,
    required this.padding,
    required this.head,
    required this.options,
    required this.feedback,
    required this.tip,
  });

  /// Page padding (gutter + top nudge + bottom breathing room).
  final EdgeInsets padding;

  /// Eyebrow, counter and the question.
  final QuizHead head;

  /// The answer rows.
  final Widget options;

  /// The verdict under the rows; `null` before the question is judged.
  final Widget? feedback;

  /// The rule of the exercise, always last.
  final String tip;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          head,
          const SizedBox(height: 20),
          options,
          if (feedback != null) ...<Widget>[
            const SizedBox(height: 6),
            feedback!,
          ],
          QuizTipBar(text: tip),
        ],
      ),
    );
  }
}
