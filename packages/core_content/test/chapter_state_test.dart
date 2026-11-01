/// ChapterStage state machine tests (`docs/07-modules.md` §2.4).
///
/// Every transition guard gets a positive and a negative case. Out-of-stage
/// events must be strict no-ops (returning the identical instance) so a
/// mis-ordered UI event can never corrupt progress.
library;

import 'package:core_content/core_content.dart';
import 'package:test/test.dart';

ChapterState fresh({bool available = true}) =>
    ChapterState.initial(chapterId: 'ch1', available: available);

ChapterState get atReading => fresh().open();

ChapterState get atVocabulary => atReading
    .markParagraphRead('p1', chapterParagraphIds: <String>{'p1'});

/// Target words of the fixture chapter used by the browse guard.
const Set<String> targetVocabIds = <String>{'w1', 'w2'};

ChapterState get atQuiz => atVocabulary
    .markVocabViewed('w1', targetVocabIds: targetVocabIds)
    .markVocabViewed('w2', targetVocabIds: targetVocabIds);

ChapterState get atRetell =>
    atQuiz.submitQuiz(answers: <String, int>{'q1': 1}, correct: 8, total: 10);

ChapterState get atComplete => atRetell.submitRetellAttempt(
      const RetellAttempt(
        durationMs: 12000,
        wordCount: 40,
        concept: 0.5,
        fluency: 0.5,
        completeness: 0.5,
        total: 0.5,
        missingConceptIds: <String>[],
      ),
    );

RetellAttempt attempt(double total) => RetellAttempt(
      durationMs: 10000,
      wordCount: 30,
      concept: total,
      fluency: total,
      completeness: total,
      total: total,
      missingConceptIds: const <String>[],
    );

