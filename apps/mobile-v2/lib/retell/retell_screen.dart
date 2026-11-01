/// Retell screen S5 (design-spec §4.6, D2 in docs/13).
///
/// Four-phase machine (D2, in `retell_machine.dart`): pre-explain the
/// microphone on a first press -> hold to record for at most
/// `rubric.maxSeconds` -> on-device recognition -> gentle feedback -> "Done"
/// hands off to S6. The countdown ring follows the rubric cap (never a fixed
/// 30 s), a press under 800 ms is discarded with a toast, and when the ASR is
/// not connected the screen degrades to the reference key points instead of
/// inventing a score.
///
/// Red lines: no score, percentage, star rating, ranking or pass/fail anywhere
/// (docs/04 §3); the recording is discarded as soon as it is superseded or the
/// screen is left (docs/09 §6).
library;

import 'dart:async';

import 'package:core_content/core_content.dart';
import 'package:core_scoring/core_scoring.dart';
import 'package:core_speech/core_speech.dart';
import 'package:flutter/material.dart';

import '../audio/audio_player_service.dart';
import '../audio/mic_permission.dart';
import '../audio/retell_audio_source.dart';
import '../i18n/app_localizations.dart';
import '../i18n/gloss_lookup.dart';
import '../reading/reading_controller.dart';
import '../settings/app_settings.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../ui/components/app_toast.dart';
import '../ui/components/confirm_dialog.dart';
import '../ui/components/dock_cta.dart';
import '../ui/components/inline_bar.dart';
import '../ui/components/record_button.dart';
import '../ui/components/stage_app_bar.dart';
import 'retell_parts.dart';
import 'retell_tools.dart';

part 'retell_machine.dart';

enum _RetellPhase { idle, recording, processing, feedback }

class RetellScreen extends StatefulWidget {
  const RetellScreen({
    super.key,
    required this.controller,
    required this.engine,
    required this.audio,
    required this.permission,
    required this.player,
    required this.mediaResolver,
    required this.defaultGloss,
    this.onDone,
    this.l10n,
    this.appSettings,
    this.onPreviousStep,
    this.onNextStep,
  });

  final ReadingController controller;
  final SpeechEngine engine;
  final RetellAudioSource audio;
  final MicPermissionService permission;
  final AudioPlayerService player;
  final MediaResolver mediaResolver;
  final String defaultGloss;
  final VoidCallback? onDone;

  /// Step navigation (practice mode).
  final VoidCallback? onPreviousStep;
  final VoidCallback? onNextStep;

  /// Explicit catalog override (tests); production resolves via [L10nScope].
  final AppLocalizations? l10n;

  /// Shared settings; when present gloss switches rebuild this screen live.
  final AppSettings? appSettings;

  /// Step index of this screen inside the four-stage loop.
  static const int step = 4;

  @override
  State<RetellScreen> createState() => _RetellScreenState();
}

