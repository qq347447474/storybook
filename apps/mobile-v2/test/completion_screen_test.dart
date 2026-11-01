/// Completion screen (S6) widget tests: the four ticked steps, the story's
/// closing line, the eyebrow that names the chapter, the celebration kill
/// switch, and the CTA that leaves the screen (design-spec §4.7).
library;

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyapp/completion/confetti_layer.dart';
import 'package:storyapp/completion/completion_screen.dart';
import 'package:storyapp/i18n/app_localizations.dart';
import 'package:storyapp/ui/components/app_chip.dart';

const Retell _retell = Retell(
  scenes: <Scene>[],
  rubric: Rubric(
    minWords: 10,
    maxSeconds: 60,
    conceptWeight: 0.6,
    fluencyWeight: 0.2,
    completenessWeight: 0.2,
    wpmTargetRange: <int>[70, 120],
  ),
);

Paragraph _paragraph(String id, String text) => Paragraph(
      id: id,
      text: text,
      audio: AudioTimeline(
        url: 'media/$id.mp3',
        durationMs: 8000,
        sentences: <SpokenSentence>[
          SpokenSentence(text: text, startMs: 0, endMs: 8000),
        ],
      ),
    );

VocabItem _word(String id, String lemma, {bool isTarget = true}) => VocabItem(
      id: id,
      lemma: lemma,
      surfaceForm: lemma,
      partOfSpeech: 'noun',
      senseKey: '$lemma:noun+1',
      definition: 'a small pool of water',
      gloss: LocalizedText(const <String, String>{'zh-Hans': '水坑', 'en': 'puddle'}),
      sourceSentence: 'Rain filled the puddle.',
      sourceParagraphId: 'ch2-p1',
      cefr: 'A2',
      isTarget: isTarget,
    );

/// Chapter 2 of the sample book: two paragraphs, two target words, one
/// non-target. Flags let a test drop the text, the words, or both.
Chapter chapter({bool withReading = true, bool withWords = true}) => Chapter(
      id: 'ch2',
      order: 2,
      title: 'Across the Puddle',
      available: true,
      estimatedMinutes: 6,
      reading: withReading
          ? <Paragraph>[
              _paragraph('ch2-p1', 'Rain filled the puddle by the door.'),
              _paragraph('ch2-p2', 'Sail, she whispered. Then the boat moved.'),
            ]
          : const <Paragraph>[],
      vocabulary: withWords
          ? <VocabItem>[
              _word('v1', 'puddle'),
              _word('v2', 'sail'),
              _word('v3', 'whisper', isTarget: false),
            ]
          : const <VocabItem>[],
      quiz: const <QuizItem>[],
      retell: _retell,
    );

Widget wrap(Widget child) => MaterialApp(home: child);

/// The ticked recap chips, in loop order.
List<String> recapLabels(WidgetTester tester) => tester
    .widgetList<AppChip>(find.byWidgetPredicate(
      (Widget w) => w is AppChip && w.icon == 'check',
    ))
    .map((AppChip chip) => chip.label)
    .toList();

