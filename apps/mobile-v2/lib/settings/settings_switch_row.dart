/// The reduce-motion row of S7 (design-spec §4.8 learning group, `.switch` in
/// `visual/app.css` L3423-3455).
///
/// The whole row toggles, so the 44 dp target is the row and not just the
/// 46 × 28 dp control (design-spec §6.4). The [Switch] keeps its own key so a
/// test can still tap the control itself.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'settings_rows.dart';

/// Label, sub line and a trailing [Switch] that mirrors the stored preference.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.label,
    this.sub,
    required this.value,
    required this.onChanged,
    this.switchKey,
  });

  /// Row text, e.g. "Reduce motion".
  final String label;

  /// What switching it off/on does.
  final String? sub;

  /// Current state.
  final bool value;

  /// Called with the requested state.
  final ValueChanged<bool> onChanged;

  /// Key placed on the [Switch] itself so tests can tap the control.
  final Key? switchKey;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(minHeight: SettingsLayout.rowMinHeight),
          child: Padding(
            padding: SettingsLayout.rowPadding,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: SettingsRowText(label: label, sub: sub),
                ),
                Switch(
                  key: switchKey,
                  value: value,
                  onChanged: onChanged,
                  // `.switch` off `#d9cfbc` is not in the palette; the nearest
                  // token is `line-strong`, so the control never introduces a
                  // colour the rest of the app cannot name.
                  trackColor: WidgetStateProperty.resolveWith<Color>(
                    (Set<WidgetState> states) =>
                        states.contains(WidgetState.selected)
                            ? AppColors.primary
                            : AppColors.lineStrong,
                  ),
                  thumbColor: WidgetStateProperty.resolveWith<Color>(
                    (Set<WidgetState> states) =>
                        states.contains(WidgetState.selected)
                            ? AppColors.onPrimary
                            : AppColors.surfaceRaised,
                  ),
                  trackOutlineColor:
                      const WidgetStatePropertyAll<Color>(Colors.transparent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