class _RetellScreenState extends State<RetellScreen>
    with WidgetsBindingObserver, _RetellMachine {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.appSettings?.addListener(_onSettingsChanged);
    initMachine();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.appSettings?.removeListener(_onSettingsChanged);
    disposeMachine();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // docs/09 §5: background -> stop; a half recording never keeps running.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_phase == _RetellPhase.recording) unawaited(_stopRecording());
    }
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = _l10nOf(context);
    final String stage = l10n.t('s5.stage',
        args: <String, Object>{'step': RetellScreen.step});
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            StageAppBar(
              step: RetellScreen.step,
              onClose: () => Navigator.of(context).maybePop(),
              closeLabel: l10n.t('nav.close'),
              progressLabel: stage,
              onPreviousStep: widget.onPreviousStep,
              onNextStep: widget.onNextStep,
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    RetellHead(
                      eyebrow: stage,
                      title: l10n.t('s5.title'),
                      count: _scenes.length > 1
                          ? l10n.t('quiz.count', args: <String, Object>{
                              'current': 1,
                              'total': _scenes.length,
                            })
                          : null,
                    ),
                    RetellSceneFigure(
                      scene: _scene,
                      mediaResolver: widget.mediaResolver,
                      glossLocale: widget.controller.glossLocale,
                      defaultGloss: widget.defaultGloss,
                    ),
                    RetellStepChips(labels: <String>[
                      l10n.t('chapter.reading'),
                      l10n.t('chapter.vocabulary'),
                      l10n.t('chapter.quiz'),
                      l10n.t('chapter.retell'),
                    ]),
                    RetellNarrative(
                      question: _scene.prompt,
                      prompt: l10n.t('s5.prompt'),
                    ),
                    RetellHintTools(
                      hint1Label: l10n.t('retell.hint1'),
                      hint2Label: l10n.t('retell.hint2'),
                      hint1Body: glossOf(_scene.hint1,
                          widget.controller.glossLocale, widget.defaultGloss),
                      hint2Body: glossOf(_scene.hint2,
                          widget.controller.glossLocale, widget.defaultGloss),
                      openHint: _openHint,
                      hint1Seen: _hint1Seen,
                      onToggle1: () => setState(() {
                        _hint1Seen = true;
                        _openHint = _openHint == 1 ? null : 1;
                      }),
                      onToggle2: () => setState(() {
                        _openHint = _openHint == 2 ? null : 2;
                      }),
                    ),
                    if (_phase == _RetellPhase.feedback) ...<Widget>[
                      const SizedBox(height: 14),
                      _feedbackCard(l10n),
                    ],
                    if (_showRetryNote) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        l10n.t('retell.retry'),
                        key: const Key('retell-retry-note'),
                        style: AppTypography.meta
                            .copyWith(color: AppColors.ink3, height: 1.55),
                      ),
                    ],
                    RetellTipBar(text: l10n.t('s5.tip')),
                  ],
                ),
              ),
            ),
            // design-spec §4.6: the record key lives in the fixed dock, so a
            // hold never fights the scrollable's drag recogniser (which would
            // delay `onTapDown` past the 100 ms press deadline).
            _recordBlock(l10n),
            AppDock(
              key: const Key('retell-continue'),
              primaryLabel: l10n.t('s5.done'),
              helper: widget.onDone == null ? l10n.t('s5.tip') : null,
              onPrimaryPressed: widget.onDone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordBlock(AppLocalizations l10n) {
    final bool recording = _phase == _RetellPhase.recording;
    final int remaining =
        (_rubric.maxSeconds - _heldSeconds).ceil().clamp(0, _rubric.maxSeconds);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: <Widget>[
          RetellRecordStatus(
            statusText: recording
                ? l10n.t('s5.recording')
                : _phase == _RetellPhase.processing
                    ? l10n.t('s5.processing')
                    : null,
            countdown: recording ? remaining : null,
          ),
          const SizedBox(height: 10),
          RecordButton(
            key: const Key('retell-record-button'),
            state: switch (_phase) {
              _RetellPhase.recording => RecordState.recording,
              _RetellPhase.processing => RecordState.processing,
              _RetellPhase.idle || _RetellPhase.feedback => RecordState.idle,
            },
            maxSeconds: _rubric.maxSeconds,
            heldSeconds: _heldSeconds,
            label: l10n.t('retell.record'),
            onHoldStart: _onHoldStart,
            onHoldEnd: _onHoldEnd,
            onTooShort: _onTooShort,
            onTimeout: _onTimeout,
          ),
          if (_asrDegraded &&
              (_phase == _RetellPhase.processing ||
                  _phase == _RetellPhase.feedback)) ...<Widget>[
            const SizedBox(height: 12),
            RetellAsrNote(message: l10n.t('s5.asrNote')),
          ],
          if (_micDeniedPermanently) ...<Widget>[
            const SizedBox(height: 12),
            InlineBar(
              key: const Key('retell-perm-banner'),
              message: l10n.t('s5.permBody'),
              icon: 'mic-off',
              actionLabel: l10n.t('perm.mic.settings'),
              onAction: widget.permission.openSettings,
            ),
          ],
        ],
      ),
    );
  }

  /// Renders ONLY counts and key-point names — never a total, rank or verdict.
  Widget _feedbackCard(AppLocalizations l10n) {
    if (_noSpeech) {
      return RetellFeedbackCard(
        title: l10n.t('retell.feedback.noSpeech'),
        missingPoints: const <String>[],
        retryLabel: l10n.t('retell.retry'),
        onRetry: _retryTake,
      );
    }
    return RetellFeedbackCard(
      title: l10n.t('retell.feedback.concepts',
          args: <String, Object>{'hit': _hit, 'total': _total}),
      missingPoints: _missingLabels,
      paceText: _paceText,
      transcriptLabel: l10n.t('s5.transcriptLabel'),
      transcriptText: _transcriptText,
      replayLabel: _audioPath == null || _audioPath!.isEmpty
          ? null
          : l10n.t('retell.replay'),
      retryLabel: l10n.t('retell.retry'),
      onReplay: () async {
        await widget.player.load(_audioPath!);
        await widget.player.play();
      },
      onRetry: _retryTake,
    );
  }
}
