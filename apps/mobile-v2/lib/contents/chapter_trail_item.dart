/// One row of the S1 trail: the chapter card, its node and its foot
/// (`.trail-item` / `.chapter-card`, `visual/app.css` L1400-1615,
/// design-spec §4.2).
///
/// Reading order inside the card: kicker ("Chapter 2") -> serif title ->
/// sentences / audio length -> status badge, then the four-segment mini
/// progress with either "Continue reading" or the locked note.
///
/// The row is tappable through the card only. A locked row keeps the card in
/// the tree (so the lock glyph and "Waiting to unlock" explain themselves) but
/// exposes it as a disabled button and swallows the tap — design-spec §4.2
/// "锁定点击：不跳转，不弹错误".
library;

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';

import '../i18n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../ui/components/app_chip.dart';
import '../ui/components/dashed_border.dart';
import '../ui/components/segmented_bar.dart';
import 'chapter_trail_parts.dart';
import 'contents_meta.dart';

class ChapterTrailItem extends StatelessWidget {
  const ChapterTrailItem({
    super.key,
    required this.chapter,
    required this.number,
    required this.stage,
    required this.current,
    required this.l10n,
    required this.onOpenChapter,
  });

  /// Chapter rendered by this row.
  final Chapter chapter;

  /// 1-based position among the chapters sorted by `order` — the `01` glyph.
  final int number;

  /// Progress stage; already resolved by the screen (locked chapters arrive as
  /// [ChapterStage.locked]).
  final ChapterStage stage;

  /// The one row the learner should continue — brand node, brand card edge.
  final bool current;

  /// Catalog of the active UI language.
  final AppLocalizations l10n;

  /// Fired by the card; `null` while the chapter cannot be opened.
  final VoidCallback? onOpenChapter;

  // ------------------------------------------------------------------ geometry
  /// `.trail-item { padding-left: 50px }` — 36 dp node + 14 dp gutter.
  static const double trailInset = 50;

  /// `.trail { gap: 12px }` between two cards.
  static const double gap = 12;

  /// `.chapter-card { border-radius: 19px }` pulled onto the 20 dp card step
  /// (`--r-lg`), the same corner S0's book card uses.
  static const double radius = 20;

  /// `.chapter-card { padding: 14px 14px 13px }`.
  static const EdgeInsets cardPadding = EdgeInsets.fromLTRB(14, 14, 14, 13);

  /// `.mini-steps { width: 82px; gap: 4px }`, 3 dp segments.
  static const double stepsWidth = 82;
  static const double stepsHeight = 3;
  static const double stepsGap = 4;

  /// `.chapter-top { gap: 10px }` / `.chapter-foot { margin-top: 12px }`.
  static const double _topGap = 10;
  static const double _footGap = 12;

  bool get _locked => onOpenChapter == null;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        // Node first so the card paints over the trail rail behind it.
        PositionedDirectional(
          start: 0,
          top: ChapterTrailNode.cardTop,
          child: ChapterTrailNode(
            key: Key('contents-node-${chapter.id}'),
            number: number,
            stage: stage,
            current: current,
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: trailInset,
            bottom: gap,
          ),
          child: _card(),
        ),
      ],
    );
  }

  Widget _card() {
    final ChapterBadgeSpec badge = badgeOf(stage);

    final Widget body = Padding(
      padding: cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _heading()),
              const SizedBox(width: _topGap),
              AppBadge(
                key: Key('contents-stage-${chapter.id}'),
                icon: badge.icon,
                label: l10n.t(badge.labelKey),
                tone: badge.tone,
              ),
            ],
          ),
          const SizedBox(height: _footGap),
          Row(
            children: <Widget>[
              SizedBox(
                width: stepsWidth,
                child: SegmentedBar(
                  key: Key('contents-steps-${chapter.id}'),
                  total: 4,
                  filled: stepsOf(stage),
                  height: stepsHeight,
                  gap: stepsGap,
                ),
              ),
              const SizedBox(width: _footGap),
              // The bar keeps its 82 dp width; the label takes what is left and
              // wraps instead of overflowing at large text scales (§6.4).
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: _locked
                      ? ChapterLockedNote(label: l10n.t('chapter.waitingUnlock'))
                      : ChapterContinueCta(label: l10n.t('book.continue')),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Semantics(
      key: Key('contents-chapter-${chapter.id}'),
      container: true,
      button: true,
      // §4.2: a locked chapter must reach assistive tech as disabled, not as a
      // control that silently does nothing.
      enabled: !_locked,
      child: Container(
        decoration: BoxDecoration(
          color: _locked
              ? AppColors.surface.withValues(alpha: 0.5)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(radius),
          // Locked cards swap the hairline for the dashed outline below.
          border: _locked ? null : Border.all(color: _borderColor()),
          boxShadow: _shadow(),
        ),
        child: Stack(
          children: <Widget>[
            Material(
              // The container above owns fill, border and shadow.
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onOpenChapter,
                borderRadius: BorderRadius.circular(radius),
                child: body,
              ),
            ),
            if (_locked)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: DashedBoxBorderPainter(
                      color: AppColors.line,
                      radius: radius,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Kicker + serif title + meta row.
  Widget _heading() {
    final List<String> meta = chapterMetaParts(l10n, chapter, locked: _locked);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          // `.chapter-kicker { 700 label; 0.13em; ink-3 }`.
          l10n.t('chapter.index', args: <String, Object>{'n': number}),
          style: AppTypography.label.copyWith(color: AppColors.ink3),
        ),
        const SizedBox(height: 4),
        Text(
          chapter.title,
          style: AppTypography.h2.copyWith(
            color: _locked ? AppColors.ink2 : AppColors.ink,
          ),
        ),
        if (meta.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          _metaRow(meta),
        ],
      ],
    );
  }

  /// `17 sentences · 1:31 audio`, dots between items (`.meta-dot`).
  Widget _metaRow(List<String> parts) {
    return Wrap(
      spacing: 7,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        for (int i = 0; i < parts.length; i++) ...<Widget>[
          if (i > 0) const ChapterMetaDot(),
          Text(
            parts[i],
            style: AppTypography.tabular(
              AppTypography.meta.copyWith(color: AppColors.ink3),
            ),
          ),
        ],
      ],
    );
  }

  /// The row being continued gets the brand edge; every other row the hairline.
  Color _borderColor() {
    return current
        ? AppColors.primary.withValues(alpha: 0.36)
        : AppColors.line;
  }

  /// `--shadow-card` on a resting card, the brand-tinted lift on the current
  /// one (`.trail-item.is-current .chapter-card`).
  List<BoxShadow>? _shadow() {
    if (_locked) return null;
    if (current) {
      return <BoxShadow>[
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.6),
          offset: const Offset(0, 16),
          blurRadius: 32,
          spreadRadius: -26,
        ),
      ];
    }
    return <BoxShadow>[
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
    ];
  }
}
