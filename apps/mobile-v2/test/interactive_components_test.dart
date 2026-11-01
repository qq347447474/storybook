/// Widget tests for `ReadingPlayer` and `OptionRow` — the two interactive
/// components that carry a *measurement* contract: which fraction a tap hands
/// back, which recipes the five option states paint, and what the disabled gate
/// does to both.
///
/// The card family (`FlipCard`, `WordCard`) lives in `word_card_test.dart` so
/// each suite stays inside the 300-line budget.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyapp/theme/app_colors.dart';
import 'package:storyapp/ui/app_icon.dart';
import 'package:storyapp/ui/components/option_row.dart';
import 'package:storyapp/ui/components/reading_player.dart';

import 'component_harness.dart';

/// The seek track, found through the label its screen-reader node carries.
final Finder _seekTrack = find.byWidgetPredicate(
  (Widget w) => w is Semantics && w.properties.label == 'Seek',
);

/// The row's own `Material`: where its fill and hairline are painted.
Material _rowSurface(WidgetTester tester, String key) => tester.widget<Material>(
      find
          .descendant(of: find.byKey(ValueKey<String>(key)), matching: find.byType(Material))
          .first,
    );

Color _rowBorder(WidgetTester tester, String key) =>
    (_rowSurface(tester, key).shape! as RoundedRectangleBorder).side.color;

