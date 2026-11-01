/// The S0 book card (`.book-card` / `.book-body`, `visual/app.css`
/// L1119-1250) — one card per book of the pack.
///
/// Reading order follows design-spec §4.1: cover, kicker, serif title, meta
/// row (`A2` chip · chapters · words), one-line summary, reading progress
/// (only once the book has been started) and the full-width 56 dp CTA.
///
/// Every colour is an [AppColors] token, every text style an [AppTypography]
/// token, every glyph an [AppIcon]; all copy is passed in localised, except
/// the summary, which is content data (see [bookSummary]).
library;

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';

import '../i18n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../ui/app_icon.dart';
import '../ui/components/app_chip.dart';
import 'library_book_parts.dart';
import 'library_cover.dart';

class LibraryBookCard extends StatelessWidget {
  const LibraryBookCard({
    super.key,
    required this.book,
    required this.started,
    required this.completedChapters,
    required this.l10n,
    required this.onOpenBook,
    this.mediaResolver,
    this.uiLocale = 'en',
    this.defaultGloss = 'en',
  });

  /// The book rendered by this card.
  final Book book;

  /// True when the learner already has progress in this book: shows the
  /// progress block and flips the CTA to "Continue reading".
  final bool started;

  /// Chapters currently in the `complete` stage — numerator of
  /// `reading progress N / M` (design-spec §4.1 已开始 state).
  final int completedChapters;

  /// Catalog of the active UI language.
  final AppLocalizations l10n;

  /// Fired by the card body and by the CTA alike — both lead to S1.
  final void Function(Book book) onOpenBook;

  /// Cover resolver; `null` degrades to the alt-text placeholder.
  final MediaResolver? mediaResolver;

  /// UI locale for the cover alt lookup.
  final String uiLocale;

  /// Pack default gloss, last fallback of the alt lookup.
  final String defaultGloss;

  /// `.book-card { padding: 9px; border-radius: var(--r-xl) }` on the token
  /// grid: 10 dp plate inset, 20 dp corner (S0 team decision).
  static const double cardRadius = 20;
  static const double _plateInset = 10;

  /// `.book-body { padding: 15px 11px 8px }` on the 4 pt grid.
  static const EdgeInsets _bodyPadding = EdgeInsets.fromLTRB(12, 16, 12, 8);

  /// `.book-meta { gap: 8px }` (app.css L1190).
  static const double _metaGap = 8;

  /// `.book-body .btn { margin-top: 14px }` (app.css L1250).
  static const double _ctaGap = 14;

  /// `.btn svg { width: 19px }` (app.css L813).
  static const double _ctaIconSize = 19;

  @override
  Widget build(BuildContext context) {
    // Summary is content data: `book.blurb` in the gloss locale (same lookup
    // as the cover alt above), else the book's opening sentence (bookSummary).
    final String summary = bookSummary(
      book,
      glossLocale: uiLocale,
      defaultGloss: defaultGloss,
    );
    final int total = book.chapters.length;
    final int done = completedChapters.clamp(0, total);

    return GestureDetector(
      key: Key('library-book-${book.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onOpenBook(book),
      child: Container(
        padding: const EdgeInsets.all(_plateInset),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(cardRadius),
          border: Border.all(color: AppColors.line),
          // `--shadow-card`: a 1 dp contact shadow plus a wide, very light
          // ambient one — ink-tinted, never black (design-spec §2.5).
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LibraryCover(
              key: Key('library-cover-${book.id}'),
              cover: book.cover,
              mediaResolver: mediaResolver,
              uiLocale: uiLocale,
              defaultGloss: defaultGloss,
              offlineLabel: l10n.t('library.offlineTag'),
              retryLabel: l10n.t('err.retry'),
            ),
            Padding(
              padding: _bodyPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.t(
                      'library.kicker',
                      args: <String, Object>{'cefr': book.level.cefr},
                    ),
                    style: AppTypography.label.copyWith(color: AppColors.ink3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.title,
                    style: AppTypography.title.copyWith(color: AppColors.ink),
                  ),
                  const SizedBox(height: 8),
                  _metaRow(),
                  if (summary.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(color: AppColors.ink2),
                    ),
                  ],
                  if (started) ...<Widget>[
                    const SizedBox(height: 12),
                    BookProgress(
                      key: Key('library-progress-${book.id}'),
                      bookId: book.id,
                      label: l10n.t('library.progressLabel'),
                      value: l10n.t(
                        'library.progressValue',
                        args: <String, Object>{'done': done, 'total': total},
                      ),
                      total: total,
                      done: done,
                    ),
                  ],
                  const SizedBox(height: _ctaGap),
                  _cta(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// `A2` chip · chapters · words, separated by 3 dp dots (`.meta-dot`).
  Widget _metaRow() {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: _metaGap,
      runSpacing: 4,
      children: <Widget>[
        Semantics(
          // The chip is the bare CEFR code; the screen reader gets the full
          // phrase (design-spec §7.4).
          label: l10n.t(
            'library.level',
            args: <String, Object>{'cefr': book.level.cefr},
          ),
          excludeSemantics: true,
          child: AppChip(book.level.cefr, variant: AppChipVariant.level),
        ),
        _metaText(l10n.t(
          'library.chapters',
          args: <String, Object>{'count': book.chapters.length},
        )),
        const MetaDot(),
        _metaText(l10n.t(
          'library.wordCount',
          args: <String, Object>{'count': book.level.wordCount},
        )),
      ],
    );
  }

  Widget _metaText(String value) {
    return Text(
      value,
      style: AppTypography.tabular(
        AppTypography.meta.copyWith(color: AppColors.ink2),
      ),
    );
  }

  /// Full-width 56 dp pill. The theme owns height/shape/fill (design-spec
  /// §2.4), so the card only adds the trailing arrow of `.btn svg`.
  Widget _cta() {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: FilledButton(
        key: Key('library-action-${book.id}'),
        onPressed: () => onOpenBook(book),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                l10n.t(started ? 'book.continue' : 'book.start'),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            const AppIcon(
              'arrow-right',
              size: _ctaIconSize,
              color: AppColors.onPrimary,
            ),
          ],
        ),
      ),
    );
  }
}
