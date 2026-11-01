/// The S1 app bar: back control, page title and the settings bypass
/// (`.appbar` / `.appbar__title`, `visual/app.css` L950-966).
///
/// Copy arrives already localised — this widget owns geometry, not sentences.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../ui/app_icon.dart';

class ContentsAppBar extends StatelessWidget {
  const ContentsAppBar({
    super.key,
    required this.title,
    required this.backLabel,
    required this.settingsLabel,
    this.onSettings,
  });

  /// Page title — "Contents".
  final String title;

  /// Screen-reader / tooltip label of the back control.
  final String backLabel;

  /// Screen-reader / tooltip label of the settings bypass.
  final String settingsLabel;

  /// Opens S7. `null` hides the control: a button that cannot act is worse
  /// than no button, and the caller wires this from the app graph.
  final VoidCallback? onSettings;

  /// `.appbar { min-height: 54px; padding: 0 14px 0 8px; gap: 10px }`.
  static const double minHeight = 54;
  static const double gap = 10;

  /// `.icon-btn svg { width: 22px }` (app.css L777).
  static const double iconSize = 22;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8, end: 14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight),
        child: Row(
          children: <Widget>[
            // IconButton already supplies the 44 dp target the `.icon-btn`
            // circle needs, without painting ink outside the radius.
            IconButton(
              key: const Key('contents-back'),
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: backLabel,
              icon: const AppIcon('arrow-left', size: iconSize),
            ),
            const SizedBox(width: gap),
            Expanded(
              child: Text(
                title,
                // `.appbar__title { 600 15px/1.3; letter-spacing: .005em }`.
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.005 * 15,
                  color: AppColors.ink,
                ),
              ),
            ),
            if (onSettings != null)
              IconButton(
                key: const Key('contents-settings'),
                onPressed: onSettings,
                tooltip: settingsLabel,
                icon: const AppIcon('settings', size: iconSize),
              ),
          ],
        ),
      ),
    );
  }
}
