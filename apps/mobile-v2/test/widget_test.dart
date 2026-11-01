import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyapp/main.dart';

void main() {
  testWidgets('T4 smoke: StoryApp builds without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(const StoryApp());
    await tester.pump();
    expect(find.byType(StoryApp), findsOneWidget);
  });

  // Regression for the S0 advisory: the S7 "reduce motion" switch is folded
  // into [MediaQueryData.disableAnimations] *above* [MaterialApp], so a pushed
  // route (S1..S7) must inherit it too — not only the home subtree. Without
  // the hoisted notifier a pushed route kept animating its confetti, flips and
  // transitions (design-spec §2.6).
  testWidgets('reduce motion reaches a pushed route and can be switched back',
      (WidgetTester tester) async {
    // Leave the global flag clean for every later test in this suite.
    addTearDown(() => activeReduceMotion.value = false);

    await tester.pumpWidget(const StoryApp());
    await tester.pump();

    // A zero-size probe that reports the ambient MediaQuery on every build.
    bool? pushedRouteDisablesAnimations;
    final Widget probe = Builder(builder: (BuildContext context) {
      pushedRouteDisablesAnimations = MediaQuery.disableAnimationsOf(context);
      return const SizedBox.shrink();
    });

    final NavigatorState navigator =
        tester.state<NavigatorState>(find.byType(Navigator).first);

    activeReduceMotion.value = true;
    await tester.pump();
    navigator.push<void>(MaterialPageRoute<void>(builder: (_) => probe)).ignore();
    await tester.pump();

    expect(pushedRouteDisablesAnimations, isTrue,
        reason: 'a pushed route must inherit the S7 preference');

    activeReduceMotion.value = false;
    await tester.pump();

    expect(pushedRouteDisablesAnimations, isFalse,
        reason: 'switching reduce motion off must restore route animations');
  });
}
