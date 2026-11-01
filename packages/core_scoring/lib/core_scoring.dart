/// Scoring layer of the graded reader: quiz grading (`gradeQuiz`,
/// `weakSkills`) and retell scoring (`scoreRetell`).
///
/// Pure Dart only — this package must never import `package:flutter/*`
/// (constraint C2). All functions must be pure (constraint C3): no clock,
/// no randomness, no file IO, no platform APIs; identical input yields
/// identical output so unit tests are stable.
///
/// Public API is specified in `docs/07-modules.md` §3.
library;

export 'src/quiz_grading.dart';
export 'src/retell_scoring.dart';

/// Identity of this package; referenced by the app shell to verify wiring.
const String coreScoringName = 'core_scoring';
