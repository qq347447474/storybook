/// Widget tests for the vocabulary card: the generic `FlipCard` and the S3
/// `WordCard` content layer on top of it.
///
/// The interesting contracts here are geometric and temporal — the face swaps
/// at 90° rather than at the end, reduced motion collapses the flip to a frame,
/// and the sentence keeps an emphasised run around the target word.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyapp/theme/app_colors.dart';
import 'package:storyapp/ui/app_icon.dart';
import 'package:storyapp/ui/components/app_chip.dart';
import 'package:storyapp/ui/components/flip_card.dart';
import 'package:storyapp/ui/components/word_card.dart';

import 'component_harness.dart';

/// Holds `revealed` the way a screen would, so the card stays controlled.
class _CardHost extends StatefulWidget {
  const _CardHost({required this.revealed, this.disableAnimations = false});

  final bool revealed;
  final bool disableAnimations;

  @override
  State<_CardHost> createState() => _CardHostState();
}

class _CardHostState extends State<_CardHost> {
  late bool _revealed = widget.revealed;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: widget.disableAnimations),
      child: FlipCard(
        revealed: _revealed,
        onToggle: () => setState(() => _revealed = !_revealed),
        front: const Center(child: Text('front')),
        back: const Center(child: Text('back')),
      ),
    );
  }
}

void main() {
  group('FlipCard', () {
    testWidgets('swaps to the back face mid-flip, not at the end', (WidgetTester tester) async {
      await pumpInApp(tester, const _CardHost(revealed: false));

      expect(find.text('front'), findsOneWidget);
      expect(find.text('back'), findsNothing);
      expect(tester.getSize(find.byType(FlipCard)).height, 280);

      await tester.tap(find.byType(FlipCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      // 180 / 320 = 56 % — past 90°, so the back is already the visible face.
      expect(find.text('back'), findsOneWidget);
      expect(find.text('front'), findsNothing);

      await tester.pump(const Duration(milliseconds: 140));
      expect(find.text('back'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion switches the face on the next frame', (WidgetTester tester) async {
      await pumpInApp(tester, const _CardHost(revealed: false, disableAnimations: true));

      await tester.tap(find.byType(FlipCard));
      await tester.pump();
      await tester.pump();

      expect(find.text('back'), findsOneWidget);
      expect(find.text('front'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('announces itself as a toggled button', (WidgetTester tester) async {
      await pumpInApp(
        tester,
        const FlipCard(revealed: true, front: Text('front'), back: Text('back')),
      );

      final Semantics node = tester.widget<Semantics>(
        find.descendant(of: find.byType(FlipCard), matching: find.byType(Semantics)).first,
      );
      expect(node.properties.button, isTrue);
      expect(node.properties.toggled, isTrue);
      expect(find.text('back'), findsOneWidget);
    });
  });

  group('WordCard', () {
    Widget card(bool revealed, {VoidCallback? onSpeak}) => WordCard(
          word: 'tapped',
          phonetic: '/tæpt/',
          partOfSpeech: 'verb',
          revealed: revealed,
          definition: '轻敲；轻叩',
          example: 'The rain tapped on the window.',
          exampleTarget: 'tapped',
          frontHint: 'Tap the card for the meaning',
          backHint: 'Tap to go back',
          // The two faces own their own speaker: the front says the word, the
          // back says the sentence. The helper keeps one knob for both.
          onSpeakWord: onSpeak,
          onSpeakExample: onSpeak,
        );

    testWidgets('front shows word, phonetic, part of speech and the nudge',
        (WidgetTester tester) async {
      await pumpInApp(tester, card(false));

      expect(tester.takeException(), isNull);
      expect(find.text('tapped'), findsOneWidget);
      expect(find.text('/tæpt/'), findsOneWidget);
      expect(find.text('verb'), findsOneWidget);
      expect(find.text('Tap the card for the meaning'), findsOneWidget);
      expect(find.text('Tap to go back'), findsNothing);
      expect(tester.widget<AppChip>(find.byType(AppChip)).variant, AppChipVariant.level);
      expect(iconNamed('speaker'), findsOneWidget);
      expect(iconNamed('rotate'), findsOneWidget);
      expect(tester.getSize(find.byType(WordCard)), const Size(360, 280));
    });

    testWidgets('front word is 34 dp serif; back meaning uses the body step',
        (WidgetTester tester) async {
      await pumpInApp(tester, card(false));
      final TextStyle front = tester.widget<Text>(find.text('tapped')).style!;
      expect(front.fontSize, 34);
      expect(front.fontFamily, 'serif');

      await pumpInApp(tester, card(true));
      final TextStyle back = tester.widget<Text>(find.text('轻敲；轻叩')).style!;
      expect(back.fontSize, 15);
    });

    testWidgets('back shows the meaning and keeps the sentence, word picked out',
        (WidgetTester tester) async {
      await pumpInApp(tester, card(true));

      expect(tester.takeException(), isNull);
      expect(find.text('轻敲；轻叩'), findsOneWidget);
      expect(find.textContaining('on the window'), findsOneWidget);
      expect(find.text('Tap to go back'), findsOneWidget);
      // The target word inside the quote is brand-coloured (§5.6).
      expect(hasRun(tester, 'tapped', AppColors.primary), isTrue);
    });

    testWidgets('a missing speech callback dims the speaker instead of hiding it',
        (WidgetTester tester) async {
      await pumpInApp(tester, card(true));

      expect(
        find.byWidgetPredicate(
          (Widget w) => w is Opacity && w.opacity == WordCard.audioDisabledOpacity,
        ),
        findsOneWidget,
      );
      expect(iconNamed('speaker'), findsOneWidget);
      expect(tester.widget<InkWell>(find.byType(InkWell).first).onTap, isNull);
      expect(tester.widget<AppIcon>(iconNamed('speaker')).color, AppColors.ink3);
    });

    testWidgets('survives a 160 % text scale without overflowing', (WidgetTester tester) async {
      await pumpScaled(tester, card(true), 1.6);

      // The faces scroll inside their fixed footprint instead of overflowing
      // (design-spec §6.4 allows text up to 150 %).
      expect(tester.takeException(), isNull);
      expect(find.text('轻敲；轻叩'), findsOneWidget);
    });

    testWidgets('speaking is a 44 dp target on the front face', (WidgetTester tester) async {
      int speaks = 0;
      await pumpInApp(tester, card(false, onSpeak: () => speaks += 1));

      final Finder button = find.ancestor(
        of: iconNamed('speaker'),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(button), const Size(44, 44));

      await tester.tap(button);
      expect(speaks, 1);
      // The tap must not also flip the card.
      expect(find.text('tapped'), findsOneWidget);
      expect(find.text('轻敲；轻叩'), findsNothing);
    });
  });
}
