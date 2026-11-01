/// S0 chrome below and instead of the cards: the dashed offline note
/// (`.shelf-note`, `visual/app.css` L1252-1275) and the empty shelf
/// (`.library-empty`, L1277-1316).
///
/// Both are pure layout over tokens and take their copy already localised, so
/// the screen file stays a list of sections.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../ui/app_icon.dart';
import '../ui/app_illustration.dart';
import '../ui/components/app_chip.dart';
import '../ui/components/dashed_border.dart';

/// "Fully offline · story, audio and practice all live on the device."
///
/// Dashed `line-strong` frame: the note is an aside, so it must not read as a
/// card (design-spec §2.5 reserves the card shadow for content).
class ShelfNote extends StatelessWidget {
  const ShelfNote({
    super.key,
    required this.title,
    required this.body,
  });

  /// Bold leading phrase — "Fully offline".
  final String title;

  /// Rest of the sentence — "Story, audio and practice all live on the device."
  final String body;

  /// `.shelf-note { padding: 13px 14px; gap: 11px; border-radius: 16px }`.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 12,
  );
  static const double radius = 16;
  static const double gap = 11;

  /// `.shelf-note svg { 20px }` in `--accent-strong` (app.css L1264).
  static const double iconSize = 20;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: CustomPaint(
        painter: const DashedBoxBorderPainter(
          color: AppColors.lineStrong,
          radius: radius,
        ),
        child: Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const AppIcon(
                'download',
                size: iconSize,
                color: AppColors.accentStrong,
              ),
              const SizedBox(width: gap),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: title,
                        style: AppTypography.meta.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w600,
                          height: 1.55,
                        ),
                      ),
                      // Typographic separator, not copy.
                      TextSpan(
                        text: ' · ',
                        style: AppTypography.meta.copyWith(
                          color: AppColors.ink2,
                          height: 1.55,
                        ),
                      ),
                      TextSpan(
                        text: body,
                        style: AppTypography.meta.copyWith(
                          color: AppColors.ink2,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty shelf: brand mark, heading, one line of explanation and the
/// "available offline" chip. No CTA — there is nothing to start
/// (design-spec §4.1 空书库).
class EmptyShelf extends StatelessWidget {
  const EmptyShelf({
    super.key,
    required this.title,
    required this.body,
    required this.chipLabel,
  });

  final String title;
  final String body;
  final String chipLabel;

  /// `.library-empty { min-height: 470px; border-radius: var(--r-xl) }` on the
  /// 20 dp token corner.
  static const double minHeight = 470;
  static const double radius = 20;
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 36,
  );

  /// `.empty-mark { 92px circle; margin-bottom: 20px }`, mark itself 48 dp.
  static const double markCircle = 92;
  static const double markSize = 48;
  static const double _markGap = 20;

  /// `.library-empty p { max-width: 230px }`.
  static const double _bodyMaxWidth = 230;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('library-empty'),
      constraints: const BoxConstraints(minHeight: minHeight),
      child: CustomPaint(
        // The frame is dashed (`.library-empty { border: 1px dashed }`), which
        // `BoxDecoration` cannot draw — the shared dash painter owns it.
        painter: const DashedBoxBorderPainter(
          color: AppColors.lineStrong,
          radius: radius,
        ),
        child: DecoratedBox(
          // A 55 % surface plate: the dashed frame stays visible on paper.
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Padding(
            padding: padding,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: markCircle,
                    height: markCircle,
                    decoration: const BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: markSize,
                        height: markSize,
                        child: AppIllustration('logo-mark'),
                      ),
                    ),
                  ),
                  const SizedBox(height: _markGap),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTypography.h2.copyWith(color: AppColors.ink),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _bodyMaxWidth),
                    child: Text(
                      body,
                      textAlign: TextAlign.center,
                      style: AppTypography.meta.copyWith(
                        color: AppColors.ink2,
                        height: 1.65,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // `FittedBox`: the chip label is a single unbreakable line
                  // (AppChip never wraps), so a long translation — or the
                  // +30 % pseudo-locale — must scale instead of overflowing
                  // the dashed frame (docs/03 §6.2).
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AppChip(chipLabel, icon: 'download'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
