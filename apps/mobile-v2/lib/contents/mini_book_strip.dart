/// `.mini-book` — the strip under the S1 app bar: cover thumbnail, book title
/// and level (`visual/app.css` L1331-1396, design-spec §4.2 item 2).
library;

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../ui/app_icon.dart';
import '../ui/components/app_chip.dart';
import '../ui/components/dashed_border.dart';
import '../ui/media_image.dart';

class MiniBookStrip extends StatelessWidget {
  const MiniBookStrip({
    super.key,
    required this.book,
    required this.levelLabel,
    required this.chaptersLabel,
    this.mediaResolver,
  });

  /// Book summarised by the strip.
  final Book book;

  /// Spoken form of the level, e.g. "Level A2" — the chip itself shows only the
  /// bare code (design-spec §7.4).
  final String levelLabel;

  /// "2 chapters", already pluralised by the catalog.
  final String chaptersLabel;

  /// Cover resolver; `null` degrades to the dashed missing state.
  final MediaResolver? mediaResolver;

  /// `.mini-book { padding: 11px; gap: 13px; border-radius: var(--r-lg) }`.
  static const EdgeInsets padding = EdgeInsets.all(11);
  static const double gap = 13;
  static const double radius = 20;

  /// `.mini-meta { gap: 7px; margin-top: 4px }` on the 4 pt grid.
  static const double metaGap = 8;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.line),
        // `--shadow-card`, ink-tinted and never black (design-spec §2.5).
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.04),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.38),
            offset: const Offset(0, 14),
            blurRadius: 34,
            spreadRadius: -26,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          MiniCover(cover: book.cover, mediaResolver: mediaResolver),
          const SizedBox(width: gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.title.copyWith(color: AppColors.ink),
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Semantics(
                      label: levelLabel,
                      excludeSemantics: true,
                      child: AppChip(
                        book.level.cefr,
                        variant: AppChipVariant.level,
                      ),
                    ),
                    const SizedBox(width: metaGap),
                    Flexible(
                      child: Text(
                        chaptersLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.tabular(
                          AppTypography.meta.copyWith(color: AppColors.ink2),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `.mini-cover` — a 56 × 60 portrait thumbnail of the book cover.
///
/// Decorative by construction: the title sits right beside it, so the hand-off
/// ships `alt=""` and the plate stays out of the semantics tree. A missing cover
/// becomes the dashed `is-missing` state instead of a broken image
/// (design-spec §4.1 封面缺失, §5.11).
class MiniCover extends StatefulWidget {
  const MiniCover({super.key, required this.cover, this.mediaResolver});

  /// Cover metadata of the book.
  final Cover cover;

  /// Resolver; `null` renders the missing state straight away (tests, packs
  /// whose media has not been generated).
  final MediaResolver? mediaResolver;

  /// `.mini-cover { width: 52px; height: 60px; border-radius: 11px }` — the
  /// width is taken to the 56 dp step of the Phase 3 token grid.
  static const double width = 56;
  static const double height = 60;
  static const double radius = 10;

  /// `.mini-missing svg { width: 18px }`.
  static const double iconSize = 18;

  @override
  State<MiniCover> createState() => _MiniCoverState();
}

class _MiniCoverState extends State<MiniCover> {
  /// Resolved once: the strip has no retry affordance (design-spec §4.2 shows
  /// the dashed plate, not a button), so the future is final.
  late final Future<ResolvedMedia?> _future = _resolve();

  Future<ResolvedMedia?> _resolve() async {
    final MediaResolver? resolver = widget.mediaResolver;
    if (resolver == null) return null;
    return resolver.resolve(widget.cover.url);
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: MiniCover.width,
        height: MiniCover.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(MiniCover.radius),
          child: FutureBuilder<ResolvedMedia?>(
            future: _future,
            builder:
                (BuildContext context, AsyncSnapshot<ResolvedMedia?> snap) {
              final ResolvedMedia? media = snap.data;
              if (media == null) return _missing();
              return _imageFor(media);
            },
          ),
        ),
      ),
    );
  }

  /// Origin-aware loader (raster or SVG); every failure degrades to the
  /// missing state.
  Widget _imageFor(ResolvedMedia media) =>
      MediaImage(media: media, errorFallback: _missing());

  /// `.mini-cover.is-missing`: dashed outline, sunken plate, image glyph.
  Widget _missing() {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const ColoredBox(color: AppColors.surfaceSunken),
        CustomPaint(
          painter: DashedBoxBorderPainter(
            color: AppColors.lineStrong,
            radius: MiniCover.radius,
          ),
        ),
        const Center(
          child: AppIcon(
            'image',
            size: MiniCover.iconSize,
            color: AppColors.ink3,
          ),
        ),
      ],
    );
  }
}
