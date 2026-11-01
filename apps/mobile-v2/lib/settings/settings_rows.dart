/// Building blocks of S7 (design-spec §4.8): group label, panel card, the row
/// body and the tappable row.
///
/// Geometry is taken from the hand-off (`.settings-group`, `.settings-label`,
/// `.settings-card`, `.set-row` — `visual/app.css` L3352-3420) and snapped onto
/// the 4 pt grid plus the 10 / 14 / 20 radii of design-spec §2.4. Copy never
/// lives here: every label, sub line and value arrives from the caller, already
/// localised.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../ui/app_icon.dart';

/// Measurements shared by the S7 blocks and the sheets it opens.
class SettingsLayout {
  const SettingsLayout._();

  /// `--gutter: 20px` — page inset on both sides.
  static const double gutter = 20;

  /// `--r-sm`: icon tiles inside a card.
  static const double radiusInner = 10;

  /// `--r-md`: cards, row groups, sheet options.
  static const double radiusCard = 14;

  /// `.set-row { min-height: 60px }` (app.css L3364).
  static const double rowMinHeight = 60;

  /// `.settings-group { margin-top: 20px }` (app.css L3352).
  static const double groupGap = 20;

  /// `.settings-label { margin: 0 4px 8px }` (app.css L3356) — the caption is
  /// inset 4 dp past the card edge.
  static const double labelInset = 4;
  static const double labelGap = 8;

  /// `.set-row { padding: 10px 14px }` (app.css L3364).
  static const EdgeInsets rowPadding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 10);

  /// `.set-sub { margin-top: 2px }` (app.css L3396).
  static const double subGap = 2;

  /// `.set-value { gap: 4px }` (app.css L3404).
  static const double valueGap = 4;

  /// Gap between the row body and its trailing value.
  static const double valueInset = 12;

  /// `.set-value svg { width: 15px }` (app.css L3414) — the picker chevron.
  static const double pickerChevron = 15;

  /// `.set-row svg` on the "opens a detail" rows is drawn at 17 dp.
  static const double detailChevron = 17;
}

/// A titled group: micro label + bordered surface card whose rows are split by
/// 1 px hairlines (`.settings-group` + `.settings-card`).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.label,
    required this.children,
  });

  /// Group caption — "Language", "Learning", "About". Caller-localised.
  final String label;

  /// Rows; a hairline is inserted between them (`.set-row + .set-row`).
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(const Divider(height: 1, thickness: 1, color: AppColors.line));
      }
      rows.add(children[i]);
    }

    return Padding(
      padding: const EdgeInsets.only(top: SettingsLayout.groupGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // The caption is a heading, not body copy: screen readers announce
          // the group before the rows that follow it.
          Semantics(
            header: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SettingsLayout.labelInset,
                0,
                SettingsLayout.labelInset,
                SettingsLayout.labelGap,
              ),
              child: Text(
                label,
                style: AppTypography.label.copyWith(color: AppColors.ink3),
              ),
            ),
          ),
          Container(
            // `clipBehavior` keeps the row ink inside the rounded border.
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(SettingsLayout.radiusCard),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
        ],
      ),
    );
  }
}

/// The two-line body of a settings row: `.set-label` over `.set-sub`.
///
/// Shared by [SettingsRow] and `SettingsSwitchRow` so the two recipes cannot
/// drift apart.
class SettingsRowText extends StatelessWidget {
  const SettingsRowText({super.key, required this.label, this.sub});

  /// Primary row text. Caller-localised.
  final String label;

  /// Secondary line under [label] — what the setting does.
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          // `.set-label { font: 500 14px/1.4 }` — the Body step at 500.
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.ink,
          ),
        ),
        if (sub != null) ...<Widget>[
          const SizedBox(height: SettingsLayout.subGap),
          Text(
            sub!,
            // `.set-sub { font: 400 10.5px/1.45; color: ink-3 }`.
            style: AppTypography.meta.copyWith(
              fontWeight: FontWeight.w400,
              height: 1.45,
              color: AppColors.ink3,
            ),
          ),
        ],
      ],
    );
  }
}

/// A tappable (or static) settings row: body, optional trailing value and icon
/// (`.set-row` / `.set-main` / `.set-value`).
///
/// A row with [onTap] reports as a button; a static one stays plain text, so
/// the version row is not announced as actionable.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.sub,
    this.value,
    this.trailingIcon,
    this.trailingIconSize = SettingsLayout.pickerChevron,
    this.onTap,
  });

  /// Primary row text. Caller-localised.
  final String label;

  /// Secondary line under [label] — what the setting does.
  final String? sub;

  /// Current value shown before the icon, e.g. the locale endonym.
  final String? value;

  /// Icon name for [AppIcon]; null hides the trailing glyph.
  final String? trailingIcon;

  /// Edge length of [trailingIcon].
  final double trailingIconSize;

  /// Opens the picker / detail sheet. Null makes the row informational.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget body = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: SettingsLayout.rowMinHeight),
      child: Padding(
        padding: SettingsLayout.rowPadding,
        child: Row(
          children: <Widget>[
            Expanded(child: SettingsRowText(label: label, sub: sub)),
            if (value != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: SettingsLayout.valueInset,
                ),
                child: Text(
                  value!,
                  // `.set-value { font: 500 12px/1.3; color: ink-2 }`.
                  style: AppTypography.meta.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink2,
                  ),
                ),
              ),
            if (trailingIcon != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: SettingsLayout.valueGap,
                ),
                child: AppIcon(
                  trailingIcon!,
                  size: trailingIconSize,
                  color: AppColors.ink3,
                ),
              ),
          ],
        ),
      ),
    );

    if (onTap == null) return body;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, child: body),
    );
  }
}
