/// Production bindings for S5, registered here and only here (C8).
///
/// [SherpaSpeechEngine] is the offline ASR engine (docs/09 §3):
/// mic PCM 16kHz/mono -> silero-vad segmentation -> whisper-tiny.en
/// recognition, all through the `sherpa_onnx` plugin. Model files are
/// extracted from bundled assets and sha256-verified against
/// models.manifest.json before first use ([verifyModelFiles]).
///
/// Failure paths are explicit (L3): any model/load failure makes
/// `ensureModelReady()` report false and the S5 screen shows the docs/09 §8
/// "model unavailable" guidance — never a silent degradation and never a
/// cloud ASR path.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core_speech/core_speech.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'mic_permission.dart';
import 'retell_audio_source.dart';

/// Verifies and materialises the ASR model files: extracts every file listed
/// in `models.manifest.json` from bundled assets into [targetDir], then
/// checks its sha256 against the manifest. Returns false (never throws) on
/// any missing file/hash mismatch, so callers can drive the docs/09 §8
/// guidance. Pure file logic — injectable [loadAsset] keeps it unit-testable
/// without the native plugin.
Future<bool> verifyModelFiles({
  required Future<Uint8List> Function(String assetKey) loadAsset,
  required String targetDir,
}) async {
  try {
    final Uint8List raw = await loadAsset('assets/models/models.manifest.json');
    final Map<String, dynamic> manifest =
        json.decode(utf8.decode(raw)) as Map<String, dynamic>;
    final List<dynamic> models = manifest['models'] as List<dynamic>;
    for (final dynamic model in models) {
      final List<dynamic> files =
          (model as Map<String, dynamic>)['files'] as List<dynamic>;
      for (final dynamic f in files) {
        final Map<String, dynamic> entry = f as Map<String, dynamic>;
        final String rel = entry['file'] as String;
        final String want = entry['sha256'] as String;
        final File dest = File(
            '$targetDir${Platform.pathSeparator}${rel.split('/').join(Platform.pathSeparator)}');
        if (!dest.existsSync()) {
          final Uint8List bytes = await loadAsset('assets/models/$rel');
          dest.parent.createSync(recursive: true);
          dest.writeAsBytesSync(bytes);
        }
        final String got = sha256Of(dest);
        if (got != want) {
          return false; // tampered/corrupt: explicit failure, no silent path
        }
      }
    }
    return true;
  } on Exception catch (_) {
    return false;
  }
}

String sha256Of(File file) {
  final Digest digest = sha256.convert(file.readAsBytesSync());
  return digest.toString();
}

class SherpaSpeechEngine extends SpeechEngineBase {
  SherpaSpeechEngine({
    required this.supportDir,
    Future<Uint8List> Function(String assetKey)? loadAsset,
  }) : _loadAsset = loadAsset ?? _rootBundleLoad;

  /// App support directory: models are extracted under `<supportDir>/models`.
  final String supportDir;
  final Future<Uint8List> Function(String assetKey) _loadAsset;

  static const int sampleRate = 16000;

  bool _modelsVerified = false;
  sherpa.VoiceActivityDetector? _vad;
  sherpa.OfflineRecognizer? _recognizer;
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _pcmSub;
  final List<_SegmentDraft> _segments = <_SegmentDraft>[];
  int _totalSamples = 0;

  static Future<Uint8List> _rootBundleLoad(String assetKey) async {
    final ByteData data = await rootBundle.load(assetKey);
    return data.buffer.asUint8List();
  }

  String get _modelsDir => '$supportDir${Platform.pathSeparator}models';

  String _modelPath(String rel) =>
      '$_modelsDir${Platform.pathSeparator}${rel.split('/').join(Platform.pathSeparator)}';

