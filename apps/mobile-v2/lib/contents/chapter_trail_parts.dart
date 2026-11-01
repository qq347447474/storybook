/// Small pieces of one S1 trail row: the 36 dp node, the text affordance at the
/// card's foot and the dot between two meta items (`.trail-node` app.css
/// L1430-1470, `.chapter-cta` L1571-1590, `.chapter-locked-note` L1605,
/// `.meta-dot` L1190).
///
/// They live next to [ChapterTrailItem] rather than inside it so that file
/// stays a readable reading order (node -> kicker -> title -> meta -> foot).
library;

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../ui/app_icon.dart';

/// `.trail-node` — a 36 dp circle carrying the chapter number, a check or a
/// lock.
///
/// Wayfinding, not a control: the card beside it states the same thing in words,
/// so the node stays out of the semantics tree (§7.2 — never colour-only, and
/// never two competing descriptions of one row).
class ChapterTrailNode extends StatelessWidget {
  const ChapterTrailNode({
    super.key,
    required this.number,
    required this.stage,
    required this.current,
  });

  /// Chapter position, printed zero-padded (`01`) like the hand-off.
  final int number;

  /// Resolved stage; [ChapterStage.locked] swaps the number for a lock.
  final ChapterStage stage;

  /// True for the chapter the learner should continue — brand fill + halo.
  final bool current;

  /// `.trail-node { width/height: 36px }` (app.css L1401).
  static const double size = 36;

  /// `.trail-node { top: 20px }` — the node sits on the card's kicker line.
  static const double cardTop = 20;

  /// `.trail-node svg { width: 16px }` + `border: 2px solid`.
  static const double iconSize = 16;

  /// `.trail-item.is-current .trail-node { box-shadow: 0 0 0 6px … }` — the
  /// 9 % brand halo, mirrored onto a spread shadow.
  static const double haloSpread = 6;

  @override
  Widget build(BuildContext context) {
    final bool locked = stage == ChapterStage.locked;
    final bool complete = stage == ChapterStage.complete;

    final Color fill;
    final Color border;
    final Color ink;
    if (locked) {
      fill = AppColors.paperDeep;
      border = AppColors.line;
      ink = AppColors.ink3;
    } else if (complete) {
      fill = AppTones.success.bg;
      border = AppColors.successLine;
      ink = AppColors.successInk;
    } else if (current) {
      fill = AppColors.primary;
      border = AppColors.primary;
      ink = AppColors.onPrimary;
    } else {
      fill = AppColors.paper;
      border = AppColors.lineStrong;
      ink = AppColors.ink3;
    }

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: border, width: 2),
          boxShadow: current
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.primaryGhost,
                    spreadRadius: haloSpread,
                  ),
                ]
              : null,
        ),
        child: _glyph(ink),
      ),
    );
  }

  Widget _glyph(Color ink) {
    switch (stage) {
      case ChapterStage.locked:
        return AppIcon('lock', size: iconSize, color: ink);
      case ChapterStage.complete:
        return AppIcon('check', size: iconSize, color: ink);
      case ChapterStage.unread:
      case ChapterStage.reading:
      case ChapterStage.vocabulary:
      case ChapterStage.quiz:
      case ChapterStage.retell:
        return Text(
          number.toString().padLeft(2, '0'),
          style: AppTypography.tabular(
            AppTypography.label.copyWith(color: ink, letterSpacing: 0),
          ),
        );
    }
  }
}

/// `.chapter-cta` — "Continue reading" and its arrow.
///
/// A *label*, not a button: the whole card is the control, so the affordance is
/// excluded from the semantics tree instead of competing with it.
class ChapterContinueCta extends StatelessWidget {
  const ChapterContinueCta({super.key, required this.label});

  /// Already localised call to action.
  final String label;

  /// `.chapter-cta svg { width: 14px }` and `gap: 4px`.
  static const double iconSize = 14;
  static const double gap = 4;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: Text(
              label,
              style: AppTypography.meta.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: gap),
          const AppIcon(
            'arrow-right',
            size: iconSize,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

/// `.chapter-locked-note` — the reason a chapter cannot be opened, stated in
/// words right next to the lock (§4.2 "锁图标与'等待解锁'已说明原因").
class ChapterLockedNote extends StatelessWidget {
  const ChapterLockedNote({super.key, required this.label});

  /// Already localised "Waiting to unlock".
  final String label;

  /// `.chapter-locked-note svg { width: 13px }` and `gap: 5px`.
  static const double iconSize = 13;
  static const double gap = 5;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const AppIcon('lock', size: iconSize, color: AppColors.ink3),
        const SizedBox(width: gap),
        Flexible(
          child: Text(
            label,
            style: AppTypography.meta.copyWith(color: AppColors.ink3),
          ),
        ),
      ],
    );
  }
}

/// `.meta-dot` — a 3 dp `line-strong` separator between two meta items.
///
/// A local copy of S0's dot on purpose: twenty lines of decoration are cheaper
/// than a `library/` -> `contents/` import between two screens.
class ChapterMetaDot extends StatelessWidget {
  const ChapterMetaDot({super.key});

  /// `.meta-dot { width: 3px; height: 3px }`.
  static const double size = 3;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.lineStrong,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}
