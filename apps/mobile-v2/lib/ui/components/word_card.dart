/// S3 word card — the content layer of [FlipCard] (design-spec §5.6,
/// `.flip-face` … `.back-foot` app.css L1974-2156).
///
/// Front: part-of-speech chip, pronunciation button, the word at 34/40 serif,
/// its phonetic, and the "tap to see the meaning" nudge.
/// Back: the word plus its chip, the meaning, the sentence it came from with
/// that word picked out, and the way back.
///
/// Every string, including the two nudges and the screen-reader labels, is a
/// parameter: the card is content, not copy.
///
/// The shell widgets (surface, nudge rule, example box, speaker) live in
/// `word_card_parts.dart` — a part of this library, so they stay private.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../app_icon.dart';
import 'app_chip.dart';
import 'dashed_border.dart';
import 'flip_card.dart';

part 'word_card_parts.dart';

/// A two-sided vocabulary card.
class WordCard extends StatelessWidget {
  const WordCard({
    super.key,
    required this.word,
    required this.phonetic,
    required this.partOfSpeech,
    required this.revealed,
    required this.definition,
    required this.frontHint,
    required this.backHint,
    this.example,
    this.exampleLabel,
    this.exampleTarget,
    this.onToggle,
    this.onSpeakWord,
    this.onSpeakExample,
    this.speakWordLabel,
    this.speakExampleLabel,
    this.height,
  });

  /// Headword, shown on both faces.
  final String word;

  /// IPA transcription, e.g. `/tæpt/`.
  final String phonetic;

  /// Part of speech, e.g. `verb` — rendered as a level chip.
  final String partOfSpeech;

  /// Which face is up. Owned by the caller (see [FlipCard.revealed]).
  final bool revealed;

  /// Meaning of [word] on the back face.
  final String definition;

  /// "Tap the card to read the meaning" — front nudge, localised.
  final String frontHint;

  /// "Tap to go back" — back nudge, localised.
  final String backHint;

  /// The sentence from the story. The example box is omitted when null.
  final String? example;

  /// Micro label above the example sentence, e.g. "In the story"
  /// (`.example-label`, app.css L2125). Omitted when null.
  final String? exampleLabel;

  /// The word to emphasise inside [example], painted in `primary` bold — the
  /// Flutter equivalent of the hand-off's `<strong>` (app.css L2136-2139).
  final String? exampleTarget;

  /// Flip callback. `null` freezes the card.
  final VoidCallback? onToggle;

  /// Front speaker: pronunciation of the headword. `null` dims the button
  /// (design-spec §5.6 still ships the card when speech is unavailable) —
  /// which is what a pack generated before the word clip existed gets.
  final VoidCallback? onSpeakWord;

  /// Back speaker: the example sentence read out loud.
  final VoidCallback? onSpeakExample;

  /// Screen-reader label for the front speaker.
  final String? speakWordLabel;

  /// Screen-reader label for the back speaker.
  final String? speakExampleLabel;

  /// Card height; `null` keeps [FlipCard]'s 280 dp. A screen that runs with a
  /// large text scale passes a taller card instead of letting a face overflow
  /// (the hand-off draws it at 356 dp).
  final double? height;

  /// `.word-main { font: 600 47px/1.1 }` (app.css L2067) → the spec's 34–40 px.
  /// Only the family, weight and tracking are overridden so the size stays on
  /// the Display step (design-spec §2.3 — seven steps, no eighth).
  static final TextStyle wordStyle = AppTypography.display.copyWith(
    fontFamily: AppTypography.serifFamily,
    fontFamilyFallback: AppTypography.serifFallback,
    fontWeight: FontWeight.w600,
    height: 40 / 34,
    letterSpacing: -0.02 * 34,
    color: AppColors.ink,
  );

  /// `.audio-btn:disabled` has no hand-off class; `.round-btn:disabled` (0.4)
  /// is the closest documented dim, so one number drives both speakers.
  static const double audioDisabledOpacity = 0.4;

  /// Front speaker: `44dp 热区` (design-spec §5.6). Back speaker: the hand-off
  /// draws 36 dp, which design-spec §7.5 forbids as a *target* — so it keeps the
  /// 36 dp circle and grows an invisible 44 dp hot zone around it.
  static const double frontSpeakSize = 44;
  static const double backSpeakSize = 36;
  static const double backSpeakTarget = 44;

  /// `.flip-face { padding: 20px }` (app.css L1981).
  static const EdgeInsets _facePadding = EdgeInsets.all(20);

  @override
  Widget build(BuildContext context) {
    return FlipCard(
      revealed: revealed,
      onToggle: onToggle,
      height: height ?? 280,
      front: _front(),
      back: _back(),
    );
  }

  Widget _front() {
    return _Face(
      child: Stack(
        children: <Widget>[
          // `.flip-face--front::after` — 210 dp brand halo in the corner.
          Positioned(
            top: -70,
            right: -70,
            width: 210,
            height: 210,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    AppColors.primaryGhost,
                    AppColors.primaryGhost.withValues(alpha: 0),
                  ],
                  stops: const <double>[0, 0.68],
                ),
              ),
            ),
          ),
          Padding(
            padding: _facePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    AppChip(partOfSpeech, variant: AppChipVariant.level),
                    const Spacer(),
                    _AudioButton(
                      size: frontSpeakSize,
                      onPressed: onSpeakWord,
                      label: speakWordLabel,
                    ),
                  ],
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        word,
                        style: wordStyle,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        phonetic,
                        // `.word-ipa`: 400 13px, ink-3 — Meta is the only step
                        // at that weight and size.
                        style: AppTypography.meta.copyWith(
                          color: AppColors.ink3,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                _Nudge(text: frontHint),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _back() {
    return _Face(
      child: Padding(
        padding: _facePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // `.back-head`: word + chip, 1 px rule underneath.
            Container(
              padding: const EdgeInsets.only(bottom: 13),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      word,
                      style: AppTypography.h2.copyWith(color: AppColors.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  AppChip(partOfSpeech, variant: AppChipVariant.level),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(definition, style: _definitionStyle),
            const Spacer(),
            if (example != null)
              _ExampleBox(
                text: example!,
                label: exampleLabel,
                target: exampleTarget,
              ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(child: Text(backHint, style: _hintStyle)),
                _AudioButton(
                  size: backSpeakSize,
                  tapTarget: backSpeakTarget,
                  onPressed: onSpeakExample,
                  label: speakExampleLabel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// `.back-def`: sans 500, 1.55 line height, `--ink`.
final TextStyle _definitionStyle = AppTypography.body.copyWith(
  color: AppColors.ink,
  fontWeight: FontWeight.w500,
  height: 1.55,
);

/// `.flip-nudge` / `.back-tap`: 500, ink-3.
final TextStyle _hintStyle = AppTypography.meta.copyWith(color: AppColors.ink3);