  @override
  Future<bool> checkModels() async {
    // Cache hit: models already verified in this app lifecycle.
    if (_modelsVerified) return true;
    try {
      final bool ok = await verifyModelFiles(
        loadAsset: _loadAsset,
        targetDir: _modelsDir,
      );
      if (!ok) return false;
      sherpa.initBindings();
      // Smoke-load both native models; a load failure is a "model not
      // ready" state (docs/09 §8), never a crash.
      final sherpa.VoiceActivityDetector vad = sherpa.VoiceActivityDetector(
        config: sherpa.VadModelConfig(
          sileroVad: sherpa.SileroVadModelConfig(
            model: _modelPath('silero-vad/silero_vad.onnx'),
          ),
          sampleRate: sampleRate,
        ),
        bufferSizeInSeconds: 30,
      );
      final sherpa.OfflineRecognizer rec = sherpa.OfflineRecognizer(
        sherpa.OfflineRecognizerConfig(
          model: sherpa.OfflineModelConfig(
            whisper: sherpa.OfflineWhisperModelConfig(
              encoder: _modelPath('whisper-tiny.en/tiny.en-encoder.int8.onnx'),
              decoder: _modelPath('whisper-tiny.en/tiny.en-decoder.int8.onnx'),
              language: 'en',
              task: 'transcribe',
            ),
            tokens: _modelPath('whisper-tiny.en/tiny.en-tokens.txt'),
            numThreads: 2,
            debug: false,
          ),
        ),
      );
      vad.free();
      rec.free();
      _modelsVerified = true;
      return true;
    } on Exception catch (_) {
      return false;
    } on Error catch (_) {
      // Native plugin missing on this platform: explicit "not ready".
      return false;
    }
  }

  @override
  Future<void> beginCapture() async {
    if (!_modelsVerified) {
      throw StateError('checkModels() must succeed before capture');
    }
    if (_vad != null || _recognizer != null || _recorder != null) {
      throw StateError('beginCapture() called while a capture is active');
    }
    sherpa.initBindings();
    _segments.clear();
    _totalSamples = 0;
    debugPrint('[ASR] beginCapture() — file mode (no AudioRecord)');
    try {
      _vad = sherpa.VoiceActivityDetector(
        config: sherpa.VadModelConfig(
          sileroVad: sherpa.SileroVadModelConfig(
            model: _modelPath('silero-vad/silero_vad.onnx'),
          ),
          sampleRate: sampleRate,
        ),
        bufferSizeInSeconds: 30,
      );
      _recognizer = sherpa.OfflineRecognizer(
        sherpa.OfflineRecognizerConfig(
          model: sherpa.OfflineModelConfig(
            whisper: sherpa.OfflineWhisperModelConfig(
              encoder: _modelPath('whisper-tiny.en/tiny.en-encoder.int8.onnx'),
              decoder: _modelPath('whisper-tiny.en/tiny.en-decoder.int8.onnx'),
              language: 'en',
              task: 'transcribe',
            ),
            tokens: _modelPath('whisper-tiny.en/tiny.en-tokens.txt'),
            numThreads: 2,
            debug: false,
          ),
        ),
      );
    } catch (error) {
      await _releaseCaptureResources();
      rethrow;
    }
  }

  /// Idempotent teardown of anything a capture still holds (pcm
  /// subscription, recorder, VAD, recognizer). Fields are nulled before
  /// freeing so endCapture()/dispose() can never double-free, in any order.
  Future<void> _releaseCaptureResources() async {
    final StreamSubscription<Uint8List>? sub = _pcmSub;
    _pcmSub = null;
    await sub?.cancel();
    final AudioRecorder? recorder = _recorder;
    _recorder = null;
    try {
      await recorder?.stop();
    } on Exception catch (_) {
      // Best effort: teardown must not throw (C6).
    }
    await recorder?.dispose();
    final sherpa.VoiceActivityDetector? vad = _vad;
    _vad = null;
    vad?.free();
    final sherpa.OfflineRecognizer? recognizer = _recognizer;
    _recognizer = null;
    recognizer?.free();
  }

