/// Pack loading and validation tests.
///
/// The happy path reads the real fixture
/// `content/the-paper-boat/pack.json`; every bad-pack case mutates a copy of
/// that fixture and asserts the exact `contentctl` rule code that must fire.
/// Any thrown exception fails the test (C5: parse/validate must not throw).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core_content/core_content.dart';
import 'package:test/test.dart';

const String fixturePath = '../../content/the-paper-boat/pack.json';

String fixtureText() => File(fixturePath).readAsStringSync();

Map<String, dynamic> fixtureMap() =>
    json.decode(fixtureText()) as Map<String, dynamic>;

Future<PackLoadResult> loadText(String text, {String appVersion = '1.0.0'}) {
  final repo = JsonContentRepository(
    appVersion: appVersion,
    readAsset: (String key) async => Uint8List.fromList(utf8.encode(text)),
  );
  return repo.loadFromAsset('pack.json');
}

Future<PackLoadResult> loadMutant(
  void Function(Map<String, dynamic> pack) mutate, {
  String appVersion = '1.0.0',
}) {
  final pack = fixtureMap();
  mutate(pack);
  return loadText(json.encode(pack), appVersion: appVersion);
}

// --- nested access helpers for mutators ---

Map<String, dynamic> bookOf(Map<String, dynamic> pack) =>
    (pack['books'] as List<dynamic>)[0] as Map<String, dynamic>;

Map<String, dynamic> chapterOf(Map<String, dynamic> pack, [int ci = 0]) =>
    (bookOf(pack)['chapters'] as List<dynamic>)[ci] as Map<String, dynamic>;

Map<String, dynamic> paraOf(Map<String, dynamic> pack,
        [int ci = 0, int pi = 0]) =>
    (chapterOf(pack, ci)['reading'] as List<dynamic>)[pi]
        as Map<String, dynamic>;

Map<String, dynamic> audioOf(Map<String, dynamic> pack,
        [int ci = 0, int pi = 0]) =>
    paraOf(pack, ci, pi)['audio'] as Map<String, dynamic>;

Map<String, dynamic> vocabOf(Map<String, dynamic> pack,
        [int ci = 0, int vi = 0]) =>
    (chapterOf(pack, ci)['vocabulary'] as List<dynamic>)[vi]
        as Map<String, dynamic>;

Map<String, dynamic> quizOf(Map<String, dynamic> pack,
        [int ci = 0, int qi = 0]) =>
    (chapterOf(pack, ci)['quiz'] as List<dynamic>)[qi]
        as Map<String, dynamic>;

Map<String, dynamic> retellOf(Map<String, dynamic> pack, [int ci = 0]) =>
    chapterOf(pack, ci)['retell'] as Map<String, dynamic>;

Map<String, dynamic> sceneOf(Map<String, dynamic> pack,
        [int ci = 0, int si = 0]) =>
    (retellOf(pack, ci)['scenes'] as List<dynamic>)[si]
        as Map<String, dynamic>;

Map<String, dynamic> conceptOf(Map<String, dynamic> pack,
        [int ci = 0, int si = 0, int k = 0]) =>
    (sceneOf(pack, ci, si)['concepts'] as List<dynamic>)[k]
        as Map<String, dynamic>;

List<String> codesOf(PackLoadResult result) =>
    (result as PackInvalid).errors.map((PackError e) => e.code).toList();

