/// The hold-to-record key of S5 (design-spec §5.7, `.record-btn`
/// `visual/app.css` L2894-2985).
///
/// A 74 dp key in the fixed retell dock: press and hold to listen, release to
/// stop. The key owns **no** copy and no timer for the take itself — the caller
/// drives [heldSeconds] from its recorder, and the key turns that number into
/// the countdown arc, so the ring can never drift from the audio.
///
/// Callbacks are intentionally narrow: [onHoldEnd] only fires for a hold that
/// reached [minHold] (design-spec §5.7 "录制 < 0.8s 视为太短"), everything
/// shorter goes to [onTooShort]; the caller decides what (if anything) to tell
/// the learner — this widget never shows a toast on its own.
///
/// The state machine lives in `record_button_state.dart`, the paints and the
/// 74 dp skin in `record_button_parts.dart`; both are parts of this library, so
/// the public surface stays one widget and one enum.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyEvent, KeyUpEvent, LogicalKeyboardKey;

import '../../theme/app_colors.dart';
import '../app_icon.dart';

part 'record_button_parts.dart';
part 'record_button_state.dart';

/// The four faces of the key, one per hand-off state (design-spec §5.7).
enum RecordState {
  /// Idle: brand fill, mic glyph — "hold to speak".
  idle,

  /// Listening: red-brown fill, pulse ring, countdown arc, stop glyph.
  recording,

  /// Recognising: ink fill, no ring, ignores press.
  processing,

  /// No recorder behind the key (permission denied, model missing): warm grey,
  /// no ring, ignores press.
  disabled,
}

/// Press-and-hold record key.
///
/// The keyboard mirrors the pointer (design-spec §7.3): Space / Enter press
/// starts the take and their release ends it, Escape abandons it.
class RecordButton extends StatefulWidget {
  const RecordButton({
    super.key,
    required this.state,
    required this.maxSeconds,
    this.heldSeconds = 0,
    this.label,
    this.onHoldStart,
    this.onHoldEnd,
    this.onTooShort,
    this.onTimeout,
    this.minHold = defaultMinHold,
    this.processingProgress,
  })  : assert(maxSeconds > 0, 'RecordButton: maxSeconds must be positive'),
        assert(heldSeconds >= 0, 'RecordButton: heldSeconds cannot be negative'),
        assert(
          processingProgress == null ||
              (processingProgress >= 0 && processingProgress <= 1),
          'RecordButton: processingProgress is a 0..1 fraction',
        );

  /// Current face. Owned by the caller — the key never guesses.
  final RecordState state;

  /// Length of the countdown arc, in seconds.
  ///
  /// The arc is scaled to this value rather than a fixed 30 s: the retell limit
  /// is a content decision, so the ring must follow whatever the caller allows.
  final int maxSeconds;

  /// How much of the take is already recorded, in seconds. Drives the arc.
  final double heldSeconds;

  /// Screen-reader label, e.g. "Hold to record, release to stop".
  final String? label;

  /// A press started — start the recorder here, not in your build method.
  final VoidCallback? onHoldStart;

  /// A press ended after at least [minHold]; the value is the measured hold.
  final ValueChanged<Duration>? onHoldEnd;

  /// The press was shorter than [minHold]; nothing was recorded.
  final VoidCallback? onTooShort;

  /// [heldSeconds] reached [maxSeconds] — stop and process now.
  final VoidCallback? onTimeout;

  /// Shortest press that counts as a take (`.8s`, design-spec §5.7).
  final Duration minHold;

  /// Optional determinate progress of the recognition step, `0..1`. `null`
  /// keeps the plain ink face.
  final double? processingProgress;

  /// `.record-btn { width: 74px; height: 74px }` (app.css L2897).
  static const double size = 74;

  /// `.record-btn::after { inset: -7px }` (app.css L2924) — the ring lives 7 dp
  /// outside the key, so the paint box is 88 dp square.
  static const double ringInset = 7;

  /// Side of the square that holds key, ring and focus ring.
  static const double canvasSize = size + ringInset * 2;

  /// `rec-pulse: 1.4s ease-out infinite` (app.css L2982).
  static const Duration pulseCycle = Duration(milliseconds: 1400);

  /// `transform: scale(1.3)` at the end of the pulse (app.css L2985).
  static const double pulseScale = 1.3;

  /// design-spec §5.7: below 0.8 s the take is discarded.
  static const Duration defaultMinHold = Duration(milliseconds: 800);

  /// `--dur-fast: 150ms` (app.css L84) — press and colour changes.
  static const Duration motion = Duration(milliseconds: 150);

  /// The pulse ring's identity, so a caller (or a test) can assert that reduced
  /// motion really removed it rather than trusting the pixels.
  static const Key pulseKey = ValueKey<String>('record-pulse');

  @override
  State<RecordButton> createState() => _RecordButtonState();
}
