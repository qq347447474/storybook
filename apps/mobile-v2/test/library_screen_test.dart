/// Library screen (S0) widget tests: shelf chrome, card reading order,
/// start/continue, reading progress, cover resolution and degradation, empty
/// shelf, settings bypass.
library;

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyapp/i18n/app_localizations.dart';
import 'package:storyapp/library/library_book_row.dart';
import 'package:storyapp/library/library_screen.dart';
import 'package:storyapp/ui/app_illustration.dart';
import 'package:storyapp/ui/components/segmented_bar.dart';

const Paragraph fixtureParagraph = Paragraph(
  id: 'ch1-p1',
  text: 'Ada looked out the window. Rain ran down the glass.',
  audio: AudioTimeline(
    url: 'media/ch1-p1.mp3',
    durationMs: 1000,
    sentences: <SpokenSentence>[],
  ),
);

Chapter chapterOf(
  String id,
  int order,
  String title, {
  List<Paragraph> reading = const <Paragraph>[],
}) =>
    Chapter(
      id: id,
      order: order,
      title: title,
      available: true,
      estimatedMinutes: 3,
      reading: reading,
      vocabulary: const <VocabItem>[],
      quiz: const <QuizItem>[],
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

Book fixtureBook({LocalizedText? blurb}) => Book(
      id: 'the-paper-boat',
      title: 'The Paper Boat',
      blurb: blurb,
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
        author: 'Sample Authoring Unit',
        license: 'proprietary',
        generator: 'ai-assisted',
        sourceNote: 'note',
      ),
      cover: Cover(
        url: 'media/cover.png',
        aspect: 1.5,
        alt: LocalizedText(const <String, String>{'en': 'A girl at a window'}),
      ),
      chapters: <Chapter>[
        chapterOf('ch1', 1, 'One', reading: const <Paragraph>[fixtureParagraph]),
        chapterOf('ch2', 2, 'Two'),
      ],
    );

const Locales fixtureLocales = Locales(
  content: <String>['en-US'],
  gloss: <String>['zh-Hans', 'en'],
  defaultGloss: 'zh-Hans',
);

ContentPack packOf(List<Book> books) => ContentPack(
      schemaVersion: 1,
      contentVersion: '1.0.0',
      minAppVersion: '1.0.0',
      locales: fixtureLocales,
      books: books,
    );

class FakeMediaResolver implements MediaResolver {
  FakeMediaResolver({this.result});

  /// Result returned once [queue] is drained.
  ResolvedMedia? result;

  /// Per-call results (first call first) — lets a retry succeed.
  final List<ResolvedMedia?> queue = <ResolvedMedia?>[];

  int calls = 0;

  @override
  Future<ResolvedMedia?> resolve(String url) async {
    calls++;
    if (queue.isNotEmpty) return queue.removeAt(0);
    return result;
  }
}

const ResolvedMedia bundledCover = ResolvedMedia(
  origin: MediaOrigin.bundled,
  location: 'media/cover.png',
  assetKey: 'assets/content/the-paper-boat/media/cover.png',
);

Widget wrap(Widget child) => MaterialApp(home: child);

