/// DefaultMediaResolver tests: bundled -> cache -> remote fallback order,
/// sha256 verification, and the null = temporarily unavailable contract (C6).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core_content/core_content.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late List<String> log;

  Uint8List bytesOf(String s) => Uint8List.fromList(utf8.encode(s));

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('media_resolver_test');
    log = <String>[];
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  String sha256HexOf(String data) =>
      sha256.convert(utf8.encode(data)).toString();

  OfflineMediaEntry entryFor(String url, String data) {
    return OfflineMediaEntry(
      url: url,
      path: url, // contentctl pack format: path == url for bundled files
      kind: 'audio',
      bytes: data.length,
      sha256: sha256HexOf(data),
    );
  }

  test('bundled hit: verified sha256 resolves without cache or network',
      () async {
    var bundledReads = 0;
    var remoteCalls = 0;
    final resolver = DefaultMediaResolver(
      offlineEntries: <String, OfflineMediaEntry>{
        'media/a.mp3': entryFor('media/a.mp3', 'payload'),
      },
      readBundled: (String p) async {
        bundledReads++;
        return bytesOf('payload');
      },
      cacheDir: tmp.path,
      fetchRemote: (String url) async {
        remoteCalls++;
        return null;
      },
      onLog: log.add,
    );
    final resolved = await resolver.resolve('media/a.mp3');
    expect(resolved, isNotNull);
    expect(resolved!.origin, MediaOrigin.bundled);
    expect(resolved.location, 'media/a.mp3');
    expect(resolved.assetKey, 'media/a.mp3', reason: 'empty prefix default');
    expect(resolved.sha256, sha256HexOf('payload'));
    expect(bundledReads, 1);
    expect(remoteCalls, 0);
  });

  test('bundled assetKey joins bundledAssetPrefix once (T7d-2)', () async {
    String? seenKey;
    final resolver = DefaultMediaResolver(
      offlineEntries: <String, OfflineMediaEntry>{
        'media/a.mp3': entryFor('media/a.mp3', 'payload'),
      },
      bundledAssetPrefix: 'assets/content/the-paper-boat/',
      readBundled: (String key) async {
        seenKey = key;
        return bytesOf('payload');
      },
      cacheDir: tmp.path,
      fetchRemote: (String url) async => null,
    );
    final resolved = await resolver.resolve('media/a.mp3');
    expect(seenKey, 'assets/content/the-paper-boat/media/a.mp3',
        reason: 'reader receives the full bundle key');
    expect(resolved!.assetKey, 'assets/content/the-paper-boat/media/a.mp3');
    expect(resolved.location, 'media/a.mp3',
        reason: 'location semantics unchanged (compat)');
  });

  test('sha256 mismatch counts as a miss and logs once', () async {
    var remoteCalls = 0;
    final resolver = DefaultMediaResolver(
      offlineEntries: <String, OfflineMediaEntry>{
        'media/a.mp3': entryFor('media/a.mp3', 'expected'),
      },
      readBundled: (String p) async => bytesOf('tampered'),
      cacheDir: tmp.path,
      fetchRemote: (String url) async {
        remoteCalls++;
        return bytesOf('from-network');
      },
      onLog: log.add,
    );
    final resolved = await resolver.resolve('media/a.mp3');
    // Falls through to remote; the integrity failure was logged.
    expect(resolved!.origin, MediaOrigin.remote);
    expect(remoteCalls, 1);
    expect(log, hasLength(1));
    expect(log.single, contains('sha256 mismatch'));
  });

  test('cache hit is used when the bundled entry is absent', () async {
    File('${tmp.path}${Platform.pathSeparator}media_a.mp3')
        .writeAsStringSync('cached-bytes');
    var remoteCalls = 0;
    final resolver = DefaultMediaResolver(
      offlineEntries: const <String, OfflineMediaEntry>{},
      readBundled: (String p) async => null,
      cacheDir: tmp.path,
      fetchRemote: (String url) async {
        remoteCalls++;
        return null;
      },
      onLog: log.add,
    );
    final resolved = await resolver.resolve('media/a.mp3');
    expect(resolved!.origin, MediaOrigin.cached);
    expect(remoteCalls, 0);
  });

  test('remote is the last fallback and is cached for next time', () async {
    final resolver = DefaultMediaResolver(
      offlineEntries: const <String, OfflineMediaEntry>{},
      readBundled: (String p) async => null,
      cacheDir: tmp.path,
      fetchRemote: (String url) async => bytesOf('remote-bytes'),
      onLog: log.add,
    );
    final first = await resolver.resolve('media/a.mp3');
    expect(first!.origin, MediaOrigin.remote);
    expect(first.location, 'media/a.mp3');
    final second = await resolver.resolve('media/a.mp3');
    expect(second!.origin, MediaOrigin.cached);
  });

  test('returns null when every stage fails (C6, no throw)', () async {
    final resolver = DefaultMediaResolver(
      offlineEntries: const <String, OfflineMediaEntry>{},
      readBundled: (String p) async => null,
      cacheDir: tmp.path,
      fetchRemote: (String url) async => null,
      onLog: log.add,
    );
    expect(await resolver.resolve('media/none.mp3'), isNull);
  });

  test('returns null when the fetcher throws (C6, no throw)', () async {
    final resolver = DefaultMediaResolver(
      offlineEntries: <String, OfflineMediaEntry>{
        'media/a.mp3': entryFor('media/a.mp3', 'expected'),
      },
      readBundled: (String p) async => throw const SocketException('down'),
      cacheDir: tmp.path,
      fetchRemote: (String url) async => throw const SocketException('down'),
      onLog: log.add,
    );
    expect(await resolver.resolve('media/a.mp3'), isNull);
    // One log for the bundled read failure, one for the network failure.
    expect(log, hasLength(2));
  });

  test('offline map parses the contentctl pack format', () {
    final map = OfflineMediaMap.fromJson(<String, dynamic>{
      'schemaVersion': 1,
      'contentVersion': '1.0.0',
      'entries': <dynamic>[
        <String, dynamic>{
          'url': 'media/a.mp3',
          'path': 'media/a.mp3',
          'kind': 'audio',
          'bytes': 12,
          'sha256': 'ab',
        },
        <String, dynamic>{'url': 'https://x/y.png', 'kind': 'image', 'remote': true},
      ],
      'missing': <dynamic>['media/b.mp3'],
    });
    expect(map.entries, hasLength(2));
    expect(map.entries['media/a.mp3']!.sha256, 'ab');
    expect(map.entries['https://x/y.png']!.remote, isTrue);
    expect(map.missing, <String>['media/b.mp3']);
  });
}
