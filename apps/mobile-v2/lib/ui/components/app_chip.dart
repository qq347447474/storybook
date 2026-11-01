/// Metadata chips and status badges (design-spec §5.2).
///
/// Both are single-line, pill-shaped and non-interactive: they label content,
/// they never carry an action. Colours come exclusively from [AppColors] and
/// the text from [AppTypography]; the geometry is the only thing fixed by the
/// hand-off (`visual/app.css` L870-881 `.chip`, L904-914 `.badge`).
///
/// The two heights are expressed as *minimum* heights instead of fixed ones.
/// The hand-off pins 27 / 26 dp at 100 % text scale, while design-spec §6.4
/// lets meta text reach 150 % — a hard height would clip the label there.
library;

import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../app_icon.dart';

/// How much of the palette a chip is allowed to spend.
///
/// The hand-off ships four visual recipes (`.chip`, `.chip--level`,
/// `.chip--outline`, `.chip--soft`); three of them are used by the S1–S6
/// screens, and the borderless `surface-sunken` base variant was folded into
/// [plain] — the "still missing" chip of S5 is the only plain chip on screen
/// and it carries the `--line` hairline (app.css L2826).
enum AppChipVariant {
  /// Neutral metadata on a card or on paper: `surface` fill, `line` hairline.
  plain,

  /// Step / CEFR level: `primary-soft` fill, brand ink (`.chip--level`).
  level,

  /// Vocabulary count and "can still be added" points: warm tint
  /// (`.chip--soft`).
  soft,
}

/// A 27 dp metadata pill: `A2`, `5 words`, a missing key point.
class AppChip extends StatelessWidget {
  const AppChip(
    this.label, {
    super.key,
    this.variant = AppChipVariant.plain,
    this.icon,
  });

  /// Chip text. Supplied by the caller — components never hard-code copy.
  final String label;

  /// Palette recipe. See [AppChipVariant].
  final AppChipVariant variant;

  /// Optional 13 dp leading glyph, e.g. `book` on an offline note.
  final String? icon;

  /// `.chip { height: 27px }` (app.css L873).
  static const double chipHeight = 27;

  /// `.chip svg { width: 13px; height: 13px }` (app.css L899).
  static const double iconSize = 13;

  /// `.chip { padding: 0 11px }` (app.css L875).
  static const double _horizontalPadding = 11;

  /// `.chip { gap: 6px }` (app.css L872).
  static const double _gap = 6;

  /// Pill radius (`.chip { border-radius: var(--r-pill) }`, app.css L876).
  static const BorderRadius _pill = BorderRadius.all(Radius.circular(999));

  @override
  Widget build(BuildContext context) {
    final Color fill = switch (variant) {
      AppChipVariant.plain => AppColors.surface,
      AppChipVariant.level => AppColors.primarySoft,
      AppChipVariant.soft => AppColors.accentSoft,
    };
    final Color ink = switch (variant) {
      AppChipVariant.plain => AppColors.ink2,
      AppChipVariant.level => AppColors.primary,
      AppChipVariant.soft => AppColors.accentStrong,
    };
    final TextStyle style = AppTypography.label.copyWith(
      color: ink,
      // `.chip` runs untracked; `.chip--level` adds `letter-spacing: .04em`
      // for the two-character level token (app.css L889).
      letterSpacing: variant == AppChipVariant.level ? 0.04 * 11 : 0,
    );

    return Container(
      constraints: const BoxConstraints(minHeight: chipHeight),
      padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: _pill,
        border: variant == AppChipVariant.plain
            ? const Border.fromBorderSide(BorderSide(color: AppColors.line))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            AppIcon(icon!, size: iconSize, color: ink),
            const SizedBox(width: _gap),
          ],
          Text(label, style: style, softWrap: false),
        ],
      ),
    );
  }
}

/// Chapter / step state of a 26 dp badge — one member per `.badge--*` recipe
/// of the hand-off (app.css L904-949), so no screen has to invent a tint:
///
/// | tone      | app.css class         | fill / ink                      |
/// | --------- | --------------------- | ------------------------------- |
/// | `neutral` | `.badge--locked`      | `surface-sunken` / `ink-3`      |
/// | `brand`   | `.badge--reading`     | `primary-soft` / `primary`      |
/// | `soft`    | `.badge--vocabulary`  | `accent-soft` / `accent-strong` |
/// | `info`    | `.badge--quiz`        | `teal` triad                    |
/// | `retell`  | `.badge--retell`      | `plum` triad                    |
/// | `success` | `.badge--complete`    | `success` triad                 |
/// | `warning` | (no hand-off class)   | `warning` triad                 |
enum AppBadgeTone { neutral, brand, soft, info, retell, success, warning }

/// A 26 dp status pill: **always** a 13 dp icon *and* text.
///
/// [icon] and [label] are both required by construction — design-spec §5.2:
/// "all status badges must contain a 13 dp icon + text, never only a different
/// background". The tone only adds redundancy; it never carries the status on
/// its own (§7.2).
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.icon,
    required this.label,
    this.tone = AppBadgeTone.neutral,
  });

  /// Icon name for [AppIcon]; 13 dp, painted in the tone ink.
  final String icon;

  /// Badge text — "Reading", "Locked", "Done". Caller-localised.
  final String label;

  /// Semantic recipe. See [AppBadgeTone].
  final AppBadgeTone tone;

  /// `.badge { height: 26px }` (app.css L907).
  static const double badgeHeight = 26;

  /// `.badge svg { width: 13px; height: 13px }` (app.css L915).
  static const double iconSize = 13;

  /// `.badge { padding: 0 9px }` (app.css L909).
  static const double _horizontalPadding = 9;

  /// `.badge { gap: 5px }` (app.css L906).
  static const double _gap = 5;

  static const BorderRadius _pill = BorderRadius.all(Radius.circular(999));

  @override
  Widget build(BuildContext context) {
    final (Color fill, Color ink) = switch (tone) {
      // `.badge--locked` (app.css L945).
      AppBadgeTone.neutral => (AppColors.surfaceSunken, AppColors.ink3),
      // `.badge--reading` (app.css L920) — the current chapter.
      AppBadgeTone.brand => (AppColors.primarySoft, AppColors.primary),
      // `.badge--vocabulary` (app.css L925) — new words in this chapter.
      AppBadgeTone.soft => (AppColors.accentSoft, AppColors.accentStrong),
      // `.badge--quiz` (app.css L930) — the quiet-information triad.
      AppBadgeTone.info => (AppTones.teal.bg, AppTones.teal.ink),
      // `.badge--retell` (app.css L935) — the step-4 plum triad.
      AppBadgeTone.retell => (AppTones.plum.bg, AppTones.plum.ink),
      // `.badge--complete` (app.css L940).
      AppBadgeTone.success => (AppTones.success.bg, AppTones.success.ink),
      AppBadgeTone.warning => (AppTones.warning.bg, AppTones.warning.ink),
    };

    return Container(
      constraints: const BoxConstraints(minHeight: badgeHeight),
      padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
      decoration: BoxDecoration(color: fill, borderRadius: _pill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppIcon(icon, size: iconSize, color: ink),
          const SizedBox(width: _gap),
          Text(label, style: AppTypography.label.copyWith(color: ink, letterSpacing: 0), softWrap: false),
        ],
      ),
    );
  }
}
