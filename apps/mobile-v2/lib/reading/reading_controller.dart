/// Reading screen controller: bridges the chapter state machine
/// (`core_content`) and progress persistence (`docs/07-modules.md` §5).
///
/// Lifecycle contract: the caller runs [openChapter] before presenting the
/// screen and may call [save] at any time; [markParagraphRead] persists on
/// every transition so a killed process never loses progress.
library;

import 'package:core_content/core_content.dart';
import 'package:core_scoring/core_scoring.dart';
import 'package:flutter/foundation.dart';

import '../settings/app_settings.dart';

class ReadingController extends ChangeNotifier {
  ReadingController({
    required this.bookId,
    required this.chapter,
    required this.packId,
    required this.contentVersion,
    required ProgressStore progressStore,
    this.appSettings,
  })  : _store = progressStore,
        _state = ChapterState.initial(
          chapterId: chapter.id,
          available: chapter.available,
        );

  final String bookId;
  final Chapter chapter;
  final String packId;
  final String contentVersion;
  final ProgressStore _store;

  /// Shared user settings; when present its values win over the persisted
  /// defaults (decision ③: glossLocale is user-settable on S7).
  final AppSettings? appSettings;

  ChapterState _state;
  ProgressDoc? _doc;
  ProgressQuiz? _quizStats;
  final Map<String, ProgressRetellEntry> _retellByScene =
      <String, ProgressRetellEntry>{};
  bool _opened = false;

  ChapterState get state => _state;

  /// Real quiz statistics for progress persistence (T5: attempts cumulative,
  /// answered/correct/wrongItemIds from the latest graded QuizResult).
  ProgressQuiz? get quizStats => _quizStats;

  /// Gloss locale for support-language fields (decision ③): shared app
  /// settings first, then progress settings, default `zh-Hans`.
  String get glossLocale =>
      appSettings?.glossLocale ?? _doc?.settings.glossLocale ?? 'zh-Hans';

  /// Ids of the `isTarget` vocabulary items (browse-guard input).
  Set<String> get targetVocabIds => chapter.vocabulary
      .where((VocabItem v) => v.isTarget)
      .map((VocabItem v) => v.id)
      .toSet();

  /// Paragraph ids of the chapter (state machine guard input).
  Set<String> get paragraphIds =>
      chapter.reading.map((Paragraph p) => p.id).toSet();

  /// Progress key of this chapter: `<bookId>/<chapterId>` (decision ①).
  String get progressKey => progressChapterKey(bookId, chapter.id);

  /// Loads stored progress and applies the `unread -> reading` transition
  /// (opening the reading screen is that event). Idempotent.
  ///
  /// A chapter that resolves to `locked` (pack `available=false`) never
  /// opens: no stage transition and no rewrite of the stored entry — the
  /// chain guard in the app shell is the primary defence, this is the
  /// controller's own "return early" (S1 rule).
  Future<void> openChapter() async {
    _doc = await _store.load(packId);
    final ProgressChapter? entry = _doc!.chapters[progressKey];
    if (entry != null) {
      _state = chapterStateOf(chapterId: chapter.id, entry: entry);
      _quizStats = entry.quiz;
      for (final ProgressRetellEntry e in entry.retell) {
        _retellByScene[e.sceneId] = e;
      }
    }
    if (_state.stage == ChapterStage.locked) {
      _opened = true;
      notifyListeners();
      return;
    }
    if (!_opened && _state.stage == ChapterStage.unread) {
      _state = _state.open();
    }
    _opened = true;
    notifyListeners();
    await save();
  }

  /// Records a visible paragraph (`reading -> vocabulary` fires once every
  /// paragraph has been read) and persists immediately.
  ///
  /// An already-read paragraph is NOT skipped: on a re-read
  /// ([reopenForReading] keeps `readParagraphIds`) re-evaluating the all-read
  /// guard is exactly what advances `reading -> vocabulary` at once, so the
  /// "next" step is available immediately. Notify/persist only fire when
  /// something meaningfully changed (stage or a newly recorded paragraph).
  Future<void> markParagraphRead(String paragraphId) async {
    final ChapterState before = _state;
    _state = _state.markParagraphRead(
      paragraphId,
      chapterParagraphIds: paragraphIds,
    );
    if (before.stage != _state.stage ||
        before.readParagraphIds.length != _state.readParagraphIds.length) {
      notifyListeners();
      await save();
    }
  }

