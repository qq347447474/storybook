/// Library screen S0 (design-spec §4.1, `visual/app.css`).
///
/// Layout: eyebrow + Display heading with the settings bypass on the right,
/// a tools row (book count + card/list switch), then either
///
///  * **cards** — the first book as a full [LibraryBookCard] followed by a
///    "more stories" two-column grid of the rest, or
///  * **list** — every book as a compact [LibraryBookRow] sorted by title,
///
/// closed by the offline note. The empty shelf replaces all of it when the
/// pack carries no book at all.
///
/// The view mode is local UI state: it is not persisted, so a fresh launch
/// always opens on the richer card layout. Copy is looked up in the catalog
/// (docs/03), never written here.
library;

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';

import '../i18n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../ui/app_icon.dart';
import '../ui/components/confirm_dialog.dart';
import 'library_book_card.dart';
import 'library_book_row.dart';
import 'library_book_tile.dart';
import 'library_shelf.dart';
import 'library_view_toggle.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.pack,
    required this.bookStarted,
    required this.onOpenBook,
    this.onOpenSettings,
    this.onDeleteBook,
    this.downloadedBookIds = const <String>{},
    this.chapterStages = const <String, Map<String, ChapterStage>>{},
    this.mediaResolver,
    this.l10n,
  });

  final ContentPack pack;

  /// bookId -> true when the learner already has progress for the book.
  final Map<String, bool> bookStarted;

  final void Function(Book book) onOpenBook;
  final VoidCallback? onOpenSettings;

  /// Runs after the learner confirmed the delete dialog for a downloaded
  /// book. The owner reloads its book graph; this screen only reports which
  /// book went. Non-null without a matching [downloadedBookIds] entry still
  /// keeps the row tap-only.
  final void Function(Book book)? onDeleteBook;

  /// Books with a local copy under `storyapp_cache/` — the only ones the
  /// list offers for deletion. The bundled title is never in here.
  final Set<String> downloadedBookIds;

  /// bookId -> chapterId -> stage. Drives the `reading progress N / M` line.
  final Map<String, Map<String, ChapterStage>> chapterStages;

  /// Optional cover resolver; null covers degrade to alt-text placeholders.
  final MediaResolver? mediaResolver;

  /// Explicit catalog override (tests); production resolves via [L10nScope].
  final AppLocalizations? l10n;

  /// `--gutter: 20px` (app.css L78): the one page margin of the whole app.
  static const double gutter = 20;

  /// `.lib-head { padding: 12px 2px 16px; gap: 14px }`.
  static const double headGap = 14;

  /// `.lib-tools { padding: 0 2px 14px; gap: 12px }`.
  static const EdgeInsets toolsPadding = EdgeInsets.fromLTRB(2, 0, 2, 14);

  /// `.book-grid { gap: 18px 12px }`, two columns.
  static const double gridRowGap = 18;
  static const double gridColumnGap = 12;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  LibraryViewMode _mode = LibraryViewMode.cards;

  AppLocalizations get _l10n => widget.l10n ?? L10nScope.of(context);

  /// Books sorted by title (A–Z), the order both views share.
  List<Book> get _sorted {
    final List<Book> books = List<Book>.of(widget.pack.books);
    books.sort((Book a, Book b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return books;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = _l10n;
    final bool empty = widget.pack.books.isEmpty;
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _head(l10n, empty),
            Expanded(
              child: empty
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(
                        LibraryScreen.gutter,
                        2,
                        LibraryScreen.gutter,
                        24,
                      ),
                      children: <Widget>[
                        EmptyShelf(
                          title: l10n.t('library.empty'),
                          body: l10n.t('library.emptyBody'),
                          chipLabel: l10n.t('library.emptyChip'),
                          ctaLabel: l10n.t('library.emptyCta'),
                          onCta: widget.onOpenSettings,
                        ),
                      ],
                    )
                  : _body(l10n),
            ),
          ],
        ),
      ),
    );
  }

  /// Eyebrow + Display heading, with the 44 dp settings bypass on the right.
  Widget _head(AppLocalizations l10n, bool empty) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LibraryScreen.gutter,
        12,
        14,
        16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.t('library.eyebrow'),
                  style: AppTypography.label.copyWith(
                    color: AppColors.primary,
                    letterSpacing: 0.16 * 11,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  l10n.t('nav.library'),
                  style: AppTypography.display.copyWith(color: AppColors.ink),
                ),
              ],
            ),
          ),
          // The empty shelf still needs the settings bypass: it is the only
          // way to "更新书本" and fill the shelf.
          if (widget.onOpenSettings != null)
            Padding(
              padding: const EdgeInsets.only(left: LibraryScreen.headGap),
              child: _SettingsBypass(
                label: l10n.t('nav.settings'),
                onPressed: widget.onOpenSettings!,
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(AppLocalizations l10n) {
    final List<Book> books = _sorted;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        LibraryScreen.gutter,
        2,
        LibraryScreen.gutter,
        24,
      ),
      children: <Widget>[
        Padding(
          padding: LibraryScreen.toolsPadding,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.t('library.count', args: <String, Object>{
                    'count': books.length,
                  }),
                  style: AppTypography.meta.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.02 * 11.5,
                    color: AppColors.ink3,
                  ),
                ),
              ),
              LibraryViewToggle(
                mode: _mode,
                onChanged: (LibraryViewMode mode) =>
                    setState(() => _mode = mode),
                groupLabel: l10n.t('library.viewGroup'),
                cardsLabel: l10n.t('library.viewCards'),
                listLabel: l10n.t('library.viewList'),
              ),
            ],
          ),
        ),
        if (_mode == LibraryViewMode.cards)
          ..._cards(l10n, books)
        else
          ..._list(l10n, books),
        ShelfNote(
          title: l10n.t('library.shelfTitle'),
          body: l10n.t('library.shelfBody'),
        ),
      ],
    );
  }

  /// Featured card + "more stories" grid.
  List<Widget> _cards(AppLocalizations l10n, List<Book> books) {
    final Book featured = books.first;
    final List<Book> rest = books.skip(1).toList();
    return <Widget>[
      LibraryBookCard(
        book: featured,
        started: widget.bookStarted[featured.id] ?? false,
        completedChapters: _completedFor(featured),
        l10n: l10n,
        mediaResolver: widget.mediaResolver,
        uiLocale: l10n.localeTag,
        defaultGloss: widget.pack.locales.defaultGloss,
        onOpenBook: widget.onOpenBook,
      ),
      if (rest.isNotEmpty) ...<Widget>[
        const SizedBox(height: 24),
        _ShelfMoreHeading(
          title: l10n.t('library.moreStories'),
          count: l10n.t('library.count', args: <String, Object>{
            'count': rest.length,
          }),
        ),
        const SizedBox(height: 13),
        _grid(l10n, rest),
      ],
    ];
  }

  /// Two-column grid: fixed `childAspectRatio` keeps every tile identical.
  Widget _grid(AppLocalizations l10n, List<Book> books) {
    return GridView.builder(
      key: const Key('library-book-grid'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: books.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: LibraryScreen.gridRowGap,
        crossAxisSpacing: LibraryScreen.gridColumnGap,
        // 3:2 cover + title block ≈ 0.62 of the column width.
        childAspectRatio: 0.62,
      ),
      itemBuilder: (BuildContext context, int index) {
        final Book book = books[index];
        return LibraryBookTile(
          book: book,
          metaLine: _metaLine(l10n, book),
          statusLabel: _statusLabel(l10n, book),
          statusIcon: (widget.bookStarted[book.id] ?? false) ? 'book' : 'clock',
          mediaResolver: widget.mediaResolver,
          offlineLabel: l10n.t('library.offlineTag'),
          uiLocale: l10n.localeTag,
          defaultGloss: widget.pack.locales.defaultGloss,
          onOpen: () => widget.onOpenBook(book),
        );
      },
    );
  }

  /// Flat list of every book, still sorted A–Z.
  List<Widget> _list(AppLocalizations l10n, List<Book> books) {
    return <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 2, 2, 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.t('library.allBooks'),
                style: AppTypography.h2.copyWith(
                  fontSize: 19,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.01 * 19,
                  color: AppColors.ink,
                ),
              ),
            ),
            Text(
              l10n.t('library.sortAZ'),
              style: AppTypography.meta.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.02 * 11,
                color: AppColors.ink3,
              ),
            ),
          ],
        ),
      ),
      Container(
        key: const Key('library-book-list'),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Column(
          children: <Widget>[
            for (int i = 0; i < books.length; i++)
              Container(
                decoration: i == 0
                    ? null
                    : const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.line),
                        ),
                      ),
                child: LibraryBookRow(
                  book: books[i],
                  metaLine: _metaLine(l10n, books[i]),
                  statusLabel: _statusLabel(l10n, books[i]),
                  statusIcon:
                      (widget.bookStarted[books[i].id] ?? false) ? 'book' : 'clock',
                  isCurrent: widget.bookStarted[books[i].id] ?? false,
                  mediaResolver: widget.mediaResolver,
                  offlineLabel: l10n.t('library.offlineTag'),
                  uiLocale: l10n.localeTag,
                  defaultGloss: widget.pack.locales.defaultGloss,
                  onOpen: () => widget.onOpenBook(books[i]),
                  // Long-press is the maintenance gesture: only a downloaded
                  // copy has something to delete (the bundled title never is).
                  onLongPress: widget.onDeleteBook != null &&
                          widget.downloadedBookIds.contains(books[i].id)
                      ? () => _confirmDelete(l10n, books[i])
                      : null,
                ),
              ),
          ],
        ),
      ),
    ];
  }

  /// `A2 · 共 2 章 · 282 词` — the shared meta line of both views.
  String _metaLine(AppLocalizations l10n, Book book) {
    return <String>[
      book.level.cefr,
      l10n.t('library.chapters', args: <String, Object>{
        'count': book.chapters.length,
      }),
      l10n.t('library.wordCount', args: <String, Object>{
        'count': book.level.wordCount,
      }),
    ].join(' · ');
  }

  /// "Reading · 1 / 2" once started, otherwise "Not started".
  String _statusLabel(AppLocalizations l10n, Book book) {
    if (!(widget.bookStarted[book.id] ?? false)) {
      return l10n.t('library.notStarted');
    }
    return l10n.t('library.reading', args: <String, Object>{
      'done': _completedFor(book),
      'total': book.chapters.length,
    });
  }

  /// Long-press → destructive confirm → [LibraryScreen.onDeleteBook].
  ///
  /// Scrim taps and Escape answer "cancel" (the dialog's denial path), so the
  /// destructive button can never be reached by accident.
  Future<void> _confirmDelete(AppLocalizations l10n, Book book) async {
    final void Function(Book)? onDelete = widget.onDeleteBook;
    if (onDelete == null) return;
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.t('library.deleteTitle', args: <String, Object>{
        'title': book.title,
      }),
      body: l10n.t('library.deleteBody'),
      denyLabel: l10n.t('library.deleteCancel'),
      allowLabel: l10n.t('library.deleteConfirm'),
      destructive: true,
    );
    if (confirmed) onDelete(book);
  }

  /// Chapters of [book] already at `ChapterStage.complete`.
  int _completedFor(Book book) {
    final Map<String, ChapterStage>? stages = widget.chapterStages[book.id];
    if (stages == null) return 0;
    int done = 0;
    for (final Chapter chapter in book.chapters) {
      if (stages[chapter.id] == ChapterStage.complete) done++;
    }
    return done;
  }
}

/// `.shelf-more__head` — serif heading with the count on the right.
class _ShelfMoreHeading extends StatelessWidget {
  const _ShelfMoreHeading({required this.title, required this.count});

  final String title;
  final String count;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: AppTypography.h2.copyWith(
              fontSize: 19,
              height: 1.25,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.01 * 19,
              color: AppColors.ink,
            ),
          ),
        ),
        Text(
          count,
          style: AppTypography.meta.copyWith(
            fontSize: 11,
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: AppColors.ink3,
          ),
        ),
      ],
    );
  }
}

/// `.icon-btn--outline`: a 42 dp paper circle inside a 44 dp tap target.
class _SettingsBypass extends StatelessWidget {
  const _SettingsBypass({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  static const double tapTarget = 44;
  static const double diameter = 42;
  static const double iconSize = 22;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tapTarget,
      height: tapTarget,
      child: Center(
        child: Tooltip(
          message: label,
          child: Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.line),
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
            child: Material(
              type: MaterialType.transparency,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const Key('library-settings'),
                onTap: onPressed,
                child: const Center(
                  child: AppIcon('settings', size: iconSize),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