void main() {
  testWidgets('the four steps of the loop are all ticked',
      (WidgetTester tester) async {
    final AppLocalizations l10n =
        (await tester.runAsync(() => AppLocalizations.load('en')))!;
    await tester.pumpWidget(wrap(CompletionScreen(
      reduceMotion: true,
      l10n: l10n,
      chapter: chapter(),
      bookTitle: 'The Paper Boat',
    )));
    await tester.pumpAndSettle();

    expect(recapLabels(tester), <String>['Read', 'Words', 'Quiz', 'Retell']);
  });

  testWidgets('the quote card shows the closing line and its credit',
      (WidgetTester tester) async {
    final AppLocalizations l10n =
        (await tester.runAsync(() => AppLocalizations.load('en')))!;
    await tester.pumpWidget(wrap(CompletionScreen(
      reduceMotion: true,
      l10n: l10n,
      chapter: chapter(),
      bookTitle: 'The Paper Boat',
    )));
    await tester.pumpAndSettle();

    // First sentence of the LAST paragraph, verbatim in the content language.
    expect(find.text('Sail, she whispered.'), findsOneWidget);
    expect(find.text('THE PAPER BOAT · CH. 2'), findsOneWidget);
    expect(find.byKey(const Key('completion-quote')), findsOneWidget);
    // The word count clause counts target words (2 of the 3 shipped).
    expect(find.textContaining('2 new words'), findsOneWidget);
  });

  testWidgets('the quote card disappears when the chapter has no text',
      (WidgetTester tester) async {
    final AppLocalizations l10n =
        (await tester.runAsync(() => AppLocalizations.load('en')))!;
    // No reading text, but the chapter did teach words: the quote goes, the
    // word count stays truthful.
    await tester.pumpWidget(wrap(CompletionScreen(
      reduceMotion: true,
      l10n: l10n,
      chapter: chapter(withReading: false),
      bookTitle: 'The Paper Boat',
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('completion-quote')), findsNothing);
    expect(find.textContaining('2 new words'), findsOneWidget);

    // Nothing at all to count: no count clause, only the "no score" tail.
    await tester.pumpWidget(wrap(CompletionScreen(
      reduceMotion: true,
      l10n: l10n,
      chapter: chapter(withReading: false, withWords: false),
      bookTitle: 'The Paper Boat',
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('completion-quote')), findsNothing);
    expect(find.byKey(const Key('completion-body')), findsNothing);
    expect(find.byKey(const Key('completion-body-tail')), findsOneWidget);
  });

  testWidgets('reduce motion removes the confetti entirely',
      (WidgetTester tester) async {
    final AppLocalizations l10n =
        (await tester.runAsync(() => AppLocalizations.load('en')))!;

    await tester.pumpWidget(wrap(CompletionScreen(
      reduceMotion: false,
      l10n: l10n,
      chapter: chapter(),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(ConfettiLayer), findsOneWidget);
    expect(ConfettiPainter.pieces.length, 12);

    // §4.7 减少动效: no confetti at all — not a stiller one.
    await tester.pumpWidget(wrap(CompletionScreen(
      reduceMotion: true,
      l10n: l10n,
      chapter: chapter(),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(ConfettiLayer), findsNothing);

    // The platform flag is folded in on top of the in-app switch (§2.6).
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: CompletionScreen(
            reduceMotion: false,
            l10n: l10n,
            chapter: chapter(),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(ConfettiLayer), findsNothing);
  });

  testWidgets('the eyebrow names the chapter, and degrades without one',
      (WidgetTester tester) async {
    final AppLocalizations l10n =
        (await tester.runAsync(() => AppLocalizations.load('en')))!;
    await tester.pumpWidget(wrap(CompletionScreen(
      reduceMotion: true,
      l10n: l10n,
      chapter: chapter(),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Chapter 2 complete'), findsOneWidget);
    expect(find.text('You told the story.'), findsOneWidget);
    expect(find.textContaining('No score'), findsOneWidget);

    await tester.pumpWidget(wrap(CompletionScreen(
      reduceMotion: true,
      l10n: l10n,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Chapter complete'), findsOneWidget);
  });

  testWidgets('CTA fires onDone', (WidgetTester tester) async {
    final AppLocalizations l10n =
        (await tester.runAsync(() => AppLocalizations.load('en')))!;
    bool done = false;
    await tester.pumpWidget(wrap(CompletionScreen(
      reduceMotion: true,
      l10n: l10n,
      onDone: () => done = true,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('completion-cta')));
    await tester.pumpAndSettle();
    expect(done, isTrue);
  });

  testWidgets('"Read it again" fires onReplay, never the exit action',
      (WidgetTester tester) async {
    final AppLocalizations l10n =
        (await tester.runAsync(() => AppLocalizations.load('en')))!;
    int replayed = 0;
    int done = 0;
    await tester.pumpWidget(wrap(CompletionScreen(
      reduceMotion: true,
      l10n: l10n,
      onDone: () => done += 1,
      onReplay: () => replayed += 1,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('completion-again')));
    await tester.pumpAndSettle();
    expect(replayed, 1, reason: 'the re-read entry owns the ghost action');
    expect(done, 0);

    // No re-read entry wired (S5 callers, tests): the ghost action degrades
    // to the exit action instead of dead-ending.
    await tester.pumpWidget(wrap(CompletionScreen(
      reduceMotion: true,
      l10n: l10n,
      onDone: () => done += 1,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('completion-again')));
    await tester.pumpAndSettle();
    expect(done, 1);
  });
}
