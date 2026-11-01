/// Editorial illustrations from the hand-off (`visual/assets/`, mirrored into
/// `assets/visual/`).
///
/// These are the only raster-free hero images in the app: a cover, two scene
/// plates used as reading / retell backdrops and the brand mark. They are
/// authored at fixed intrinsic sizes, so the widget owns the frame
/// ([AspectRatio]) and the asset fills it — never the other way round.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A framed SVG illustration.
///
/// Decorative by default (same contract as `AppIcon`): pass [semanticLabel]
/// when the picture is the only description of what is on screen. When the
/// same illustration is adjacent to a heading that already says it, leave the
/// label null so the screen reader does not repeat itself (design-spec §7.2).
class AppIllustration extends StatelessWidget {
  const AppIllustration(
    this.name, {
    super.key,
    this.aspectRatio = defaultAspectRatio,
    this.fit = BoxFit.contain,
    this.semanticLabel,
  });

  /// Illustration name, matching `assets/visual/<name>.svg`.
  final String name;

  /// Width / height of the frame. Use one of the ratio constants below that
  /// matches the asset, otherwise the picture letterboxes or crops.
  final double aspectRatio;

  /// How the asset fills the frame. [BoxFit.contain] (default) never crops,
  /// which is what a full plate wants; [BoxFit.cover] is for edge-to-edge
  /// cards where the outer band of the artwork may be cut.
  final BoxFit fit;

  /// Screen-reader label. Leave null for decorative artwork.
  final String? semanticLabel;

  /// Every illustration shipped in `assets/visual/`, alphabetical.
  static const List<String> names = <String>[
    'cover-paper-boat',
    'logo-mark',
    'scene-puddle-boat',
    'scene-rain-window',
  ];

  /// `cover-paper-boat.svg` — 1200 × 800.
  static const double coverAspectRatio = 3 / 2;

  /// `scene-rain-window.svg`, `scene-puddle-boat.svg` — 1200 × 675.
  static const double sceneAspectRatio = 16 / 9;

  /// `logo-mark.svg` — 96 × 96.
  static const double markAspectRatio = 1;

  /// Library covers are the common case, so 3:2 is the default frame.
  static const double defaultAspectRatio = coverAspectRatio;

  /// Membership test for [names]; built once so the two cannot drift.
  static final Set<String> _known = names.toSet();

  /// Asset path for an illustration name.
  static String assetPath(String name) => 'assets/visual/$name.svg';

  @override
  Widget build(BuildContext context) {
    assert(
      _known.contains(name),
      'AppIllustration: unknown illustration "$name". Copy it from '
      'visual/assets/$name.svg into assets/visual/ and list it in '
      'AppIllustration.names.',
    );
    if (!_known.contains(name)) {
      return const SizedBox.shrink();
    }

    Widget art = SvgPicture.asset(
      assetPath(name),
      fit: fit,
      alignment: Alignment.center,
      // The artwork carries no <title>/<desc>; the frame decides whether it
      // speaks, so the loader must stay out of the semantics tree.
      excludeFromSemantics: true,
      // Crop the overflow of BoxFit.cover at the frame edge instead of
      // letting the artwork paint outside its card.
      clipBehavior: Clip.hardEdge,
    );

    if (semanticLabel != null) {
      art = Semantics(label: semanticLabel, image: true, container: true, child: art);
    }

    // Web-safe wrapper: `<svg width height>` in app.js locks the same ratio.
    return AspectRatio(aspectRatio: aspectRatio, child: art);
  }
}
