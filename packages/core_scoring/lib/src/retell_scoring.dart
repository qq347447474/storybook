/// Oral retell scoring: three weighted factors over a normalized transcript
/// (`docs/04-scoring.md` §2, `docs/07-modules.md` §3.2). Pure functions only
/// (C3): no clock, no randomness, no IO, no platform APIs.
library;

import 'dart:math' as math;

import 'package:core_content/core_content.dart';

import 'normalization.dart';

/// One ASR output ready for scoring.
class Transcript {
  const Transcript({
    required this.text,
    required this.durationMs,
    required this.pauseGapsMs,
  });

  /// Raw ASR text; normalization happens inside [scoreRetell] (decision ②).
  final String text;

  /// Total speech duration in milliseconds.
  final int durationMs;

  /// Durations of the pauses detected by VAD, in milliseconds.
  final List<int> pauseGapsMs;
}

/// Three-factor retell score. All factors are normalized to 0..1.
class RetellScore {
  const RetellScore({
    required this.concept,
    required this.fluency,
    required this.completeness,
    required this.total,
    required this.missingConceptIds,
    required this.feedbackKeys,
  });

  /// Concept coverage (weighted by `rubric.conceptWeight`).
  final double concept;

  /// Pace and pausing quality (weighted by `rubric.fluencyWeight`).
  final double fluency;

  /// Utterance length vs the target (weighted by `rubric.completenessWeight`).
  final double completeness;

  /// Weighted sum of the three factors.
  final double total;

  /// Ids of the concepts with no hit, in scene order.
  final List<String> missingConceptIds;

  /// i18n keys only (C4) — never ready-made copy. Placeholders such as
  /// `{hit}` are filled in by the UI layer.
  final List<String> feedbackKeys;
}

/// Scores one retell attempt.
///
/// - Normalization (fixed English rules, decision ②): lowercase, contraction
///   expansion, numbers 0-999 to words, punctuation to spaces, then
///   deterministic suffix stemming (`raining`/`rained`/`rain` are equal).
/// - Concept coverage (decision ⑤): all `scenes[].concepts` form one pool;
///   a concept is hit when any of its `terms` appears (word-boundary, after
///   stemming). Any missed `required: true` concept clamps coverage to 0.5.
/// - Fluency (decision ⑥): `span = max - min` of `rubric.wpmTargetRange`;
///   more than 3 pauses longer than 2000 ms multiply fluency by 0.8.
/// - Completeness (decision ⑤): `min(1, wordCount / Σ scene.targetWordCount)`.
RetellScore scoreRetell({
  required Transcript transcript,
  required List<Scene> scenes,
  required Rubric rubric,
}) {
  final List<String> tokens = normalizeWords(transcript.text);
  final List<String> stems = tokens.map(stemWord).toList(growable: false);
  final int wordCount = stems.length;

  // --- concept coverage: one merged pool across all scenes (decision ⑤) ---
  final List<Concept> concepts = <Concept>[
    for (final Scene scene in scenes) ...scene.concepts,
  ];
  final missingConceptIds = <String>[];
  var hits = 0;
  for (final Concept concept in concepts) {
    if (_conceptHit(concept.terms, stems)) {
      hits += 1;
    } else {
      missingConceptIds.add(concept.id);
    }
  }
  double coverage = concepts.isEmpty ? 1.0 : hits / concepts.length;
  final bool requiredMissed = concepts.any(
    (Concept c) => c.required && missingConceptIds.contains(c.id),
  );
  if (requiredMissed) {
    coverage = math.min(coverage, 0.5);
  }

  // --- fluency ---
  double fluency;
  if (transcript.durationMs <= 0) {
    fluency = 0.0;
  } else {
    final double wpm = wordCount / (transcript.durationMs / 60000.0);
    final double lo = rubric.wpmTargetRange[0].toDouble();
    final double hi = rubric.wpmTargetRange[1].toDouble();
    final double mid = (lo + hi) / 2.0;
    final double span = hi - lo; // decision ⑥: full width, not half-width
    if (span <= 0) {
      fluency = wpm == mid ? 1.0 : 0.0;
    } else {
      final double deviation = (wpm - mid).abs() / span;
      fluency = 1.0 - deviation.clamp(0.0, 1.0);
    }
  }
  final int longPauses =
      transcript.pauseGapsMs.where((int gap) => gap > 2000).length;
  if (longPauses > 3) {
    fluency *= 0.8;
  }

  // --- completeness: denominator is the sum of scene targets (decision ⑤) ---
  int targetTotal = 0;
  for (final Scene scene in scenes) {
    targetTotal += scene.targetWordCount;
  }
  final double completeness = targetTotal <= 0
      ? (wordCount > 0 ? 1.0 : 0.0)
      : math.min(1.0, wordCount / targetTotal);

  // --- weighted total (rubric weights must sum to 1, RUBRIC-SUM) ---
  final double total = rubric.conceptWeight * coverage +
      rubric.fluencyWeight * fluency +
      rubric.completenessWeight * completeness;

  return RetellScore(
    concept: coverage,
    fluency: fluency,
    completeness: completeness,
    total: total,
    missingConceptIds: List<String>.unmodifiable(missingConceptIds),
    feedbackKeys: List<String>.unmodifiable(_feedbackKeys(
      wordCount: wordCount,
      rubric: rubric,
      conceptCount: concepts.length,
      hits: hits,
      fluency: fluency,
    )),
  );
}

/// True when any of [terms] appears in [stems] as a consecutive word run
/// (word-boundary match after stemming; no fuzzy matching beyond that).
bool _conceptHit(List<String> terms, List<String> stems) {
  for (final String term in terms) {
    final List<String> termStems =
        normalizeWords(term).map(stemWord).toList(growable: false);
    if (termStems.isEmpty) continue;
    for (var i = 0; i + termStems.length <= stems.length; i++) {
      var ok = true;
      for (var j = 0; j < termStems.length; j++) {
        if (stems[i + j] != termStems[j]) {
          ok = false;
          break;
        }
      }
      if (ok) return true;
    }
  }
  return false;
}

/// Maps the score to i18n keys only (C4). Conditions:
///
/// - no words recognized -> only `retell.feedback.noSpeech`
/// - wordCount < rubric.minWords -> `retell.feedback.tooShort`
/// - at least one concept hit -> `retell.feedback.concepts`
/// - fluency >= 0.8 -> `retell.feedback.fluencyOk`, otherwise
///   `retell.feedback.fluency`
///
/// Missed concepts are not mapped to a key here: the UI shows them as
/// content concept labels (`missingConceptIds` -> labels), per docs/08 S5.
List<String> _feedbackKeys({
  required int wordCount,
  required Rubric rubric,
  required int conceptCount,
  required int hits,
  required double fluency,
}) {
  if (wordCount == 0) {
    return <String>['retell.feedback.noSpeech'];
  }
  final keys = <String>[];
  if (wordCount < rubric.minWords) {
    keys.add('retell.feedback.tooShort');
  }
  if (conceptCount > 0 && hits >= 1) {
    keys.add('retell.feedback.concepts');
  }
  keys.add(
    fluency >= 0.8 ? 'retell.feedback.fluencyOk' : 'retell.feedback.fluency',
  );
  return keys;
}
