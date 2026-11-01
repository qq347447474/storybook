/// The framing pieces of S5 retell (design-spec §4.6): head, scene figure,
/// step chips and the narration block.
///
/// Pure presentation — every string and every callback arrives from
/// `retell_screen.dart`, so this file never touches the recorder, the score
/// or the catalog. Geometry and type come from [AppColors] / [AppTypography];
/// there is not one bare hex in here.
library;

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';

import '../i18n/gloss_lookup.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../ui/components/app_chip.dart';
import '../ui/media_image.dart';

/// Placeholder scene for a chapter that ships without `retell.scenes[]` —
/// keeps every builder total instead of guarding emptiness at each call site.
final Scene emptyRetellScene = Scene(
  id: '',
  order: 1,
  image: Media(url: '', alt: LocalizedText(const <String, String>{})),
  prompt: '',
  concepts: const <Concept>[],
  hint1: LocalizedText(const <String, String>{}),
  hint2: LocalizedText(const <String, String>{}),
  suggestedAnswer: '',
  targetWordCount: 0,
);

/// Eyebrow + serif invitation, with the optional `N / M` scene counter.
class RetellHead extends StatelessWidget {
  const RetellHead({
    super.key,
    required this.eyebrow,
    required this.title,
    this.count,
  });

  /// `复述 · 第 4 步` — already localised.
  final String eyebrow;

  /// Serif heading — `把故事讲出来`.
  final String title;

  /// `1 / 2` when the chapter carries more than one scene; null hides it.
  final String? count;

  /// `.retell-head { padding: 8px 2px 0 }` (app.css), title 12 dp under.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(2, 8, 2, 0);
  static const double titleGap = 12;
  static const double eyebrowTracking = 0.13;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  eyebrow,
                  key: const Key('retell-eyebrow'),
                  style: AppTypography.label.copyWith(
                    color: AppColors.primary,
                    letterSpacing: eyebrowTracking * 11,
                  ),
                ),
              ),
              if (count != null)
                Text(
                  count!,
                  key: const Key('retell-step-counter'),
                  style: AppTypography.tabular(
                    AppTypography.meta.copyWith(color: AppColors.ink3),
                  ),
                ),
            ],
          ),
          const SizedBox(height: titleGap),
          Text(
            title,
            key: const Key('retell-title'),
            // `title` slot: serif 600, the editorial heading of the screen.
            style: AppTypography.title.copyWith(color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}

/// The 3:2 scene plate (`.scene-figure`), origin-aware (T7d-2): bundled media
/// rides the asset key, cached media the file path, remote media the URL, and
/// every failure degrades to the alt-text placeholder (C6).
class RetellSceneFigure extends StatelessWidget {
  const RetellSceneFigure({
    super.key,
    required this.scene,
    required this.mediaResolver,
    required this.glossLocale,
    required this.defaultGloss,
  });

  final Scene scene;
  final MediaResolver mediaResolver;
  final String glossLocale;
  final String defaultGloss;

  /// design-spec §4.6: "3:2 水洼纸船场景插画".
  static const double aspectRatio = 3 / 2;
  static const double radius = 18;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: FutureBuilder<ResolvedMedia?>(
            future: mediaResolver.resolve(scene.image.url),
            builder:
                (BuildContext context, AsyncSnapshot<ResolvedMedia?> snap) {
              final ResolvedMedia? media = snap.data;
              if (media != null) return _imageFor(media);
              return _placeholder();
            },
          ),
        ),
      ),
    );
  }

  /// Raster or SVG — the pipeline draws scene art as SVG.
  Widget _imageFor(ResolvedMedia media) =>
      MediaImage(media: media, errorFallback: _placeholder());

  Widget _placeholder() {
    final String alt = glossOf(scene.image.alt, glossLocale, defaultGloss);
    return Semantics(
      label: alt,
      child: Container(
        key: const Key('retell-image-placeholder'),
        color: AppColors.surfaceSunken,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: Text(
          alt,
          textAlign: TextAlign.center,
          style: AppTypography.meta.copyWith(color: AppColors.ink3),
        ),
      ),
    );
  }
}

/// The four stages of the loop, all ticked (`.recap`) — the step never relies
/// on colour alone (design-spec §7.2).
class RetellStepChips extends StatelessWidget {
  const RetellStepChips({super.key, required this.labels});

  /// Step names in loop order: read, words, quiz, retell.
  final List<String> labels;

  static const double gap = 6;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        key: const Key('retell-steps'),
        spacing: gap,
        runSpacing: gap,
        children: <Widget>[
          for (final String label in labels) AppChip(label, icon: 'check'),
        ],
      ),
    );
  }
}

/// The narration block: the content-language question of the scene over the
/// localised invitation to tell it back.
class RetellNarrative extends StatelessWidget {
  const RetellNarrative({
    super.key,
    required this.question,
    required this.prompt,
    this.promptGloss,
  });

  /// Scene question in the **content** language (docs/03: never translated).
  final String question;

  /// `用自己的话，把刚读过的故事讲出来` — UI copy.
  final String prompt;

  /// Optional gloss-locale line under the question (decision ③).
  final String? promptGloss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            question,
            key: const Key('retell-question'),
            style: AppTypography.h2.copyWith(
              color: AppColors.ink,
              letterSpacing: -0.012 * 22,
            ),
          ),
          if (promptGloss != null && promptGloss!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              promptGloss!,
              style: AppTypography.meta.copyWith(color: AppColors.ink3),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            prompt,
            key: const Key('retell-prompt'),
            style: AppTypography.body.copyWith(
              color: AppColors.ink2,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
