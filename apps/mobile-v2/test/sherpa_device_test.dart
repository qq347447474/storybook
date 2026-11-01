/// Device-only verification for the sherpa-onnx binding (T7b 真机项).
///
/// These tests need real hardware (native plugin + microphone). They are
/// SKIPPED in the regular `flutter test` run so the CI suite stays green;
/// run them on a device with:
///
///     flutter test --run-skipped test/sherpa_device_test.dart
///
/// Expected results are documented in the T7b report's 真机验证步骤清单.
@Tags(<String>['device'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storyapp/audio/production_bindings.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('sherpa_device');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  testWidgets('checkModels loads whisper + silero on a real device',
      (WidgetTester tester) async {
    final engine = SherpaSpeechEngine(supportDir: tmp.path);
    // Real rootBundle assets + real native smoke-load.
    expect(await engine.ensureModelReady(), isTrue,
        reason: 'models bundled and loadable (docs/09 §4)');
    await engine.dispose();
  }, skip: true); // device-only: flutter test --run-skipped test/sherpa_device_test.dart

  testWidgets('record -> VAD -> whisper round trip recognises speech',
      (WidgetTester tester) async {
    final engine = SherpaSpeechEngine(supportDir: tmp.path);
    expect(await engine.ensureModelReady(), isTrue);
    await engine.start();
    // Speak a known sentence into the device mic during this window.
    await Future<void>.delayed(const Duration(seconds: 4));
    final transcript = await engine.stop();
    expect(transcript.text.trim(), isNotEmpty,
        reason: 'whisper returns non-empty raw text');
    expect(transcript.durationMs, greaterThan(0));
    await engine.dispose();
  }, skip: true); // device-only: requires microphone; flutter test --run-skipped
}
