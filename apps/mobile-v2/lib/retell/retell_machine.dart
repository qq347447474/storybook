/// Recording state machine behind [RetellScreen] (D2, design-spec §4.6).
part of 'retell_screen.dart';

mixin _RetellMachine on State<RetellScreen> {
  _RetellPhase _phase = _RetellPhase.idle;
  bool _asrReady = true;
  bool _engineListening = false;
  bool _pressed = false;
  bool _stopping = false;
  bool _micDeniedPermanently = false;
  bool _showRetryNote = false;
  bool _noSpeech = false;
  bool _asrDegraded = false;
  String? _transcriptText;
  double _heldSeconds = 0;
  int _ticks = 0;
  String? _audioPath;
  int _hit = 0;
  int _total = 0;
  List<String> _missingLabels = const <String>[];
  String? _paceText;
  int? _openHint;
  bool _hint1Seen = false;
  Timer? _holdTick;
  final ScrollController _scroll = ScrollController();
  StreamSubscription<RecordingInterruption>? _interruptionSub;

  List<Scene> get _scenes => widget.controller.chapter.retell.scenes;

  Rubric get _rubric => widget.controller.chapter.retell.rubric;

  Scene get _scene => _scenes.isEmpty ? emptyRetellScene : _scenes.first;

  AppLocalizations _l10nOf(BuildContext context) =>
      widget.l10n ?? L10nScope.of(context);


  void initMachine() {
    _interruptionSub = widget.audio.interruptions.listen(_onInterruption);
    // Model loading deferred to first record press: loading the ~100MB
    // whisper ONNX model in initState causes a visible stutter on entry.
  }

  void disposeMachine() {
    _holdTick?.cancel();
    _scroll.dispose();
    _interruptionSub?.cancel();
    unawaited(widget.audio.discard()); // privacy: never outlive the screen
  }

  bool _modelCheckStarted = false;

  Future<void> _checkModel() async {
    if (_modelCheckStarted) return;
    _modelCheckStarted = true;
    final bool ok = await widget.engine.ensureModelReady();
    if (!mounted) return;
    setState(() => _asrReady = ok);
  }

  void _onHoldStart() {
    _pressed = true;
    unawaited(_beginPress());
  }

  void _onHoldEnd(Duration held) => _endTake();

  void _onTimeout() => _endTake();

  void _endTake() {
    _pressed = false;
    if (_phase == _RetellPhase.recording) unawaited(_stopRecording());
  }

  void _onTooShort() {
    _pressed = false;
    if (_phase != _RetellPhase.recording) return;
    unawaited(_discardTake());
    showAppToast(context, _l10nOf(context).t('s5.tooShort'));
  }

  /// D2 phase 1: the microphone is pre-explained before the OS prompt, and
  /// nothing records before the learner has agreed. Consent lands on the next
  /// hold — the press that opened the dialog is already over (§4.6).
  Future<void> _beginPress() async {
    if (_phase != _RetellPhase.idle && _phase != _RetellPhase.feedback) return;
    // Kick off model loading on first press (not in initState — avoids
    // the ~100MB ONNX load stuttering the screen entry).
    unawaited(_checkModel());
    MicPermissionState state = await widget.permission.check();
    if (!mounted) return;
    if (state != MicPermissionState.granted) {
      final AppLocalizations l10n = _l10nOf(context);
      final bool allow = await showConfirmDialog(
        context,
        title: l10n.t('s5.permTitle'),
        body: l10n.t('s5.permBody'),
        denyLabel: l10n.t('s5.permDeny'),
        allowLabel: l10n.t('s5.permAllow'),
      );
      if (!mounted || !allow) return;
      state = await widget.permission.request();
      if (!mounted) return;
      setState(() => _micDeniedPermanently =
          state == MicPermissionState.permanentlyDenied);
      return;
    }
    if (_pressed && _phase != _RetellPhase.recording) await _startRecording();
  }

  Future<void> _startRecording() async {
    await widget.audio.discard(); // supersede the previous attempt's file (§6)
    // File-only recording: the WAV file feeds both playback and ASR.
    // No separate engine.start() — dual AudioRecord starves on MIUI.
    await widget.audio.start();
    if (!mounted) return;
    if (!_pressed) {
      await _cancelStartup();
      return;
    }
    setState(() {
      _phase = _RetellPhase.recording;
      _heldSeconds = 0;
      _ticks = 0;
      _showRetryNote = _noSpeech = _asrDegraded = false;
      _paceText = null;
    });
    _holdTick?.cancel();
    // [RecordButton] fires `onTimeout` once the cap is on screen.
    _holdTick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _phase != _RetellPhase.recording) return;
      _ticks += 1;
      setState(() => _heldSeconds =
          (_ticks * 0.1).clamp(0, _rubric.maxSeconds).toDouble());
    });
  }

  Future<void> _cancelStartup() async {
    if (_engineListening) {
      await widget.engine.stop();
      _engineListening = false;
    }
    await widget.audio.discard();
  }

  Future<void> _discardTake() async {
    _holdTick?.cancel();
    setState(() {
      _phase = _RetellPhase.idle;
      _heldSeconds = 0;
    });
    await _cancelStartup();
  }


  Future<void> _stopRecording() async {
    if (_stopping) return;
    _stopping = true;
    _holdTick?.cancel();
    setState(() {
      _phase = _RetellPhase.processing;
      _asrDegraded = !_asrReady;
    });
    // Stop the single file recorder and get the WAV path.
    final String path = await widget.audio.stop();
    _engineListening = false;
    // Feed the WAV file through VAD + Whisper (no separate AudioRecord).
    Transcript transcript = const Transcript(text: '', durationMs: 0, pauseGapsMs: <int>[]);
    if (_asrReady && path.isNotEmpty) {
      try {
        final capture = await widget.engine.processWavFile(path);
        transcript = transcriptFromCapture(capture);
      } catch (e) {
        debugPrint('[ASR] processWavFile failed: $e');
      }
    }
    if (mounted) _finishTake(transcript, path);
    _stopping = false;
  }

  void _finishTake(Transcript transcript, String path) {
    debugPrint('[ASR] _finishTake: text="${transcript.text}" '
        'durationMs=${transcript.durationMs} '
        'pauses=${transcript.pauseGapsMs.length} '
        'asrReady=$_asrReady');
    final List<Concept> concepts = <Concept>[
      for (final Scene s in _scenes) ...s.concepts,
    ];
    _total = concepts.length;
    if (!_asrReady) {
      // ASR not connected: reference points only, never a score (D2 phase 3).
      setState(() {
        _phase = _RetellPhase.feedback;
        _audioPath = path;
        _noSpeech = false;
        _hit = 0;
        _paceText = null;
        _transcriptText = transcript.text;
        _missingLabels = <String>[
          for (final Concept c in concepts) _conceptLabel(c),
        ];
      });
      _revealFeedback();
      return;
    }
    if (transcript.text.trim().isEmpty) {
      // docs/09 §8: an empty recognition is "re-record", not an attempt.
      setState(() {
        _phase = _RetellPhase.feedback;
        _audioPath = path;
        _noSpeech = true;
        _asrDegraded = false;
        _transcriptText = transcript.text;
      });
      _revealFeedback();
      return;
    }
    final RetellScore score = scoreRetell(
      transcript: transcript,
      scenes: _scenes,
      rubric: _rubric,
    );
    setState(() {
      _phase = _RetellPhase.feedback;
      _audioPath = path;
      _noSpeech = false;
      _asrDegraded = false;
      _transcriptText = transcript.text;
      _hit = _total - score.missingConceptIds.length;
      _paceText = _l10nOf(context).t(
        score.feedbackKeys.contains('retell.feedback.fluencyOk')
            ? 'retell.feedback.fluencyOk'
            : 'retell.feedback.fluency',
      );
      _missingLabels = <String>[
        for (final String id in score.missingConceptIds) _labelFor(id),
      ];
    });
    _revealFeedback();
    unawaited(widget.controller.submitRetellAttempt(
      sceneId: _scene.id,
      attempt: RetellAttempt(
        durationMs: transcript.durationMs,
        wordCount: _rawWordCount(transcript.text),
        concept: score.concept,
        fluency: score.fluency,
        completeness: score.completeness,
        total: score.total,
        missingConceptIds: List<String>.from(score.missingConceptIds),
      ),
      conceptHitIds: <String>[
        for (final Scene s in _scenes)
          for (final Concept c in s.concepts)
            if (!score.missingConceptIds.contains(c.id)) c.id,
      ],
    ));
  }

  /// Interruption path: discard the half recording entirely (docs/09 §5).
  Future<void> _abortRecording() async {
    _holdTick?.cancel();
    if (_engineListening) {
      await widget.engine.stop();
      _engineListening = false;
    }
    if (_phase == _RetellPhase.recording || _phase == _RetellPhase.processing) {
      await widget.audio.discard();
    }
    if (!mounted) return;
    setState(() {
      _phase = _RetellPhase.idle;
      _heldSeconds = 0;
      _noSpeech = false;
      _asrDegraded = false;
      _paceText = null;
      _showRetryNote = true;
    });
  }

  void _onInterruption(RecordingInterruption event) {
    if (event == RecordingInterruption.background) {
      if (_phase == _RetellPhase.recording) unawaited(_stopRecording());
      return;
    }
    unawaited(_abortRecording().then((_) async {
      if (event != RecordingInterruption.permissionRevoked) return;
      final MicPermissionState s = await widget.permission.check();
      if (mounted) {
        setState(() => _micDeniedPermanently =
            s == MicPermissionState.permanentlyDenied);
      }
    }));
  }

  void _retryTake() => setState(() {
        _phase = _RetellPhase.idle;
        _heldSeconds = 0;
        _noSpeech = _asrDegraded = false;
        _paceText = null;
      });

  void _revealFeedback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  int _rawWordCount(String text) {
    final String trimmed = text.trim();
    return trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length;
  }

  String _conceptLabel(Concept c) =>
      retellConceptLabel(c, widget.controller.glossLocale, widget.defaultGloss);

  String _labelFor(String id) =>
      retellLabelFor(_scenes, id, widget.controller.glossLocale, widget.defaultGloss);
}
