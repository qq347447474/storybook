/// The fixed bottom dock: helper line + full-width 56 dp CTA (design-spec
/// §2.4 / §5.1, `.dock` app.css L1006-1029, `.helper` L1022-1030).
///
/// Every screen of the flow ends in one of these; the CTA never scrolls with
/// the content and never sits above the gesture area. The bottom padding is
/// therefore computed from the live safe-area inset (design-spec §6.3:
/// `padding-bottom = gesture inset + 6`).
library;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../app_icon.dart';

/// Bottom action bar with one primary CTA.
///
/// The dock owns the button so the 56 dp / full-width / pill geometry can
/// never drift between screens: pass [primaryLabel] and [onPrimaryPressed].
/// A `null` callback means "disabled", and design-spec §5.1 requires a reason
/// next to a greyed button — hence the assert on [helper].
class AppDock extends StatelessWidget {
  const AppDock({
    super.key,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.helper,
    this.helperIsReady = false,
    this.action,
    this.fill,
  }) : assert(
          onPrimaryPressed != null || helper != null,
          'AppDock: a disabled CTA must explain why it is disabled '
          '(design-spec §5.1) — pass `helper`.',
        );

  /// CTA label, localised by the caller.
  final String primaryLabel;

  /// CTA callback. `null` disables the button.
  final VoidCallback? onPrimaryPressed;

  /// Helper line above the CTA: the reason a CTA is disabled, or a nudge.
  final String? helper;

  /// Paints [helper] in `success-ink` (`.helper--ready`, app.css L1026) — used
  /// when the helper confirms the step can proceed (e.g. "answer recorded").
  final bool helperIsReady;

  /// Optional secondary text button below the CTA, e.g. "Skip for now".
  final Widget? action;

  /// Dock fill. Defaults to `surface`; the hand-off paints `--paper`
  /// (app.css L1010) — the phase-2B decision is a lighter plate separated by a
  /// 1 px `--line` hairline so the button plate reads as its own layer without
  /// a shadow (design-spec §2.5 reserves shadows for cards and sheets).
  final Color? fill;

  /// `.dock { padding: 10px var(--gutter) calc(var(--gesture-inset) + 6px) }`
  /// (app.css L1009); `--gutter: 20px` (app.css L79).
  static const EdgeInsets _padding = EdgeInsets.fromLTRB(20, 10, 20, 0);

  /// `.helper { min-height: 18px; margin-bottom: 2px }` (app.css L1023).
  static const double _helperMinHeight = 18;
  static const double _helperGap = 2;

  /// design-spec §6.3: gesture inset + 6 dp.
  static const double _safeAreaTrailing = 6;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: fill ?? AppColors.surface,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        padding: _padding.copyWith(bottom: bottomInset + _safeAreaTrailing),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (helper != null)
              Padding(
                padding: const EdgeInsets.only(bottom: _helperGap),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: _helperMinHeight),
                  child: Text(
                    helper!,
                    textAlign: TextAlign.center,
                    style: AppTypography.meta.copyWith(
                      color: helperIsReady ? AppColors.successInk : AppColors.ink3,
                    ),
                  ),
                ),
              ),
            // design-spec §6.4: the 56 dp height is a red line, so the label
            // may scale up to 130 % and no further.
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: FilledButton(
                onPressed: onPrimaryPressed,
                child: Text(primaryLabel, textAlign: TextAlign.center),
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

/// Secondary text button that sits under the dock CTA (`.btn--ghost`).
///
/// 46 dp minimum height comes from the theme's `textButtonTheme`; the label is
/// `--primary`, `--ink-3` when disabled.
class AppDockAction extends StatelessWidget {
  const AppDockAction({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  /// Button label, localised by the caller.
  final String label;

  /// Callback; `null` disables the button.
  final VoidCallback? onPressed;

  /// Optional 16 dp leading glyph (`.link-btn svg { 16px }`, app.css L866).
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            // Disabled text buttons turn `--ink-3` (app.css L138); the glyph
            // has to follow, it cannot stay brand-coloured.
            AppIcon(
              icon!,
              size: AppIconSize.sm,
              color: onPressed == null ? AppColors.ink3 : AppColors.primary,
            ),
            const SizedBox(width: 6),
          ],
          Text(label),
        ],
      ),
    );
  }
}
