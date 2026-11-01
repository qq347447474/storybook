/// Real navigation chain regression (T7d-3): pump the REAL [StoryApp]
/// (only the two platform channels are mocked), walk S0 -> S1 -> S2 via
/// real Navigator pushes, and assert the L10nScope resolves for pushed
/// routes (the bug: scope sat below the Navigator -> the first push hit
/// 'scope != null') and that copy renders via t() - never raw keys.
///
/// The bundled-media fix (5e0e147) is exercised on the same path: the
/// real DefaultMediaResolver resolves the cover through the asset-key
/// branch.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyapp/i18n/app_localizations.dart';
import 'package:storyapp/main.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('nav_chain_test');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
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
    // Bundled cover goes through the assetKey branch (5e0e147) on the
    // real resolver path.
    final Image cover = tester.widget<Image>(find.byType(Image).first);
    expect(cover.image, isA<AssetImage>());

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
