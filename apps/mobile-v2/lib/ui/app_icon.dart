/// Vector icon renderer for the hand-off icon set.
///
/// One SVG per symbol of the sprite inlined in `visual/prototype.html`
/// (design-spec §2.7: 24 × 24 viewBox, stroke 1.8–1.9, round caps, filled
/// only for play / pause / spark). The sprite is split into
/// `assets/icons/<name>.svg` and each file keeps `#000000` where the sprite
/// had the inherited-colour keyword — flutter_svg cannot resolve it, so the
/// paint colour is injected at render time with a [ColorFilter] instead.
///
/// Screens must use [AppIcon] rather than `Icon(Icons.*)`: Material glyphs
/// belong to a different stroke weight and are replaced screen by screen in
/// Phase 3.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// The three icon sizes the layout uses (design-spec §2.7, `app.css`).
///
/// 24 is the designed size; 20 and 16 are the only permitted reductions, so
/// the 1.8 stroke never drops below 1.2 px of optical weight.
class AppIconSize {
  const AppIconSize._();

  /// Inline with meta text, inside chips and list rows.
  static const double sm = 16;

  /// Dense headers, trailing actions on a card.
  static const double md = 20;

  /// Default: nav bars, primary CTAs, standalone glyphs.
  static const double lg = 24;
}

/// A single icon from the project icon set, painted in one flat colour.
///
/// Decorative by default: the widget contributes nothing to the semantics
/// tree, which is correct when the icon sits next to a text label
/// (design-spec §2.7 — an icon never carries meaning on its own). Pass
/// [semanticLabel] only for an icon that *is* the control, e.g. an
/// icon-only play button.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.name, {
    super.key,
    this.size = AppIconSize.lg,
    this.color,
    this.semanticLabel,
  });

  /// Icon name — the sprite symbol id without its `i-` prefix, matching
  /// `assets/icons/<name>.svg`. See [names] for the complete list.
  final String name;

  /// Edge length in logical pixels. Use [AppIconSize] constants.
  final double size;

  /// Paint colour; defaults to [AppColors.ink].
  final Color? color;

  /// Screen-reader label. Leave null for decorative icons.
  final String? semanticLabel;

  /// Every icon shipped in `assets/icons/`, alphabetical.
  static const List<String> names = <String>[
    'alert',
    'arrow-left',
    'arrow-right',
    'award',
    'book',
    'bulb',
    'cards',
    'check',
    'check-circle',
    'chevron-down',
    'chevron-left',
    'chevron-right',
    'clock',
    'close',
    'download',
    'eye',
    'globe',
    'grid',
    'headphones',
    'image',
    'info',
    'list',
    'lock',
    'mic',
    'mic-off',
    'pause',
    'play',
    'quiz',
    'refresh',
    'rotate',
    'settings',
    'spark',
    'speaker',
    'unlock',
    'volume',
    'waves',
  ];

  /// Membership test for [names]; built once so the two cannot drift.
  static final Set<String> _known = names.toSet();

  /// Asset path for an icon name.
  static String assetPath(String name) => 'assets/icons/$name.svg';

  @override
  Widget build(BuildContext context) {
    // A missing icon is a build-time mistake, never a runtime state: assert
    // loudly in debug, degrade to nothing in release instead of crashing.
    assert(
      _known.contains(name),
      'AppIcon: unknown icon "$name". Add the symbol to the sprite in '
      'visual/prototype.html, extract it to assets/icons/$name.svg and list '
      'it in AppIcon.names.',
    );
    if (!_known.contains(name)) {
      return const SizedBox.shrink();
    }

    final Widget icon = SvgPicture.asset(
      assetPath(name),
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(color ?? AppColors.ink, BlendMode.srcIn),
      // The SVG files carry no <title>/<desc>; excluding them keeps the
      // semantics tree to the one label the caller opted into.
      excludeFromSemantics: true,
    );

    if (semanticLabel == null) {
      return icon;
    }
    return Semantics(label: semanticLabel, container: true, child: icon);
  }
}
