/// The S7 language picker (design-spec §4.8, state row "语言弹层"): a bottom
/// sheet with a listbox of locales, each option carrying a check mark and a
/// sub line. Picking one applies it immediately — there is no "save" step.
///
/// Option geometry follows `.sheet-option` in `visual/app.css` L3586-3632
/// (54 dp minimum height, `line` hairline, 14 dp corners); the selected recipe
/// uses the brand pair from the token file instead of the hand-off's one-off
/// `#f7f4ff`.
library;

import 'package:flutter/material.dart';

import '../i18n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../ui/app_icon.dart';
import '../ui/components/app_sheet.dart';
import 'settings_rows.dart';

/// The pseudolocale of the A3 walkthrough. It is a QA tool, not a language a
/// learner can choose, so it never appears in the picker.
const String pseudoLocaleTag = 'qps-ploc';

/// Locales the interface can be switched to (design-spec §4.8: 中文 / English).
const List<String> uiLocaleOptions = <String>['en', 'zh-Hans'];

/// One pickable locale of the sheet.
class LocaleChoice {
  const LocaleChoice({
    required this.tag,
    required this.label,
    required this.sub,
  });

  /// BCP-47 tag the choice writes into settings.
  final String tag;

  /// Endonym shown as the option title, e.g. `中文`.
  final String label;

  /// One line under [label] — what switching to this locale means.
  final String sub;
}

/// Endonym of [tag]. A language names itself in its own language, so a learner
/// can find it before the interface has been switched.
String localeName(AppLocalizations l10n, String tag) => switch (tag) {
      'zh-Hans' => l10n.t('settings.localeName.zh'),
      'en' => l10n.t('settings.localeName.en'),
      _ => tag,
    };

/// Sub line for [tag]; set [gloss] for the "definitions" wording of the
/// vocabulary picker.
String localeSubLine(
  AppLocalizations l10n,
  String tag, {
  required bool gloss,
}) =>
    switch (tag) {
      'zh-Hans' => l10n.t(
          gloss
              ? 'settings.localeName.zhSubGloss'
              : 'settings.localeName.zhSub'),
      'en' => l10n.t(
          gloss ? 'settings.localeName.enSubGloss' : 'settings.localeName.enSub'),
      _ => tag,
    };

/// Opens the picker and completes with the chosen tag, or null when dismissed.
Future<String?> showLocaleSheet(
  BuildContext context, {
  required String title,
  required String body,
  required String caption,
  required List<LocaleChoice> options,
  required String selectedTag,
}) {
  return showAppSheet<String>(
    context,
    title: title,
    subtitle: body,
    child: Builder(
      builder: (BuildContext sheetContext) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < options.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 6),
              _LocaleOption(
                key: Key('settings-locale-option-${options[i].tag}'),
                choice: options[i],
                selected: options[i].tag == selectedTag,
                onTap: () => Navigator.of(sheetContext).pop(options[i].tag),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              caption,
              textAlign: TextAlign.center,
              // `.sheet-caption { font: 400 9.5px/1.5; color: ink-3 }`.
              style: AppTypography.meta.copyWith(
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: AppColors.ink3,
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// One option of the listbox: title, sub line, trailing check when selected.
class _LocaleOption extends StatelessWidget {
  const _LocaleOption({
    super.key,
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final LocaleChoice choice;
  final bool selected;
  final VoidCallback onTap;

  /// `.sheet-option { min-height: 54px; padding: 10px 13px }`.
  static const double minHeight = 54;
  static const EdgeInsets _padding =
      EdgeInsets.symmetric(horizontal: 13, vertical: 10);

  /// `.sheet-option svg { width: 19px }` (app.css L3618).
  static const double checkSize = 19;

  @override
  Widget build(BuildContext context) {
    final Color border = selected ? AppColors.primary : AppColors.line;

    return Semantics(
      // The check mark is decorative; the state is announced here instead, so
      // selection is never colour-only (design-spec §7.2).
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        borderRadius:
            BorderRadius.circular(SettingsLayout.radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SettingsLayout.radiusCard),
          child: Container(
            constraints: const BoxConstraints(minHeight: minHeight),
            padding: _padding,
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(SettingsLayout.radiusCard),
              border: Border.all(color: border),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        choice.label,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(
                          height: SettingsLayout.subGap),
                      Text(
                        choice.sub,
                        style: AppTypography.meta.copyWith(
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                          color: AppColors.ink3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SettingsLayout.valueInset),
                // Stays in the layout when unselected so the text never
                // shifts sideways between states.
                Opacity(
                  opacity: selected ? 1 : 0,
                  child: AppIcon(
                    'check',
                    size: checkSize,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