  /// Records one browsed vocabulary card. `vocabulary -> quiz` fires only
  /// after every target word has been browsed (the state-machine guard).
  Future<void> markVocabViewed(String vocabId) async {
    if (_state.viewedVocabIds.contains(vocabId)) return;
    final ChapterState before = _state;
    _state = _state.markVocabViewed(vocabId, targetVocabIds: targetVocabIds);
    if (!identical(before, _state)) {
      notifyListeners();
      await save();
    }
  }

  /// Grades one full quiz attempt (decision ⑦: any attempt with accuracy
  /// >= 0.8 unlocks retell and never falls back) and persists real quiz
  /// statistics (attempts cumulative across sessions).
  Future<void> submitQuizAttempt({
    required Map<String, int> answers,
    required QuizResult result,
  }) async {
    _state = _state.submitQuiz(
      answers: answers,
      correct: result.correct,
      total: result.total,
    );
    _quizStats = ProgressQuiz(
      attempts: (_quizStats?.attempts ?? 0) + 1,
      answered: result.total,
      correct: result.correct,
      wrongItemIds: List<String>.from(result.wrongQuizIds),
    );
    notifyListeners();
    await save();
  }

  /// Records one scored retell attempt (decision ⑦: any score completes the
  /// chapter, attempts after `complete` are still recorded for practice) and
  /// persists a per-scene progress entry (schema `retell[]`).
  ///
  /// Empty recognitions (`noSpeech`) are NOT submitted — docs/09 §8 counts
  /// them as "allow a re-record", not as an attempt.
  Future<void> submitRetellAttempt({
    required String sceneId,
    required RetellAttempt attempt,
    List<String> conceptHitIds = const <String>[],
  }) async {
    _state = _state.submitRetellAttempt(attempt);
    final ProgressRetellEntry entry = _retellByScene.putIfAbsent(
      sceneId,
      () => ProgressRetellEntry(
        sceneId: sceneId,
        attempts: 0,
        bestScore: 0.0,
        lastConceptHits: const <String>[],
        lastWordCount: 0,
        lastDurationMs: 0,
      ),
    );
    entry.attempts += 1;
    if (attempt.total > entry.bestScore) entry.bestScore = attempt.total;
    entry.lastConceptHits = List<String>.from(conceptHitIds);
    entry.lastWordCount = attempt.wordCount;
    entry.lastDurationMs = attempt.durationMs;
    notifyListeners();
    await save();
  }

  /// S6 "read it again": re-enters the reading step without rewriting the
  /// chapter's history — [ChapterState.reopenForReading] keeps the best retell
  /// score, the quiz statistics (attempts / wrongItemIds live in [quizStats]
  /// and survive untouched) and the read paragraphs. The stage change is
  /// persisted like every other transition.
  Future<void> reopenForReading() async {
    final ChapterState before = _state;
    _state = _state.reopenForReading();
    if (!identical(before, _state)) {
      notifyListeners();
      await save();
    }
  }

  /// Persists the current chapter state into the progress document.
  Future<void> save() async {
    _doc ??= await _store.load(packId);
    _doc!.packId = packId;
    _doc!.contentVersion = contentVersion;
    // Settings are owned by AppSettings when wired; copy them at save time
    // so chapter writes never clobber newer S7 preferences.
    final AppSettings? settings = appSettings;
    if (settings != null) {
      _doc!.settings = ProgressSettings(
        uiLocale: settings.uiLocale,
        glossLocale: settings.glossLocale,
        reduceMotion: settings.reduceMotion,
      );
    }
    final ProgressChapter chapter = progressChapterOf(_state, quiz: _quizStats);
    if (_retellByScene.isNotEmpty) {
      // Per-scene aggregation (T7): progressChapterOf collapses attempts
      // into one entry; the screen-level map is the richer source.
      chapter.retell = _retellByScene.values.toList();
    }
    _doc!.chapters[progressKey] = chapter;
    await _store.save(_doc!);
  }
}
