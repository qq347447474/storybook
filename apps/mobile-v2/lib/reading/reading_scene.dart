/// `.scene-figure` — the 3:2 story plate of S2 with its "with audio" caption
/// (`visual/app.css` L1680-1710, design-spec §4.3 item 3).
///
/// Separate from `reading_parts.dart` only to keep both files inside the
/// 300-line budget: the plate is one illustration plus one pill.
library;

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';

import '../i18n/gloss_lookup.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../ui/app_icon.dart';
import '../ui/app_illustration.dart';
import '../ui/media_image.dart';

/// `.scene-figure` — the 3:2 story plate with its "with audio" caption.
///
/// The art is the **pack's own** illustration whenever it carries one — the
/// chapter's retell scene plate first, then the book cover. The bundled
/// `scene-rain-window` / `scene-puddle-boat` plates are only the fallback for
/// packs that shipped before images existed; every downloaded book used to
/// show that same default because the screen never consulted the pack.
class SceneFigure extends StatelessWidget {
  const SceneFigure({
    super.key,
    required this.illustration,
    required this.caption,
    this.alt,
    this.artCandidates = const <String>[],
    this.mediaResolver,
  });

  /// Bundled fallback of `assets/visual/`, e.g. `scene-rain-window`.
  final String illustration;

  /// "With audio" — the small pill in the bottom-right corner.
  final String caption;

  /// Content-language alt text (from the pack's scene), when it has one.
  final String? alt;

  /// Pack media URLs to try in order (scene plate, then cover). The first one
  /// that resolves wins; empty or all-missing falls back to [illustration].
  final List<String> artCandidates;

  /// Resolver for [artCandidates]; `null` shows the bundled plate.
  final MediaResolver? mediaResolver;

  /// `.scene-figure { border-radius: 22px }` (app.css L1690).
  static const double radius = 22;

  /// `.scene-caption { right/bottom: 10px; height: 23px }`.
  static const double captionInset = 10;
  static const double captionHeight = 23;
  static const double captionIconSize = 12;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        children: <Widget>[
          ColoredBox(
            color: AppColors.surfaceSunken,
            child: AspectRatio(
              aspectRatio: AppIllustration.sceneAspectRatio,
              child: _PackArt(
                candidates: artCandidates,
                fallback: illustration,
                mediaResolver: mediaResolver,
                semanticLabel: alt,
              ),
            ),
          ),
          PositionedDirectional(
            end: captionInset,
            bottom: captionInset,
            child: _Caption(text: caption),
          ),
        ],
      ),
    );
  }
}

/// `.scene-caption`: solid brand pill, glyph + text (§7.2 — never colour only).
class _Caption extends StatelessWidget {
  const _Caption({required this.text});

  final String text;

  static const double _gap = 5;
  static const EdgeInsets _padding = EdgeInsets.symmetric(horizontal: 8);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: SceneFigure.captionHeight),
      padding: _padding,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const AppIcon(
            'headphones',
            size: SceneFigure.captionIconSize,
            color: AppColors.onPrimary,
          ),
          const SizedBox(width: _gap),
          Text(
            text,
            softWrap: false,
            style: AppTypography.label.copyWith(
              color: AppColors.onPrimary,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Resolves the pack's own artwork for the story plate.
///
/// Tries [candidates] in order through the [MediaResolver] and paints the
/// first one that comes back — SVG or PNG alike (pipeline art is SVG, the
/// bundled sample cover is PNG). When nothing resolves, the bundled plate
/// named by [fallback] stands in, so a pack without images still renders.
class _PackArt extends StatefulWidget {
  const _PackArt({
    required this.candidates,
    required this.fallback,
    required this.mediaResolver,
    this.semanticLabel,
  });

  final List<String> candidates;
  final String fallback;
  final MediaResolver? mediaResolver;
  final String? semanticLabel;

  @override
  State<_PackArt> createState() => _PackArtState();
}

class _PackArtState extends State<_PackArt> {
  late final Future<ResolvedMedia?> _future = _resolve();

  Future<ResolvedMedia?> _resolve() async {
    final MediaResolver? resolver = widget.mediaResolver;
    if (resolver == null) return null;
    for (final String url in widget.candidates) {
      if (url.isEmpty) continue;
      try {
        final ResolvedMedia? media = await resolver.resolve(url);
        if (media != null) return media;
      } on Exception catch (_) {
        // A single missing file never blocks the plate; try the next one.
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ResolvedMedia?>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<ResolvedMedia?> snap) {
        final ResolvedMedia? media = snap.data;
        if (media != null) {
          return MediaImage(
            media: media,
            fit: BoxFit.cover,
            errorFallback: _bundled(),
          );
        }
        return _bundled();
      },
    );
  }

  Widget _bundled() => AppIllustration(
        widget.fallback,
        aspectRatio: AppIllustration.sceneAspectRatio,
        fit: BoxFit.cover,
        semanticLabel: widget.semanticLabel,
      );
}

/// Alt text of the chapter's scene plate: the pack's own retell illustration alt
/// (content language, decision ③), or `null` when it ships no scene.
String? sceneAltOf(List<Scene> scenes, String glossLocale) {
  if (scenes.isEmpty) return null;
  final String alt = glossOf(
    scenes.first.image.alt,
    glossLocale,
    // Same locale twice: any available translation beats no alt at all.
    glossLocale,
  );
  return alt.isEmpty ? null : alt;
}
