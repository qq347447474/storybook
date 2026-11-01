/// Table of contents (S1) widget tests: chapter order, the three node states
/// (current / complete / locked), the badge that repeats each state in words
/// *and* an icon, the four-segment stage bar, the book-length legend and the
/// locked chapter that is announced as disabled and never opens.
///
/// The keys `contents-chapter-*` and `contents-stage-*` are the contract S0's
/// navigation regression relies on (`test/navigation_chain_test.dart`).
library;

import 'dart:ui' show Tristate;

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyapp/contents/contents_screen.dart';
import 'package:storyapp/i18n/app_localizations.dart';
import 'package:storyapp/ui/app_icon.dart';
import 'package:storyapp/ui/components/app_chip.dart';
import 'package:storyapp/ui/components/segmented_bar.dart';

/// One spoken paragraph of [durationMs] split into [sentences] spans.
Paragraph paragraph(String id, {int durationMs = 38000, int sentences = 2}) =>
    Paragraph(
      id: id,
      text: 'A paper boat waits on the windowsill.',
      audio: AudioTimeline(
        url: 'media/$id.mp3',
        durationMs: durationMs,
        sentences: <SpokenSentence>[
          for (int i = 0; i < sentences; i++)
            SpokenSentence(
              text: 'Sentence $i.',
              startMs: i * 1000,
              endMs: (i + 1) * 1000,
            ),
        ],
      ),
    );

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

Chapter chapter(
  String id,
  int order,
  String title, {
  bool available = true,
  int audioMs = 38000,
  int sentences = 2,
  int estimatedMinutes = 0,
  bool withReading = true,
}) =>
    Chapter(
      id: id,
      order: order,
      title: title,
      available: available,
      estimatedMinutes: estimatedMinutes,
      reading: withReading
          ? <Paragraph>[
              paragraph('$id-p1', durationMs: audioMs, sentences: sentences),
            ]
          : const <Paragraph>[],
      vocabulary: const <VocabItem>[],
      quiz: const <QuizItem>[],
      retell: _retell,
    );

/// Three chapters. `estimatedMinutes` mirrors the sample pack (ch1 = 7,
/// ch2 = 6) so the whole book reads "about 13 min"; the unavailable third
/// chapter ships no content at all — the "not available" state of §4.2.
Book fixtureBook({
  int ch1Minutes = 7,
  int ch2Minutes = 6,
  int audioMs = 38000,
  bool withReading = true,
}) =>
    Book(
      id: 'b1',
      title: 'The Paper Boat',
      series: const Series(id: 's1', name: 'Sample', order: 1),
      level: const Level(
        cefr: 'A2',
        wordCount: 282,
        avgSentenceLen: 9.1,
        ttr: 0.5,
        newWordDensity: 35.5,
        targetWpm: 100,
      ),
      attribution: const Attribution(
        author: 'A',
        license: 'proprietary',
        generator: 'ai-assisted',
        sourceNote: 'n',
      ),
      cover: Cover(
        url: 'media/cover.png',
        aspect: 1.5,
        alt: LocalizedText(const <String, String>{'en': 'alt'}),
      ),
      // Deliberately out of order: the screen must sort by `order`.
      chapters: <Chapter>[
        chapter(
          'ch2',
          2,
          'Chapter Two',
          estimatedMinutes: ch2Minutes,
          audioMs: audioMs,
          withReading: withReading,
        ),
        chapter(
          'ch1',
          1,
          'Chapter One',
          estimatedMinutes: ch1Minutes,
          audioMs: audioMs,
          withReading: withReading,
        ),
        chapter(
          'ch3',
          3,
          'Chapter Three',
          available: false,
          withReading: false,
        ),
      ],
    );

/// Pumps S1 with an explicit catalog and stage map, then waits for layout.
Future<void> pumpContents(
  WidgetTester tester, {
  required AppLocalizations l10n,
  Book? book,
  Map<String, ChapterStage> stages = const <String, ChapterStage>{},
  void Function(Chapter)? onOpen,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: ContentsScreen(
      book: book ?? fixtureBook(),
      chapterStages: stages,
      l10n: l10n,
      onOpenChapter: onOpen ?? (_) {},
    ),
  ));
  await tester.pumpAndSettle();
}