void main() {
  group('initial state', () {
    test('available chapter starts unread', () {
      expect(fresh().stage, ChapterStage.unread);
    });

    test('unavailable chapter starts locked', () {
      expect(fresh(available: false).stage, ChapterStage.locked);
    });
  });

  group('locked -> unread (guard: available)', () {
    test('unlock moves locked to unread', () {
      final s = fresh(available: false).unlock();
      expect(s.stage, ChapterStage.unread);
    });

    test('unlock from unread is a no-op', () {
      final s = fresh();
      expect(identical(s.unlock(), s), isTrue);
    });
  });

  group('unread -> reading', () {
    test('open moves unread to reading', () {
      expect(fresh().open().stage, ChapterStage.reading);
    });

    test('open from locked is a no-op', () {
      final s = fresh(available: false);
      expect(identical(s.open(), s), isTrue);
    });
  });

  group('reading -> vocabulary (guard: all paragraphs read)', () {
    const ids = <String>{'p1', 'p2'};

    test('partial reading keeps the stage and records the paragraph', () {
      final s = atReading.markParagraphRead('p1', chapterParagraphIds: ids);
      expect(s.stage, ChapterStage.reading);
      expect(s.readParagraphIds, <String>{'p1'});
    });

    test('reading the last remaining paragraph advances to vocabulary', () {
      final s = atReading
          .markParagraphRead('p1', chapterParagraphIds: ids)
          .markParagraphRead('p2', chapterParagraphIds: ids);
      expect(s.stage, ChapterStage.vocabulary);
      expect(s.readParagraphIds, ids);
    });

    test('re-reading after completion is harmless', () {
      final s = atReading
          .markParagraphRead('p1', chapterParagraphIds: ids)
          .markParagraphRead('p2', chapterParagraphIds: ids)
          .markParagraphRead('p1', chapterParagraphIds: ids);
      expect(s.stage, ChapterStage.vocabulary);
    });

    test('markParagraphRead from unread is a no-op', () {
      final s = fresh();
      expect(
        identical(s.markParagraphRead('p1', chapterParagraphIds: ids), s),
        isTrue,
      );
    });
  });

  group('vocabulary -> quiz (guard: target words browsed)', () {
    test('markVocabViewed advances only after every target is browsed', () {
      final partial =
          atVocabulary.markVocabViewed('w1', targetVocabIds: targetVocabIds);
      expect(partial.stage, ChapterStage.vocabulary);
      expect(partial.viewedVocabIds, <String>{'w1'});
      final done = partial.markVocabViewed('w2', targetVocabIds: targetVocabIds);
      expect(done.stage, ChapterStage.quiz);
    });

    test('markVocabViewed from reading is a no-op', () {
      final base = atReading;
      expect(
        identical(base.markVocabViewed('w1', targetVocabIds: targetVocabIds), base),
        isTrue,
      );
    });
  });

  group('quiz guards (accuracy >= 0.8, boundary inclusive)', () {
    test('exactly 0.8 unlocks retell', () {
      final s =
          atQuiz.submitQuiz(answers: <String, int>{'q1': 0}, correct: 8, total: 10);
      expect(s.stage, ChapterStage.retell);
    });

    test('just below 0.8 stays in quiz but records the answers', () {
      final s =
          atQuiz.submitQuiz(answers: <String, int>{'q1': 2}, correct: 7, total: 10);
      expect(s.stage, ChapterStage.quiz);
      expect(s.quizAnswers, <String, int>{'q1': 2});
    });

    test('7/9 (0.777...) stays in quiz', () {
      final s =
          atQuiz.submitQuiz(answers: <String, int>{'q1': 1}, correct: 7, total: 9);
      expect(s.stage, ChapterStage.quiz);
    });

    test('a clean score unlocks retell', () {
      final s =
          atQuiz.submitQuiz(answers: <String, int>{'q1': 3}, correct: 10, total: 10);
      expect(s.stage, ChapterStage.retell);
    });

    test('decision 7: one qualifying submission unlocks despite earlier fails',
        () {
      final s1 =
          atQuiz.submitQuiz(answers: <String, int>{'q1': 0}, correct: 3, total: 10);
      expect(s1.stage, ChapterStage.quiz);
      final s2 =
          s1.submitQuiz(answers: <String, int>{'q1': 1}, correct: 8, total: 10);
      expect(s2.stage, ChapterStage.retell);
    });

    test('decision 7: retell never falls back on a later low score', () {
      final base = atRetell;
      final s = base.submitQuiz(
          answers: <String, int>{'q1': 0}, correct: 1, total: 10);
      expect(s.stage, ChapterStage.retell);
      expect(identical(s, base), isTrue);
    });

    test('a zero-question quiz passes vacuously', () {
      final s = atQuiz.submitQuiz(answers: const <String, int>{}, correct: 0, total: 0);
      expect(s.stage, ChapterStage.retell);
    });

    test('submitQuiz from reading is a no-op', () {
      final base = atReading;
      expect(
        identical(
          base.submitQuiz(
              answers: <String, int>{'q1': 1}, correct: 10, total: 10),
          base,
        ),
        isTrue,
      );
    });
  });

  group('retell -> complete (guard: any scored attempt, no pass mark)', () {
    test('a low score still completes the chapter', () {
      final s = atRetell.submitRetellAttempt(attempt(0.1));
      expect(s.stage, ChapterStage.complete);
      expect(s.bestRetellScore, 0.1);
      expect(s.retellAttempts, hasLength(1));
    });

    test('practice attempts after complete are recorded and update the best',
        () {
      final s = atComplete.submitRetellAttempt(attempt(0.9));
      expect(s.stage, ChapterStage.complete);
      expect(s.retellAttempts, hasLength(2));
      expect(s.bestRetellScore, 0.9);
    });

    test('a worse practice attempt does not lower the best score', () {
      final s = atComplete.submitRetellAttempt(attempt(0.2));
      expect(s.bestRetellScore, 0.5);
    });

    test('submitRetellAttempt from quiz is a no-op', () {
      final base = atQuiz;
      expect(identical(base.submitRetellAttempt(attempt(0.9)), base), isTrue);
    });
  });

  group('re-read entry (reopenForReading)', () {
    test('complete moves back to reading and keeps every statistic', () {
      final s = atComplete.reopenForReading();
      expect(s.stage, ChapterStage.reading);
      expect(s.bestRetellScore, atComplete.bestRetellScore);
      expect(s.retellAttempts, atComplete.retellAttempts);
      expect(s.quizAnswers, atComplete.quizAnswers);
      expect(s.readParagraphIds, atComplete.readParagraphIds,
          reason: 'kept on purpose: "next" is available at once on a re-read');
      expect(s.viewedVocabIds, atComplete.viewedVocabIds);
    });

    test('retell moves back to reading', () {
      expect(atRetell.reopenForReading().stage, ChapterStage.reading);
    });

    test('reading and unread are no-ops', () {
      final reading = atReading;
      expect(identical(reading.reopenForReading(), reading), isTrue);
      final unread = fresh();
      expect(identical(unread.reopenForReading(), unread), isTrue);
    });

    test('locked, vocabulary and quiz are no-ops too', () {
      final locked = fresh(available: false);
      expect(identical(locked.reopenForReading(), locked), isTrue);
      final vocabulary = atVocabulary;
      expect(identical(vocabulary.reopenForReading(), vocabulary), isTrue);
      final quiz = atQuiz;
      expect(identical(quiz.reopenForReading(), quiz), isTrue);
    });

    test('a re-read re-enters the loop where the guard already passes', () {
      // readParagraphIds survive, so re-marking any paragraph re-evaluates
      // the all-read guard and advances immediately (reading -> vocabulary).
      final s = atComplete.reopenForReading();
      expect(s.stage, ChapterStage.reading);
      final next = s.markParagraphRead('p1',
          chapterParagraphIds: <String>{'p1'});
      expect(next.stage, ChapterStage.vocabulary);
    });
  });

  group('full lifecycle', () {
    test('walks locked -> complete in order', () {
      final s0 = ChapterState.initial(chapterId: 'ch1', available: false);
      expect(s0.stage, ChapterStage.locked);
      final s1 = s0.unlock();
      expect(s1.stage, ChapterStage.unread);
      final s2 = s1.open();
      expect(s2.stage, ChapterStage.reading);
      final s3 = s2.markParagraphRead('p1', chapterParagraphIds: <String>{'p1'});
      expect(s3.stage, ChapterStage.vocabulary);
      final s4 = s3.markVocabViewed('w1', targetVocabIds: <String>{'w1'});
      expect(s4.stage, ChapterStage.quiz);
      final s5 = s4.submitQuiz(
          answers: <String, int>{'q1': 1}, correct: 9, total: 10);
      expect(s5.stage, ChapterStage.retell);
      final s6 = s5.submitRetellAttempt(attempt(0.7));
      expect(s6.stage, ChapterStage.complete);
      expect(s6.bestRetellScore, 0.7);
      expect(s6.chapterId, 'ch1');
    });
  });
}
