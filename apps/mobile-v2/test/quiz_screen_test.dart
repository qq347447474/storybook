/// Quiz screen (S4) widget tests under D1 (docs/13): every question must be
/// answered correctly before the next one; a wrong answer never reveals the
/// correct option and only that question can be retried; the run is submitted
/// once, when the last answer is right, and the unlock panel follows.
///
/// `packages/core_content`'s 0.8 guard stays a compatibility net for v1 data —
/// it is not the path this screen takes, and nothing here depends on it.
library;

import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyapp/i18n/app_localizations.dart';
import 'package:storyapp/quiz/quiz_screen.dart';
import 'package:storyapp/reading/reading_controller.dart';
import 'package:storyapp/ui/components/option_row.dart';
import 'package:storyapp/ui/components/unlock_panel.dart';

const String evidenceText = 'She made a paper boat.';

/// 5 questions with known correct answers 0, 1, 2, 3, 0.
Chapter quizChapter() {
  const para = Paragraph(
    id: 'ch1-p1',
    text: evidenceText,
    audio: AudioTimeline(
      url: 'media/ch1-p1.mp3',
      durationMs: 1000,
      sentences: <SpokenSentence>[
        SpokenSentence(text: evidenceText, startMs: 0, endMs: 1000),
      ],
    ),
  );
  QuizItem item(int n, int answer) => QuizItem(
        id: 'ch1-q$n',
        skill: 'detail',
        prompt: 'Question $n prompt?',
        options: const <String>['alpha', 'beta', 'gamma', 'delta'],
        answer: answer,
        explanation: LocalizedText(<String, String>{
          'zh-Hans': '第 $n 题讲解。',
          'en': 'Explanation for question $n.',
        }),
        evidence: 'ch1-p1',
      );

  return Chapter(
    id: 'ch1',
    order: 1,
    title: 'A Rainy Morning',
    available: true,
    estimatedMinutes: 3,
    reading: const <Paragraph>[para],
    vocabulary: const <VocabItem>[],
    quiz: <QuizItem>[
      item(1, 0),
      item(2, 1),
      item(3, 2),
      item(4, 3),
      item(5, 0),
    ],
    retell: const Retell(
      scenes: <Scene>[],
      rubric: Rubric(
        minWords: 10,
        maxSeconds: 60,
        conceptWeight: 0.6,
        fluencyWeight: 0.2,
        completenessWeight: 0.2,
        wpmTargetRange: <int>[70, 120],
      ),
    ),
  );
}

Future<ReadingController> makeController(Directory tmp) async {
  final controller = ReadingController(
    bookId: 'the-paper-boat',
    chapter: quizChapter(),
    packId: 'the-paper-boat',
    contentVersion: '1.0.0',
    progressStore: FileProgressStore(directory: tmp.path),
  );
  await controller.openChapter();
  await controller.markParagraphRead('ch1-p1');
  await controller.markVocabViewed('v-none');
  expect(controller.state.stage, ChapterStage.quiz);
  return controller;
}

Widget wrap(Widget child) => MaterialApp(home: child);

Finder ctaFinder() => find.descendant(
      of: find.byKey(const Key('quiz-dock')),
      matching: find.byType(FilledButton),
    );

FilledButton cta(WidgetTester tester) =>
    tester.widget<FilledButton>(ctaFinder());

OptionVisualState optionState(WidgetTester tester, int index) =>
    tester.widget<OptionRow>(find.byKey(Key('quiz-option-$index'))).state;

/// Picks [option] and submits; leaves the verdict on screen.
Future<void> submit(WidgetTester tester, int option) async {
  await tester.tap(find.byKey(Key('quiz-option-$option')));
  await tester.pumpAndSettle();
  await tester.tap(ctaFinder());
  await tester.pumpAndSettle();
}

