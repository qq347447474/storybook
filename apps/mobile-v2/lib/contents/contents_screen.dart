/// Table of contents screen S1 (design-spec §4.2, `visual/app.css` L1320-1630).
///
/// The screen is a reading order, top to bottom: a regular app bar, the mini
/// book strip, the "Chapters" heading with the book's length, one
/// [ChapterTrailItem] per chapter (sorted by `order`, not by pack order) and
/// the note explaining the four-step loop.
///
/// State rules (design-spec §4.2):
/// - the first chapter that is neither finished nor locked is the **current**
///   one: brand node, brand card edge;
/// - a finished chapter keeps a check node and may be re-opened;
/// - a locked / unavailable chapter shows the lock node, a neutral badge and
///   "Waiting to unlock", and does not navigate anywhere;
/// - chain lock ([isChapterUnlocked]): a chapter that has not reached
///   `complete` renders as locked while its predecessor is not `complete`
///   (S1 rule — the four-step loop opens one chapter at a time). A chapter
///   that already reached `complete` is exempt: the lock gates early entry,
///   it never revokes a finished chapter.
library;

import 'dart:math' as math;

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';

import '../i18n/app_localizations.dart';
import '../theme/app_colors.dart';
import 'chapter_trail_item.dart';
import 'chapter_trail_parts.dart';
import 'contents_app_bar.dart';
import 'contents_meta.dart';
import 'contents_trail_parts.dart';
import 'mini_book_strip.dart';

class ContentsScreen extends StatelessWidget {
  const ContentsScreen({
    super.key,
    required this.book,
    required this.chapterStages,
    required this.onOpenChapter,
    this.l10n,
    this.mediaResolver,
    this.onOpenSettings,
  });

  final Book book;

  /// chapterId -> current stage (from progress; defaults applied per
  /// availability).
  final Map<String, ChapterStage> chapterStages;

  final void Function(Chapter chapter) onOpenChapter;

  /// Explicit catalog override (tests); production resolves via [L10nScope].
  final AppLocalizations? l10n;

  /// Cover resolver for the mini book strip; `null` shows the dashed missing
  /// state (design-spec §4.1 封面缺失).
  final MediaResolver? mediaResolver;

  /// Opens S7 (the global bypass); `null` hides the app bar control.
  final VoidCallback? onOpenSettings;

  /// `--gutter: 20px` (app.css L78): the one page margin of the app.
  static const double gutter = 20;

  /// `.scroll { padding: 0 var(--gutter) 24px }` with the 2 dp top nudge of
  /// `.screen--contents .scroll { padding-top: 2px }`.
  static const EdgeInsets listPadding =
      EdgeInsets.fromLTRB(gutter, 2, gutter, 24);

  /// `.trail::before { left: 17px; border-left: 2px dashed }`.
  static const double railLeft = 17;
  static const double railWidth = 2;

  /// The rail spans node centre to node centre: 20 dp card edge inset + half a
  /// 36 dp node (`.trail-node { top: 20px; width: 36px }`).
  static const double railInset =
      ChapterTrailNode.cardTop + ChapterTrailNode.size / 2;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = this.l10n ?? L10nScope.of(context);
    final List<Chapter> chapters = List<Chapter>.of(book.chapters)
      ..sort((Chapter a, Chapter b) => a.order.compareTo(b.order));
    final List<String> orderedIds = <String>[
      for (final Chapter chapter in chapters) chapter.id,
    ];
    final List<ChapterStage> stages = <ChapterStage>[
      for (int i = 0; i < chapters.length; i++)
        _stageOf(chapters[i], i, orderedIds),
    ];
    final int currentIndex = continueChapterIndex(stages);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            ContentsAppBar(
              title: l10n.t('book.contents'),
              backLabel: l10n.t('nav.back'),
              settingsLabel: l10n.t('nav.settings'),
              onSettings: onOpenSettings,
            ),
            Expanded(
              child: ListView(
                padding: listPadding,
                children: <Widget>[
                  MiniBookStrip(
                    book: book,
                    levelLabel: l10n.t(
                      'library.level',
                      args: <String, Object>{'cefr': book.level.cefr},
                    ),
                    chaptersLabel: l10n.t(
                      'library.chapters',
                      args: <String, Object>{'count': chapters.length},
                    ),
                    mediaResolver: mediaResolver,
                  ),
                  TrailHead(
                    title: l10n.t('book.chaptersHeading'),
                    lengthLabel: bookLengthLabel(l10n, book),
                  ),
                  _trail(l10n, chapters, stages, currentIndex),
                  TrailNote(text: l10n.t('book.flowNote')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Resolved **display** stage of [chapter]: the progress value folded
  /// through the availability flag and the chain lock
  /// ([isChapterUnlocked]). The lock wins over a stored stage that has not
  /// reached `complete` — a chapter the learner cannot open yet renders as
  /// locked even when progress (or the pack's `available` flag) says
  /// otherwise. A stored `complete` is never masked: the lock gates early
  /// entry only, it never revokes a finished chapter.
  ChapterStage _stageOf(
    Chapter chapter,
    int index,
    List<String> orderedIds,
  ) {
    final bool unlocked = isChapterUnlocked(
      index,
      chapterStages,
      available: chapter.available,
      orderedIds: orderedIds,
    );
    if (!unlocked) return ChapterStage.locked;
    final ChapterStage stage = chapterStages[chapter.id] ??
        (chapter.available ? ChapterStage.unread : ChapterStage.locked);
    if (stage == ChapterStage.locked || !chapter.available) {
      return ChapterStage.locked;
    }
    return stage;
  }

  /// The trail: cards stacked with a dashed rail running behind the nodes.
  Widget _trail(
    AppLocalizations l10n,
    List<Chapter> chapters,
    List<ChapterStage> stages,
    int currentIndex,
  ) {
    return Stack(
      children: <Widget>[
        PositionedDirectional(
          start: railLeft,
          top: railInset,
          bottom: railInset,
          width: railWidth,
          child: const IgnorePointer(
            child: CustomPaint(
              painter: _TrailRailPainter(AppColors.lineStrong),
            ),
          ),
        ),
        Column(
          children: <Widget>[
            for (int i = 0; i < chapters.length; i++)
              ChapterTrailItem(
                chapter: chapters[i],
                number: chapters[i].order,
                stage: stages[i],
                current: i == currentIndex,
                l10n: l10n,
                onOpenChapter: stages[i] == ChapterStage.locked
                    ? null
                    : () => onOpenChapter(chapters[i]),
              ),
          ],
        ),
      ],
    );
  }
}

/// `.trail::before` — a 2 dp dashed rail, node centre to node centre.
///
/// Stateless and never animated: a scrolling list repaints it, but the dash
/// walk is the same handful of `drawLine` calls a divider makes.
class _TrailRailPainter extends CustomPainter {
  const _TrailRailPainter(this.color);

  /// `--line-strong` at the call site (decorative, carries no text).
  final Color color;

  /// `.trail::before { border-left: 2px dashed }` — 4 on, 4 off at 2 dp.
  static const double dash = 4;
  static const double gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = size.width
      ..strokeCap = StrokeCap.round;
    final double x = size.width / 2;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, math.min(y + dash, size.height)),
        paint,
      );
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_TrailRailPainter oldDelegate) =>
      oldDelegate.color != color;
}
