/// The three controls inside [ReadingPlayer]: the 46 dp play key, the
/// draggable 18 dp track and the 42 × 30 speed pill.
///
/// A part of `reading_player.dart` on purpose — they are only meaningful in
/// that row, need the same constants, and staying private keeps the public API
/// to one widget.
part of 'reading_player.dart';

/// `.play-btn` — a 46 dp brand circle holding a 20 dp glyph.
class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.isPlaying,
    required this.onPressed,
    required this.label,
  });

  final bool isPlaying;
  final VoidCallback? onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        shape: const CircleBorder(),
        // The app theme gives every filled button a 56 dp minimum height; the
        // play key is 46, so both the minimum and the fixed size are pinned.
        minimumSize: const Size.square(ReadingPlayer.playSize),
        fixedSize: const Size.square(ReadingPlayer.playSize),
        // 46 dp already clears the 44 dp floor, so no invisible padding.
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        // The disabled look is carried by the caller's `Opacity`; keeping the
        // brand fill avoids the theme's warm grey bleeding in.
        disabledBackgroundColor: AppColors.primary,
        disabledForegroundColor: AppColors.onPrimary,
      ),
      child: Padding(
        // `.play-btn svg { margin-left: 1px }` — the play triangle is left-heavy
        // and needs the nudge; the pause bars are symmetric.
        padding: EdgeInsets.only(left: isPlaying ? 0 : 1),
        child: AppIcon(
          isPlaying ? 'pause' : 'play',
          size: ReadingPlayer.playIconSize,
          color: AppColors.onPrimary,
          semanticLabel: label,
        ),
      ),
    );
  }
}

/// `.player-track` — 18 dp hit area, 4 dp fill, 10 dp knob.
///
/// The fill follows [fraction] with no transition on purpose: an animated width
/// lags the finger during a drag and reads as input delay.
class _SeekBar extends StatelessWidget {
  const _SeekBar({
    required this.fraction,
    required this.onSeek,
    required this.label,
    required this.valueLabel,
  });

  final double fraction;
  final ValueChanged<double>? onSeek;
  final String? label;
  final String valueLabel;

  void _seekTo(double dx, double width) {
    final ValueChanged<double>? callback = onSeek;
    if (callback == null || width <= 0) return;
    callback((dx / width).clamp(0.0, 1.0).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ReadingPlayer.trackHitHeight,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;
          final double fill = width * fraction;
          final double maxLeft = width - ReadingPlayer.knobSize;
          final double knobLeft = (fill - ReadingPlayer.knobSize / 2)
              .clamp(0.0, maxLeft < 0 ? 0.0 : maxLeft)
              .toDouble();
          final double centre =
              (ReadingPlayer.trackHitHeight - ReadingPlayer.trackHeight) / 2;

          final Widget bar = GestureDetector(
            behavior: HitTestBehavior.opaque,
            // A tap seeks immediately; a horizontal drag scrubs. The vertical
            // axis is left to the page scroll, so a swipe still scrolls.
            onTapDown: onSeek == null
                ? null
                : (TapDownDetails d) => _seekTo(d.localPosition.dx, width),
            onHorizontalDragStart: onSeek == null
                ? null
                : (DragStartDetails d) => _seekTo(d.localPosition.dx, width),
            onHorizontalDragUpdate: onSeek == null
                ? null
                : (DragUpdateDetails d) => _seekTo(d.localPosition.dx, width),
            child: Stack(
              children: <Widget>[
                _rail(
                  left: 0,
                  width: width,
                  top: centre,
                  color: AppColors.progressTrack,
                ),
                _rail(
                  left: 0,
                  width: fill,
                  top: centre,
                  color: AppColors.primary,
                ),
                Positioned(
                  left: knobLeft,
                  top: (ReadingPlayer.trackHitHeight - ReadingPlayer.knobSize) / 2,
                  width: ReadingPlayer.knobSize,
                  height: ReadingPlayer.knobSize,
                  child: DecoratedBox(
                    // White dot with a brand ring: readable on both the fill and
                    // the empty track (design-spec §5.4 — "白色圆点").
                    decoration: BoxDecoration(
                      color: AppColors.onPrimary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          );

          if (label == null) return bar;
          return Semantics(
            container: true,
            enabled: onSeek != null,
            label: label,
            value: valueLabel,
            child: ExcludeSemantics(child: bar),
          );
        },
      ),
    );
  }

  /// One 4 dp rounded rail segment of the track.
  Widget _rail({
    required double left,
    required double width,
    required double top,
    required Color color,
  }) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: ReadingPlayer.trackHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(ReadingPlayer.trackHeight / 2),
        ),
      ),
    );
  }
}

/// `.speed-btn` — 42 × 30 pill with a padded 48 dp touch target.
class _SpeedButton extends StatelessWidget {
  const _SpeedButton({
    required this.speed,
    required this.onPressed,
    required this.label,
  });

  final double speed;
  final VoidCallback? onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        minimumSize: const Size(ReadingPlayer.speedMinWidth, ReadingPlayer.speedHeight),
        // The drawn pill stays 30 dp; the padded target keeps the hot zone at
        // 48 dp (design-spec §7.5: 热区 ≥ 44, 按钮容器不可缩小).
        tapTargetSize: MaterialTapTargetSize.padded,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink2,
        disabledBackgroundColor: AppColors.surface,
        disabledForegroundColor: AppColors.ink3,
        side: const BorderSide(color: AppColors.lineStrong),
        textStyle: AppTypography.label.copyWith(letterSpacing: 0),
      ),
      child: Text(
        ReadingPlayer.formatSpeed(speed),
        softWrap: false,
        semanticsLabel: label,
      ),
    );
  }
}