/// Answers the current question correctly and walks to the next one.
Future<void> answerCorrect(WidgetTester tester, int option) async {
  await submit(tester, option);
  await tester.tap(ctaFinder());
  await tester.pumpAndSettle();
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('quiz_screen_test');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  testWidgets('submit stays disabled until an option is selected',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final controller = await makeController(tmp);
    await tester.pumpWidget(wrap(QuizScreen(
      controller: controller,
      l10n: l10n,
      defaultGloss: 'en',
    )));
    await tester.pumpAndSettle();

    expect(cta(tester).onPressed, isNull);
    expect(find.text('Choose an answer'), findsOneWidget);
    expect(find.text('3 / 4'), findsOneWidget); // stage bar
    expect(find.text('1 / 5'), findsOneWidget); // question counter

    await tester.tap(find.byKey(const Key('quiz-option-1')));
    await tester.pumpAndSettle();
    expect(cta(tester).onPressed, isNotNull);
    expect(optionState(tester, 1), OptionVisualState.selected);
    expect(optionState(tester, 0), OptionVisualState.idle);
  });

  testWidgets('a wrong answer never marks the correct option and shows evidence',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final controller = await makeController(tmp);
    await tester.pumpWidget(wrap(QuizScreen(
      controller: controller,
      l10n: l10n,
      defaultGloss: 'en',
    )));
    await tester.pumpAndSettle();

    // Q1 answer is option 0; pick option 1.
    await submit(tester, 1);

    expect(find.text('Look back at the story.'), findsOneWidget);
    expect(find.text('You read it.'), findsNothing);
    expect(optionState(tester, 1), OptionVisualState.wrong);
    // The right row is dimmed like every other un-picked row: no reveal.
    for (final int i in <int>[0, 2, 3]) {
      expect(optionState(tester, i), OptionVisualState.dimmed);
    }
    // The evidence sentence from the story is quoted back (§4.5).
    expect(find.text(evidenceText), findsOneWidget);
    expect(find.text('From the story'), findsOneWidget);
    expect(controller.state.stage, ChapterStage.quiz);
  });

  testWidgets('a wrong answer can only be retried on the same question',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final controller = await makeController(tmp);
    await tester.pumpWidget(wrap(QuizScreen(
      controller: controller,
      l10n: l10n,
      defaultGloss: 'en',
    )));
    await tester.pumpAndSettle();

    await answerCorrect(tester, 0); // q1 right -> q2
    expect(find.text('2 / 5'), findsOneWidget);

    await submit(tester, 0); // q2 wrong (answer is 1)
    expect(find.byKey(const Key('quiz-feedback')), findsOneWidget);

    await tester.tap(ctaFinder()); // "Try again"
    await tester.pumpAndSettle();

    // Same question, feedback cleared, nothing selected again.
    expect(find.text('2 / 5'), findsOneWidget);
    expect(find.byKey(const Key('quiz-feedback')), findsNothing);
    expect(cta(tester).onPressed, isNull);
    expect(optionState(tester, 0), OptionVisualState.idle);

    // The earlier correct answer survived: retrying does not rewind the run.
    await answerCorrect(tester, 1);
    expect(find.text('3 / 5'), findsOneWidget);
  });

  testWidgets('the last correct answer submits once and rises the unlock panel',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final controller = await makeController(tmp);
    var retellPushed = false;
    await tester.pumpWidget(wrap(QuizScreen(
      controller: controller,
      l10n: l10n,
      defaultGloss: 'en',
      onContinueToRetell: () => retellPushed = true,
    )));
    await tester.pumpAndSettle();

    for (final int option in <int>[0, 1, 2, 3]) {
      await answerCorrect(tester, option);
    }
    await submit(tester, 0); // last answer, correct

    // Submitted exactly once, at 100 % — the stage is already retell.
    expect(controller.state.stage, ChapterStage.retell);

    // The panel waits a beat so the tick is seen first (§4.5: 650 ms). The
    // number is pinned here; the visible check is that it arrives on its own,
    // without another tap.
    expect(QuizScreen.unlockDelay, const Duration(milliseconds: 650));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.byType(UnlockPanel), findsOneWidget);
    expect(find.text('Ready to retell'), findsOneWidget);
    // No score / percentage / ranking anywhere on the panel.
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('score'), findsWidgets); // "no score" wording only

    // The dock still says "Go to retell" behind the panel — tap the panel's.
    await tester.tap(find.descendant(
      of: find.byType(UnlockPanel),
      matching: find.text('Go to retell'),
    ));
    await tester.pumpAndSettle();
    expect(retellPushed, isTrue);
  });

  testWidgets('the graded submission is the single all-correct attempt',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final controller = await makeController(tmp);
    final store = FileProgressStore(directory: tmp.path);
    await tester.pumpWidget(wrap(QuizScreen(
      controller: controller,
      l10n: l10n,
      defaultGloss: 'en',
    )));
    await tester.pumpAndSettle();

    // A wrong answer mid-run is not submitted at all: it is just retried.
    await answerCorrect(tester, 0);
    await submit(tester, 0); // q2 wrong
    await tester.tap(ctaFinder());
    await tester.pumpAndSettle();
    final midRun =
        (await store.load('the-paper-boat')).chapters['the-paper-boat/ch1']!;
    expect(midRun.quiz.attempts, 0,
        reason: 'a wrong answer is retried, never graded');
    expect(midRun.quiz.correct, 0);

    await answerCorrect(tester, 1);
    await answerCorrect(tester, 2);
    await answerCorrect(tester, 3);
    await submit(tester, 0);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    await controller.save();

    final chapter =
        (await store.load('the-paper-boat')).chapters['the-paper-boat/ch1']!;
    expect(chapter.quiz.attempts, 1);
    expect(chapter.quiz.answered, 5);
    expect(chapter.quiz.correct, 5);
    expect(chapter.quiz.wrongItemIds, isEmpty);
    expect(chapter.status, 'retell');
  });
}