  /// Reads a WAV file written by [RecordRetellAudioSource], feeds its PCM
  /// through VAD + Whisper, and returns the assembled [SpeechCapture].
  /// This replaces the old dual-AudioRecord approach that starved on MIUI.
  @override
  Future<SpeechCapture> processWavFile(String path) async {
    debugPrint('[ASR] processWavFile: $path');
    // Ensure VAD + recognizer are initialized (beginCapture may not have
    // been called in file mode).
    if (_vad == null || _recognizer == null) {
      debugPrint('[ASR] processWavFile: initializing VAD + recognizer');
      sherpa.initBindings();
      _segments.clear();
      _totalSamples = 0;
      _vad = sherpa.VoiceActivityDetector(
        config: sherpa.VadModelConfig(
          sileroVad: sherpa.SileroVadModelConfig(
            model: _modelPath('silero-vad/silero_vad.onnx'),
          ),
          sampleRate: sampleRate,
        ),
        bufferSizeInSeconds: 30,
      );
      _recognizer = sherpa.OfflineRecognizer(
        sherpa.OfflineRecognizerConfig(
          model: sherpa.OfflineModelConfig(
            whisper: sherpa.OfflineWhisperModelConfig(
              encoder: _modelPath('whisper-tiny.en/tiny.en-encoder.int8.onnx'),
              decoder: _modelPath('whisper-tiny.en/tiny.en-decoder.int8.onnx'),
              language: 'en',
              task: 'transcribe',
            ),
            tokens: _modelPath('whisper-tiny.en/tiny.en-tokens.txt'),
            numThreads: 2,
            debug: false,
          ),
        ),
      );
    }
    final File file = File(path);
    if (!file.existsSync()) {
      debugPrint('[ASR] processWavFile: file not found');
      return SpeechCapture(segments: [], durationMs: 0);
    }
    final Uint8List bytes = file.readAsBytesSync();
    debugPrint('[ASR] processWavFile: ${bytes.length} bytes');
    // WAV header diagnostic.
    final String riff = String.fromCharCodes(bytes.sublist(0, 4));
    final String wave = String.fromCharCodes(bytes.sublist(8, 12));
    final int dataSize = bytes.length - 44;
    debugPrint('[ASR] WAV header: RIFF=$riff WAVE=$wave '
        'dataSize=$dataSize');
    // WAV header is 44 bytes; PCM16 mono follows.
    if (bytes.length <= 44) {
      debugPrint('[ASR] processWavFile: too short for WAV');
      return SpeechCapture(segments: [], durationMs: 0);
    }
    final Uint8List pcmBytes = bytes.sublist(44);
    final Float32List samples = _pcm16ToFloat(pcmBytes);
    _totalSamples = samples.length;
    // Diagnostic: check audio amplitude to distinguish "silence" from "VAD miss".
    double maxAbs = 0;
    double sumAbs = 0;
    for (final double s in samples) {
      final double a = s.abs();
      if (a > maxAbs) maxAbs = a;
      sumAbs += a;
    }
    debugPrint('[ASR] processWavFile: ${samples.length} samples '
        '(${samples.length * 1000 ~/ sampleRate}ms) '
        'maxAmplitude=${maxAbs.toStringAsFixed(4)} '
        'avgAmplitude=${(sumAbs / samples.length).toStringAsFixed(4)}');
    // Feed through VAD in chunks of exactly 512 samples (32ms at 16kHz).
    // Silero-vad requires 512-sample chunks — wrong size = silent discard.
    const int chunkSize = 512;
    for (int i = 0; i < samples.length; i += chunkSize) {
      final int end = (i + chunkSize < samples.length)
          ? i + chunkSize
          : samples.length;
      final Float32List chunk = Float32List.fromList(samples.sublist(i, end));
      _vad?.acceptWaveform(chunk);
      _drainSegments();
    }
    _vad?.flush();
    _drainSegments();
    final List<SpeechSegment> out = <SpeechSegment>[
      for (final _SegmentDraft b in _segments)
        SpeechSegment(startMs: b.startMs, endMs: b.endMs, text: b.text),
    ];
    debugPrint('[ASR] processWavFile: ${out.length} segments');
    for (final SpeechSegment s in out) {
      debugPrint('[ASR]   segment [${s.startMs}-${s.endMs}ms] "${s.text}"');
    }
    _segments.clear();
    return SpeechCapture(
      segments: out,
      durationMs: samples.length * 1000 ~/ sampleRate,
    );
  }

  @override
  Future<void> dispose() async {
    // Safety net (QA T7c): dispose without endCapture (aborted session,
    // exception path, early exit) must still release the native resources
    // the capture holds. _releaseCaptureResources is idempotent, so this is
    // safe after a normal endCapture() too.
    await _releaseCaptureResources();
    await super.dispose();
  }

  void _drainSegments() {
    final sherpa.VoiceActivityDetector? vad = _vad;
    if (vad == null) return;
    while (!vad.isEmpty()) {
      final sherpa.SpeechSegment seg = vad.front();
      vad.pop();
      if (seg.samples.isEmpty) continue;
      final String text = _recognize(seg.samples);
      debugPrint('[ASR] VAD segment: samples=${seg.samples.length} '
          '-> text="${text.trim()}"');
      final int startMs = seg.start * 1000 ~/ sampleRate;
      final int endMs =
          startMs + seg.samples.length * 1000 ~/ sampleRate;
      _segments.add(_SegmentDraft(
          startMs: startMs, endMs: endMs, text: text));
      emitPartial(SpeechPartial(text: text, isFinal: true));
    }
  }

