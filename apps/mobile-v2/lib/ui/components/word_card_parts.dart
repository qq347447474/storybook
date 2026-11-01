/// The shell widgets of [WordCard]: the card surface, the dashed nudge rule,
/// the example box and the speaker button.
///
/// A part of `word_card.dart` on purpose — they share that library's private
/// style tokens (`_definitionStyle`, `_hintStyle`) and are meaningless outside
/// the card, so keeping them here keeps the public API to one widget.
part of 'word_card.dart';

/// `.flip-face`: `surface` fill, `--line` hairline, `--r-xl` corners.
///
/// The face is a fixed footprint, so its content is laid out inside a scroll
/// view that is at least as tall as the card: at the default text scale
/// everything fits and the `Spacer`s in the faces behave normally, while at a
/// large scale the content scrolls instead of overflowing (design-spec §6.4
/// allows text up to 150 %).
class _Face extends StatelessWidget {
  const _Face({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(child: child),
            ),
          );
        },
      ),
    );
  }
}

/// `.flip-nudge`: dashed rule, then a 14 dp glyph and the hint.
class _Nudge extends StatelessWidget {
  const _Nudge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(
          height: 1,
          child: CustomPaint(painter: DashedLinePainter(color: AppColors.line)),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const AppIcon('rotate', size: 14, color: AppColors.ink3),
            const SizedBox(width: 7),
            Flexible(
              child: Text(text, style: _hintStyle, textAlign: TextAlign.center),
            ),
          ],
        ),
      ],
    );
  }
}

/// `.example-box` — `surface-sunken` plate with the target word picked out,
/// optionally under a micro label (`.example-label`).
class _ExampleBox extends StatelessWidget {
  const _ExampleBox({required this.text, required this.label, required this.target});

  final String text;
  final String? label;
  final String? target;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (label != null) ...<Widget>[
            // `.example-label`: 700 label step, 0.14em, accent-strong.
            Text(
              label!,
              style: AppTypography.label.copyWith(
                color: AppColors.accentStrong,
                letterSpacing: 0.14 * 11,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text.rich(
            TextSpan(style: _exampleStyle, children: _spans(text, target)),
          ),
        ],
      ),
    );
  }
}

/// A circular speaker button; dims itself when [onPressed] is null.
///
/// [size] is the drawn circle, [tapTarget] the area that actually answers a
/// finger. The hand-off draws the back-face speaker at 36 dp, but design-spec
/// §7.5 is a red line — "热区 ≥ 44,图标可 20–24dp,但按钮容器不可缩小" — so the
/// back face keeps its 36 dp circle and grows an invisible 44 dp hot zone
/// around it. The visible ripple still runs inside the 36 dp circle: the two
/// tap handlers share one callback and the inner `InkWell` wins the gesture
/// arena, so a tap can never fire twice.
class _AudioButton extends StatelessWidget {
  const _AudioButton({
    required this.size,
    required this.onPressed,
    required this.label,
    this.tapTarget,
  });

  final double size;
  final VoidCallback? onPressed;
  final String? label;

  /// Hot-zone edge length; defaults to [size] (no invisible padding).
  final double? tapTarget;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final double target = math.max(size, tapTarget ?? size);

    final Widget circle = SizedBox(
      width: size,
      height: size,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(side: BorderSide(color: AppColors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Center(
            child: AppIcon(
              'speaker',
              // `.audio-btn svg { width: 18px }` (app.css L2052).
              size: 18,
              color: enabled ? AppColors.primary : AppColors.ink3,
              semanticLabel: label,
            ),
          ),
        ),
      ),
    );

    if (target <= size) {
      return Opacity(
        opacity: enabled ? 1 : WordCard.audioDisabledOpacity,
        child: circle,
      );
    }

    return Opacity(
      opacity: enabled ? 1 : WordCard.audioDisabledOpacity,
      child: SizedBox(
        width: target,
        height: target,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // The transparent margin of the hot zone answers the finger.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTap: onPressed,
              ),
            ),
            circle,
          ],
        ),
      ),
    );
  }
}

/// `.example-box p`: serif italic 400 — Body size, serif family.
final TextStyle _exampleStyle = AppTypography.body.copyWith(
  fontFamily: AppTypography.serifFamily,
  fontFamilyFallback: AppTypography.serifFallback,
  fontStyle: FontStyle.italic,
  height: 1.55,
  color: AppColors.ink,
);

/// Splits [text] into plain runs and one emphasised run around [target].
///
/// Literal, case-insensitive matching: the target comes from story content, so
/// a regex metacharacter must never change what gets highlighted. The first
/// occurrence only — a flashcard quotes one sentence, not a concordance.
List<TextSpan> _spans(String text, String? target) {
  final String needle = target?.trim() ?? '';
  if (needle.isEmpty) return <TextSpan>[TextSpan(text: text)];

  final int at = text.toLowerCase().indexOf(needle.toLowerCase());
  if (at < 0) return <TextSpan>[TextSpan(text: text)];

  final TextStyle mark = _exampleStyle.copyWith(
    color: AppColors.primary,
    fontWeight: FontWeight.w700,
    fontStyle: FontStyle.normal,
  );
  return <TextSpan>[
    if (at > 0) TextSpan(text: text.substring(0, at)),
    TextSpan(text: text.substring(at, at + needle.length), style: mark),
    if (at + needle.length < text.length)
      TextSpan(text: text.substring(at + needle.length)),
  ];
}
