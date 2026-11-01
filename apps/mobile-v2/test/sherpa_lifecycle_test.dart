/// Lifecycle hardening tests (QA T7c) for SherpaSpeechEngine: dispose
/// without endCapture must be safe and idempotent, and the beginCapture
/// guards must reject misuse without touching the native plugin.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:storyapp/audio/production_bindings.dart';

Future<Uint8List> missingAsset(String key) async =>
    throw Exception('no asset $key');

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('sherpa_lifecycle');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('dispose on an untouched engine is safe and idempotent', () async {
    final engine = SherpaSpeechEngine(
        supportDir: tmp.path, loadAsset: missingAsset);
    await engine.dispose();
    await engine.dispose(); // second dispose must not throw either
  });

  test('beginCapture without verified models throws StateError', () async {
    final engine = SherpaSpeechEngine(
        supportDir: tmp.path, loadAsset: missingAsset);
    expect(engine.beginCapture(), throwsStateError);
    await engine.dispose();
  });

  test('start after dispose rejects (base state machine guard)', () async {
    final engine = SherpaSpeechEngine(
        supportDir: tmp.path, loadAsset: missingAsset);
    await engine.dispose();
    expect(engine.start(), throwsStateError);
    expect(engine.stop(), throwsStateError);
    expect(engine.ensureModelReady(), throwsStateError);
  });

  test('ensureModelReady with missing models is an explicit false', () async {
    final engine = SherpaSpeechEngine(
        supportDir: tmp.path, loadAsset: missingAsset);
    expect(await engine.ensureModelReady(), isFalse);
    await engine.dispose();
  });
}