Finder iconNamed(String name) =>
    find.byWidgetPredicate((Widget w) => w is AppIcon && w.name == name);

/// The badge of [chapterId], read as a widget so tone, glyph and label are all
/// asserted from one place.
AppBadge badgeOf(WidgetTester tester, String chapterId) =>
    tester.widget<AppBadge>(find.byKey(Key('contents-stage-$chapterId')));

int stepsOf(WidgetTester tester, String chapterId) => tester
    .widget<SegmentedBar>(find.byKey(Key('contents-steps-$chapterId')))
    .filled;

void main() {
  testWidgets('chapters are listed by order with a node and a badge per state',
      (WidgetTester tester) async {
    final AppLocalizations l10n =
        (await tester.runAsync(() => AppLocalizations.load('en')))!;
    await pumpContents(
      tester,
      l10n: l10n,
      stages: const <String, ChapterStage>{
        // ch1 must be complete before ch2 unlocks (chain rule), so the
        // three display states are: ch1 complete, ch2 current, ch3 locked.
        'ch1': ChapterStage.complete,
        'ch2': ChapterStage.vocabulary,
      },
    );

    // Sorted by order: One, Two, Three (input order was 2,1,3).
    final double y1 =
        tester.getTopLeft(find.byKey(const Key('contents-chapter-ch1'))).dy;
    final double y2 =
        tester.getTopLeft(find.byKey(const Key('contents-chapter-ch2'))).dy;
    final double y3 =
        tester.getTopLeft(find.byKey(const Key('contents-chapter-ch3'))).dy;
    expect(y1, lessThan(y2));
    expect(y2, lessThan(y3));

    // Node: the 36 dp circle of the hand-off in every state.
    for (final String id in <String>['ch1', 'ch2', 'ch3']) {
      expect(
        tester.getSize(find.byKey(Key('contents-node-$id'))),
        const Size(36, 36),
      );
    }
    // Finished one a check; the current one its number; locked one a lock.
    expect(
      find.descendant(
        of: find.byKey(const Key('contents-node-ch1')),
        matching: iconNamed('check'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('contents-node-ch2')),
        matching: find.text('02'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('contents-node-ch3')),
        matching: iconNamed('lock'),
      ),
      findsOneWidget,
    );

    // Badge repeats the state in words AND glyph (§7.2), never colour alone.
    expect(badgeOf(tester, 'ch1').tone, AppBadgeTone.success);
    expect(badgeOf(tester, 'ch1').icon, 'check-circle');
    expect(badgeOf(tester, 'ch1').label, 'Done');
    expect(badgeOf(tester, 'ch2').tone, AppBadgeTone.brand);
    expect(badgeOf(tester, 'ch2').icon, 'cards');
    expect(badgeOf(tester, 'ch2').label, 'Words');
    expect(badgeOf(tester, 'ch3').tone, AppBadgeTone.neutral);
    expect(badgeOf(tester, 'ch3').icon, 'lock');
    expect(badgeOf(tester, 'ch3').label, 'Locked');
  });

  testWidgets('the strip and the chapters heading summarise the book',
      (WidgetTester tester) async {
    final AppLocalizations l10n =
        (await tester.runAsync(() => AppLocalizations.load('en')))!;
    await pumpContents(tester, l10n: l10n);

    expect(find.text('Contents'), findsOneWidget); // app bar
    expect(find.text('The Paper Boat'), findsWidgets); // strip title
    expect(find.text('A2'), findsOneWidget); // level chip
    expect(find.text('3 chapters'), findsOneWidget);
    expect(find.text('Chapters'), findsOneWidget);
    // estimatedMinutes 7 + 6 + 0 — the author's estimate for the whole
    // four-step loop, which is what design-spec §4.2's "约 N 分钟" measures.
    expect(find.text('About 13 min'), findsOneWidget);
    // No resolver in tests: the dashed missing plate, never a broken image.
    expect(find.byType(Image), findsNothing);
    expect(iconNamed('image'), findsOneWidget);
  });

  testWidgets('the length legend falls back to audio, then to sentences',
      (WidgetTester tester) async {
    final AppLocalizations l10n =
        (await tester.runAsync(() => AppLocalizations.load('en')))!;

    // 1. No author estimate anywhere: two 38 s chapters round up to 2 min.
    await pumpContents(
      tester,
      l10n: l10n,
      book: fixtureBook(ch1Minutes: 0, ch2Minutes: 0),
    );
    expect(find.text('About 2 min'), findsOneWidget);

    // 2. Neither estimate nor audio length: the sentence count stands in.
    await pumpContents(
      tester,
      l10n: l10n,
      book: fixtureBook(ch1Minutes: 0, ch2Minutes: 0, audioMs: 0),
    );
    expect(find.text('About 2 min'), findsNothing);
    expect(find.text('4 sentences'), findsOneWidget);
    expect(iconNamed('clock'), findsOneWidget);

    // 3. Nothing truthful to count: the legend is dropped, not faked.
    await pumpContents(
      tester,
      l10n: l10n,
      book: fixtureBook(ch1Minutes: 0, ch2Minutes: 0, withReading: false),
    );
    expect(iconNamed('clock'), findsNothing);
  });

  testWidgets('the four-segment bar counts the steps behind each chapter',
      (WidgetTester tester) async {
    final AppLocalizations l10n =
        (await tester.runAsync(() => AppLocalizations.load('en')))!;
    await pumpContents(
      tester,
      l10n: l10n,
      stages: const <String, ChapterStage>{
        'ch1': ChapterStage.complete,
        'ch2': ChapterStage.quiz,
      },
    );

    // complete = four steps done, quiz = three, locked = none.
    expect(stepsOf(tester, 'ch1'), 4);
    expect(stepsOf(tester, 'ch2'), 3);
    expect(stepsOf(tester, 'ch3'), 0);

    // Chain lock masks a stored stage that has not reached `complete`: ch2
    // cannot sit at "words" while ch1 is only at quiz, and renders as a
    // zero-step locked row. (A stored `complete` is never masked — it keeps
    // its bar even mid re-read, pinned in the re-read regression below.)
    await pumpContents(
      tester,
      l10n: l10n,
      stages: const <String, ChapterStage>{
        'ch1': ChapterStage.quiz,
        'ch2': ChapterStage.vocabulary,
      },
    );
    expect(stepsOf(tester, 'ch2'), 0);
    expect(badgeOf(tester, 'ch2').label, 'Locked');
  });

  testWidgets('a chapter unlocks only after the previous one is complete',
      (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final AppLocalizations l10n =
        (await tester.runAsync(() => AppLocalizations.load('en')))!;
    Chapter? opened;

    // ch1 in progress -> an unfinished ch2 renders locked although the pack
    // ships it available:true; a mid-loop stored stage does not override the
    // chain lock either (only `complete` keeps its access — see the re-read
    // pin in the next test).
    await pumpContents(
      tester,
      l10n: l10n,
      stages: const <String, ChapterStage>{
        'ch1': ChapterStage.reading,
        'ch2': ChapterStage.vocabulary,
      },
      onOpen: (Chapter c) => opened = c,
    );
    expect(badgeOf(tester, 'ch2').label, 'Locked');
    expect(
      find.descendant(
        of: find.byKey(const Key('contents-node-ch2')),
        matching: iconNamed('lock'),
      ),
      findsOneWidget,
    );
    expect(find.text('Continue reading'), findsOneWidget); // ch1 only
    final SemanticsData locked =
        tester.getSemantics(find.byKey(const Key('contents-chapter-ch2')))
            .getSemanticsData();
    expect(locked.flagsCollection.isEnabled, Tristate.isFalse);
    await tester.tap(find.byKey(const Key('contents-chapter-ch2')));
    await tester.pumpAndSettle();
    expect(opened, isNull, reason: 'chain-locked chapters must not open');

    // ch1 complete -> ch2 unlocks and opens.
    await pumpContents(
      tester,
      l10n: l10n,
      stages: const <String, ChapterStage>{'ch1': ChapterStage.complete},
      onOpen: (Chapter c) => opened = c,
    );
    expect(badgeOf(tester, 'ch2').label, 'Read');
    final SemanticsData open =
        tester.getSemantics(find.byKey(const Key('contents-chapter-ch2')))
            .getSemanticsData();
    expect(open.flagsCollection.isEnabled, Tristate.isTrue);
    await tester.tap(find.byKey(const Key('contents-chapter-ch2')));
    await tester.pumpAndSettle();
    expect(opened?.id, 'ch2');
    handle.dispose();
  });

  testWidgets('a finished chapter never re-locks while an earlier one is re-read',
      (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final AppLocalizations l10n =
        (await tester.runAsync(() => AppLocalizations.load('en')))!;
    Chapter? opened;

    // B×C regression: ch2 finished earlier; the learner taps "read it again"
    // on ch1 (reopenForReading: complete -> reading). The chain lock guards
    // *early* entry only — it must never revoke ch2's earned access.
    await pumpContents(
      tester,
      l10n: l10n,
      stages: const <String, ChapterStage>{
        'ch1': ChapterStage.reading,
        'ch2': ChapterStage.complete,
      },
      onOpen: (Chapter c) => opened = c,
    );

    // ch2 keeps its finished presentation: Done badge with the check glyph
    // and a full four-step bar — no lock anywhere on the row.
    expect(badgeOf(tester, 'ch2').label, 'Done');
    expect(badgeOf(tester, 'ch2').icon, 'check-circle');
    expect(stepsOf(tester, 'ch2'), 4);
    expect(
      find.descendant(
        of: find.byKey(const Key('contents-node-ch2')),
        matching: iconNamed('check'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('contents-node-ch2')),
        matching: iconNamed('lock'),
      ),
      findsNothing,
    );

    // Only ch3 (unavailable) still explains itself — ch2 shows no lock note.
    expect(find.text('Waiting to unlock'), findsOneWidget);

    // And it is really openable: announced enabled and the tap opens it.
    final SemanticsData open =
        tester.getSemantics(find.byKey(const Key('contents-chapter-ch2')))
            .getSemanticsData();
    expect(open.flagsCollection.isEnabled, Tristate.isTrue);
    await tester.tap(find.byKey(const Key('contents-chapter-ch2')));
    await tester.pumpAndSettle();
    expect(opened?.id, 'ch2',
        reason: 'a finished chapter must open even mid re-read of ch1');
    handle.dispose();
  });

  testWidgets('a locked chapter is disabled, explains itself and never opens',
      (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final AppLocalizations l10n =
        (await tester.runAsync(() => AppLocalizations.load('en')))!;
    Chapter? opened;
    await pumpContents(
      tester,
      l10n: l10n,
      onOpen: (Chapter c) => opened = c,
    );

    // No progress at all: ch2 is chain-locked (ch1 not complete) and ch3 is
    // unavailable — §4.2 锁定: no CTA, the lock glyph plus "Waiting to
    // unlock" say why. The "Unlocks after the previous chapter" note fills
    // the meta row of a locked chapter with nothing else to report (ch3).
    expect(find.text('Waiting to unlock'), findsNWidgets(2));
    expect(find.text('Unlocks after the previous chapter'), findsOneWidget);
    expect(find.text('Continue reading'), findsOneWidget); // ch1 only

    for (final String id in <String>['ch2', 'ch3']) {
      final SemanticsData locked =
          tester.getSemantics(find.byKey(Key('contents-chapter-$id')))
              .getSemanticsData();
      expect(locked.flagsCollection.isEnabled, Tristate.isFalse,
          reason: 'a locked chapter must be announced as disabled');
      await tester.tap(find.byKey(Key('contents-chapter-$id')));
      await tester.pumpAndSettle();
    }
    expect(opened, isNull, reason: 'locked chapters must not open');

    final SemanticsData open =
        tester.getSemantics(find.byKey(const Key('contents-chapter-ch1')))
            .getSemanticsData();
    expect(open.flagsCollection.isEnabled, Tristate.isTrue);

    await tester.tap(find.byKey(const Key('contents-chapter-ch1')));
    await tester.pumpAndSettle();
    expect(opened?.id, 'ch1');
    handle.dispose();
  });
}
