/// S0 flat list row (`.book-row` / `.row-cover` / `.row-main`,
/// `visual/app.css`).
///
/// A 72 dp tall row: 42 × 54 cover thumb, two-line text block, status caption
/// and a chevron. The current book gets the brand-tinted background with an
/// inset accent bar so "where I left off" is visible at a glance in the list.
library;

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../ui/app_icon.dart';
import '../ui/media_image.dart';

class LibraryBookRow extends StatelessWidget {
  const LibraryBookRow({
    super.key,
    required this.book,
    required this.metaLine,
    required this.statusLabel,
    required this.onOpen,
    this.onLongPress,
    this.isCurrent = false,
    this.mediaResolver,
    this.offlineLabel = '',
    this.uiLocale = 'en',
    this.defaultGloss = 'en',
    this.statusIcon = 'book',
  });

  final Book book;
  final String metaLine;
  final String statusLabel;
  final VoidCallback onOpen;

  /// Long-press hook for the row's maintenance actions (delete the local
  /// copy). Null keeps the row tap-only — the bundled book has nothing to
  /// remove and must not raise a dead dialog.
  final VoidCallback? onLongPress;

  /// True for the book the learner has progress in.
  final bool isCurrent;

  final MediaResolver? mediaResolver;
  final String offlineLabel;
  final String uiLocale;
  final String defaultGloss;
  final String statusIcon;

  /// `.book-row { min-height: 72px; gap: 11px; padding: 9px 4px 9px 10px }`.
  static const double minHeight = 72;
  static const double _gap = 11;
  static const EdgeInsets _padding = EdgeInsets.fromLTRB(10, 9, 4, 9);

  /// `.row-cover { width: 42px; height: 54px; border-radius: 9px }`.
  static const double thumbWidth = 42;
  static const double thumbHeight = 54;
  static const double thumbRadius = 9;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isCurrent,
      label: '${book.title}, $metaLine, $statusLabel',
      child: Material(
        color: isCurrent ? AppColors.primaryGhost : Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          onLongPress: onLongPress,
          child: Container(
            constraints: const BoxConstraints(minHeight: minHeight),
            padding: _padding,
            decoration: isCurrent
                ? const BoxDecoration(
                    // `.book-row.is-current { box-shadow: inset 3px 0 0 }`.
                    border: Border(
                      left: BorderSide(color: AppColors.primary, width: 3),
                    ),
                  )
                : null,
            child: Row(
              children: <Widget>[
                _Thumb(
                  book: book,
                  mediaResolver: mediaResolver,
                ),
                const SizedBox(width: _gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.h2.copyWith(
                          fontSize: 15.5,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.01 * 15.5,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        metaLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.meta.copyWith(
                          fontSize: 11,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: isCurrent ? AppColors.ink2 : AppColors.ink3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AppIcon(
                      statusIcon,
                      size: 12,
                      color: isCurrent ? AppColors.primaryStrong : AppColors.ink3,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      statusLabel,
                      style: AppTypography.meta.copyWith(
                        fontSize: 11,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: isCurrent ? AppColors.primaryStrong : AppColors.ink3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                const AppIcon('chevron-right', size: 15, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `.row-cover` — a portrait thumb, cropped `cover` so the art fills 42 × 54.
///
/// It resolves through the same [MediaResolver] as the full cover plate but
/// skips the placeholder chrome: a row thumb is decoration, the row's text
/// already names the book.
class _Thumb extends StatefulWidget {
  const _Thumb({
    required this.book,
    required this.mediaResolver,
  });

  final Book book;
  final MediaResolver? mediaResolver;

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  late final Future<ResolvedMedia?> _future = _resolve();

  Future<ResolvedMedia?> _resolve() async {
    final MediaResolver? resolver = widget.mediaResolver;
    if (resolver == null) return null;
    return resolver.resolve(widget.book.cover.url);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: LibraryBookRow.thumbWidth,
      height: LibraryBookRow.thumbHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LibraryBookRow.thumbRadius),
        child: ColoredBox(
          color: AppColors.surfaceSunken,
          child: FutureBuilder<ResolvedMedia?>(
            future: _future,
            builder:
                (BuildContext context, AsyncSnapshot<ResolvedMedia?> snap) {
              final ResolvedMedia? media = snap.data;
              if (media == null) {
                return const Center(
                  child: AppIcon('image', size: 16, color: AppColors.ink3),
                );
              }
              // `BoxFit.cover` on the fixed 42 × 54 box is exactly the
              // hand-off's `object-fit: cover`.
              return MediaImage(media: media);
            },
          ),
        ),
      ),
    );
  }
}
