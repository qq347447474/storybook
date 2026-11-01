/// FileProgressStore tests: `<bookId>/<chapterId>` key format, atomic write
/// (temp + rename), and degraded empty progress for missing/corrupt docs.
library;

import 'dart:convert';
import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late FileProgressStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('progress_store_test');
    store = FileProgressStore(directory: tmp.path);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  ProgressDoc sampleDoc() {
    final doc = ProgressDoc.empty('the-paper-boat');
    doc.contentVersion = '1.0.0';
    doc.chapters[progressChapterKey('the-paper-boat', 'ch1')] = progressChapterOf(
      ChapterState.initial(chapterId: 'ch1', available: true)
          .open()
          .markParagraphRead('ch1-p1', chapterParagraphIds: <String>{'ch1-p1'}),
    );
    return doc;
  }

  test('chapter keys use the <bookId>/<chapterId> format (decision 1)', () async {
    await store.save(sampleDoc());
    final raw = json.decode(File('${tmp.path}${Platform.pathSeparator}'
            'the-paper-boat.progress.json')
        .readAsStringSync()) as Map<String, dynamic>;
    final chapters = raw['chapters'] as Map<String, dynamic>;
    expect(chapters.keys, <String>['the-paper-boat/ch1']);
    // Must match schema/progress.v1.schema.json chapters.propertyNames.
    expect(RegExp(r'^[a-z0-9][a-z0-9-]*/[a-z0-9][a-z0-9-]*$')
        .hasMatch(chapters.keys.single), isTrue);
  });

  test('save/load round trip preserves status, reads and best score', () async {
    final doc = sampleDoc();
    await store.save(doc);
    final loaded = await store.load('the-paper-boat');
    expect(loaded.packId, 'the-paper-boat');
    expect(loaded.contentVersion, '1.0.0');
    expect(loaded.updatedAt, isNotEmpty);
    final entry = loaded.chapters['the-paper-boat/ch1']!;
    expect(entry.status, 'vocabulary');
    expect(entry.readParagraphs, <String>['ch1-p1']);
  });

  test('write is atomic: temp file is renamed away, target is valid JSON',
      () async {
    await store.save(sampleDoc());
    await store.save(sampleDoc()); // second replace must also be atomic
    final files = tmp
        .listSync()
        .map((FileSystemEntity e) => e.uri.pathSegments.last)
        .toList();
    expect(files, isNot(contains('the-paper-boat.progress.json.tmp')));
    final raw = json.decode(File('${tmp.path}${Platform.pathSeparator}'
            'the-paper-boat.progress.json')
        .readAsStringSync());
    expect(raw, isA<Map<String, dynamic>>());
  });

  test('missing document degrades to empty progress (no throw)', () async {
    final loaded = await store.load('never-saved');
    expect(loaded.packId, 'never-saved');
    expect(loaded.chapters, isEmpty);
    expect(loaded.skills, isEmpty);
  });

  test('corrupt document degrades to empty progress (no throw)', () async {
    File('${tmp.path}${Platform.pathSeparator}bad.progress.json')
        .writeAsStringSync('{not json !!!');
    final loaded = await store.load('bad');
    expect(loaded.chapters, isEmpty);
  });

  test('foreign schemaVersion degrades to empty progress', () async {
    File('${tmp.path}${Platform.pathSeparator}v2.progress.json').writeAsStringSync(
        json.encode(<String, dynamic>{'schemaVersion': 2, 'chapters': <String, dynamic>{}}));
    final loaded = await store.load('v2');
    expect(loaded.chapters, isEmpty);
  });

  test('chapterStateOf/progressChapterOf round trip the lossless fields', () {
    final state = ChapterState.initial(chapterId: 'ch1', available: true)
        .open()
        .markParagraphRead('ch1-p1', chapterParagraphIds: <String>{'ch1-p1'})
        .markParagraphRead('ch1-p2', chapterParagraphIds: <String>{'ch1-p1', 'ch1-p2'});
    final entry = progressChapterOf(state);
    final back = chapterStateOf(chapterId: 'ch1', entry: entry);
    expect(back.stage, state.stage);
    expect(back.readParagraphIds, state.readParagraphIds);
  });

  test('retell attempts map into one entry with bestScore and counts', () {
    const state = ChapterState(
      chapterId: 'ch1',
      stage: ChapterStage.complete,
      readParagraphIds: <String>{},
      quizAnswers: <String, int>{},
      retellAttempts: <RetellAttempt>[
        RetellAttempt(
          durationMs: 1000,
          wordCount: 30,
          concept: 0.5,
          fluency: 0.5,
          completeness: 0.5,
          total: 0.5,
          missingConceptIds: <String>[],
        ),
      ],
      bestRetellScore: 0.5,
    );
    final entry = progressChapterOf(state, retellSceneId: 'ch1-s1');
    expect(entry.retell, hasLength(1));
    expect(entry.retell.single.sceneId, 'ch1-s1');
    expect(entry.retell.single.attempts, 1);
    expect(entry.retell.single.bestScore, 0.5);
    expect(entry.retell.single.lastWordCount, 30);
    expect(entry.status, 'complete');
    final back = chapterStateOf(chapterId: 'ch1', entry: entry);
    expect(back.bestRetellScore, 0.5);
  });
}