/// Pumps S0 on the 360 × 800 dp design canvas (design-spec §2.4).
Future<void> pumpShelf(
  WidgetTester tester, {
  required List<Book> books,
  Map<String, bool> bookStarted = const <String, bool>{},
  Map<String, Map<String, ChapterStage>> chapterStages =
      const <String, Map<String, ChapterStage>>{},
  MediaResolver? mediaResolver,
  void Function(Book book)? onOpenBook,
  VoidCallback? onOpenSettings,
  void Function(Book book)? onDeleteBook,
  Set<String> downloadedBookIds = const <String>{},
  String locale = 'en',
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final AppLocalizations l10n =
      (await tester.runAsync(() => AppLocalizations.load(locale)))!;
  await tester.pumpWidget(wrap(LibraryScreen(
    pack: packOf(books),
    bookStarted: bookStarted,
    chapterStages: chapterStages,
    mediaResolver: mediaResolver,
    l10n: l10n,
    onOpenBook: onOpenBook ?? (Book _) {},
    onOpenSettings: onOpenSettings,
    onDeleteBook: onDeleteBook,
    downloadedBookIds: downloadedBookIds,
  )));
  await tester.pumpAndSettle();
}

/// Switches the shelf to the flat list view (S0 清单).
Future<void> switchToList(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('library-view-list')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('bundled cover loads by asset key and degrades to alt on miss',
      (WidgetTester tester) async {
    await pumpShelf(
      tester,
      books: <Book>[fixtureBook()],
      mediaResolver: FakeMediaResolver(result: bundledCover),
    );

    final Image image = tester.widget<Image>(find.byType(Image).first);
    expect(image.image, isA<AssetImage>(),
        reason: 'bundled origin loads by asset key (T7d-2)');
    expect((image.image as AssetImage).assetName,
        'assets/content/the-paper-boat/media/cover.png');
    // The sample book no longer ships in the bundle, so the decode misses and
    // the cover plate must fall back to its alt label rather than break.
    expect(find.text('A girl at a window'), findsOneWidget,
        reason: 'missing bundled bytes degrade to the alt placeholder');
  });

  testWidgets('shelf shows eyebrow, heading, meta, summary and start CTA',
      (WidgetTester tester) async {
    await pumpShelf(
      tester,
      books: <Book>[fixtureBook()],
      mediaResolver: FakeMediaResolver(result: bundledCover),
      onOpenSettings: () {},
    );

    expect(find.text('Your shelf'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('The Paper Boat'), findsOneWidget);
    expect(find.text('Short story · A2'), findsOneWidget);
    expect(find.text('A2'), findsOneWidget, reason: 'level chip');
    expect(find.text('2 chapters'), findsOneWidget);
    expect(find.text('282 words'), findsOneWidget);
    // No blurb in this fixture: the summary falls back to the book's own
    // opening sentence (content data, not catalog copy).
    expect(find.text('Ada looked out the window.'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget, reason: 'cover pill');
    expect(
        find.text('Fully offline · Story, audio and practice all live on '
            'the device.'),
        findsOneWidget);
    expect(find.text('Start reading'), findsOneWidget);
    expect(
        find.byKey(const Key('library-progress-the-paper-boat')), findsNothing);
  });

  testWidgets('the summary prefers the pack blurb, in the gloss locale',
      (WidgetTester tester) async {
    final Book withBlurb = fixtureBook(
      blurb: LocalizedText(const <String, String>{
        'zh-Hans': '小女孩折了一只纸船，让它在雨中启航。',
        'en': 'A little girl folds a paper boat and sends it sailing.',
      }),
    );

    // UI locale `en`: the en blurb wins over the opening-sentence heuristic.
    await pumpShelf(tester, books: <Book>[withBlurb]);
    expect(
      find.text('A little girl folds a paper boat and sends it sailing.'),
      findsOneWidget,
    );
    expect(find.text('Ada looked out the window.'), findsNothing,
        reason: 'a pack blurb replaces the heuristic line entirely');

    // UI locale `zh-Hans`: the card shows the zh-Hans translation.
    await pumpShelf(tester, books: <Book>[withBlurb], locale: 'zh-Hans');
    expect(find.text('小女孩折了一只纸船，让它在雨中启航。'), findsOneWidget);
  });

  testWidgets('started book shows reading progress N / M and continue CTA',
      (WidgetTester tester) async {
    await pumpShelf(
      tester,
      books: <Book>[fixtureBook()],
      bookStarted: const <String, bool>{'the-paper-boat': true},
      chapterStages: const <String, Map<String, ChapterStage>>{
        'the-paper-boat': <String, ChapterStage>{
          'ch1': ChapterStage.complete,
          'ch2': ChapterStage.reading,
        },
      },
      mediaResolver: FakeMediaResolver(result: bundledCover),
    );

    expect(find.text('Reading progress'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    final SegmentedBar bar = tester.widget<SegmentedBar>(
      find.byKey(const Key('library-segmented-the-paper-boat')),
    );
    expect(bar.total, 2, reason: 'one segment per chapter');
    expect(bar.filled, 1);
    // The bar must actually paint: a childless DecoratedBox collapses to zero
    // height under a loose cross-axis constraint.
    expect(
      tester.getSize(find.byKey(const Key('library-segmented-the-paper-boat')))
          .height,
      6,
    );
    expect(find.text('Continue reading'), findsOneWidget);
    expect(find.text('Start reading'), findsNothing);
  });

  testWidgets('empty pack guides to updating books instead of shipping content',
      (WidgetTester tester) async {
    bool openedSettings = false;
    await pumpShelf(
      tester,
      books: const <Book>[],
      onOpenSettings: () => openedSettings = true,
    );

    expect(find.byKey(const Key('library-empty')), findsOneWidget);
    expect(find.text('Your shelf is empty'), findsOneWidget);
    expect(find.text('Download to read offline'), findsOneWidget);
    expect(find.byType(AppIllustration), findsOneWidget, reason: 'brand mark');
    // The shelf starts empty and is filled only by "Update Books": the CTA
    // and the settings bypass are the two ways there, so both must be live.
    final Finder cta = find.byKey(const Key('library-empty-cta'));
    expect(cta, findsOneWidget);
    expect(find.text('Update Books'), findsWidgets);
    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(openedSettings, isTrue);
  });

  testWidgets('cover keeps its aspect ratio and degrades to alt text + retry',
      (WidgetTester tester) async {
    await pumpShelf(tester, books: <Book>[fixtureBook()]);

    final AspectRatio ratio =
        tester.widget<AspectRatio>(find.byType(AspectRatio).first);
    expect(ratio.aspectRatio, 1.5);
    // Media missing -> placeholder with the cover alt text (uiLocale=en).
    expect(find.text('A girl at a window'), findsOneWidget);
    // ... and a retry control instead of a broken-image glyph (§5.11).
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('retrying the cover resolves it again',
      (WidgetTester tester) async {
    final FakeMediaResolver resolver = FakeMediaResolver();
    await pumpShelf(
      tester,
      books: <Book>[fixtureBook()],
      mediaResolver: resolver,
    );
    expect(resolver.calls, 1);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(resolver.calls, 2, reason: 'retry must re-resolve, not re-render');
  });

  testWidgets('tapping a book fires onOpenBook', (WidgetTester tester) async {
    Book? opened;
    await pumpShelf(
      tester,
      books: <Book>[fixtureBook()],
      mediaResolver: FakeMediaResolver(result: bundledCover),
      onOpenBook: (Book book) => opened = book,
    );

    await tester.tap(find.byKey(const Key('library-book-the-paper-boat')));
    await tester.pumpAndSettle();
    expect(opened?.id, 'the-paper-boat');
  });

  testWidgets('the settings control opens S7', (WidgetTester tester) async {
    bool opened = false;
    await pumpShelf(
      tester,
      books: <Book>[fixtureBook()],
      mediaResolver: FakeMediaResolver(result: bundledCover),
      onOpenSettings: () => opened = true,
    );

    await tester.tap(find.byKey(const Key('library-settings')));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
  });

  testWidgets('long-pressing a downloaded list row confirms, then deletes',
      (WidgetTester tester) async {
    Book? deleted;
    await pumpShelf(
      tester,
      books: <Book>[fixtureBook()],
      mediaResolver: FakeMediaResolver(result: bundledCover),
      onDeleteBook: (Book book) => deleted = book,
      downloadedBookIds: const <String>{'the-paper-boat'},
    );
    await switchToList(tester);

    await tester.longPress(find.byType(LibraryBookRow).first);
    await tester.pumpAndSettle();

    // The dialog names the book and offers the destructive button.
    expect(find.text('Delete “The Paper Boat”?'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(deleted, isNull, reason: 'nothing goes before the confirmation');

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(deleted?.id, 'the-paper-boat');
  });

  testWidgets('cancelling the delete dialog leaves the book alone',
      (WidgetTester tester) async {
    Book? deleted;
    await pumpShelf(
      tester,
      books: <Book>[fixtureBook()],
      mediaResolver: FakeMediaResolver(result: bundledCover),
      onDeleteBook: (Book book) => deleted = book,
      downloadedBookIds: const <String>{'the-paper-boat'},
    );
    await switchToList(tester);

    await tester.longPress(find.byType(LibraryBookRow).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(deleted, isNull);
    expect(find.byType(LibraryBookRow), findsOneWidget,
        reason: 'the row survives a cancelled delete');
  });

  testWidgets('a non-downloaded row raises no delete dialog',
      (WidgetTester tester) async {
    Book? deleted;
    await pumpShelf(
      tester,
      books: <Book>[fixtureBook()],
      mediaResolver: FakeMediaResolver(result: bundledCover),
      onDeleteBook: (Book book) => deleted = book,
      // Nothing downloaded: the bundled title must stay tap-only.
      downloadedBookIds: const <String>{},
    );
    await switchToList(tester);

    await tester.longPress(find.byType(LibraryBookRow).first);
    await tester.pumpAndSettle();

    expect(find.text('Delete “The Paper Boat”?'), findsNothing);
    expect(deleted, isNull);
    expect(find.byType(LibraryBookRow), findsOneWidget);
  });
}
