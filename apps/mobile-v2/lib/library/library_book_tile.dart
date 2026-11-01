/// S0 "more stories" grid tile (`.book-tile` / `.tile-cover`,
/// `visual/app.css`).
///
/// Cover plate on top, then a two-line serif title, a meta line
/// (`A2 · 2 章 · 282 词`) and a status line. The tile is intentionally
/// quieter than [LibraryBookCard]: only the featured book gets the full
/// blurb + CTA treatment.
library;

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../ui/app_icon.dart';
import 'library_cover.dart';

class LibraryBookTile extends StatelessWidget {
  const LibraryBookTile({
    super.key,
    required this.book,
    required this.metaLine,
    required this.statusLabel,
    required this.onOpen,
    this.mediaResolver,
    this.offlineLabel = '',
    this.uiLocale = 'en',
    this.defaultGloss = 'en',
    this.statusIcon = 'book',
  });

  final Book book;

  /// Pre-formatted meta line — the tile never builds copy itself.
  final String metaLine;

  /// Status caption, e.g. "未开始" or "阅读中 · 1 / 2".
  final String statusLabel;

  final VoidCallback onOpen;
  final MediaResolver? mediaResolver;
  final String offlineLabel;
  final String uiLocale;
  final String defaultGloss;

  /// Glyph in front of the status caption.
  final String statusIcon;

  /// `.tile-cover { border-radius: 14px }`, `aspect-ratio 3 / 2`.
  static const double coverRadius = 14;

  /// `.book-tile__title { margin-top: 9px; min-height: 42px }`.
  static const double _titleGap = 9;
  static const double _titleMinHeight = 42;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${book.title}, $metaLine, $statusLabel',
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // `.tile-cover` — a 3:2 plate with a soft drop shadow.
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(coverRadius),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.05),
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                    ),
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.5),
                      offset: const Offset(0, 10),
                      blurRadius: 20,
                      spreadRadius: -20,
                    ),
                  ],
                ),
                child: LibraryCover(
                  cover: book.cover,
                  uiLocale: uiLocale,
                  defaultGloss: defaultGloss,
                  offlineLabel: offlineLabel,
                  showTag: false,
                  mediaResolver: mediaResolver,
                ),
              ),
              const SizedBox(height: _titleGap),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _titleMinHeight),
                child: Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.h2.copyWith(
                    fontSize: 16,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.01 * 16,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                metaLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.meta.copyWith(
                  fontSize: 11,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink3,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AppIcon(statusIcon, size: 12, color: AppColors.ink3),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      statusLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.meta.copyWith(
                        fontSize: 11,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
