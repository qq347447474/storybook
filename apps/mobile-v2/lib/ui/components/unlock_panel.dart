/// The unlock panel that closes the quiz step (design-spec §4.5 "解锁面板",
/// §5.9; `.overlay` / `.unlock-card` `visual/app.css` L2466-2560).
///
/// It is the only celebration the app allows: no score, no percentage, no
/// stars — an unlock glyph, one sentence of reassurance, the four steps of the
/// chapter ticked off, and one way forward. Every string is a parameter: the
/// panel is a vessel, the screen owns the copy.
library;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../app_icon.dart';
import 'app_chip.dart';
import 'dashed_border.dart';

/// A centred card: unlock glyph, title, explanation, the four step chips and
/// one full-width CTA.
class UnlockPanel extends StatefulWidget {
  const UnlockPanel({
    super.key,
    required this.title,
    required this.body,
    required this.steps,
    required this.ctaLabel,
    this.onCta,
    this.icon = 'unlock',
  });

  /// "Ready to retell" — the panel's heading, localised by the caller.
  final String title;

  /// One or two sentences framing what was achieved *without* a score.
  final String body;

  /// The steps of the chapter, in order, already localised. Each renders as a
  /// ticked chip; the whole flow is marked done, so no step is singled out.
  final List<String> steps;

  /// CTA label, e.g. "Go to retell".
  final String ctaLabel;

  /// CTA callback. `null` disables the button — `showUnlockPanel` pops the
  /// panel before calling it.
  final VoidCallback? onCta;

  /// Glyph of the 72 dp disc. `unlock` is the hand-off's choice.
  final String icon;

  /// `.unlock-card { border-radius: 28px }` (app.css L2489) — design-spec §5.9
  /// pins the same card at 26 dp.
  static const double radius = 26;

  /// `.unlock-icon { width: 72px; height: 72px }` (app.css L2503).
  static const double discSize = 72;

  /// `.unlock-icon::after { inset: -7px }` (app.css L2518).
  static const double discRingInset = 7;

  /// `.unlock-icon svg { width: 30px }` (app.css L2513).
  static const double iconSize = 30;

  /// `.unlock-card > p { max-width: 260px }` (app.css L2535).
  static const double bodyMaxWidth = 260;

  /// `--dur-slow: 320ms` with `--ease-out: cubic-bezier(.22,.9,.26,1)`
  /// (design-spec §2.6, app.css L89) — the sheet rise.
  static const Duration motion = Duration(milliseconds: 320);
  static const Curve curve = Cubic(0.22, 0.9, 0.26, 1);

  @override
  State<UnlockPanel> createState() => _UnlockPanelState();
}

class _UnlockPanelState extends State<UnlockPanel> {
  /// design-spec §5.9: focus moves into the dialog on open. Landing on the
  /// heading reads the whole panel before the CTA (design-spec §7.3).
  final FocusNode _titleFocus = FocusNode(debugLabel: 'UnlockPanel.title');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _titleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: Container(
        // `--shadow-float` (design-spec §2.5) is assigned to the sheets and to
        // this panel; it is ink-tinted, never black.
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(UnlockPanel.radius),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.35),
              offset: const Offset(0, 18),
              blurRadius: 44,
              spreadRadius: -20,
            ),
          ],
        ),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(UnlockPanel.radius),
          clipBehavior: Clip.antiAlias,
          child: Container(
            padding: EdgeInsets.fromLTRB(22, 24, 22, bottomInset + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(child: _disc()),
                const SizedBox(height: 16),
                Focus(
                  focusNode: _titleFocus,
                  child: Semantics(
                    header: true,
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: AppTypography.title.copyWith(color: AppColors.ink),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: UnlockPanel.bodyMaxWidth,
                    ),
                    child: Text(
                      widget.body,
                      textAlign: TextAlign.center,
                      // `.unlock-card > p`: 400 13px / 1.65, ink-2.
                      style: AppTypography.body.copyWith(
                        color: AppColors.ink2,
                        height: 1.65,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _steps(),
                const SizedBox(height: 20),
                // design-spec §6.4: the 56 dp CTA height is a red line, so the
                // label may scale up to 130 % and no further.
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: FilledButton(
                    onPressed: widget.onCta,
                    child: Text(widget.ctaLabel, textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The unlock disc: brand-soft circle, 30 dp glyph, dashed halo.
  Widget _disc() {
    const double ring = UnlockPanel.discSize + UnlockPanel.discRingInset * 2;
    return SizedBox.square(
      dimension: ring,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CustomPaint(
            size: const Size.square(ring),
            painter: DashedBoxBorderPainter(
              // `.unlock-icon::after { border: 1px dashed rgba(91,75,214,.3) }`
              color: AppColors.primary.withValues(alpha: 0.3),
              radius: ring / 2,
              dashLength: 4,
              gapLength: 4,
            ),
          ),
          Container(
            width: UnlockPanel.discSize,
            height: UnlockPanel.discSize,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: AppIcon(
                widget.icon,
                size: UnlockPanel.iconSize,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// `.unlock-stages`: the four steps, one 27 dp chip each, 6 dp apart.
  Widget _steps() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final String step in widget.steps)
          AppChip(step, icon: 'check', variant: AppChipVariant.level),
      ],
    );
  }
}

/// Shows [UnlockPanel] over the current route and completes when it closes.
///
/// The scrim is `AppColors.scrim` and taps on it do nothing: the panel is the
/// only way forward (design-spec §5.9 — a dialog, not a hint). The CTA pops the
/// panel before running [onCta], so the callback may push the next screen; with
/// no [onCta] the panel still closes, because a modal nobody can dismiss is a
/// dead end.
Future<void> showUnlockPanel(
  BuildContext context, {
  required String title,
  required String body,
  required List<String> steps,
  required String ctaLabel,
  VoidCallback? onCta,
  String icon = 'unlock',
}) {
  final bool reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: AppColors.scrim,
    transitionDuration: reduced ? Duration.zero : UnlockPanel.motion,
    pageBuilder: (
      BuildContext routeContext,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: UnlockPanel(
              title: title,
              body: body,
              steps: steps,
              ctaLabel: ctaLabel,
              icon: icon,
              onCta: () {
                Navigator.of(routeContext).pop();
                onCta?.call();
              },
            ),
          ),
        ),
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
        curve: UnlockPanel.curve,
      );
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          // `.unlock-card { transform: translateY(18px) }` (app.css L2494).
          position: Tween<Offset>(
            begin: const Offset(0, 0.05),
            end: Offset.zero,
          ).animate(eased),
          child: child,
        ),
      );
    },
  );
}
