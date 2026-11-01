/// `SpeechEngine` contract (`docs/07-modules.md` §4) and its pure-Dart
/// lifecycle base class.
///
/// The interface is the only thing the UI knows. The default implementation
/// is offline (sherpa-onnx); `AndroidSpeechRecognizerFallback` (phase 2) is
/// for degradation only and must be labelled "may upload audio" in settings,
/// otherwise the privacy statement is false. `ensureModelReady` returning
/// false must trigger UI guidance — never a silent failure.
library;

import 'dart:async';

import 'package:core_scoring/core_scoring.dart';

import 'speech_types.dart';
import 'transcript_assembly.dart';

export 'speech_types.dart';

/// One ASR session over the microphone.
abstract class SpeechEngine {
  /// Verifies the on-device models; false means "not ready" (UI guides the
  /// user instead of failing silently).
  Future<bool> ensureModelReady();

  /// Starts a recording session. Precondition: `ensureModelReady()` has
  /// succeeded ([SpeechEngineState.ready]).
  Future<void> start();

  /// Live recognition stream; `isFinal` marks a segment-final hypothesis.
  Stream<SpeechPartial> partials();

  /// Stops recording and returns the [Transcript] for scoring. The text is
  /// raw ASR output — normalisation happens inside `scoreRetell` (decision ②).
  Future<Transcript> stop();

  /// Processes a WAV file (PCM16 mono 16kHz) through VAD + recognition.
  /// Used instead of dual-AudioRecord streaming (MIUI mic conflict fix).
  Future<SpeechCapture> processWavFile(String path);

  /// Releases native resources. Idempotent.
  ///
  /// Subclasses holding native resources (recorders, recognizers) must
  /// override this and release them even when [stop] never ran (aborted
  /// session / exception path), then call `super.dispose()`.
  Future<void> dispose();
}

/// Template implementation of the engine lifecycle, shared by every binding
/// (sherpa-onnx in phase 2, fakes in tests).
///
/// Subclasses supply the platform capture through three hooks; everything
/// else — state transitions, the partials stream, and transcript assembly
/// from VAD segments — is pure Dart and unit tested.
abstract class SpeechEngineBase implements SpeechEngine {
  SpeechEngineBase() {
    _partials = StreamController<SpeechPartial>.broadcast();
  }

  late final StreamController<SpeechPartial> _partials;
  SpeechEngineState _state = SpeechEngineState.idle;

  /// Current lifecycle state.
  SpeechEngineState get state => _state;

  // ---- hooks for bindings -------------------------------------------------

  /// Checks that the model files exist and are loadable. Called by
  /// [ensureModelReady].
  Future<bool> checkModels();

  /// Starts the platform capture pipeline (mic + VAD + ASR).
  Future<void> beginCapture();

  /// Ends the capture pipeline and returns the VAD-segmented result.
  Future<SpeechCapture> endCapture();

  /// Processes a WAV file written by the file recorder, feeding its PCM
  /// through VAD + recognition. Replaces the dual-AudioRecord approach.
  Future<SpeechCapture> processWavFile(String path) =>
      throw UnimplementedError('processWavFile not implemented');

  /// Bindings push live hypotheses through this while capturing.
  void emitPartial(SpeechPartial partial) {
    if (_state != SpeechEngineState.listening) return;
    if (!_partials.isClosed) _partials.add(partial);
  }

  // ---- lifecycle ---------------------------------------------------------

  @override
  Future<bool> ensureModelReady() async {
    _requireNotDisposed('ensureModelReady');
    if (_state == SpeechEngineState.listening) {
      throw StateError('ensureModelReady() must not run while listening');
    }
    final bool ok = await checkModels();
    if (ok && _state == SpeechEngineState.idle) {
      _state = SpeechEngineState.ready;
    }
    return ok;
  }

  @override
  Future<void> start() async {
    _requireNotDisposed('start');
    if (_state != SpeechEngineState.ready) {
      throw StateError('start() requires the ready state (call ensureModelReady)');
    }
    _state = SpeechEngineState.listening;
    await beginCapture();
  }

  @override
  Stream<SpeechPartial> partials() => _partials.stream;

  @override
  Future<Transcript> stop() async {
    _requireNotDisposed('stop');
    if (_state != SpeechEngineState.listening) {
      throw StateError('stop() requires an active recording');
    }
    final SpeechCapture capture = await endCapture();
    _state = SpeechEngineState.ready; // model stays ready: S5 retry loops
    return transcriptFromCapture(capture);
  }

  @override
  Future<void> dispose() async {
    if (_state == SpeechEngineState.disposed) return;
    _state = SpeechEngineState.disposed;
    await _partials.close();
  }

  void _requireNotDisposed(String op) {
    if (_state == SpeechEngineState.disposed) {
      throw StateError('$op() called on a disposed engine');
    }
  }
}
