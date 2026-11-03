/// Real navigation chain regression (T7d-3): pump the REAL [StoryApp]
/// (only the two platform channels are mocked), walk S0 -> S1 -> S2 via
/// real Navigator pushes, and assert the L10nScope resolves for pushed
/// routes (the bug: scope sat below the Navigator -> the first push hit
/// 'scope != null') and that copy renders via t() - never raw keys.
///
/// The shelf now ships **no built-in book**, so the fixture seeds a download
/// cache (`storyapp_cache/the-paper-boat/pack.json`) before the bootstrap —
/// the exact channel "更新书本" fills, and the one `_assemble` reads.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyapp/i18n/app_localizations.dart';
import 'package:storyapp/main.dart';

/// Minimal schema-valid pack the real parser accepts. One chapter is enough
/// to walk S0 -> S1 -> S2.
const String _cachedPack = '''
{
  "schemaVersion": 1,
  "contentVersion": "1.1.0",
  "minAppVersion": "1.0.0",
  "locales": {"content": ["en"], "gloss": ["zh-Hans", "en"], "defaultGloss": "zh-Hans"},
  "books": [{
    "id": "the-paper-boat",
    "title": "The Paper Boat",
    "blurb": {"zh-Hans": "一只纸船。", "en": "A paper boat."},
    "series": {"id": "s1", "name": "Short Stories", "order": 1},
    "level": {"cefr": "A2", "wordCount": 60, "avgSentenceLen": 6, "ttr": 0.8,
              "newWordDensity": 0.1, "targetWpm": 100},
    "attribution": {"author": "Test", "illustrator": "Test", "license": "CC BY 4.0",
                    "generator": "human", "sourceNote": "fixture"},
    "cover": {"url": "media/cover.png", "aspect": 1.5,
              "alt": {"en": "A girl at a window", "zh-Hans": "窗边的女孩"}},
    "chapters": [{
      "id": "ch1", "order": 1, "title": "One", "available": true, "estimatedMinutes": 5,
      "reading": [{
        "id": "ch1-p1", "text": "One sentence.",
        "audio": {"url": "media/ch1-p1.mp3", "durationMs": 1200,
                  "sentences": [{"text": "One sentence.", "startMs": 0, "endMs": 1200}]}
      }],
      "vocabulary": [],
      "quiz": [],
      "retell": {
        "rubric": {"minWords": 20, "maxSeconds": 60,
                   "conceptWeight": 0.6, "fluencyWeight": 0.2, "completenessWeight": 0.2,
                   "wpmTargetRange": [70, 120]},
        "scenes": [{
          "id": "ch1-scene1", "order": 1,
          "image": {"url": "media/ch1-s1.svg", "alt": {"en": "a scene", "zh-Hans": "场景"}},
          "prompt": "Describe it.",
          "concepts": [{"id": "c1", "label": {"en": "boat", "zh-Hans": "船"},
                        "terms": ["boat"], "required": true}],
          "hint1": {"zh-Hans": "提示", "en": "hint"},
          "hint2": {"zh-Hans": "提示", "en": "hint"},
          "suggestedAnswer": "It shows a boat.",
          "targetWordCount": 20
        }]
      }
    }]
  }]
}
''';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('nav_chain_test');
    // Seed the download cache exactly like "更新书本" leaves it: a book
    // directory with its pack.json. The bootstrap merges this into the shelf.
    final Directory bookDir =
        Directory('${tmp.path}/storyapp_cache/the-paper-boat')
          ..createSync(recursive: true);
    File('${bookDir.path}/pack.json').writeAsStringSync(_cachedPack);
  });

  tearDown(() {
    // The real bootstrap opens a player and cache files; on Windows those
    // handles can outlive the test body by a tick and lock the temp tree.
    // The directory is throwaway either way.
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  testWidgets('S0 -> push S1 -> push S2: L10nScope resolves on every route',
      (WidgetTester tester) async {
    // Platform channels the bootstrap touches (C8 seams).
    const MethodChannel pathChannel =
        MethodChannel('plugins.flutter.io/path_provider');
    const MethodChannel infoChannel =
        MethodChannel('dev.fluttercommunity.plus/package_info');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        pathChannel, (MethodCall call) async {
      if (call.method == 'getApplicationSupportDirectory') return tmp.path;
      return null;
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        infoChannel, (MethodCall call) async {
      return <String, dynamic>{
        'appName': 'StoryApp',
        'packageName': 'com.example.storyapp',
        'version': '1.0.0',
        'buildNumber': '1',
        'buildSignature': '',
      };
    });

    await tester.runAsync(() => AppLocalizations.load('en'));
    await tester.pumpWidget(const StoryApp());
    await tester.pumpAndSettle();

    // S0: library renders real catalog copy (not keys).
    expect(find.text('The Paper Boat'), findsOneWidget);
    expect(find.text('library.books'), findsNothing,
        reason: 'copy must not leak raw keys');
    // The seeded cache book is listed (and therefore deletable) — the shelf
    // no longer hardcodes a bundled title.
    expect(find.byKey(const Key('library-book-the-paper-boat')), findsOneWidget);

    // S0 -> S1 via a real Navigator.push. Before the fix this threw
    // 'L10nScope is missing above this context'.
    await tester.tap(find.byKey(const Key('library-book-the-paper-boat')));
    await tester.pumpAndSettle();

    // S1: contents copy rendered via t() on a pushed route. Only ch1 reads
    // "Read" — ch2 stays chain-locked until ch1 is complete.
    expect(find.text('The Paper Boat'), findsWidgets); // title + app bar
    expect(find.text('Read'), findsWidgets,
        reason: 'stage label resolved through the pushed route scope');
    expect(find.text('chapter.reading'), findsNothing,
        reason: 'copy must not leak raw keys');
    expect(find.byKey(const Key('contents-chapter-ch1')), findsOneWidget);

    // S1 -> S2 entry through another real push.
    await tester.tap(find.byKey(const Key('contents-chapter-ch1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reading-player')), findsOneWidget,
        reason: 'reading screen reached with its audio control');
    expect(find.text('reading.title'), findsNothing);
  });
}
