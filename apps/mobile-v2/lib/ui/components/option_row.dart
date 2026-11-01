/// Answer option row of the quiz (design-spec §5.5, `.option` app.css
/// L2256-2374).
///
/// Five states, one of them a modifier: [OptionVisualState.dimmed] paints the
/// idle recipe at 52 % and is what the hand-off puts on the options the learner
/// did not pick. `correct` / `wrong` never rely on colour alone — each one also
/// swaps the radio circle for a check / close glyph (§7.2).
///
/// The row owns no copy: the letter, the option text and the screen-reader
/// sentence all arrive as parameters.
library;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../app_icon.dart';

/// What the row is telling the learner.
enum OptionVisualState {
  /// Untouched: `surface` fill, `--line` hairline.
  idle,

  /// Picked but not judged: `primary-soft` fill, brand border.
  selected,

  /// Picked and right: success triad + check glyph.
  correct,

  /// Picked and wrong: danger triad + close glyph.
  wrong,

  /// Not picked, or unreachable: the idle recipe at [OptionRow.dimmedOpacity].
  dimmed,
}

/// One answer option: letter circle, option text, radio / result circle.
class OptionRow extends StatelessWidget {
  const OptionRow({
    super.key,
    required this.letter,
    required this.text,
    this.state = OptionVisualState.idle,
    this.onTap,
    this.semanticLabel,
  });

  /// `A`, `B`, `C`… — the letter inside the 26 dp disc.
  final String letter;

  /// Option copy, localised by the caller.
  final String text;

  /// Current state. See [OptionVisualState].
  final OptionVisualState state;

  /// Tap callback. `null` locks the row (post-answer, design-spec §5.5:
  /// "答题后锁定选项，禁止改选") and reports `enabled: false`.
  final VoidCallback? onTap;

  /// Screen-reader sentence. The component never assembles one from [letter]
  /// and [text], because "A. The girl folded the boat. selected" is not a
  /// sentence in every locale. When null the child nodes are read naturally.
  final String? semanticLabel;

  /// `.option { min-height: 58px }` (app.css L2262) reduced to the 52 dp visual
  /// height of design-spec §5.5 — the 44 dp floor is still met at every text
  /// scale because this is a *minimum*.
  static const double minHeight = 52;

  /// `.option { border-radius: 16px }` (app.css L2265) → the spec's 11 dp.
  static const double radius = 11;

  /// `.option__letter { width: 28px }` (app.css L2285) → the spec's 26 dp.
  static const double letterSize = 26;

  /// `.option__radio { width: 21px }` (app.css L2302) → the spec's 17 dp.
  static const double radioSize = 17;

  /// `.option__radio svg { 13px }` (app.css L2309).
  static const double radioIconSize = 13;

  /// `.option.is-dim { opacity: .52 }` (app.css L2369).
  static const double dimmedOpacity = 0.52;

  /// `.option { gap: 11px; padding: 11px 13px }` (app.css L2260, L2263).
  static const double _gap = 11;
  static const EdgeInsets _padding = EdgeInsets.symmetric(horizontal: 13, vertical: 11);

  /// Outer fill / hairline, letter disc, and radio treatment for [state].
  _Recipe get _recipe {
    switch (state) {
      case OptionVisualState.idle:
      case OptionVisualState.dimmed:
        return const _Recipe(
          fill: AppColors.surface,
          border: AppColors.line,
          letterFill: AppColors.surfaceSunken,
          letterInk: AppColors.ink2,
          radioBorder: AppColors.lineStrong,
        );
      case OptionVisualState.selected:
        return const _Recipe(
          fill: AppColors.primarySoft,
          border: AppColors.primary,
          letterFill: AppColors.primary,
          letterInk: AppColors.onPrimary,
          radioBorder: AppColors.primary,
          radioDot: AppColors.primary,
        );
      case OptionVisualState.correct:
        return const _Recipe(
          fill: AppColors.successBg,
          border: AppColors.successLine,
          letterFill: AppColors.successInk,
          letterInk: AppColors.onPrimary,
          radioBorder: AppColors.successInk,
          radioFill: AppColors.successInk,
          radioIcon: 'check',
        );
      case OptionVisualState.wrong:
        return const _Recipe(
          fill: AppColors.dangerBg,
          border: AppColors.dangerLine,
          letterFill: AppColors.dangerInk,
          letterInk: AppColors.onPrimary,
          radioBorder: AppColors.dangerInk,
          radioFill: AppColors.dangerInk,
          radioIcon: 'close',
        );
    }
  }

