/// Behaviour of [RecordButton]: press lifecycle, hold measurement, the timeout
/// latch, the pulse controller and the keyboard mirror of the pointer.
///
/// A part of `record_button.dart` — the state class is meaningless on its own
/// and must stay private, so it does not earn a library of its own.
part of 'record_button.dart';

class _RecordButtonState extends State<RecordButton>
    with TickerProviderStateMixin {
  /// Measured hold. A [Ticker] rather than a `Stopwatch` on purpose: it is
  /// driven by frame timestamps, so it reports the same number the learner sees
  /// on screen and a widget test can advance it with `pump`.
  late final Ticker _holdTicker = createTicker(_onTick);
  Duration _held = Duration.zero;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: RecordButton.pulseCycle,
  );

  final FocusNode _focusNode = FocusNode(debugLabel: 'RecordButton');

  bool _pressed = false;
  bool _keyDown = false;
  bool _focused = false;

  /// Set once per take when [RecordButton.heldSeconds] reaches the limit, so the
  /// limit fires once and the release that follows does not report a second
  /// end.
  bool _timedOut = false;

  /// Only an idle key starts a take: processing and disabled ignore the press.
  bool get _acceptsPress => widget.state == RecordState.idle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Also the first frame: this runs before the first build, one step after
    // `initState`, where reading `MediaQuery` is still illegal.
    _syncPulse();
  }

  @override
  void didUpdateWidget(RecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != RecordState.recording) {
      _timedOut = false;
    } else if (!_timedOut && widget.heldSeconds >= widget.maxSeconds) {
      _timedOut = true;
      // The caller reacts by switching state, and a synchronous callback would
      // rebuild it in the middle of this frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _timedOut) widget.onTimeout?.call();
      });
    }
    _syncPulse();
  }

  @override
  void dispose() {
    _holdTicker.dispose();
    _pulse.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) => _held = elapsed;

  /// Starts or stops the pulse so reduced motion (design-spec §6.6) never leaves
  /// an animating controller behind — a stopped controller cannot keep the
  /// frame loop awake.
  void _syncPulse() {
    final bool want = widget.state == RecordState.recording &&
        !MediaQuery.disableAnimationsOf(context);
    if (want == _pulse.isAnimating) return;
    if (want) {
      _pulse.repeat();
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  void _beginHold() {
    if (!_acceptsPress || _pressed) return;
    setState(() {
      _pressed = true;
      _held = Duration.zero;
    });
    _holdTicker.start();
    widget.onHoldStart?.call();
  }

  /// Ends the press and reports it.
  ///
  /// A pointer cancel (the page scrolled instead, the app lost focus) and Escape
  /// both arrive here as a release: the caller was already told to start
  /// recording in [RecordButton.onHoldStart], so dropping the press silently
  /// would leave a recorder running with no key held — the "ghost recording"
  /// design-spec §4.6 forbids.
  void _endHold() {
    if (!_pressed) return;
    final Duration held = _held;
    _holdTicker.stop();
    setState(() => _pressed = false);

    // A take the caller already closed (limit reached, or the state moved on)
    // must not be ended twice.
    if (_timedOut) return;
    if (widget.state != RecordState.idle &&
        widget.state != RecordState.recording) {
      return;
    }
    if (held < widget.minHold) {
      widget.onTooShort?.call();
      return;
    }
    widget.onHoldEnd?.call(held);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final bool activation = event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;

    if (activation) {
      if (event is KeyDownEvent && !_keyDown) {
        _keyDown = true;
        _beginHold();
      } else if (event is KeyUpEvent && _keyDown) {
        _keyDown = false;
        _endHold();
      }
      // Key repeat is swallowed: a held key is one press, not sixty.
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _pressed) {
      _endHold();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    final bool pulsing = widget.state == RecordState.recording &&
        !reduced &&
        _pulse.isAnimating;

    return Semantics(
      button: true,
      enabled: widget.state != RecordState.disabled &&
          widget.state != RecordState.processing,
      label: widget.label,
      child: Focus(
        focusNode: _focusNode,
        onFocusChange: (bool focused) => setState(() => _focused = focused),
        onKeyEvent: _onKey,
        child: SizedBox(
          width: RecordButton.canvasSize,
          height: RecordButton.canvasSize,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              if (pulsing) _PulseRing(key: RecordButton.pulseKey, pulse: _pulse),
              IgnorePointer(
                child: CustomPaint(
                  size: const Size.square(RecordButton.canvasSize),
                  painter: _RecordRingPainter(
                    state: widget.state,
                    fraction: (widget.heldSeconds / widget.maxSeconds)
                        .clamp(0.0, 1.0)
                        .toDouble(),
                    focused: _focused,
                    processingProgress: widget.processingProgress,
                  ),
                ),
              ),
              _RecordKey(
                state: widget.state,
                pressed: _pressed,
                reducedMotion: reduced,
                onPressStart: _acceptsPress ? _beginHold : null,
                // A take in progress keeps its release handler: the caller
                // flips the key to `recording` the moment the press starts, and
                // dropping `onTapUp` then would orphan the pointer-up — the key
                // would never hear the end of its own take.
                onPressEnd: (_acceptsPress || _pressed) ? _endHold : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