void main() {
  group('fixture pack (happy path)', () {
    test('loadFromFile returns PackOk with the documented shape', () async {
      final repo = JsonContentRepository(
        appVersion: '1.0.0',
        readAsset: (String key) async =>
            throw StateError('asset reader must not be used'),
      );
      final result = await repo.loadFromFile(fixturePath);
      expect(result, isA<PackOk>());
      final ok = result as PackOk;
      expect(ok.upgradeRecommended, isFalse);
      final pack = ok.pack;
      expect(pack.schemaVersion, 1);
      expect(pack.contentVersion, '1.1.0');
      expect(pack.minAppVersion, '1.0.0');
      expect(pack.books, hasLength(1));
      expect(pack.books.first.id, 'the-paper-boat');
      expect(pack.books.first.chapters, hasLength(2));
      final targets = pack.books.first.chapters
          .expand((Chapter c) => c.vocabulary)
          .where((VocabItem v) => v.isTarget);
      expect(targets, hasLength(10));
      expect(pack.locales.gloss, containsAll(<String>['zh-Hans', 'en']));
      expect(pack.locales.content, contains('en-US'));
      // Decision ④: definition stays a plain String.
      expect(pack.books.first.chapters.first.vocabulary.first.definition,
          isA<String>());
    });

    test('loadFromAsset returns the same pack through the injected reader',
        () async {
      var requested = '';
      final repo = JsonContentRepository(
        appVersion: '1.0.0',
        readAsset: (String key) async {
          requested = key;
          return Uint8List.fromList(utf8.encode(fixtureText()));
        },
      );
      final result = await repo.loadFromAsset('assets/pack.json');
      expect(requested, 'assets/pack.json');
      expect(result, isA<PackOk>());
      expect((result as PackOk).pack.books.first.chapters, hasLength(2));
    });

    test('missing asset yields PackInvalid SCHEMA-NOT-FOUND, no throw',
        () async {
      final repo = JsonContentRepository(
        appVersion: '1.0.0',
        readAsset: (String key) async =>
            throw const FileSystemException('missing'),
      );
      final result = await repo.loadFromAsset('nope.json');
      expect(result, isA<PackInvalid>());
      expect(codesOf(result), contains('SCHEMA-NOT-FOUND'));
    });

    test('book.blurb is optional and localized like gloss', () async {
      // The fixture ships one: parsed per declared gloss locale.
      final ok = (await loadText(fixtureText())) as PackOk;
      expect(ok.pack.books.first.blurb, isNotNull);
      expect(
        ok.pack.books.first.blurb!.byLocale.keys,
        containsAll(<String>['zh-Hans', 'en']),
      );

      // A pack without one still loads — schema keeps `blurb` optional.
      final without = await loadMutant(
        (Map<String, dynamic> pack) => bookOf(pack).remove('blurb'),
      );
      expect(without, isA<PackOk>());
      expect((without as PackOk).pack.books.first.blurb, isNull);

      // A blurb that misses a declared gloss locale is a validation error.
      final partial = await loadMutant(
        (Map<String, dynamic> pack) =>
            (bookOf(pack)['blurb'] as Map<String, dynamic>).remove('en'),
      );
      expect(partial, isA<PackInvalid>());
      expect(codesOf(partial), contains('I18N-INCOMPLETE'));
    });

    test('vocab.audio is optional and parsed as a clip', () async {
      // Absent is fine: the word card keeps its speaker disabled.
      final without = await loadMutant(
        (Map<String, dynamic> pack) => vocabOf(pack).remove('audio'),
      );
      expect(without, isA<PackOk>());
      expect(
        (without as PackOk).pack.books.first.chapters.first.vocabulary.first
            .audio,
        isNull,
      );

      // Present: url + durationMs, no timeline.
      final withClip = await loadMutant(
        (Map<String, dynamic> pack) => vocabOf(pack)['audio'] =
            <String, dynamic>{'url': 'media/v-muddy.mp3', 'durationMs': 800},
      );
      final item = (withClip as PackOk)
          .pack
          .books
          .first
          .chapters
          .first
          .vocabulary
          .first;
      expect(item.audio?.url, 'media/v-muddy.mp3');
      expect(item.audio?.durationMs, 800);

      // A zero duration is still an error — a clip is a real measurement.
      final broken = await loadMutant(
        (Map<String, dynamic> pack) => vocabOf(pack)['audio'] =
            <String, dynamic>{'url': 'media/v-muddy.mp3', 'durationMs': 0},
      );
      expect(broken, isA<PackInvalid>());
      expect(codesOf(broken), contains('AUDIO-DURATION'));
    });

    test('vocab.exampleAudio is optional and parsed as a clip', () async {
      // Absent is fine: the example speaker falls back to the paragraph window.
      final without = await loadMutant(
        (Map<String, dynamic> pack) => vocabOf(pack).remove('exampleAudio'),
      );
      expect(without, isA<PackOk>());
      expect(
        (without as PackOk).pack.books.first.chapters.first.vocabulary.first
            .exampleAudio,
        isNull,
      );

      // Present: a standalone recording of sourceSentence.
      final withClip = await loadMutant(
        (Map<String, dynamic> pack) => vocabOf(pack)['exampleAudio'] =
            <String, dynamic>{
          'url': 'media/v-muddy-example.mp3',
          'durationMs': 2400,
        },
      );
      final item = (withClip as PackOk)
          .pack
          .books
          .first
          .chapters
          .first
          .vocabulary
          .first;
      expect(item.exampleAudio?.url, 'media/v-muddy-example.mp3');
      expect(item.exampleAudio?.durationMs, 2400);
    });

    test('missing file path yields PackInvalid SCHEMA-NOT-FOUND, no throw',
        () async {
      final repo = JsonContentRepository(
        appVersion: '1.0.0',
        readAsset: (String key) async =>
            throw StateError('asset reader must not be used'),
      );
      final result =
          await repo.loadFromFile('../../content/no-such-dir/pack.json');
      expect(result, isA<PackInvalid>());
      expect(codesOf(result), contains('SCHEMA-NOT-FOUND'));
    });
  });

  group('minAppVersion / upgradeRecommended (C5)', () {
    test('minAppVersion above the app version still loads with upgrade hint',
        () async {
      final result = await loadText(fixtureText(), appVersion: '0.9.0');
      expect(result, isA<PackOk>());
      final ok = result as PackOk;
      expect(ok.upgradeRecommended, isTrue);
      // Not rejected: full content is still available to the caller.
      expect(ok.pack.books, hasLength(1));
      expect(ok.pack.books.first.chapters, hasLength(2));
    });

    test('equal minAppVersion does not flag an upgrade', () async {
      final result = await loadText(fixtureText(), appVersion: '1.0.0');
      expect((result as PackOk).upgradeRecommended, isFalse);
    });

    test('app newer than minAppVersion does not flag an upgrade', () async {
      final result = await loadText(fixtureText(), appVersion: '2.0.0');
      expect((result as PackOk).upgradeRecommended, isFalse);
    });

    test('far-future minAppVersion loads with upgrade hint', () async {
      final result = await loadMutant(
        (Map<String, dynamic> pack) => pack['minAppVersion'] = '999.0.0',
        appVersion: '1.0.0',
      );
      expect(result, isA<PackOk>());
      expect((result as PackOk).upgradeRecommended, isTrue);
    });
  });

  group('bad packs -> PackInvalid with the right code, never throwing', () {
    final List<(String, String, Future<PackLoadResult> Function())> textCases =
        <(String, String, Future<PackLoadResult> Function())>[
      (
        'unparseable JSON',
        'SCHEMA-BROKEN',
        () => loadText('{not json at all'),
      ),
      (
        'root is an array',
        'TOP-SCHEMA',
        () => loadText('[]'),
      ),
    ];

    final List<(String, String, void Function(Map<String, dynamic>))> cases =
        <(String, String, void Function(Map<String, dynamic>))>[
      (
        'schemaVersion is not 1',
        'TOP-SCHEMA',
        (Map<String, dynamic> p) => p['schemaVersion'] = 2,
      ),
      (
        'contentVersion not semver',
        'TOP-SCHEMA',
        (Map<String, dynamic> p) => p['contentVersion'] = 'abc',
      ),
      (
        'minAppVersion not semver',
        'TOP-SCHEMA',
        (Map<String, dynamic> p) => p['minAppVersion'] = '1.0',
      ),
      (
        'books empty',
        'BOOKS-EMPTY',
        (Map<String, dynamic> p) => p['books'] = <dynamic>[],
      ),
      (
        'chapters empty',
        'CHAPTERS-EMPTY',
        (Map<String, dynamic> p) => bookOf(p)['chapters'] = <dynamic>[],
      ),
      (
        'reading empty',
        'READING-EMPTY',
        (Map<String, dynamic> p) => chapterOf(p)['reading'] = <dynamic>[],
      ),
      (
        'locales.gloss empty',
        'I18N-GLOSS-EMPTY',
        (Map<String, dynamic> p) => (p['locales']
            as Map<String, dynamic>)['gloss'] = <dynamic>[],
      ),
      (
        'locales.content empty',
        'I18N-CONTENT-EMPTY',
        (Map<String, dynamic> p) => (p['locales']
            as Map<String, dynamic>)['content'] = <dynamic>[],
      ),
      (
        'defaultGloss not declared in gloss',
        'I18N-DEFAULT',
        (Map<String, dynamic> p) => (p['locales']
            as Map<String, dynamic>)['defaultGloss'] = 'fr',
      ),
      (
        'duplicate book id',
        'ID-DUP-BOOK',
        (Map<String, dynamic> p) => (p['books'] as List<dynamic>)
            .add(json.decode(json.encode(bookOf(p)))),
      ),
      (
        'duplicate chapter id',
        'ID-DUP-CHAPTER',
        (Map<String, dynamic> p) => chapterOf(p, 1)['id'] = 'ch1',
      ),
      (
        'duplicate paragraph id',
        'ID-DUP-PARA',
        (Map<String, dynamic> p) => paraOf(p, 0, 1)['id'] = 'ch1-p1',
      ),
      (
        'duplicate vocab id',
        'ID-DUP-VOCAB',
        (Map<String, dynamic> p) => vocabOf(p, 0, 1)['id'] = 'ch1-v1',
      ),
      (
        'duplicate quiz id',
        'ID-DUP-QUIZ',
        (Map<String, dynamic> p) => quizOf(p, 0, 1)['id'] = 'ch1-q1',
      ),
      (
        'duplicate scene id',
        'ID-DUP-SCENE',
        (Map<String, dynamic> p) => (retellOf(p, 0)['scenes'] as List<dynamic>)
            .add(json.decode(json.encode(sceneOf(p, 0, 0)))),
      ),
      (
        'level object missing',
        'LEVEL-MISSING',
        (Map<String, dynamic> p) => bookOf(p).remove('level'),
      ),
      (
        'level field missing',
        'LEVEL-MISSING',
        (Map<String, dynamic> p) => (bookOf(p)['level']
            as Map<String, dynamic>).remove('wordCount'),
      ),
      (
        'sentences empty',
        'AUDIO-SENTENCES',
        (Map<String, dynamic> p) =>
            audioOf(p, 0, 0)['sentences'] = <dynamic>[],
      ),
      (
        'durationMs not positive',
        'AUDIO-DURATION',
        (Map<String, dynamic> p) => audioOf(p, 0, 0)['durationMs'] = 0,
      ),
      (
        'sentence endMs not after startMs',
        'AUDIO-RANGE',
        (Map<String, dynamic> p) =>
            ((audioOf(p, 0, 0)['sentences'] as List<dynamic>)[0]
                as Map<String, dynamic>)['endMs'] = 0,
      ),
      (
        'sentence overlaps the previous one',
        'AUDIO-OVERLAP',
        (Map<String, dynamic> p) =>
            ((audioOf(p, 0, 0)['sentences'] as List<dynamic>)[1]
                as Map<String, dynamic>)['startMs'] = 1000,
      ),
      (
        'sentence timeline exceeds durationMs',
        'AUDIO-EXCEED',
        (Map<String, dynamic> p) {
          final sentences = audioOf(p, 0, 0)['sentences'] as List<dynamic>;
          (sentences.last as Map<String, dynamic>)['endMs'] = 999999;
        },
      ),
      (
        'answer index out of range',
        'QUIZ-ANSWER',
        (Map<String, dynamic> p) => quizOf(p, 0, 0)['answer'] = 4,
      ),
      (
        'duplicate option texts',
        'QUIZ-DUP-OPTION',
        (Map<String, dynamic> p) =>
            (quizOf(p, 0, 0)['options'] as List<dynamic>)[1] =
                (quizOf(p, 0, 0)['options'] as List<dynamic>)[0],
      ),
      (
        'illegal quiz skill',
        'QUIZ-SKILL',
        (Map<String, dynamic> p) => quizOf(p, 0, 0)['skill'] = 'inferenceX',
      ),
      (
        'quiz evidence points nowhere',
        'QUIZ-EVIDENCE',
        (Map<String, dynamic> p) => quizOf(p, 0, 0)['evidence'] = 'no-such',
      ),
      (
        'illegal partOfSpeech',
        'VOCAB-POS',
        (Map<String, dynamic> p) =>
            vocabOf(p, 0, 0)['partOfSpeech'] = 'pronoun',
      ),
      (
        'illegal vocab cefr',
        'VOCAB-CEFR',
        (Map<String, dynamic> p) => vocabOf(p, 0, 0)['cefr'] = 'D1',
      ),
      (
        'vocab sourceParagraphId points nowhere',
        'VOCAB-PARA',
        (Map<String, dynamic> p) =>
            vocabOf(p, 0, 0)['sourceParagraphId'] = 'no-such',
      ),
      (
        'gloss misses a declared locale',
        'I18N-INCOMPLETE',
        (Map<String, dynamic> p) => (vocabOf(p, 0, 0)['gloss']
            as Map<String, dynamic>).remove('en'),
      ),
      (
        'gloss field absent',
        'I18N-MISSING',
        (Map<String, dynamic> p) => vocabOf(p, 0, 0).remove('gloss'),
      ),
      (
        'gloss translation empty',
        'I18N-EMPTY',
        (Map<String, dynamic> p) => (vocabOf(p, 0, 0)['gloss']
            as Map<String, dynamic>)['en'] = '   ',
      ),
      (
        'required book title missing',
        'SCHEMA',
        (Map<String, dynamic> p) => bookOf(p).remove('title'),
      ),
      (
        'id pattern violated',
        'SCHEMA',
        (Map<String, dynamic> p) => bookOf(p)['id'] = 'Bad_ID',
      ),
      (
        'rubric weight field missing',
        'RUBRIC-MISSING',
        (Map<String, dynamic> p) => (retellOf(p, 0)['rubric']
            as Map<String, dynamic>).remove('conceptWeight'),
      ),
      (
        'rubric weights do not sum to 1',
        'RUBRIC-SUM',
        (Map<String, dynamic> p) => (retellOf(p, 0)['rubric']
            as Map<String, dynamic>)['conceptWeight'] = 0.9,
      ),
      (
        'wpm range lower bound above upper bound',
        'RUBRIC-WPM',
        (Map<String, dynamic> p) => (retellOf(p, 0)['rubric']
            as Map<String, dynamic>)['wpmTargetRange'] = <int>[120, 70],
      ),
      (
        'retell scenes empty',
        'RETELL-SCENES',
        (Map<String, dynamic> p) => retellOf(p, 0)['scenes'] = <dynamic>[],
      ),
      (
        'scene concepts empty',
        'RETELL-CONCEPTS',
        (Map<String, dynamic> p) =>
            sceneOf(p, 0, 0)['concepts'] = <dynamic>[],
      ),
      (
        'concept terms empty',
        'RETELL-TERMS',
        (Map<String, dynamic> p) =>
            conceptOf(p, 0, 0, 0)['terms'] = <dynamic>[],
      ),
      (
        'duplicate concept id in one scene',
        'RETELL-CONCEPT-DUP',
        (Map<String, dynamic> p) => (sceneOf(p, 0, 0)['concepts']
                as List<dynamic>)
            .add(json.decode(json.encode(conceptOf(p, 0, 0, 0)))),
      ),
    ];

    for (final (String name, String code, Future<PackLoadResult> Function() run)
        in textCases) {
      test('$name -> $code', () async {
        final result = await run();
        expect(result, isA<PackInvalid>(), reason: 'must not return PackOk');
        expect(codesOf(result), contains(code),
            reason: 'errors: ${(result as PackInvalid).errors}');
      });
    }

    for (final (String name, String code, void Function(Map<String, dynamic>) mutate)
        in cases) {
      test('$name -> $code', () async {
        final result = await loadMutant(mutate);
        expect(result, isA<PackInvalid>(), reason: 'must not return PackOk');
        expect(codesOf(result), contains(code),
            reason: 'errors: ${(result as PackInvalid).errors}');
      });
    }
  });
}
