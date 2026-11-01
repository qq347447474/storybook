/// Quiz screen S4 (design-spec §4.5, `visual/app.css` L2180-2464).
///
/// **D1 (docs/13): every question must be answered correctly before the next
/// one.** A wrong answer never reveals the correct option — it shows the warning
/// card plus the story sentence that proves it, and only that question may be
/// retried. The single graded submission, sent after the last correct answer, is
/// therefore always 100 %. `packages/core_content`'s 0.8 guard
/// (`chapter_state.dart` `submitQuiz`) stays a compatibility net for v1 data,
/// not the v2 effective path: this screen neither relies on nor weakens it.
/// No score, percentage or pass/fail wording appears anywhere (§4.5 克制点).
library;

import 'dart:async';

import 'package:core_content/core_content.dart';
import 'package:core_scoring/core_scoring.dart';
import 'package:flutter/material.dart';

import '../i18n/app_localizations.dart';
import '../i18n/gloss_lookup.dart';
import '../reading/reading_controller.dart';
import '../settings/app_settings.dart';
import '../theme/app_colors.dart';
import '../ui/components/dock_cta.dart';
import '../ui/components/stage_app_bar.dart';
import '../ui/components/unlock_panel.dart';
import 'quiz_body.dart';
import 'quiz_parts.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.controller,
    this.l10n,
    this.appSettings,
    required this.defaultGloss,
    this.onContinueToRetell,
    this.onPreviousStep,
    this.onNextStep,
  });

  final ReadingController controller;

  /// Explicit catalog override (tests); production resolves via [L10nScope]
  /// so language switches rebuild without a restart.
  final AppLocalizations? l10n;

  /// Shared settings; when present gloss switches rebuild this screen live.
  final AppSettings? appSettings;

  /// `locales.defaultGloss` of the pack (decision ③ fallback).
  final String defaultGloss;

  /// Navigation hook of the unlock panel's CTA (S5).
  final VoidCallback? onContinueToRetell;

  /// Step navigation (practice mode).
  final VoidCallback? onPreviousStep;
  final VoidCallback? onNextStep;

  /// Step index of this screen inside the four-stage loop.
  static const int step = 3;

  /// How long the last correct answer is allowed to land before the unlock
  /// panel rises (§4.5: "650 ms 后弹面板").
  static const Duration unlockDelay = Duration(milliseconds: 650);

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _index = 0;
  int? _selected;

  /// True once the current question has been judged (right or wrong).
  bool _submitted = false;

  /// Verdict of that judgement; meaningless while [_submitted] is false.
  bool _isCorrect = false;

  /// Correct answers only — the graded submission is built from these.
  final Map<String, int> _answers = <String, int>{};

  /// Guards the panel against a double schedule (timer + CTA, rebuilds).
  bool _panelRequested = false;

  /// Delay between the last correct answer and the panel (§4.5: 650 ms).
  Timer? _panelTimer;

  @override
  void initState() {
    super.initState();
    widget.appSettings?.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _panelTimer?.cancel();
    widget.appSettings?.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  /// Resolves the active catalog: explicit override first, then the
  /// [L10nScope] (registers a dependency so language switches rebuild).
  AppLocalizations _l10nOf(BuildContext context) =>
      widget.l10n ?? L10nScope.of(context);

  List<QuizItem> get _items => widget.controller.chapter.quiz;

  QuizItem get _current => _items[_index];

  bool get _isLast => _index >= _items.length - 1;

  void _select(int option) {
    if (_submitted) return;
    setState(() => _selected = option);
  }

  /// Judges the current question. A right answer is recorded and — on the last
  /// question — becomes the single graded submission.
  void _submit() {
    if (_selected == null || _submitted) return;
    final bool correct = _selected == _current.answer;
    setState(() {
      _submitted = true;
      _isCorrect = correct;
      if (correct) _answers[_current.id] = _selected!;
    });
    if (correct && _isLast) _finish();
  }

  /// Wrong answers stay on the same question: clear the verdict, drop the
  /// selection, keep every earlier correct answer (D1).
  void _retryThisQuestion() {
    setState(() {
      _submitted = false;
      _isCorrect = false;
      _selected = null;
    });
  }

  void _next() {
    if (_isLast) return;
    setState(() {
      _index += 1;
      _selected = null;
      _submitted = false;
      _isCorrect = false;
    });
  }

  /// The one graded submission of a run: every question was answered correctly,
  /// so the accuracy is 1.0 by construction (see the library doc).
  Future<void> _finish() async {
    final QuizResult result =
        gradeQuiz(_items, Map<String, int>.of(_answers));
    await widget.controller.submitQuizAttempt(
      answers: Map<String, int>.of(_answers),
      result: result,
    );
    if (!mounted) return;
    setState(() {}); // stage is now `retell`
    _requestPanel();
  }

  /// Schedules the unlock panel a beat after the last answer, so the tick is
  /// seen before the modal covers it (design-spec §4.5).
  void _requestPanel() {
    if (_panelRequested) return;
    _panelRequested = true;
    _panelTimer = Timer(QuizScreen.unlockDelay, () {
      if (mounted) _showPanel();
    });
  }

  /// Rises the panel now — used by the CTA when the learner beats the timer.
  void _showPanelNow() {
    if (!_panelRequested) return;
    _panelTimer?.cancel();
    _showPanel();
  }

  Future<void> _showPanel() async {
    if (!mounted) return;
    final AppLocalizations l10n = _l10nOf(context);
    await showUnlockPanel(
      context,
      title: l10n.t('s4.unlockTitle'),
      body: l10n.t('s4.unlockBody'),
      steps: <String>[
        l10n.t('chapter.reading'),
        l10n.t('chapter.vocabulary'),
        l10n.t('chapter.quiz'),
        l10n.t('chapter.retell'),
      ],
      ctaLabel: l10n.t('s4.retellCta'),
      onCta: widget.onContinueToRetell,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = _l10nOf(context);
    final List<QuizItem> items = _items;
    final QuizItem item = _current;
    final String stage = l10n.t('s4.stage', args: <String, Object>{
      'step': QuizScreen.step,
      'total': 4,
    });

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            StageAppBar(
              step: QuizScreen.step,
              onClose: () => Navigator.of(context).maybePop(),
              closeLabel: l10n.t('nav.close'),
              progressLabel: stage,
              onPreviousStep: widget.onPreviousStep,
              onNextStep: widget.onNextStep,
            ),
            Expanded(
              child: QuizBody(
                // `--gutter: 20px`, `.screen--quiz .scroll { padding-top: 4px }`.
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                head: QuizHead(
                  eyebrow: stage,
                  count: l10n.t('quiz.count', args: <String, Object>{
                    'current': _index + 1,
                    'total': items.length,
                  }),
                  prompt: item.prompt,
                  promptGloss: item.promptGloss == null
                      ? null
                      : glossOf(
                          item.promptGloss!,
                          widget.controller.glossLocale,
                          widget.defaultGloss,
                        ),
                ),
                options: QuizOptions(
                  options: item.options,
                  stateOf: (int i) => optionVisualState(
                    option: i,
                    selected: _selected,
                    submitted: _submitted,
                    correct: _isCorrect,
                  ),
                  // Post-judgement the rows stop answering: the CTA is the only
                  // way forward (§5.5).
                  onSelect: _submitted ? null : _select,
                ),
                feedback: _submitted
                    ? QuizFeedbackArea(
                        correct: _isCorrect,
                        correctTitle: l10n.t('quiz.readRight'),
                        wrongTitle: l10n.t('quiz.lookBack'),
                        evidenceLabel: l10n.t('s4.evidence'),
                        evidenceText: evidenceParagraph(
                          widget.controller.chapter.reading,
                          item,
                        ),
                        correctOption: item.options[item.answer],
                      )
                    : null,
                tip: l10n.t('s4.tip'),
              ),
            ),
            AppDock(
              key: const Key('quiz-dock'),
              primaryLabel: _ctaLabel(l10n),
              helper: _helper(l10n),
              onPrimaryPressed: _ctaAction(),
            ),
          ],
        ),
      ),
    );
  }

  String _ctaLabel(AppLocalizations l10n) {
    if (!_submitted) return l10n.t('quiz.submit');
    if (!_isCorrect) return l10n.t('quiz.retry');
    return _isLast ? l10n.t('s4.retellCta') : l10n.t('quiz.next');
  }

  /// The dock helper is the reason a CTA is disabled (§5.1), so it only
  /// appears while nothing has been picked.
  String? _helper(AppLocalizations l10n) =>
      _selected == null && !_submitted ? l10n.t('s4.helper') : null;

  VoidCallback? _ctaAction() {
    if (!_submitted) return _selected == null ? null : _submit;
    if (!_isCorrect) return _retryThisQuestion;
    // The last correct answer already submitted; the CTA opens the panel the
    // same way the 650 ms timer would, so there is only one way forward.
    return _isLast ? _showPanelNow : _next;
  }
}
