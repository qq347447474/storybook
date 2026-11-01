/// deleteLocalBook unit tests: the cached pack directory, the flat media
/// files its URLs name and the book's progress rows all go — and nothing
/// belonging to any other book does.
library;

import 'dart:convert';
import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyapp/library/local_book_delete.dart';

void main() {
  late Directory support;

  setUp(() {
    support = Directory.systemTemp.createTempSync('local-book-delete');
  });

  tearDown(() {
    if (support.existsSync()) support.deleteSync(recursive: true);
  });

  File mediaFile(String url) => File(
      '${support.path}${Platform.pathSeparator}${mediaCacheFileName(url)}');

  File packFileOf(String bookId) => File(
      '${support.path}${Platform.pathSeparator}storyapp_cache'
      '${Platform.pathSeparator}$bookId${Platform.pathSeparator}pack.json');

  /// A minimal cached pack whose URLs point at every media shape the app
  /// caches: absolute CDN, relative `media/…`, nested `src` refs.
  Map<String, dynamic> packBody(String bookId) => <String, dynamic>{
        'schemaVersion': 1,
        'books': <dynamic>[
          <String, dynamic>{
            'id': bookId,
            'title': 'Book $bookId',
            'cover': <String, dynamic>{
              'url': 'https://oss.ymie.fun/storyapp/$bookId/media/cover.png',
            },
            'chapters': <dynamic>[
              <String, dynamic>{
                'id': 'ch1',
                'reading': <dynamic>[
                  <String, dynamic>{
                    'id': '$bookId-p1',
                    'audio': <String, dynamic>{
                      'url': 'media/$bookId-p1.mp3',
                      'sentences': <dynamic>[
                        <String, dynamic>{
                          'startMs': 0,
                          'endMs': 100,
                          'audio': <String, dynamic>{
                            'src': 'media/$bookId-p1-s1.mp3',
                          },
                        },
                      ],
                    },
                  },
                ],
                'vocabulary': <dynamic>[
                  <String, dynamic>{
                    'id': 'v-word',
                    'audio': <String, dynamic>{
                      'url': 'media/v-word.mp3',
                    },
                    'exampleAudio': <String, dynamic>{
                      'url': 'https://oss.ymie.fun/storyapp/$bookId/media/v-word-example.mp3',
                    },
                  },
                ],
              },
            ],
          },
        ],
      };

  void writeBook(String bookId) {
    final File pack = packFileOf(bookId);
    pack.parent.createSync(recursive: true);
    pack.writeAsStringSync(jsonEncode(packBody(bookId)));
    // One flat cache file per URL, exactly where DefaultMediaResolver looks.
    void touch(String url) {
      final File f = mediaFile(url);
      f.writeAsStringSync('audio-bytes');
    }

    touch('https://oss.ymie.fun/storyapp/$bookId/media/cover.png');
    touch('media/$bookId-p1.mp3');
    touch('media/$bookId-p1-s1.mp3');
    touch('media/v-word.mp3');
    touch('https://oss.ymie.fun/storyapp/$bookId/media/v-word-example.mp3');
  }

  /// Progress document JSON as FileProgressStore writes it (schema v1).
  void writeProgress(String packId, List<String> chapterKeys) {
    final File file = File(
        '${support.path}${Platform.pathSeparator}$packId.progress.json');
    file.writeAsStringSync(jsonEncode(<String, dynamic>{
      'schemaVersion': 1,
      'packId': packId,
      'contentVersion': '1.1.0',
      'updatedAt': '2026-11-01T00:00:00Z',
      'chapters': <String, dynamic>{
        for (final String key in chapterKeys)
          key: <String, dynamic>{
            'status': 'complete',
            'readParagraphs': <String>['$key-p1'],
            'quiz': <String, dynamic>{
              'attempts': 1,
              'answered': 1,
              'correct': 1,
              'wrongItemIds': <String>[],
            },
            'retell': <dynamic>[],
          },
      },
      'skills': <String, dynamic>{
        '${chapterKeys.first}/retell': <String, dynamic>{
          'attempts': 1,
          'bestScore': 0.5,
        },
      },
      'settings': <String, dynamic>{
        'uiLocale': 'en',
        'glossLocale': 'zh-Hans',
        'reduceMotion': false,
      },
    }));
  }

  test('deletes the pack dir, its media files and its progress rows', () async {
    writeBook('book-a');
    writeBook('book-b');
    writeProgress('pack-main', <String>['book-a/ch1', 'book-b/ch1']);

    final LocalBookDeleteResult result = await deleteLocalBook(
      bookId: 'book-a',
      supportDir: support,
      progressStore: FileProgressStore(directory: support.path),
      progressPackId: 'pack-main',
    );

    expect(result.cacheRemoved, isTrue);
    expect(result.mediaFiles, 5, reason: 'every URL in the pack maps 1:1');
    expect(result.progressEntries, 2,
        reason: 'the chapter row and its skill row both go');
    expect(result.removedAnything, isTrue);

    // The book and every media file it named are gone.
    expect(packFileOf('book-a').existsSync(), isFalse);
    for (final String url in <String>[
      'https://oss.ymie.fun/storyapp/book-a/media/cover.png',
      'media/book-a-p1.mp3',
      'media/book-a-p1-s1.mp3',
      'media/v-word.mp3',
      'https://oss.ymie.fun/storyapp/book-a/media/v-word-example.mp3',
    ]) {
      expect(mediaFile(url).existsSync(), isFalse, reason: url);
    }

    // The other book keeps everything, including its progress rows.
    expect(packFileOf('book-b').existsSync(), isTrue);
    expect(mediaFile('https://oss.ymie.fun/storyapp/book-b/media/cover.png').existsSync(),
        isTrue);
    final Map<String, dynamic> progress = jsonDecode(File(
            '${support.path}${Platform.pathSeparator}pack-main.progress.json')
        .readAsStringSync()) as Map<String, dynamic>;
    final Map<String, dynamic> chapters =
        progress['chapters'] as Map<String, dynamic>;
    expect(chapters.keys, <String>['book-b/ch1']);
    expect((progress['skills'] as Map<String, dynamic>).keys, isEmpty,
        reason: 'the removed chapter\'s skill row goes with it');
  });

  test('a missing book still reports a clean, harmless pass', () async {
    writeBook('book-b');

    final LocalBookDeleteResult result = await deleteLocalBook(
      bookId: 'book-gone',
      supportDir: support,
      progressStore: FileProgressStore(directory: support.path),
      progressPackId: 'pack-main',
    );

    expect(result.cacheRemoved, isFalse);
    expect(result.mediaFiles, 0);
    expect(result.progressEntries, 0);
    expect(result.removedAnything, isFalse);
    expect(packFileOf('book-b').existsSync(), isTrue);
  });
}