void main() {
  group('ReadingPlayer', () {
    test('formats m:ss and the four speed labels', () {
      expect(ReadingPlayer.formatTime(Duration.zero), '0:00');
      expect(ReadingPlayer.formatTime(const Duration(seconds: 7)), '0:07');
      expect(ReadingPlayer.formatTime(const Duration(minutes: 2, seconds: 5)), '2:05');
      expect(ReadingPlayer.formatTime(const Duration(seconds: -3)), '0:00');

      expect(ReadingPlayer.formatSpeed(0.75), '0.75×');
      expect(ReadingPlayer.formatSpeed(1), '1×');
      expect(ReadingPlayer.formatSpeed(1.25), '1.25×');
      expect(ReadingPlayer.formatSpeed(1.5), '1.5×');

      // A zero-length clip and an overrun must neither divide by zero nor
      // push the knob past the track.
      expect(ReadingPlayer.fractionOf(const Duration(seconds: 19), const Duration(seconds: 38)), 0.5);
      expect(ReadingPlayer.fractionOf(const Duration(seconds: 99), const Duration(seconds: 38)), 1.0);
      expect(ReadingPlayer.fractionOf(const Duration(seconds: 5), Duration.zero), 0);
    });

    testWidgets('paused shows play, both times and the current speed', (WidgetTester tester) async {
      await pumpInApp(
        tester,
        const ReadingPlayer(
          position: Duration.zero,
          duration: Duration(seconds: 38),
          isPlaying: false,
          speed: 1,
          playLabel: 'Play',
        ),
      );

      expect(tester.takeException(), isNull);
      expect(iconNamed('play'), findsOneWidget);
      expect(iconNamed('pause'), findsNothing);
      expect(tester.getSize(find.byType(FilledButton).first), const Size(46, 46));
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('0:38'), findsOneWidget);
      expect(find.text('1×'), findsOneWidget);
      expect(find.bySemanticsLabel('Play'), findsOneWidget);
    });

    testWidgets('playing swaps the glyph and the button reports the tap', (WidgetTester tester) async {
      int toggles = 0;
      await pumpInApp(
        tester,
        ReadingPlayer(
          position: const Duration(seconds: 12),
          duration: const Duration(seconds: 38),
          isPlaying: true,
          speed: 1.25,
          onPlayPause: () => toggles += 1,
        ),
      );

      expect(iconNamed('pause'), findsOneWidget);
      expect(iconNamed('play'), findsNothing);
      expect(find.text('0:12'), findsOneWidget);
      expect(find.text('1.25×'), findsOneWidget);

      await tester.tap(find.byType(FilledButton).first);
      expect(toggles, 1);
    });

    testWidgets('tapping and dragging the track seek by fraction', (WidgetTester tester) async {
      final List<double> seeks = <double>[];
      await pumpInApp(
        tester,
        ReadingPlayer(
          position: Duration.zero,
          duration: const Duration(seconds: 40),
          isPlaying: false,
          speed: 1,
          seekLabel: 'Seek',
          onSeek: seeks.add,
        ),
      );

      final Rect rect = tester.getRect(_seekTrack);
      await tester.tapAt(rect.center);
      expect(seeks.last, closeTo(0.5, 0.02));

      seeks.clear();
      final TestGesture gesture = await tester.startGesture(rect.centerLeft + const Offset(2, 0));
      await gesture.moveBy(Offset(rect.width / 2, 0));
      await gesture.up();
      expect(seeks.last, closeTo(0.5, 0.06));
    });

    testWidgets('disabled dims both buttons and refuses to seek', (WidgetTester tester) async {
      int plays = 0;
      final List<double> seeks = <double>[];
      await pumpInApp(
        tester,
        ReadingPlayer(
          position: Duration.zero,
          duration: const Duration(seconds: 40),
          isPlaying: false,
          speed: 1,
          enabled: false,
          seekLabel: 'Seek',
          onPlayPause: () => plays += 1,
          onSeek: seeks.add,
        ),
      );

      expect(
        find.byWidgetPredicate(
          (Widget w) => w is Opacity && w.opacity == ReadingPlayer.disabledOpacity,
        ),
        findsNWidgets(2),
      );

      await tester.tap(find.byType(FilledButton).first, warnIfMissed: false);
      await tester.tap(_seekTrack, warnIfMissed: false);
      expect(plays, 0);
      expect(seeks, isEmpty);

      // Nothing is a button and nothing can be dragged: the track reports
      // `enabled: false`, the play button loses its callback.
      expect(tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed, isNull);
      expect(tester.widget<Semantics>(_seekTrack).properties.enabled, isFalse);
      expect(tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed, isNull);
    });
  });

  group('OptionRow', () {
    const Map<String, OptionVisualState> states = <String, OptionVisualState>{
      'idle': OptionVisualState.idle,
      'selected': OptionVisualState.selected,
      'correct': OptionVisualState.correct,
      'wrong': OptionVisualState.wrong,
      'dimmed': OptionVisualState.dimmed,
    };

    Widget rows({VoidCallback? onTap}) => Column(
          children: <Widget>[
            for (final MapEntry<String, OptionVisualState> entry in states.entries)
              OptionRow(
                key: ValueKey<String>(entry.key),
                letter: entry.key.substring(0, 1).toUpperCase(),
                // Short on purpose: the test font is monospaced-square, so a
                // long sentence would wrap and grow the row past its 52 dp.
                text: 'A paper boat.',
                state: entry.value,
                onTap: onTap,
              ),
          ],
        );

    testWidgets('five recipes: fill, hairline and the result glyph', (WidgetTester tester) async {
      await pumpInApp(tester, rows());

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(OptionRow).first).height, 52);

      expect(_rowSurface(tester, 'idle').color, AppColors.surface);
      expect(_rowBorder(tester, 'idle'), AppColors.line);

      expect(_rowSurface(tester, 'selected').color, AppColors.primarySoft);
      expect(_rowBorder(tester, 'selected'), AppColors.primary);

      // Correct / wrong carry a glyph as well as a triad (§7.2).
      expect(_rowSurface(tester, 'correct').color, AppColors.successBg);
      expect(_rowBorder(tester, 'correct'), AppColors.successLine);
      expect(_rowSurface(tester, 'wrong').color, AppColors.dangerBg);
      expect(_rowBorder(tester, 'wrong'), AppColors.dangerLine);
      expect(iconNamed('check'), findsOneWidget);
      expect(iconNamed('close'), findsOneWidget);

      // Dimmed is the idle recipe at 52 %, not a sixth palette row.
      expect(_rowSurface(tester, 'dimmed').color, AppColors.surface);
      expect(
        find.byWidgetPredicate(
          (Widget w) => w is Opacity && w.opacity == OptionRow.dimmedOpacity,
        ),
        findsOneWidget,
      );
    });

    testWidgets('reports selection, fires the tap, and locks when inert', (WidgetTester tester) async {
      int taps = 0;
      await pumpInApp(tester, rows(onTap: () => taps += 1));

      final Semantics answered = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byKey(const ValueKey<String>('correct')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(answered.properties.button, isTrue);
      expect(answered.properties.selected, isTrue);
      expect(answered.properties.enabled, isTrue);

      final Semantics untouched = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byKey(const ValueKey<String>('idle')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(untouched.properties.selected, isFalse);

      await tester.tap(find.byKey(const ValueKey<String>('idle')));
      expect(taps, 1);

      // Post-answer lock (design-spec §5.5): no callback, no tap.
      await pumpInApp(tester, rows());
      expect(tester.widget<InkWell>(find.byType(InkWell).first).onTap, isNull);
    });

    testWidgets('letter and text come from the type scale', (WidgetTester tester) async {
      await pumpInApp(tester, rows());

      expect(tester.widget<Text>(find.text('I')).style!.fontSize, 11);
      expect(tester.widget<Text>(find.textContaining('paper boat').first).style!.fontSize, 15);
      expect(tester.widget<AppIcon>(iconNamed('check')).size, OptionRow.radioIconSize);
    });
  });
}
