/// Book cover of S0 (`.book-cover` / `.cover-tag`, `visual/app.css` L1127-1178).
///
/// A 3:2 plate that resolves through the three-stage [MediaResolver] (bundled
/// asset → local cache → network) and never breaks the layout: a missing cover
/// turns into the dashed [MediaPlaceholder] with alt text and a retry button
/// (design-spec §4.1 "封面缺失", §5.11).
///
/// The "offline readable" pill sits on the plate, so the label is passed in
/// already localised — this widget owns geometry, not copy.
library;

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';

import '../i18n/gloss_lookup.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../ui/app_icon.dart';
import '../ui/components/media_placeholder.dart';
import '../ui/media_image.dart';

class LibraryCover extends StatefulWidget {
  const LibraryCover({
    super.key,
    required this.cover,
    required this.uiLocale,
    required this.defaultGloss,
    required this.offlineLabel,
    this.mediaResolver,
    this.retryLabel,
    this.showTag = true,
  });

  /// Cover metadata of the book (url, aspect, alt).
  final Cover cover;

  /// UI locale used to pick the alt text out of `cover.alt`.
  final String uiLocale;

  /// Pack default gloss, the last fallback of the alt lookup.
  final String defaultGloss;

  /// Copy of the on-cover pill — "Offline" / "离线可读".
  final String offlineLabel;

  /// Resolver; `null` renders the placeholder straight away (tests, degraded
  /// bundles).
  final MediaResolver? mediaResolver;

  /// Retry button label of the placeholder. `null` hides the button.
  final String? retryLabel;

  /// Grid tiles show a quieter plate: no "offline" pill on top of the art.
  final bool showTag;

  /// Cover plate of the hand-off (`aspect-ratio: 3 / 2`, app.css L1130).
  static const double fallbackAspectRatio = 3 / 2;

  /// `.book-cover { border-radius: 19px }` pulled onto the `--r-md` token so
  /// the plate stays concentric with the 20 dp card corner.
  static const double radius = 14;

  /// `.cover-tag { height: 25px; padding: 0 9px; gap: 5px }` (app.css L1141).
  static const double tagHeight = 25;
  static const EdgeInsets _tagPadding = EdgeInsets.symmetric(horizontal: 9);
  static const double _tagGap = 5;

  /// `.cover-tag svg { width: 12px; height: 12px }` (app.css L1160).
  static const double _tagIconSize = 12;

  /// `left/bottom: 12px` of the hand-off, mirrored to the bottom-right per
  /// design-spec §4.1 ("右下角").
  static const double tagInset = 12;

  @override
  State<LibraryCover> createState() => _LibraryCoverState();
}

class _LibraryCoverState extends State<LibraryCover> {
  late Future<ResolvedMedia?> _future = _resolve();

  Future<ResolvedMedia?> _resolve() async {
    final MediaResolver? resolver = widget.mediaResolver;
    if (resolver == null) return null;
    return resolver.resolve(widget.cover.url);
  }

  void _retry() {
    setState(() {
      _future = _resolve();
    });
  }

  @override
  Widget build(BuildContext context) {
    final double aspect = widget.cover.aspect > 0
        ? widget.cover.aspect
        : LibraryCover.fallbackAspectRatio;
    final String alt =
        glossOf(widget.cover.alt, widget.uiLocale, widget.defaultGloss);

    return AspectRatio(
      aspectRatio: aspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LibraryCover.radius),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // `.book-cover { background: var(--surface-sunken) }` — the plate
            // reads as media even before the first frame decodes, so the card
            // never flashes its own surface colour.
            const ColoredBox(color: AppColors.surfaceSunken),
            FutureBuilder<ResolvedMedia?>(
              future: _future,
              builder: (BuildContext context,
                  AsyncSnapshot<ResolvedMedia?> snap) {
                final ResolvedMedia? media = snap.data;
                if (media != null) {
                  return _imageFor(media, alt);
                }
                return _placeholder(alt);
              },
            ),
            if (widget.showTag)
              Positioned(
                right: LibraryCover.tagInset,
                bottom: LibraryCover.tagInset,
                child: _OfflineTag(label: widget.offlineLabel),
              ),
          ],
        ),
      ),
    );
  }

  /// Origin-aware loader (T7d-2): bundled uses the asset key, cached the file
  /// path, remote the URL. Raster and SVG both go through [MediaImage]; every
  /// failure degrades to the placeholder (C6: never a broken-image glyph).
  Widget _imageFor(ResolvedMedia media, String alt) {
    return MediaImage(
      media: media,
      errorFallback: _placeholder(alt),
    );
  }

  Widget _placeholder(String alt) {
    return MediaPlaceholder(
      altText: alt,
      icon: 'image',
      // The plate already sets the height; a nested ratio would fight it.
      aspectRatio: null,
      retryLabel: widget.retryLabel,
      // No resolver means nothing to re-try: show the label disabled.
      onRetry: widget.retryLabel == null ? null : _retry,
    );
  }
}

/// `.cover-tag` — brand pill on the cover, always text + glyph (§7.2).
class _OfflineTag extends StatelessWidget {
  const _OfflineTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: LibraryCover.tagHeight),
      padding: LibraryCover._tagPadding,
      decoration: const BoxDecoration(
        // Solid brand fill instead of the hand-off's translucent plate with
        // `backdrop-filter` — AA contrast against any cover, and no blur.
        color: AppColors.primary,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const AppIcon(
            'download',
            size: LibraryCover._tagIconSize,
            color: AppColors.onPrimary,
          ),
          const SizedBox(width: LibraryCover._tagGap),
          Text(
            label,
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
