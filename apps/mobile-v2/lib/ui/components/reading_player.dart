/// Reading audio player (design-spec §5.4, `.player` app.css L1706-1845).
///
/// Presentation only: it renders the state it is given and reports gestures up.
/// The audio service, the speed list and the seeking policy live in the screen /
/// controller, so this widget can be tested and re-used by S2 (reading) and S5
/// (retell replay) without touching a plugin.
///
/// Geometry comes straight from the hand-off:
///
/// | part    | hand-off                       | here                            |
/// | ------- | ------------------------------ | ------------------------------- |
/// | play    | 46 dp circle, 20 dp glyph       | [playSize] / [playIconSize]      |
/// | track   | 18 dp hit area, 4 dp fill       | [trackHitHeight], [trackHeight]  |
/// | knob    | 10 dp dot                       | [knobSize]                       |
/// | speed   | 42 × 30 pill, ≥ 44 dp hot zone  | [speedMinWidth], [speedHeight]   |
///
/// The three controls live in `reading_player_controls.dart`, a part of this
/// library: they are implementation detail, so they stay private (`_Play…`)
/// while each file stays inside the 300-line budget.
library;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../app_icon.dart';

part 'reading_player_controls.dart';

/// Play / pause, a draggable seek track, the elapsed and total time, and the
/// speed cycle button.
class ReadingPlayer extends StatelessWidget {
  const ReadingPlayer({
    super.key,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.speed,
    this.onPlayPause,
    this.onSeek,
    this.onSpeedCycle,
    this.enabled = true,
    this.playLabel,
    this.pauseLabel,
    this.speedLabel,
    this.seekLabel,
  });

  /// Elapsed time. Clamped to `0..duration` when the fraction is computed.
  final Duration position;

  /// Total length of the clip. A zero length renders an empty track instead of
  /// dividing by zero.
  final Duration duration;

  /// Which of the two glyphs the play button shows.
  final bool isPlaying;

  /// Playback rate. The widget formats whatever it is given — the list of
  /// allowed rates (0.75 / 1 / 1.25 / 1.5) belongs to the caller.
  final double speed;

  /// Fired by the play button. `null` leaves the button inert.
  final VoidCallback? onPlayPause;

  /// Fired with the requested position as a `0..1` fraction of [duration].
  final ValueChanged<double>? onSeek;

  /// Fired by the speed pill; the caller advances to its next rate.
  final VoidCallback? onSpeedCycle;

  /// Master switch for the disabled state: dims both buttons, stops seek and
  /// reports `enabled: false` to the screen reader. Used when the clip is
  /// missing (design-spec §5.4: "音频缺失：禁用播放键").
  final bool enabled;

  /// Screen-reader labels. Never hard-coded here — a player without a label is
  /// still usable by sight, so they stay optional.
  final String? playLabel;
  final String? pauseLabel;
  final String? speedLabel;
  final String? seekLabel;

  /// `.play-btn { width: 46px; height: 46px }` (app.css L1723).
  static const double playSize = 46;

  /// `.play-btn svg { width: 20px }` (app.css L1750).
  static const double playIconSize = AppIconSize.md;

  /// `.player-track { height: 18px }` (app.css L1775).
  static const double trackHitHeight = 18;

  /// `.player-fill { height: 4px }` (app.css L1791).
  static const double trackHeight = 4;

  /// `.player-fill::after { width: 10px }` (app.css L1803).
  static const double knobSize = 10;

  /// `.speed-btn { min-width: 42px; height: 30px }` (app.css L1823-1824).
  static const double speedMinWidth = 42;
  static const double speedHeight = 30;

  /// `.speed-btn:disabled { opacity: .5 }` (app.css L1838); the play button
  /// dims by the same mechanism so one number drives both.
  static const double disabledOpacity = 0.45;

  /// `.player { padding: 10px 12px 10px 10px; gap: 12px }` (app.css L1709-1710).
  static const EdgeInsets padding = EdgeInsets.fromLTRB(10, 10, 12, 10);
  static const double gap = 12;

  /// `.player { border-radius: 19px }` (app.css L1713).
  static const double radius = 19;

  /// `.player-times { margin-top: 2px }` (app.css L1814).
  static const double _timesGap = 2;

  /// `m:ss` — the hand-off never pads the minute (`0:07`, `2:05`).
  static String formatTime(Duration value) {
    final int seconds = value.inSeconds < 0 ? 0 : value.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  /// `0.75×`, `1×`, `1.25×`, `1.5×` — trailing zeros dropped, `×` appended.
  static String formatSpeed(double value) {
    if (value == value.truncateToDouble()) return '${value.toStringAsFixed(0)}×';
    return '${value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')}×';
  }

  /// Elapsed fraction, safe for a zero-length clip and for a position that has
  /// drifted past the end.
  static double fractionOf(Duration position, Duration duration) {
    final int total = duration.inMilliseconds;
    if (total <= 0) return 0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle time = AppTypography.tabular(
      AppTypography.meta.copyWith(color: AppColors.ink3),
    );

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: <Widget>[
          Opacity(
            opacity: enabled ? 1 : disabledOpacity,
            child: _PlayButton(
              isPlaying: isPlaying,
              onPressed: enabled ? onPlayPause : null,
              label: isPlaying ? pauseLabel : playLabel,
            ),
          ),
          const SizedBox(width: gap),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _SeekBar(
                  fraction: fractionOf(position, duration),
                  onSeek: enabled ? onSeek : null,
                  label: seekLabel,
                  valueLabel: '${formatTime(position)} / ${formatTime(duration)}',
                ),
                const SizedBox(height: _timesGap),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(formatTime(position), style: time),
                    Text(formatTime(duration), style: time),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: gap),
          Opacity(
            opacity: enabled ? 1 : disabledOpacity,
            child: _SpeedButton(
              speed: speed,
              onPressed: enabled ? onSpeedCycle : null,
              label: speedLabel,
            ),
          ),
        ],
      ),
    );
  }
}
