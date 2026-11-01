/// SpeechEngineBase lifecycle tests with a scripted fake binding: state
/// transitions, partial stream behaviour, and stop() transcript output
/// (raw text, durationMs, VAD-derived pause gaps).
library;

import 'dart:async';

import 'package:core_scoring/core_scoring.dart';
import 'package:core_speech/core_speech.dart';
import 'package:test/test.dart';

/// Scripted binding: canned model check, canned VAD capture, pushes the
/// planned partials when capture starts.
class FakeSpeechEngine extends SpeechEngineBase {
  FakeSpeechEngine({
    this.modelsReady = true,
    this.capture = const SpeechCapture(segments: <SpeechSegment>[], durationMs: 0),
    this.plannedPartials = const <SpeechPartial>[],
  });

  bool modelsReady;
  SpeechCapture capture;
  final List<SpeechPartial> plannedPartials;

  int checkModelsCalls = 0;
  int beginCaptureCalls = 0;
  int endCaptureCalls = 0;

  @override
  Future<bool> checkModels() async {
    checkModelsCalls++;
    return modelsReady;
  }

  @override
  Future<void> beginCapture() async {
    beginCaptureCalls++;
    for (final SpeechPartial p in plannedPartials) {
      emitPartial(p);
    }
  }

  @override
  Future<SpeechCapture> endCapture() async {
    endCaptureCalls++;
    return capture;
  }
}

void main() {
  group('lifecycle state flow', () {
    test('idle -> ready -> listening -> ready, and a second session works',
        () async {
      final engine = FakeSpeechEngine(
        capture: const SpeechCapture(
          segments: <SpeechSegment>[
            SpeechSegment(startMs: 0, endMs: 1000, text: 'hello'),
          ],
          durationMs: 1500,
        ),
      );
      expect(engine.state, SpeechEngineState.idle);

      expect(await engine.ensureModelReady(), isTrue);
      expect(engine.state, SpeechEngineState.ready);

      await engine.start();
      expect(engine.state, SpeechEngineState.listening);

      final Transcript t = await engine.stop();
      expect(engine.state, SpeechEngineState.ready, reason: 'ready for retry');
      expect(t.text, 'hello');

      // Second session without re-checking models (retry loop, S5).
      await engine.start();
      expect(engine.state, SpeechEngineState.listening);
      await engine.stop();
      expect(engine.beginCaptureCalls, 2);
    });

    test('ensureModelReady false keeps idle and returns false (UI guidance)',
        () async {
      final engine = FakeSpeechEngine(modelsReady: false);
      expect(await engine.ensureModelReady(), isFalse);
      expect(engine.state, SpeechEngineState.idle);
    });

    test('start without ensureModelReady throws StateError', () async {
      final engine = FakeSpeechEngine();
      expect(engine.start(), throwsStateError);
    });

    test('stop without start throws StateError', () async {
      final engine = FakeSpeechEngine();
      await engine.ensureModelReady();
      expect(engine.stop(), throwsStateError);
    });

    test('operations after dispose throw; dispose is idempotent', () async {
      final engine = FakeSpeechEngine();
      await engine.ensureModelReady();
      await engine.dispose();
      await engine.dispose(); // idempotent
      expect(engine.state, SpeechEngineState.disposed);
      expect(engine.ensureModelReady(), throwsStateError);
      expect(engine.start(), throwsStateError);
      expect(engine.stop(), throwsStateError);
    });

    test('ensureModelReady during listening throws StateError', () async {
      final engine = FakeSpeechEngine();
      await engine.ensureModelReady();
      await engine.start();
      expect(engine.ensureModelReady(), throwsStateError);
    });
  });

  group('partials stream', () {
    test('emitted partials arrive in order with isFinal flags', () async {
      final engine = FakeSpeechEngine(plannedPartials: <SpeechPartial>[
        const SpeechPartial(text: 'hel', isFinal: false),
        const SpeechPartial(text: 'hello wor', isFinal: false),
        const SpeechPartial(text: 'hello world', isFinal: true),
      ]);
      await engine.ensureModelReady();
      final received = <SpeechPartial>[];
      final sub = engine.partials().listen(received.add);
      await engine.start();
      await Future<void>.delayed(Duration.zero);
      await engine.stop();
      await sub.cancel();

      expect(received.map((SpeechPartial p) => p.text).toList(),
          <String>['hel', 'hello wor', 'hello world']);
      expect(received.map((SpeechPartial p) => p.isFinal).toList(),
          <bool>[false, false, true]);
    });

    test('emitPartial outside listening is ignored', () async {
      final engine = FakeSpeechEngine();
      await engine.ensureModelReady();
      final received = <SpeechPartial>[];
      final sub = engine.partials().listen(received.add);
      engine.emitPartial(const SpeechPartial(text: 'ghost', isFinal: false));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(received, isEmpty);
    });
  });

  group('stop() transcript output (decision 2: raw text)', () {
    test('keeps raw ASR text, wall duration and VAD pause gaps', () async {
      final engine = FakeSpeechEngine(
        capture: const SpeechCapture(
          segments: <SpeechSegment>[
            // Deliberately unsorted: assembly sorts by startMs.
            SpeechSegment(startMs: 5200, endMs: 6200, text: 'three'),
            SpeechSegment(startMs: 0, endMs: 3000, text: "I'm 3"),
            SpeechSegment(startMs: 5000, endMs: 5100, text: 'cats'),
          ],
          durationMs: 7000,
        ),
      );
      await engine.ensureModelReady();
      await engine.start();
      final Transcript t = await engine.stop();

      // Raw text preserved — "I'm 3" is NOT expanded here (scoreRetell does
      // the English normalisation, decision ②).
      expect(t.text, "I'm 3 cats three");
      expect(t.durationMs, 7000);
      // Gaps: 5000-3000 = 2000, then 5200-5100 = 100.
      expect(t.pauseGapsMs, <int>[2000, 100]);
    });
  });
}
