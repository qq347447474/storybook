/// The centred two-button dialog of design-spec §5.9 (second bullet): used for
/// the first microphone request — "暂不 / 允许" — and destructive confirmations
/// (removing a downloaded book), where the filled button switches to the
/// danger tone instead of the brand fill.
///
/// Two buttons, always the same order: the quiet one on the left denies, the
/// filled one on the right allows. Escape and a tap on the scrim both count as
/// "not now", so a learner can never be trapped in a permission prompt.
library;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// A centred card with a heading, one paragraph and two 52 dp buttons.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.body,
    required this.denyLabel,
    required this.allowLabel,
    this.onDeny,
    this.onAllow,
    this.destructive = false,
  });

  /// Heading, e.g. "May we use the microphone?".
  final String title;

  /// One or two sentences: why the permission is needed, what happens without
  /// it (design-spec §5.8 — describe the fact and the next step, no pressure).
  final String body;

  /// Left button label, e.g. "Not now". Closes the dialog on tap.
  final String denyLabel;

  /// Right button label, e.g. "Allow".
  final String allowLabel;

  /// Runs after the dialog has closed with a "no" result.
  final VoidCallback? onDeny;

  /// Runs after the dialog has closed with a "yes" result.
  final VoidCallback? onAllow;

  /// True when the confirmed action destroys data (delete a downloaded book).
  /// The filled button then carries the danger tone instead of the brand fill,
  /// so the destructive path never looks like the everyday primary CTA.
  final bool destructive;

  /// design-spec §5.9: "两个 52dp 按钮".
  static const double buttonHeight = 52;

  /// Gap between the two buttons; keeps each target wider than 44 dp on a
  /// 360 dp column.
  static const double buttonGap = 10;

  /// Card radius. The hand-off's centred sheets use 22–26 dp; a dialog sits one
  /// step below the unlock panel.
  static const double radius = 22;

  /// `--dur-base: 240ms` — the fade of `.overlay` (app.css L2473).
  static const Duration motion = Duration(milliseconds: 240);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 330),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.35),
                  offset: const Offset(0, 18),
                  blurRadius: 44,
                  spreadRadius: -20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: AppTypography.h2.copyWith(color: AppColors.ink),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  body,
                  style: AppTypography.body.copyWith(
                    color: AppColors.ink2,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                // design-spec §6.4: the 52 dp height is a red line, so the
                // labels may scale up to 130 % and no further.
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _button(
                          label: denyLabel,
                          filled: false,
                          onPressed: onDeny,
                        ),
                      ),
                      const SizedBox(width: buttonGap),
                      Expanded(
                        child: _button(
                          label: allowLabel,
                          filled: true,
                          destructive: destructive,
                          onPressed: onAllow,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// `.btn--secondary` on the left, `.btn--primary` on the right, both 52 dp.
  /// A destructive confirmation paints the filled button in the danger tone.
  Widget _button({
    required String label,
    required bool filled,
    required VoidCallback? onPressed,
    bool destructive = false,
  }) {
    final ButtonStyle style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll<Size>(Size(0, buttonHeight)),
      // The theme gives every filled button a 56 dp minimum; the dialog's two
      // keys are 52, so the target size is pinned instead of padded.
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: 12),
      ),
      shape: const WidgetStatePropertyAll<OutlinedBorder>(StadiumBorder()),
      elevation: const WidgetStatePropertyAll<double>(0),
      animationDuration: const Duration(milliseconds: 150),
      backgroundColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) {
          if (filled) {
            if (destructive) {
              // Pressed slightly deeper, same red-brown family (§5.7 danger).
              return states.contains(WidgetState.pressed)
                  ? AppColors.dangerInk.withValues(alpha: 0.88)
                  : AppColors.dangerInk;
            }
            if (states.contains(WidgetState.pressed)) {
              return AppColors.primaryStrong;
            }
            return AppColors.primary;
          }
          return AppColors.surface;
        },
      ),
      foregroundColor: WidgetStatePropertyAll<Color>(
        filled ? AppColors.onPrimary : AppColors.ink,
      ),
      side: filled
          ? null
          : const WidgetStatePropertyAll<BorderSide>(
              BorderSide(color: AppColors.lineStrong),
            ),
    );

    return SizedBox(
      height: buttonHeight,
      child: FilledButton(
        onPressed: onPressed,
        style: style,
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Shows [ConfirmDialog] and reports the answer.
///
/// Returns `true` when [ConfirmDialog.allowLabel] was chosen. A tap on the scrim
/// or Escape closes the route with no value, which is read as a denial — the
/// quiet answer, never the permissive one. Either way exactly one of [onDeny] /
/// [onAllow] runs, after the route is gone.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String denyLabel,
  required String allowLabel,
  VoidCallback? onDeny,
  VoidCallback? onAllow,
  bool destructive = false,
}) async {
  final bool reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  final bool? allowed = await showGeneralDialog<bool>(
    context: context,
    // Dismissible so the barrier and Escape can answer "not now"; the scrim is
    // the shared token, not Material's default black.
    barrierDismissible: true,
    barrierLabel: denyLabel,
    barrierColor: AppColors.scrim,
    transitionDuration: reduced ? Duration.zero : ConfirmDialog.motion,
    pageBuilder: (
      BuildContext routeContext,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return ConfirmDialog(
        title: title,
        body: body,
        denyLabel: denyLabel,
        allowLabel: allowLabel,
        destructive: destructive,
        onDeny: () => Navigator.of(routeContext).pop(false),
        onAllow: () => Navigator.of(routeContext).pop(true),
      );
    },
    transitionBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) {
      final Animation<double> eased = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          // `.overlay.is-open .unlock-card` settles from 18 dp below; a dialog
          // has no travel, so it scales the last 4 % instead.
          scale: Tween<double>(begin: 0.96, end: 1).animate(eased),
          child: child,
        ),
      );
    },
  );

  if (allowed ?? false) {
    onAllow?.call();
    return true;
  }
  onDeny?.call();
  return false;
}
