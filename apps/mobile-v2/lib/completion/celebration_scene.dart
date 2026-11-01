/// The S6 celebration scene: two soft halos, the brand disc with the paper-boat
/// mark, three sparks and — unless motion is reduced — [ConfettiLayer]
/// (`.celebrate-scene`, `visual/app.css` L3118-3176, design-spec §4.7 item 1).
///
/// Everything here is decoration — the scene contributes nothing to the
/// semantics tree, and the copy underneath says what actually happened. The one
/// hard rule: with reduced motion (`MediaQuery.disableAnimations` or the S7
/// switch) the confetti does not exist at all and nothing scales (design-spec
/// §2.6: "减少动效时完全不出现"), the static disc and sparks stay.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../ui/app_icon.dart';
import '../ui/app_illustration.dart';
import '../ui/components/dashed_border.dart';
import 'confetti_layer.dart';

/// The framed celebration visual, 206 × 206 dp.
class CelebrationScene extends StatelessWidget {
  const CelebrationScene({super.key, required this.reduceMotion});

  /// The S7 `reduce motion` preference. The platform flag is folded in on top
  /// via [MediaQuery.disableAnimationsOf], so either source stills the scene.
  final bool reduceMotion;

  /// `.celebrate-scene { width: 206px; height: 206px }` (app.css L3118).
  static const double size = 206;

  /// `.celebrate-ring { inset: 12px; border: 1.5px dashed }`.
  static const double ringInset = 12;
  static const double ringStroke = 1.5;

  /// The second halo of design-spec §4.7 item 1 ("两圈柔和光环"). `app.css`
  /// only draws the dashed ring plus the disc's own edge; the soft ring is the
  /// missing middle so the disc does not float on the paper with one outline.
  static const double haloInset = 21;
  static const double haloStroke = 1;
  static const double haloOpacity = 0.1;

  /// `.celebrate-disc { inset: 30px }`.
  static const double discInset = 30;

  /// `.celebrate-disc img { width: 84px }` (app.css L3145).
  static const double markSize = 84;

  /// `rgba(91, 75, 214, .26)` halo.
  static const double ringOpacity = 0.26;

  @override
  Widget build(BuildContext context) {
    // The in-app switch and the system setting both still the scene (§2.6).
    final bool still = reduceMotion || MediaQuery.disableAnimationsOf(context);
    const double ringSize = size - ringInset * 2;
    const double haloSize = size - haloInset * 2;
    const double discSize = size - discInset * 2;

    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: <Widget>[
            PositionedDirectional(
              start: ringInset,
              top: ringInset,
              width: ringSize,
              height: ringSize,
              child: CustomPaint(
                painter: DashedBoxBorderPainter(
                  // `rgba(91, 75, 214, .26)` — brand at 26 %.
                  color: AppColors.primary.withValues(alpha: ringOpacity),
                  radius: ringSize / 2,
                  strokeWidth: ringStroke,
                ),
              ),
            ),
            // The soft inner halo — the second ring of §4.7 item 1.
            PositionedDirectional(
              start: haloInset,
              top: haloInset,
              width: haloSize,
              height: haloSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: haloOpacity),
                    width: haloStroke,
                  ),
                ),
              ),
            ),
            const PositionedDirectional(
              start: discInset,
              top: discInset,
              width: discSize,
              height: discSize,
              child: _Disc(),
            ),
            // `.spark--1` accent, `.spark--2` brand, `.spark--3` success.
            const PositionedDirectional(
              top: 34,
              end: 18,
              child: AppIcon('spark', size: 14, color: AppColors.accent),
            ),
            const PositionedDirectional(
              bottom: 44,
              start: 12,
              child: AppIcon('spark', size: 11, color: AppColors.primary),
            ),
            const PositionedDirectional(
              top: 58,
              start: 28,
              child: AppIcon('spark', size: 9, color: AppColors.successInk),
            ),
            if (!still) const Positioned.fill(child: ConfettiLayer()),
          ],
        ),
      ),
    );
  }
}

/// `.celebrate-disc` — the brand-soft plate the paper boat sits on.
class _Disc extends StatelessWidget {
  const _Disc();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // The hand-off stacks `#fff → transparent` over `--primary-soft`; one
        // gradient from surface to primary-soft at 62 % is the same composite
        // without a second layer.
        gradient: const RadialGradient(
          center: Alignment(-0.24, -0.4),
          colors: <Color>[
            AppColors.surfaceRaised,
            AppColors.primarySoft,
          ],
          stops: <double>[0, 0.62],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            // `0 22px 40px -30px rgba(91,75,214,.7)`.
            color: AppColors.primary.withValues(alpha: 0.7),
            offset: const Offset(0, 22),
            blurRadius: 40,
            spreadRadius: -30,
          ),
        ],
      ),
      child: const Center(
        child: SizedBox(
          width: CelebrationScene.markSize,
          height: CelebrationScene.markSize,
          child: AppIllustration(
            'logo-mark',
            aspectRatio: AppIllustration.markAspectRatio,
          ),
        ),
      ),
    );
  }
}
