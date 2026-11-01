/// Chapter progress state machine (`docs/07-modules.md` §2.4).
///
/// Transitions follow the product table exactly; any event that does not
/// apply to the current stage is a no-op returning the receiver unchanged,
/// so UI event ordering can never crash the app.
library;

/// Ordered stages of one chapter.
enum ChapterStage {
  locked,
  unread,
  reading,
  vocabulary,
  quiz,
  retell,
  complete,
}

/// One scored retell recording. Scores are normalized to 0..1.
class RetellAttempt {
  const RetellAttempt({
    required this.durationMs,
    required this.wordCount,
    required this.concept,
    required this.fluency,
    required this.completeness,
    required this.total,
    required this.missingConceptIds,
  });

  final int durationMs;
  final int wordCount;
  final double concept;
  final double fluency;
  final double completeness;
  final double total;
  final List<String> missingConceptIds;
}

/// Immutable progress snapshot of one chapter. Transitions return new
/// instances; [chapterId] stays the same across all of them.
class ChapterState {
  const ChapterState({
    required this.chapterId,
    required this.stage,
    required this.readParagraphIds,
    this.viewedVocabIds = const <String>{},
    required this.quizAnswers,
    required this.retellAttempts,
    required this.bestRetellScore,
  });

  /// State of a fresh chapter: `unread` when available, `locked` otherwise
  /// (table row `locked -> unread`, guard `available = true`).
  factory ChapterState.initial({
    required String chapterId,
    required bool available,
  }) {
    return ChapterState(
      chapterId: chapterId,
      stage: available ? ChapterStage.unread : ChapterStage.locked,
      readParagraphIds: const <String>{},
      viewedVocabIds: const <String>{},
      quizAnswers: const <String, int>{},
      retellAttempts: const <RetellAttempt>[],
      bestRetellScore: 0.0,
    );
  }

  final String chapterId;
  final ChapterStage stage;
  final Set<String> readParagraphIds;

  /// Target vocabulary cards browsed so far (guard input for
  /// `vocabulary -> quiz`). Not persisted in progress v1 (the schema has no
  /// field for it); after a restart the learner re-browses within the
  /// `vocabulary` stage.
  final Set<String> viewedVocabIds;

  /// quizId -> selected option index.
  final Map<String, int> quizAnswers;
  final List<RetellAttempt> retellAttempts;

  /// Max of `RetellAttempt.total` so far, 0..1.
  final double bestRetellScore;

  /// `locked -> unread` when the chapter becomes available.
  ChapterState unlock() {
    if (stage != ChapterStage.locked) return this;
    return _copyWith(stage: ChapterStage.unread);
  }

  /// `unread -> reading` (learner opened the chapter).
  ChapterState open() {
    if (stage != ChapterStage.unread) return this;
    return _copyWith(stage: ChapterStage.reading);
  }

  /// Records a read paragraph while in `reading`; moves to `vocabulary` as
  /// soon as every id in [chapterParagraphIds] has been read at least once
  /// (guard: "all paragraphs read").
  ///
  /// No-op in any other stage. Unknown ids are recorded but never advance the
  /// guard, because they do not appear in [chapterParagraphIds].
  ChapterState markParagraphRead(
    String paragraphId, {
    required Set<String> chapterParagraphIds,
  }) {
    if (stage != ChapterStage.reading) return this;
    final read = Set<String>.from(readParagraphIds)..add(paragraphId);
    final allRead = chapterParagraphIds.every(read.contains);
    return _copyWith(
      readParagraphIds: read,
      stage: allRead ? ChapterStage.vocabulary : stage,
    );
  }

  /// Records one browsed vocabulary card; moves to `quiz` as soon as every
  /// id in [targetVocabIds] has been browsed (guard: "target words browsed",
  /// symmetric with the all-paragraphs guard of [markParagraphRead]).
  ///
  /// No-op in any other stage. Ids outside [targetVocabIds] are recorded but
  /// never advance the guard.
  ChapterState markVocabViewed(
    String vocabId, {
    required Set<String> targetVocabIds,
  }) {
    if (stage != ChapterStage.vocabulary) return this;
    final viewed = Set<String>.from(viewedVocabIds)..add(vocabId);
    final allViewed = targetVocabIds.every(viewed.contains);
    return _copyWith(
      viewedVocabIds: viewed,
      stage: allViewed ? ChapterStage.quiz : stage,
    );
  }

  /// Records one quiz submission and applies the 0.8 unlock guard.
  ///
  /// - accuracy = `total <= 0` ? 1.0 (vacuously perfect) : `correct / total`
  /// - accuracy >= 0.8 -> `retell` (decision ⑦: any single submission that
  ///   reaches 0.8 unlocks retell; already-unlocked never falls back)
  /// - accuracy < 0.8 -> stays `quiz` for a retry
  ///
  /// No-op outside `quiz`, so a later low score can never relock `retell`.
  ChapterState submitQuiz({
    required Map<String, int> answers,
    required int correct,
    required int total,
  }) {
    if (stage != ChapterStage.quiz) return this;
    final accuracy = total <= 0 ? 1.0 : correct / total;
    return _copyWith(
      quizAnswers: Map<String, int>.unmodifiable(answers),
      stage: accuracy >= 0.8 ? ChapterStage.retell : stage,
    );
  }

  /// Records one scored retell recording. Any score completes the chapter
  /// (`retell -> complete`, no pass mark). Further attempts after `complete`
  /// are still recorded (practice runs update the history and the best score)
  /// but cause no stage transition.
  ///
  /// No-op before the `retell` stage.
  ChapterState submitRetellAttempt(RetellAttempt attempt) {
    if (stage != ChapterStage.retell && stage != ChapterStage.complete) {
      return this;
    }
    final attempts = List<RetellAttempt>.from(retellAttempts)..add(attempt);
    final best =
        attempt.total > bestRetellScore ? attempt.total : bestRetellScore;
    return _copyWith(
      retellAttempts: attempts,
      bestRetellScore: best,
      stage: ChapterStage.complete,
    );
  }

  /// `complete | retell -> reading` — the "read it again" entry (S6).
  ///
  /// Lightweight re-entry: only the stage moves, every statistic survives
  /// ([bestRetellScore], [quizAnswers], [retellAttempts] and — deliberately —
  /// [readParagraphIds], so the all-paragraphs guard is already satisfied and
  /// the "next" step is available immediately on the re-read). History is
  /// never rewritten and nothing throws: every other stage returns `this`.
  ChapterState reopenForReading() {
    if (stage != ChapterStage.complete && stage != ChapterStage.retell) {
      return this;
    }
    return _copyWith(stage: ChapterStage.reading);
  }

  ChapterState _copyWith({
    ChapterStage? stage,
    Set<String>? readParagraphIds,
    Set<String>? viewedVocabIds,
    Map<String, int>? quizAnswers,
    List<RetellAttempt>? retellAttempts,
    double? bestRetellScore,
  }) {
    return ChapterState(
      chapterId: chapterId,
      stage: stage ?? this.stage,
      readParagraphIds: readParagraphIds ?? this.readParagraphIds,
      viewedVocabIds: viewedVocabIds ?? this.viewedVocabIds,
      quizAnswers: quizAnswers ?? this.quizAnswers,
      retellAttempts: retellAttempts ?? this.retellAttempts,
      bestRetellScore: bestRetellScore ?? this.bestRetellScore,
    );
  }
}