  /// True for the three states that mean "this row is the learner's answer".
  bool get _isSelected =>
      state == OptionVisualState.selected ||
      state == OptionVisualState.correct ||
      state == OptionVisualState.wrong;

  @override
  Widget build(BuildContext context) {
    final _Recipe recipe = _recipe;
    final TextStyle textStyle = AppTypography.body.copyWith(
      color: AppColors.ink,
      fontWeight: FontWeight.w500,
      height: 1.45,
    );

    final Widget body = Material(
      color: recipe.fill,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: recipe.border),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        // A neutral state layer: a violet wash over the green / red triads
        // would read as a fifth state.
        overlayColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.pressed)) {
              return AppColors.ink.withValues(alpha: 0.08);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return AppColors.ink.withValues(alpha: 0.04);
            }
            return Colors.transparent;
          },
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: minHeight),
          padding: _padding,
          child: Row(
            children: <Widget>[
              Container(
                width: letterSize,
                height: letterSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: recipe.letterFill,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  letter,
                  style: AppTypography.label.copyWith(
                    color: recipe.letterInk,
                    letterSpacing: 0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(child: Text(text, style: textStyle)),
              const SizedBox(width: _gap),
              _Radio(recipe: recipe),
            ],
          ),
        ),
      ),
    );

    final Widget node = semanticLabel == null
        ? Semantics(
            button: true,
            enabled: onTap != null,
            selected: _isSelected,
            child: body,
          )
        : Semantics(
            container: true,
            button: true,
            enabled: onTap != null,
            selected: _isSelected,
            label: semanticLabel,
            onTap: onTap,
            child: ExcludeSemantics(child: body),
          );

    return state == OptionVisualState.dimmed
        ? Opacity(opacity: dimmedOpacity, child: node)
        : node;
  }
}

/// The four circles of the recipe: 17 dp radio, filled or ringed or ticked.
class _Radio extends StatelessWidget {
  const _Radio({required this.recipe});

  final _Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final String? icon = recipe.radioIcon;
    final Color? dot = recipe.radioDot;

    Widget? marker;
    if (icon != null) {
      marker = AppIcon(icon, size: OptionRow.radioIconSize, color: AppColors.onPrimary);
    } else if (dot != null) {
      // `.option.is-selected .option__radio` draws a 3 px surface gap between
      // ring and dot (app.css L2327).
      marker = SizedBox(
        width: 9,
        height: 9,
        child: DecoratedBox(
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
      );
    }

    return Container(
      width: OptionRow.radioSize,
      height: OptionRow.radioSize,
      decoration: BoxDecoration(
        color: recipe.radioFill,
        shape: BoxShape.circle,
        border: Border.all(color: recipe.radioBorder, width: 2),
      ),
      child: marker == null ? null : Center(child: marker),
    );
  }
}

/// Immutable colour recipe for one [OptionVisualState].
class _Recipe {
  const _Recipe({
    required this.fill,
    required this.border,
    required this.letterFill,
    required this.letterInk,
    required this.radioBorder,
    this.radioFill,
    this.radioDot,
    this.radioIcon,
  });

  final Color fill;
  final Color border;
  final Color letterFill;
  final Color letterInk;
  final Color radioBorder;
  final Color? radioFill;
  final Color? radioDot;
  final String? radioIcon;
}
