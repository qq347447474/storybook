/// Chapter complete screen S6 (design-spec §4.7, `visual/app.css` L3093-3300).
///
/// The screen closes the loop: the celebration scene, "you told the story", the
/// four steps ticked, the story's own closing line, and one way forward.
///
/// Two product rules shape it:
/// - **no score, no rating, no share card** (`docs/04` §3, §4.7 克制点) — every
///   number on screen is a count of content, never of performance;
/// - the celebration is decoration: it stops after 2.4 s, never blocks input,
///   and disappears entirely under reduced motion (§2.6).
///
/// [chapter] / [bookTitle] are optional so the screen still renders honestly
/// when a caller has no pack data (tests, deep re-entry): the eyebrow falls back
/// to "Chapter complete", the word count clause is dropped and the quote card is
/// hidden rather than faked.
library;

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';

import '../i18n/app_localizations.dart';
import '../theme/app_colors.dart';
import 'celebration_scene.dart';
import 'completion_meta.dart';
import 'completion_parts.dart';

class CompletionScreen extends StatelessWidget {
  const CompletionScreen({
    super.key,
    required this.reduceMotion,
    this.onDone,
    this.l10n,
    this.chapter,
    this.bookTitle,
    this.onReplay,
  });

  /// When true the celebration is a static plate — no confetti, no scaling.
  final bool reduceMotion;

  /// "Back to contents": pops this route (the caller decides how far).
  final VoidCallback? onDone;

  /// Explicit catalog override (tests); production resolves via [L10nScope].
  final AppLocalizations? l10n;

  /// Chapter that was just finished — source of the order, the word count and
  /// the closing quote. `null` degrades to the generic variant.
  final Chapter? chapter;

  /// Title of the book, for the quote's credit line.
  final String? bookTitle;

  /// "Read it again": re-enters S2 for the same chapter. `null` falls back to
  /// [onDone] so the action is never a dead end.
  final VoidCallback? onReplay;

  /// `.complete-wrap { padding: 18px 26px 0 }` (app.css L3108).
  static const EdgeInsets wrapPadding = EdgeInsets.fromLTRB(26, 18, 26, 0);

  /// `.screen--complete` warm glow: `radial-gradient(340px 280px at 50% 22%,
  /// rgba(232,161,92,.16), transparent 70%)`, expressed as the accent token at
  /// 16 % so the page keeps one palette.
  static const double glowOpacity = 0.16;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = this.l10n ?? L10nScope.of(context);
    final Chapter? chapter = this.chapter;
    final int words = chapter == null ? 0 : targetWordCount(chapter);
    final String quote = chapter == null ? '' : closingQuote(chapter);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            // 50 % / 22 % of the canvas, softened over 70 % of the radius.
            center: const Alignment(0, -0.56),
            radius: 0.62,
            colors: <Color>[
              AppColors.accent.withValues(alpha: glowOpacity),
              AppColors.accent.withValues(alpha: 0),
            ],
            stops: const <double>[0, 0.7],
          ),
        ),
        child: Column(
          children: <Widget>[
            Expanded(
              child: SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  padding: wrapPadding,
                  child: Column(
                    children: <Widget>[
                      const SizedBox(height: 6),
                      CelebrationScene(reduceMotion: reduceMotion),
                      CompletionHeading(
                        eyebrow: _eyebrow(l10n, chapter),
                        title: l10n.t('s6.title'),
                        // The count clause needs a chapter to count; without
                        // one the screen says less instead of guessing.
                        body: words > 0
                            ? l10n.t('s6.body', args: <String, Object>{
                                'words': words,
                              })
                            : null,
                        bodyTail: l10n.t('s6.bodyTail'),
                      ),
                      CompletionRecap(labels: _stepLabels(l10n)),
                      if (quote.isNotEmpty) CompletionQuote(
                        quote: quote,
                        attribution: _attribution(l10n, chapter),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
            CompleteDock(
              ctaLabel: l10n.t('s6.cta'),
              againLabel: l10n.t('s6.again'),
              onCta: onDone,
              // "Read it again" — the app shell wires [onReplay] to the real
              // re-read entry (stage back to `reading`, statistics kept); a
              // caller without that entry falls back to the exit action so
              // the control is never a dead end.
              onAgain: onReplay ?? onDone,
            ),
          ],
        ),
      ),
    );
  }

  /// "Chapter 1 complete", or the plain fact when no chapter was handed in.
  String _eyebrow(AppLocalizations l10n, Chapter? chapter) {
    if (chapter == null) return l10n.t('chapter.complete');
    return l10n.t('s6.eyebrow', args: <String, Object>{'n': chapter.order});
  }

  /// `THE PAPER BOAT · CH. 1` — the credit line under the quote.
  String _attribution(AppLocalizations l10n, Chapter? chapter) {
    final String? title = bookTitle;
    if (chapter == null || title == null || title.isEmpty) return '';
    return l10n.t('s6.attribution', args: <String, Object>{
      // The label step is set in upper case in the hand-off; the book title is
      // the only running text that gets the treatment (CJK is unaffected).
      'title': title.toUpperCase(),
      'n': chapter.order,
    });
  }

  /// The four steps of the loop, in order, all ticked.
  List<String> _stepLabels(AppLocalizations l10n) => <String>[
        l10n.t('chapter.reading'),
        l10n.t('chapter.vocabulary'),
        l10n.t('chapter.quiz'),
        l10n.t('chapter.retell'),
      ];
}
