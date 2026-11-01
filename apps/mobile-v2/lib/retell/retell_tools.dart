/// The interactive tools of S5 retell (design-spec §4.6 / §5.8): hint panels,
/// the reassurance tip line, the live record status and the feedback card
/// assembly.
///
/// Copy always arrives from the caller; this file owns layout only. The
/// feedback card passes i18n strings into [RetellFeedback], which paints the
/// hit count and the missing-point chips — never a score, rank or verdict.
library;

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';

import '../i18n/gloss_lookup.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../ui/app_icon.dart';
import '../ui/components/inline_bar.dart';
import '../ui/components/retell_feedback.dart';

/// Hint 1 / Hint 2 — two separate levels, never both open (design-spec §4.6:
/// 「两者从不同时出现」). Hint 2 unlocks only after Hint 1 has been seen.
class RetellHintTools extends StatelessWidget {
  const RetellHintTools({
    super.key,
    required this.hint1Label,
    required this.hint2Label,
    required this.hint1Body,
    required this.hint2Body,
    required this.openHint,
    required this.hint1Seen,
    required this.onToggle1,
    required this.onToggle2,
  });

  final String hint1Label;
  final String hint2Label;
  final String hint1Body;
  final String hint2Body;

  /// Which panel is open right now: `1`, `2` or `null`.
  final int? openHint;

  /// Hint 1 has been opened at least once — the unlock for Hint 2.
  final bool hint1Seen;
  final VoidCallback onToggle1;
  final VoidCallback onToggle2;

  static const double gap = 8;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _hintButton(
            key: const Key('retell-hint1'),
            label: hint1Label,
            expanded: openHint == 1,
            onPressed: onToggle1,
          ),
          if (openHint == 1)
            _hintPanel(const Key('retell-hint1-text'), hint1Body),
          const SizedBox(height: gap),
          _hintButton(
            key: const Key('retell-hint2'),
            label: hint2Label,
            expanded: openHint == 2,
            onPressed: hint1Seen ? onToggle2 : null,
          ),
          if (openHint == 2)
            _hintPanel(const Key('retell-hint2-text'), hint2Body),
        ],
      ),
    );
  }

  Widget _hintButton({
    required Key key,
    required String label,
    required bool expanded,
    required VoidCallback? onPressed,
  }) {
    return TextButton(
      key: key,
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: AppColors.primary,
        disabledForegroundColor: AppColors.ink3,
        textStyle: AppTypography.label.copyWith(letterSpacing: 0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const AppIcon('bulb', size: AppIconSize.sm, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label),
          const SizedBox(width: 4),
          const AppIcon('chevron-down',
              size: AppIconSize.sm, color: AppColors.ink3),
        ],
      ),
    );
  }

  Widget _hintPanel(Key key, String body) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        body,
        key: key,
        style: AppTypography.meta.copyWith(color: AppColors.ink2, height: 1.55),
      ),
    );
  }
}

/// `.quiz-progress-note` twin — the one reassurance line under the feedback.
class RetellTipBar extends StatelessWidget {
  const RetellTipBar({super.key, required this.text});

  final String text;

  static const EdgeInsets padding = EdgeInsets.only(top: 16);
  static const double gap = 6;
  static const double iconSize = 13;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        key: const Key('retell-tip'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: AppIcon('info', size: iconSize, color: AppColors.ink3),
          ),
          const SizedBox(width: gap),
          Expanded(
            child: Text(
              text,
              style: AppTypography.meta.copyWith(color: AppColors.ink3),
            ),
          ),
        ],
      ),
    );
  }
}

/// The `aria-live` status row over the record key: state copy on the left,
/// the remaining-seconds counter on the right while listening.
class RetellRecordStatus extends StatelessWidget {
  const RetellRecordStatus({
    super.key,
    required this.statusText,
    this.countdown,
  });

  /// `正在聆听，松开结束` / `识别中…` — already localised.
  final String? statusText;

  /// Remaining seconds of the take, shown only while listening.
  final int? countdown;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (statusText != null)
            Flexible(
              child: Text(
                statusText!,
                style: AppTypography.meta.copyWith(color: AppColors.ink2),
              ),
            ),
          if (countdown != null) ...<Widget>[
            const SizedBox(width: 8),
            Text(
              '$countdown',
              key: const Key('retell-countdown'),
              style: AppTypography.tabular(
                AppTypography.meta.copyWith(
                  color: AppColors.dangerInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Thin wrapper over [RetellFeedback] that turns the screen's take state into
/// the card's copy: a hit count headline, missing-point chips, one pace line
/// and the replay / record-again text actions.
class RetellFeedbackCard extends StatelessWidget {
  const RetellFeedbackCard({
    super.key,
    required this.title,
    required this.missingPoints,
    this.paceText,
    this.transcriptLabel,
    this.transcriptText,
    this.replayLabel,
    this.retryLabel,
    this.onReplay,
    this.onRetry,
  });

  /// Headline sentence with the hit count, already interpolated.
  final String title;

  /// Key points not covered yet — rendered as soft chips.
  final List<String> missingPoints;

  /// One-line pace hint; null hides the pace row.
  final String? paceText;

  /// Label above the transcript block.
  final String? transcriptLabel;

  /// Raw ASR transcript for the learner to verify.
  final String? transcriptText;

  final String? replayLabel;
  final String? retryLabel;
  final VoidCallback? onReplay;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return RetellFeedback(
      key: const Key('retell-feedback'),
      title: title,
      missingPoints: missingPoints,
      paceText: paceText,
      transcriptLabel: transcriptLabel,
      transcriptText: transcriptText,
      actions: <AppTextAction>[
        if (replayLabel != null && onReplay != null)
          AppTextAction(label: replayLabel!, icon: 'volume', onPressed: onReplay),
        if (retryLabel != null && onRetry != null)
          AppTextAction(label: retryLabel!, icon: 'rotate', onPressed: onRetry),
      ],
    );
  }
}

/// The ASR-not-connected notice (D2 phase 2/3) — amber, one line, no action.
class RetellAsrNote extends StatelessWidget {
  const RetellAsrNote({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return InlineBar(key: const Key('retell-asr-note'), message: message, icon: 'info');
  }
}

/// Gloss label of [c] in the learner's gloss locale (decision ③ fallback).
String retellConceptLabel(Concept c, String glossLocale, String defaultGloss) =>
    glossOf(c.label, glossLocale, defaultGloss);

/// Gloss label of the concept [id] anywhere in [scenes]; the id itself when
/// the content no longer carries it.
String retellLabelFor(List<Scene> scenes, String id, String glossLocale,
    String defaultGloss) {
  for (final Scene s in scenes) {
    for (final Concept c in s.concepts) {
      if (c.id == id) return retellConceptLabel(c, glossLocale, defaultGloss);
    }
  }
  return id;
}
