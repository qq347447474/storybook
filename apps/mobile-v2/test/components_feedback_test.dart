/// Widget tests for the feedback components: `QuizFeedback`, `InlineBar`,
/// `RetellFeedback`, `AppToast`, plus the flow-level `AppDock`.
///
/// These carry the states a learner sees after acting, so the tests pin the
/// triad colours, the highlighted evidence runs, the disabled-CTA reason, the
/// count emphasis and the toast lifetime.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyapp/theme/app_colors.dart';
import 'package:storyapp/theme/app_typography.dart';
import 'package:storyapp/ui/components/app_chip.dart';
import 'package:storyapp/ui/components/app_feedback.dart';
import 'package:storyapp/ui/components/app_toast.dart';
import 'package:storyapp/ui/components/dock_cta.dart';
import 'package:storyapp/ui/components/inline_bar.dart';
import 'package:storyapp/ui/components/retell_feedback.dart';

import 'component_harness.dart';

void main() {
  group('QuizFeedback', () {
    testWidgets('success uses the green triad and the check glyph', (WidgetTester tester) async {
      await pumpInApp(tester, const QuizFeedback.success(title: 'That is right'));

      expect(tester.takeException(), isNull);
      expect(find.text('That is right'), findsOneWidget);
      expect(find.byType(SvgPicture), findsOneWidget);
      final BoxDecoration box = boxOf(tester, find.byType(QuizFeedback)).decoration! as BoxDecoration;
      expect(box.color, AppTones.success.bg);
      expect((box.border! as Border).top.color, AppTones.success.line);
    });

    testWidgets('warning shows evidence with keyword highlights', (WidgetTester tester) async {
      await pumpInApp(
        tester,
        const QuizFeedback.warning(
          title: 'Not quite — re-read the paragraph',
          evidenceLabel: 'From the story',
          evidenceText: 'The girl folded the paper boat and let it go.',
          highlights: <String>['paper boat'],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('From the story'), findsOneWidget);
      final BoxDecoration box = boxOf(tester, find.byType(QuizFeedback)).decoration! as BoxDecoration;
      expect(box.color, AppTones.warning.bg);
      // The <mark> equivalent: the keyword run is brand-coloured.
      expect(hasRun(tester, 'paper boat', AppColors.primary), isTrue);
      // `.evidence p` is 14 px serif italic; of the seven steps the nearest is
      // Body (15), so the quote stays below the heading instead of above it.
      final Text evidence = tester.widget<Text>(
        find.byWidgetPredicate(
          (Widget w) => w is Text && (w.textSpan?.toPlainText().contains('let it go') ?? false),
        ),
      );
      expect(evidence.textSpan!.style!.fontSize, AppTypography.body.fontSize);
      expect(evidence.textSpan!.style!.fontStyle, FontStyle.italic);
      expect(runStyle(tester, 'paper boat')?.fontSize, AppTypography.body.fontSize);
      // The rest of the sentence is still there, unhighlighted.
      expect(find.textContaining('let it go'), findsOneWidget);
    });
  });

  group('InlineBar', () {
    testWidgets('renders copy and fires the optional action', (WidgetTester tester) async {
      int taps = 0;
      await pumpInApp(
        tester,
        InlineBar(
          message: 'The microphone is off. Reading and quiz still work.',
          icon: 'mic-off',
          actionLabel: 'Open settings',
          onAction: () => taps += 1,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SvgPicture), findsOneWidget);
      await tester.tap(find.text('Open settings'));
      expect(taps, 1);
    });

    testWidgets('informational bar has no button', (WidgetTester tester) async {
      await pumpInApp(tester, const InlineBar(message: 'The speech model is not installed.'));

      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('RetellFeedback', () {
    testWidgets('counts points, lists missing chips and runs the actions', (WidgetTester tester) async {
      int replay = 0;
      int again = 0;
      await pumpInApp(
        tester,
        RetellFeedback(
          title: 'You covered 3 of 4 key points',
          missingLabel: 'Can still be added',
          missingPoints: const <String>['the storm', 'the ending'],
          paceLabel: 'Pace:',
          paceText: 'Slow down a little.',
          actions: <AppTextAction>[
            AppTextAction(label: 'Replay', icon: 'volume', onPressed: () => replay += 1),
            AppTextAction(label: 'Try again', icon: 'rotate', onPressed: () => again += 1),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AppChip), findsNWidgets(2));
      expect(hasRun(tester, '3', AppColors.primary), isTrue);
      expect(hasRun(tester, '4', AppColors.primary), isTrue);
      expect(find.textContaining('Pace:'), findsOneWidget);

      await tester.tap(find.text('Replay'));
      await tester.tap(find.text('Try again'));
      expect(replay, 1);
      expect(again, 1);
    });

    testWidgets('hides the chip and pace sections when empty', (WidgetTester tester) async {
      await pumpInApp(tester, const RetellFeedback(title: 'You covered 4 of 4 key points'));

      expect(tester.takeException(), isNull);
      expect(find.byType(AppChip), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });
  });

  group('AppToast', () {
    testWidgets('is a live region on the ink scrim', (WidgetTester tester) async {
      await pumpInApp(tester, const AppToast('Recorded too short'));

      expect(tester.takeException(), isNull);
      expect(
        find.byWidgetPredicate(
          (Widget widget) => widget is Semantics && widget.properties.liveRegion == true,
        ),
        findsOneWidget,
      );
      final BoxDecoration box = boxOf(tester, find.byType(AppToast)).decoration! as BoxDecoration;
      expect(box.color, AppColors.toastScrim);
    });

    testWidgets('appears above the dock, then removes itself', (WidgetTester tester) async {
      await tester.pumpWidget(toastHost('Replaying'));

      await tester.tap(find.text('show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Replaying'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Replaying'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hideAppToast clears it on navigation', (WidgetTester tester) async {
      await tester.pumpWidget(toastHost('Replaying'));

      await tester.tap(find.text('show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Replaying'), findsOneWidget);

      hideAppToast();
      await tester.pump();
      expect(find.text('Replaying'), findsNothing);
    });

    testWidgets('a second call replaces the first toast', (WidgetTester tester) async {
      await tester.pumpWidget(toastPairHost('First', 'Second'));

      await tester.tap(find.text('one'));
      await tester.pump();
      await tester.tap(find.text('two'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('AppDock', () {
    testWidgets('enabled CTA is 56 dp, full width and fires', (WidgetTester tester) async {
      int taps = 0;
      await pumpInApp(
        tester,
        AppDock(
          primaryLabel: 'Next step',
          onPrimaryPressed: () => taps += 1,
          helper: 'Answer recorded',
          helperIsReady: true,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Answer recorded'), findsOneWidget);
      final Size button = tester.getSize(find.byType(FilledButton));
      expect(button.height, 56);
      expect(button.width, 320, reason: 'gutter 20 dp each side of a 360 dp dock');

      await tester.tap(find.text('Next step'));
      expect(taps, 1);
    });

    testWidgets('disabled CTA explains itself through the helper', (WidgetTester tester) async {
      await pumpInApp(
        tester,
        const AppDock(primaryLabel: 'Next step', onPrimaryPressed: null, helper: 'Pick an answer'),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Pick an answer'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    });

    testWidgets('a disabled CTA without a helper asserts', (WidgetTester tester) async {
      // Bound through a variable so the assert runs at runtime instead of
      // failing constant evaluation (a const assert would reject the call).
      final VoidCallback? never = null;

      expect(
        () => AppDock(primaryLabel: 'Next step', onPrimaryPressed: never),
        throwsAssertionError,
      );
    });

    testWidgets('reserves the gesture inset plus 6 dp', (WidgetTester tester) async {
      await pumpInApp(
        tester,
        Builder(
          builder: (BuildContext context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(padding: const EdgeInsets.only(bottom: 34)),
            child: AppDock(primaryLabel: 'Next step', onPrimaryPressed: () {}),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final double gap = tester.getRect(find.byType(AppDock)).bottom -
          tester.getRect(find.byType(FilledButton)).bottom;
      expect(gap, 40);
    });

    testWidgets('secondary action sits under the CTA', (WidgetTester tester) async {
      int taps = 0;
      await pumpInApp(
        tester,
        AppDock(
          primaryLabel: 'Next step',
          onPrimaryPressed: () {},
          action: AppDockAction(label: 'Skip for now', onPressed: () => taps += 1),
        ),
      );

      await tester.tap(find.text('Skip for now'));
      expect(taps, 1);
      expect(
        tester.getRect(find.byType(AppDockAction)).top,
        greaterThanOrEqualTo(tester.getRect(find.byType(FilledButton)).bottom),
      );
    });

    testWidgets('keeps 56 dp at 160 % text scale', (WidgetTester tester) async {
      await pumpScaled(tester, AppDock(primaryLabel: 'Continue', onPrimaryPressed: () {}), 1.6);

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(FilledButton)).height, 56);
    });
  });
}
