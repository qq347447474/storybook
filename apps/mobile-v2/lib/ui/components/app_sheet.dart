/// The bottom sheet of design-spec §5.9 (`.sheet` `visual/app.css` L3506-3560):
/// 20 dp top corners, a grabber, a title, an optional line of explanation and
/// whatever list the screen puts in it.
///
/// The sheet is chrome, not content: [AppSheet] renders the frame and
/// [showAppSheet] puts it on a route with the shared scrim. Copy always comes
/// from the caller.
library;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Sheet frame: grabber, heading, optional subtitle and the caller's list.
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.isScrollControlled = true,
  });

  /// Sheet heading, e.g. "Choose a chapter". Localised by the caller.
  final String title;

  /// One line under the heading; omitted when null.
  final String? subtitle;

  /// The sheet's content — a list of options, a form, a short paragraph.
  final Widget child;

  /// Tall-content mode, forwarded to [showModalBottomSheet].
  final bool isScrollControlled;

  /// design-spec §5.9 "20dp 顶部圆角".
  static const double radius = 20;

  /// `.sheet-grabber { width: 38px; height: 4px }` (app.css L3524); the hand-off
  /// draws 38, design-spec §5.9 pins 36.
  static const double grabberWidth = 36;
  static const double grabberHeight = 4;

  /// `.sheet { max-height: 84% }` (app.css L3514).
  static const double maxHeightFactor = 0.84;

  /// `.sheet { padding: 9px 20px calc(var(--gesture-inset) + 14px) }`.
  static const double gutter = 20;
  static const double topPadding = 9;
  static const double safeAreaTrailing = 14;

  /// `--dur-slow: 320ms` with `--ease-out` (design-spec §2.6).
  static const Duration motion = Duration(milliseconds: 320);

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final double maxHeight =
        MediaQuery.sizeOf(context).height * maxHeightFactor;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radius),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            top: topPadding,
            bottom: bottomInset + safeAreaTrailing,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: grabberWidth,
                  height: grabberHeight,
                  decoration: BoxDecoration(
                    // `.sheet-grabber { background: #ded4c2 }` — the
                    // `line-strong` step of the palette (design-spec §5.9).
                    color: AppColors.lineStrong,
                    borderRadius: BorderRadius.circular(grabberHeight / 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: gutter),
                child: _header(),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(gutter, 16, gutter, 0),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          // `.sheet-title { font: 600 22px/1.3 }` — the H2 step of §2.3.
          style: AppTypography.h2.copyWith(color: AppColors.ink),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 7),
          Text(
            subtitle!,
            // `.sheet-body { margin-top: 7px; font: 400 12.5px/1.65 }`.
            style: AppTypography.meta.copyWith(
              color: AppColors.ink2,
              fontWeight: FontWeight.w400,
              height: 1.65,
            ),
          ),
        ],
      ],
    );
  }
}

/// Opens [AppSheet] on the nearest navigator and completes with the value the
/// sheet is popped with.
///
/// The barrier is `AppColors.scrim` and a tap on it closes the sheet
/// (design-spec §5.9 lists a bottom sheet as dismissible, unlike the unlock
/// panel). [isScrollControlled] defaults to true so a long option list can use
/// the whole screen; [AppSheet] still caps itself at 84 %.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Widget child,
  bool isScrollControlled = true,
}) {
  final bool reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: AppColors.surface,
    barrierColor: AppColors.scrim,
    // `useSafeArea: false` — AppSheet adds the gesture inset itself, so the
    // surface runs to the bottom edge of the screen like the hand-off.
    useSafeArea: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSheet.radius)),
    ),
    clipBehavior: Clip.antiAlias,
    sheetAnimationStyle: AnimationStyle(
      duration: reduced ? Duration.zero : AppSheet.motion,
      curve: Curves.easeOut,
    ),
    builder: (BuildContext sheetContext) => AppSheet(
      title: title,
      subtitle: subtitle,
      isScrollControlled: isScrollControlled,
      child: child,
    ),
  );
}