  String _recognize(Float32List samples) {
    final sherpa.OfflineRecognizer? rec = _recognizer;
    if (rec == null) return '';
    final sherpa.OfflineStream stream = rec.createStream();
    try {
      stream.acceptWaveform(samples: samples, sampleRate: sampleRate);
      rec.decode(stream);
      return rec.getResult(stream).text;
    } finally {
      stream.free();
    }
  }

  @override
  Future<SpeechCapture> endCapture() async {
    final StreamSubscription<Uint8List>? sub = _pcmSub;
    _pcmSub = null;
    await sub?.cancel();
    final AudioRecorder? recorder = _recorder;
    _recorder = null;
    try {
      await recorder?.stop();
    } on Exception catch (_) {
      // Best effort: teardown must not throw (C6).
    }
    await recorder?.dispose();
    _vad?.flush();
    _drainSegments();
    final List<SpeechSegment> out = <SpeechSegment>[
      for (final _SegmentDraft b in _segments)
        SpeechSegment(startMs: b.startMs, endMs: b.endMs, text: b.text),
    ];
    debugPrint('[ASR] endCapture: totalSamples=$_totalSamples '
        'segments=${out.length}');
    for (final SpeechSegment s in out) {
      debugPrint('[ASR]   segment [${s.startMs}-${s.endMs}ms] "${s.text}"');
    }
    _segments.clear();
    // Frees vad/recognizer (and no-ops on the already-released recorder).
    await _releaseCaptureResources();
    return SpeechCapture(
      segments: out,
      durationMs: _totalSamples * 1000 ~/ sampleRate,
    );
  }

  static Float32List _pcm16ToFloat(Uint8List bytes) {
    final int count = bytes.length ~/ 2;
    final Int16List ints = Int16List.view(
        bytes.buffer, bytes.offsetInBytes, count);
    final Float32List out = Float32List(count);
    for (int i = 0; i < count; i++) {
      out[i] = ints[i] / 32768.0;
    }
    return out;
  }
}

/// Tiny holder for recognised segments while capture is running.
class _SegmentDraft {
  _SegmentDraft({required this.startMs, required this.endMs, required this.text});
  final int startMs;
  final int endMs;
  final String text;
}

class PermissionHandlerMicPermission implements MicPermissionService {
  @override
  Future<MicPermissionState> check() async {
    final PermissionStatus status = await Permission.microphone.status;
    return _map(status);
  }

  @override
  Future<MicPermissionState> request() async {
    final PermissionStatus status = await Permission.microphone.request();
    return _map(status);
  }

  @override
  Future<void> openSettings() => openAppSettings();

  MicPermissionState _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) return MicPermissionState.granted;
    if (status.isPermanentlyDenied) return MicPermissionState.permanentlyDenied;
    return MicPermissionState.denied;
  }
}

class RecordRetellAudioSource implements RetellAudioSource {
  RecordRetellAudioSource({required this.fileDirectory, AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final String fileDirectory;
  final AudioRecorder _recorder;
  final _interruptions =
      StreamController<RecordingInterruption>.broadcast();
  String? _path;

  @override
  Stream<RecordingInterruption> get interruptions => _interruptions.stream;

  @override
  Future<void> start() async {
    final String path =
        '$fileDirectory${Platform.pathSeparator}retell_${DateTime.now().microsecondsSinceEpoch}.wav';
    _path = path;
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        numChannels: 1,
        sampleRate: 16000,
      ),
      path: path,
    );
  }

  @override
  Future<String> stop() async {
    final String? path = await _recorder.stop();
    return path ?? _path ?? '';
  }

  @override
  Future<void> discard() async {
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    final String? path = _path;
    _path = null;
    if (path != null && path.isNotEmpty) {
      try {
        final File file = File(path);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } on Exception catch (_) {
        // Best effort: privacy wants deletion, but a failed unlink must not
        // crash the screen (C6).
      }
    }
  }

  Future<void> dispose() async {
    await _interruptions.close();
    await _recorder.dispose();
  }
}
