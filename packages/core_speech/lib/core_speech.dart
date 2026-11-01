/// Speech layer of the graded reader: the `SpeechEngine` interface and its
/// transcript types (`docs/07-modules.md` §4).
///
/// Pure Dart package — platform-specific implementations (sherpa-onnx FFI,
/// Android fallback) are injected from `apps/mobile` at registration time
/// (constraint C8); this package defines the contract, the lifecycle state
/// machine ([SpeechEngineBase]) and VAD-to-[Transcript] assembly. The real
/// sherpa-onnx binding lands with the S5 retell screen (phase 2).
library;

export 'src/speech_engine.dart';
export 'src/speech_types.dart';
export 'src/transcript_assembly.dart' show transcriptFromCapture;

/// Identity of this package; referenced by the app shell to verify wiring.
const String coreSpeechName = 'core_speech';
