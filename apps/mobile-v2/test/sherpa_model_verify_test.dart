/// Unit tests for the ASR model materialisation/verification seam
/// ([verifyModelFiles]) — pure file logic with an injected asset loader, no
/// native plugin or device needed.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyapp/audio/production_bindings.dart';

Uint8List bytesOf(String s) => Uint8List.fromList(utf8.encode(s));

/// Minimal fake manifest with two files whose "content" hashes are pinned
/// to sha256 of their asset payloads.
Map<String, Uint8List> fakeAssets() {
  final Uint8List a = bytesOf('encoder-bytes');
  final Uint8List b = bytesOf('tokens-bytes');
  final Map<String, dynamic> manifest = <String, dynamic>{
    'schemaVersion': 1,
    'models': <dynamic>[
      <String, dynamic>{
        'name': 'whisper-tiny.en',
        'files': <dynamic>[
          <String, dynamic>{
            'file': 'whisper-tiny.en/tiny.en-encoder.int8.onnx',
            'sha256': sha256OfBytes(a),
            'bytes': a.length,
          },
          <String, dynamic>{
            'file': 'whisper-tiny.en/tiny.en-tokens.txt',
            'sha256': sha256OfBytes(b),
            'bytes': b.length,
          },
        ],
      },
    ],
  };
  return <String, Uint8List>{
    'assets/models/models.manifest.json':
        bytesOf(jsonEncode(manifest)),
    'assets/models/whisper-tiny.en/tiny.en-encoder.int8.onnx': a,
    'assets/models/whisper-tiny.en/tiny.en-tokens.txt': b,
  };
}

String sha256OfBytes(Uint8List bytes) => sha256.convert(bytes).toString();

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('sherpa_model_verify');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('extracts assets and verifies hashes (first run materialises files)',
      () async {
    final Map<String, Uint8List> assets = fakeAssets();
    final bool ok = await verifyModelFiles(
      loadAsset: (String key) async => assets[key]!,
      targetDir: tmp.path,
    );
    expect(ok, isTrue);
    expect(
        File('${tmp.path}${Platform.pathSeparator}whisper-tiny.en'
                '${Platform.pathSeparator}tiny.en-encoder.int8.onnx')
            .existsSync(),
        isTrue);
  });

  test('second run with warm files stays green (idempotent)', () async {
    final Map<String, Uint8List> assets = fakeAssets();
    Future<Uint8List> loader(String key) async => assets[key]!;
    expect(await verifyModelFiles(loadAsset: loader, targetDir: tmp.path),
        isTrue);
    expect(await verifyModelFiles(loadAsset: loader, targetDir: tmp.path),
        isTrue);
  });

  test('corrupted model file -> false (explicit failure, no silent path)',
      () async {
    final Map<String, Uint8List> assets = fakeAssets();
    Future<Uint8List> loader(String key) async => assets[key]!;
    expect(await verifyModelFiles(loadAsset: loader, targetDir: tmp.path),
        isTrue);
    // Tamper with the extracted file: hash must now fail.
    final File f = File('${tmp.path}${Platform.pathSeparator}whisper-tiny.en'
        '${Platform.pathSeparator}tiny.en-encoder.int8.onnx');
    f.writeAsBytesSync(bytesOf('tampered'));
    expect(await verifyModelFiles(loadAsset: loader, targetDir: tmp.path),
        isFalse);
  });

  test('missing manifest -> false (docs/09 §8 guidance path)', () async {
    final bool ok = await verifyModelFiles(
      loadAsset: (String key) async => throw Exception('missing $key'),
      targetDir: tmp.path,
    );
    expect(ok, isFalse);
  });
}
